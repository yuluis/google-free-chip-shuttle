// UART-to-register bridge
// Simple packet protocol:
//   Write: [0x57 'W'] [addr] [d3] [d2] [d1] [d0]  -> ACK [0x06]
//   Read:  [0x52 'R'] [addr]                        -> [d3] [d2] [d1] [d0]
module uart_host_bridge #(
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

  // UART core instance
  logic [7:0] core_tx_data;
  logic       core_tx_valid;
  logic       core_tx_ready;
  logic [7:0] core_rx_data;
  logic       core_rx_valid;

  uart_core #(
    .CLK_FREQ  (CLK_FREQ),
    .BAUD_RATE (BAUD_RATE)
  ) u_uart (
    .clk      (clk),
    .rst_n    (rst_n),
    .tx_data  (core_tx_data),
    .tx_valid (core_tx_valid),
    .tx_ready (core_tx_ready),
    .tx_out   (uart_tx),
    .rx_data  (core_rx_data),
    .rx_valid (core_rx_valid),
    .rx_in    (uart_rx)
  );

  // Bridge FSM
  typedef enum logic [3:0] {
    BR_IDLE,
    BR_GET_ADDR,
    BR_GET_D3, BR_GET_D2, BR_GET_D1, BR_GET_D0,
    BR_DO_WRITE, BR_SEND_ACK,
    BR_DO_READ, BR_WAIT_RVALID,
    BR_SEND_D3, BR_SEND_D2, BR_SEND_D1, BR_SEND_D0
  } br_state_t;

  br_state_t br_state;
  logic [7:0]  cmd_byte;
  logic [7:0]  addr_byte;
  logic [31:0] data_buf;

  assign reg_addr  = addr_byte;
  assign reg_wdata = data_buf;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      br_state       <= BR_IDLE;
      cmd_byte       <= 8'h0;
      addr_byte      <= 8'h0;
      data_buf       <= 32'h0;
      reg_wr         <= 1'b0;
      reg_rd         <= 1'b0;
      core_tx_data   <= 8'h0;
      core_tx_valid  <= 1'b0;
    end else begin
      reg_wr        <= 1'b0;
      reg_rd        <= 1'b0;
      core_tx_valid <= 1'b0;

      case (br_state)
        BR_IDLE: begin
          if (core_rx_valid) begin
            cmd_byte <= core_rx_data;
            if (core_rx_data == 8'h57 || core_rx_data == 8'h52) // 'W' or 'R'
              br_state <= BR_GET_ADDR;
            // else ignore
          end
        end

        BR_GET_ADDR: begin
          if (core_rx_valid) begin
            addr_byte <= core_rx_data;
            if (cmd_byte == 8'h57)
              br_state <= BR_GET_D3;
            else
              br_state <= BR_DO_READ;
          end
        end

        // Receive 4 data bytes (MSB first)
        BR_GET_D3: if (core_rx_valid) begin data_buf[31:24] <= core_rx_data; br_state <= BR_GET_D2; end
        BR_GET_D2: if (core_rx_valid) begin data_buf[23:16] <= core_rx_data; br_state <= BR_GET_D1; end
        BR_GET_D1: if (core_rx_valid) begin data_buf[15:8]  <= core_rx_data; br_state <= BR_GET_D0; end
        BR_GET_D0: if (core_rx_valid) begin data_buf[7:0]   <= core_rx_data; br_state <= BR_DO_WRITE; end

        BR_DO_WRITE: begin
          reg_wr   <= 1'b1;
          br_state <= BR_SEND_ACK;
        end

        BR_SEND_ACK: begin
          if (core_tx_ready) begin
            core_tx_data  <= 8'h06; // ACK
            core_tx_valid <= 1'b1;
            br_state      <= BR_IDLE;
          end
        end

        BR_DO_READ: begin
          reg_rd   <= 1'b1;
          br_state <= BR_WAIT_RVALID;
        end

        BR_WAIT_RVALID: begin
          if (reg_rvalid) begin
            data_buf <= reg_rdata;
            br_state <= BR_SEND_D3;
          end
        end

        // Send 4 data bytes (MSB first)
        BR_SEND_D3: begin
          if (core_tx_ready) begin
            core_tx_data  <= data_buf[31:24];
            core_tx_valid <= 1'b1;
            br_state      <= BR_SEND_D2;
          end
        end
        BR_SEND_D2: begin
          if (core_tx_ready) begin
            core_tx_data  <= data_buf[23:16];
            core_tx_valid <= 1'b1;
            br_state      <= BR_SEND_D1;
          end
        end
        BR_SEND_D1: begin
          if (core_tx_ready) begin
            core_tx_data  <= data_buf[15:8];
            core_tx_valid <= 1'b1;
            br_state      <= BR_SEND_D0;
          end
        end
        BR_SEND_D0: begin
          if (core_tx_ready) begin
            core_tx_data  <= data_buf[7:0];
            core_tx_valid <= 1'b1;
            br_state      <= BR_IDLE;
          end
        end

        default: br_state <= BR_IDLE;
      endcase
    end
  end

endmodule
