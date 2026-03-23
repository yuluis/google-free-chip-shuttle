// ---------------------------------------------------------------------------
// uart_host_bridge.sv — v2.4 UART serial command decoder
//
// Protocol (115200 8N1):
//   Write: 'W' addr[7:0] data[31:24] data[23:16] data[15:8] data[7:0] → 'A'
//   Read:  'R' addr[7:0] → 'D' data[31:24] data[23:16] data[15:8] data[7:0]
//   Status:'S' → 'S' status[31:24..7:0]  (shortcut: reads GLOBAL_STATUS)
//   Reset: 'X' → 'A'  (triggers software reset)
//
// Address is 8-bit offset within the currently selected bank.
// Bank is set via BANK_SELECT register (bank 0, offset 0x04).
// ---------------------------------------------------------------------------
module uart_host_bridge
#(
  parameter int CLK_FREQ  = 50_000_000,
  parameter int BAUD_RATE = 115_200
)(
  input  logic        clk,
  input  logic        rst_n,

  // UART pins
  input  logic        uart_rx,
  output logic        uart_tx,

  // Register bus
  output logic        reg_wr,
  output logic        reg_rd,
  output logic [7:0]  reg_addr,
  output logic [31:0] reg_wdata,
  input  logic [31:0] reg_rdata,
  input  logic        reg_rvalid
);

  // -----------------------------------------------------------------------
  // Baud rate generator
  // -----------------------------------------------------------------------
  localparam int BAUD_DIV = CLK_FREQ / BAUD_RATE;

  logic [$clog2(BAUD_DIV)-1:0] baud_cnt;
  logic baud_tick;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baud_cnt  <= '0;
      baud_tick <= 1'b0;
    end else begin
      baud_tick <= 1'b0;
      if (baud_cnt == BAUD_DIV[$clog2(BAUD_DIV)-1:0] - 1) begin
        baud_cnt  <= '0;
        baud_tick <= 1'b1;
      end else begin
        baud_cnt <= baud_cnt + 1;
      end
    end
  end

  // -----------------------------------------------------------------------
  // UART RX — 8N1 receiver
  // -----------------------------------------------------------------------
  logic [3:0]  rx_bit_cnt;
  logic [$clog2(BAUD_DIV)-1:0] rx_baud_cnt;
  logic [7:0]  rx_shift;
  logic        rx_busy;
  logic        rx_done;
  logic [7:0]  rx_data;
  logic        rx_sync1, rx_sync2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_sync1 <= 1'b1;
      rx_sync2 <= 1'b1;
    end else begin
      rx_sync1 <= uart_rx;
      rx_sync2 <= rx_sync1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_busy     <= 1'b0;
      rx_bit_cnt  <= '0;
      rx_baud_cnt <= '0;
      rx_shift    <= '0;
      rx_done     <= 1'b0;
      rx_data     <= '0;
    end else begin
      rx_done <= 1'b0;

      if (!rx_busy) begin
        if (!rx_sync2) begin
          rx_busy     <= 1'b1;
          rx_bit_cnt  <= '0;
          rx_baud_cnt <= BAUD_DIV[$clog2(BAUD_DIV)-1:0] / 2;
        end
      end else begin
        if (rx_baud_cnt == BAUD_DIV[$clog2(BAUD_DIV)-1:0] - 1) begin
          rx_baud_cnt <= '0;
          if (rx_bit_cnt == 4'd8) begin
            rx_busy <= 1'b0;
            rx_done <= 1'b1;
            rx_data <= rx_shift;
          end else begin
            rx_shift[rx_bit_cnt[2:0]] <= rx_sync2;
            rx_bit_cnt <= rx_bit_cnt + 1;
          end
        end else begin
          rx_baud_cnt <= rx_baud_cnt + 1;
        end
      end
    end
  end

  // -----------------------------------------------------------------------
  // UART TX — 8N1 transmitter
  // -----------------------------------------------------------------------
  logic [3:0]  tx_bit_cnt;
  logic [$clog2(BAUD_DIV)-1:0] tx_baud_cnt;
  logic [9:0]  tx_shift;
  logic        tx_busy;
  logic        tx_start;
  logic [7:0]  tx_data;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_busy     <= 1'b0;
      tx_bit_cnt  <= '0;
      tx_baud_cnt <= '0;
      tx_shift    <= 10'h3FF;
      uart_tx     <= 1'b1;
    end else if (tx_start && !tx_busy) begin
      tx_shift    <= {1'b1, tx_data, 1'b0};
      tx_busy     <= 1'b1;
      tx_bit_cnt  <= '0;
      tx_baud_cnt <= '0;
      uart_tx     <= 1'b0;
    end else if (tx_busy) begin
      if (tx_baud_cnt == BAUD_DIV[$clog2(BAUD_DIV)-1:0] - 1) begin
        tx_baud_cnt <= '0;
        tx_bit_cnt  <= tx_bit_cnt + 1;
        if (tx_bit_cnt == 4'd9) begin
          tx_busy <= 1'b0;
          uart_tx <= 1'b1;
        end else begin
          uart_tx <= tx_shift[tx_bit_cnt + 1];
        end
      end else begin
        tx_baud_cnt <= tx_baud_cnt + 1;
      end
    end
  end

  // -----------------------------------------------------------------------
  // Command state machine
  // -----------------------------------------------------------------------
  typedef enum logic [3:0] {
    ST_IDLE,
    ST_WRITE_ADDR,
    ST_WRITE_D3,
    ST_WRITE_D2,
    ST_WRITE_D1,
    ST_WRITE_D0,
    ST_WRITE_EXEC,
    ST_WRITE_ACK,
    ST_READ_ADDR,
    ST_READ_EXEC,
    ST_READ_WAIT,
    ST_READ_RESP,
    ST_STATUS_EXEC,
    ST_RESET_EXEC,
    ST_RESET_ACK
  } cmd_state_t;

  cmd_state_t state;
  logic [7:0]  cmd_addr;
  logic [31:0] cmd_wdata;
  logic [31:0] cmd_rdata_buf;
  logic [1:0]  resp_byte_idx;

  // Register bus drives
  assign reg_wr    = (state == ST_WRITE_EXEC) || (state == ST_RESET_EXEC);
  assign reg_rd    = (state == ST_READ_EXEC) || (state == ST_STATUS_EXEC);
  assign reg_addr  = (state == ST_STATUS_EXEC) ? 8'h0C :   // 'S' reads GLOBAL_STATUS
                     (state == ST_RESET_EXEC)  ? 8'h5C :   // 'X' writes SOFTWARE_RESET
                     cmd_addr;
  assign reg_wdata = (state == ST_RESET_EXEC) ? 32'hDEAD : cmd_wdata;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= ST_IDLE;
      cmd_addr      <= '0;
      cmd_wdata     <= '0;
      cmd_rdata_buf <= '0;
      resp_byte_idx <= '0;
      tx_start      <= 1'b0;
      tx_data       <= '0;
    end else begin
      tx_start <= 1'b0;

      case (state)
        ST_IDLE: begin
          if (rx_done) begin
            case (rx_data)
              "W":     state <= ST_WRITE_ADDR;
              "R":     state <= ST_READ_ADDR;
              "S":     state <= ST_STATUS_EXEC;
              "X":     state <= ST_RESET_EXEC;
              default: state <= ST_IDLE;
            endcase
          end
        end

        // ---- Write: W addr D3 D2 D1 D0 → A ----
        ST_WRITE_ADDR: if (rx_done) begin cmd_addr <= rx_data; state <= ST_WRITE_D3; end
        ST_WRITE_D3:   if (rx_done) begin cmd_wdata[31:24] <= rx_data; state <= ST_WRITE_D2; end
        ST_WRITE_D2:   if (rx_done) begin cmd_wdata[23:16] <= rx_data; state <= ST_WRITE_D1; end
        ST_WRITE_D1:   if (rx_done) begin cmd_wdata[15:8]  <= rx_data; state <= ST_WRITE_D0; end
        ST_WRITE_D0:   if (rx_done) begin cmd_wdata[7:0]   <= rx_data; state <= ST_WRITE_EXEC; end

        ST_WRITE_EXEC: state <= ST_WRITE_ACK;

        ST_WRITE_ACK: begin
          if (!tx_busy) begin
            tx_start <= 1'b1;
            tx_data  <= "A";
            state    <= ST_IDLE;
          end
        end

        // ---- Read: R addr → D D3 D2 D1 D0 ----
        ST_READ_ADDR: if (rx_done) begin cmd_addr <= rx_data; state <= ST_READ_EXEC; end

        ST_READ_EXEC: state <= ST_READ_WAIT;

        // Status shortcut reuses read wait/resp
        ST_STATUS_EXEC: state <= ST_READ_WAIT;

        ST_READ_WAIT: begin
          if (reg_rvalid) begin
            cmd_rdata_buf <= reg_rdata;
            resp_byte_idx <= 2'd0;
            tx_start      <= 1'b1;
            tx_data       <= (cmd_addr == 8'h0C && state == ST_READ_WAIT) ? "S" : "D";
            state         <= ST_READ_RESP;
          end
        end

        ST_READ_RESP: begin
          if (!tx_busy && !tx_start) begin
            case (resp_byte_idx)
              2'd0: begin tx_start <= 1'b1; tx_data <= cmd_rdata_buf[31:24]; resp_byte_idx <= 2'd1; end
              2'd1: begin tx_start <= 1'b1; tx_data <= cmd_rdata_buf[23:16]; resp_byte_idx <= 2'd2; end
              2'd2: begin tx_start <= 1'b1; tx_data <= cmd_rdata_buf[15:8];  resp_byte_idx <= 2'd3; end
              2'd3: begin tx_start <= 1'b1; tx_data <= cmd_rdata_buf[7:0];   state <= ST_IDLE; end
            endcase
          end
        end

        // ---- Reset: X → A ----
        ST_RESET_EXEC: state <= ST_RESET_ACK;

        ST_RESET_ACK: begin
          if (!tx_busy) begin
            tx_start <= 1'b1;
            tx_data  <= "A";
            state    <= ST_IDLE;
          end
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule
