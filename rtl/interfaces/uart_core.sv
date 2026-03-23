// Minimal UART core — TX and RX at configurable baud rate
// 8N1 format. No flow control.
module uart_core #(
  parameter int CLK_FREQ  = 50_000_000,
  parameter int BAUD_RATE = 115_200
)(
  input  logic       clk,
  input  logic       rst_n,

  // TX
  input  logic [7:0] tx_data,
  input  logic       tx_valid,
  output logic       tx_ready,
  output logic       tx_out,

  // RX
  output logic [7:0] rx_data,
  output logic       rx_valid,
  input  logic       rx_in
);

  localparam int DIVISOR = CLK_FREQ / BAUD_RATE;

  // ---------------------------------------------------------------
  // Transmitter
  // ---------------------------------------------------------------
  typedef enum logic [1:0] { TX_IDLE, TX_START, TX_DATA, TX_STOP } tx_state_t;
  tx_state_t tx_state;

  logic [15:0] tx_baud_ctr;
  logic [2:0]  tx_bit_idx;
  logic [7:0]  tx_shift;

  assign tx_ready = (tx_state == TX_IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_state    <= TX_IDLE;
      tx_out      <= 1'b1;
      tx_baud_ctr <= '0;
      tx_bit_idx  <= '0;
      tx_shift    <= '0;
    end else begin
      case (tx_state)
        TX_IDLE: begin
          tx_out <= 1'b1;
          if (tx_valid) begin
            tx_shift    <= tx_data;
            tx_baud_ctr <= '0;
            tx_state    <= TX_START;
          end
        end

        TX_START: begin
          tx_out <= 1'b0;  // start bit
          if (tx_baud_ctr == DIVISOR - 1) begin
            tx_baud_ctr <= '0;
            tx_bit_idx  <= '0;
            tx_state    <= TX_DATA;
          end else begin
            tx_baud_ctr <= tx_baud_ctr + 1;
          end
        end

        TX_DATA: begin
          tx_out <= tx_shift[tx_bit_idx];
          if (tx_baud_ctr == DIVISOR - 1) begin
            tx_baud_ctr <= '0;
            if (tx_bit_idx == 3'd7)
              tx_state <= TX_STOP;
            else
              tx_bit_idx <= tx_bit_idx + 1;
          end else begin
            tx_baud_ctr <= tx_baud_ctr + 1;
          end
        end

        TX_STOP: begin
          tx_out <= 1'b1;  // stop bit
          if (tx_baud_ctr == DIVISOR - 1) begin
            tx_baud_ctr <= '0;
            tx_state    <= TX_IDLE;
          end else begin
            tx_baud_ctr <= tx_baud_ctr + 1;
          end
        end
      endcase
    end
  end

  // ---------------------------------------------------------------
  // Receiver
  // ---------------------------------------------------------------
  typedef enum logic [1:0] { RX_IDLE, RX_START, RX_DATA, RX_STOP } rx_state_t;
  rx_state_t rx_state;

  logic [15:0] rx_baud_ctr;
  logic [2:0]  rx_bit_idx;
  logic [7:0]  rx_shift;
  logic        rx_in_sync, rx_in_r;

  // Double-flop synchronizer for RX input
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_in_r    <= 1'b1;
      rx_in_sync <= 1'b1;
    end else begin
      rx_in_r    <= rx_in;
      rx_in_sync <= rx_in_r;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_state    <= RX_IDLE;
      rx_baud_ctr <= '0;
      rx_bit_idx  <= '0;
      rx_shift    <= '0;
      rx_data     <= '0;
      rx_valid    <= 1'b0;
    end else begin
      rx_valid <= 1'b0;

      case (rx_state)
        RX_IDLE: begin
          if (!rx_in_sync) begin  // falling edge = start bit
            rx_baud_ctr <= '0;
            rx_state    <= RX_START;
          end
        end

        RX_START: begin
          // Sample at mid-bit
          if (rx_baud_ctr == (DIVISOR / 2) - 1) begin
            if (!rx_in_sync) begin
              rx_baud_ctr <= '0;
              rx_bit_idx  <= '0;
              rx_state    <= RX_DATA;
            end else begin
              rx_state <= RX_IDLE;  // false start
            end
          end else begin
            rx_baud_ctr <= rx_baud_ctr + 1;
          end
        end

        RX_DATA: begin
          if (rx_baud_ctr == DIVISOR - 1) begin
            rx_baud_ctr          <= '0;
            rx_shift[rx_bit_idx] <= rx_in_sync;
            if (rx_bit_idx == 3'd7)
              rx_state <= RX_STOP;
            else
              rx_bit_idx <= rx_bit_idx + 1;
          end else begin
            rx_baud_ctr <= rx_baud_ctr + 1;
          end
        end

        RX_STOP: begin
          if (rx_baud_ctr == DIVISOR - 1) begin
            rx_baud_ctr <= '0;
            if (rx_in_sync) begin  // valid stop bit
              rx_data  <= rx_shift;
              rx_valid <= 1'b1;
            end
            rx_state <= RX_IDLE;
          end else begin
            rx_baud_ctr <= rx_baud_ctr + 1;
          end
        end
      endcase
    end
  end

endmodule
