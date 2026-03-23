// ---------------------------------------------------------------------------
// uart_test_wrapper.sv — UART loopback self-test
// Sends a known byte sequence through an internal loopback, receives and
// compares. Reports bytes sent, bytes received, and mismatch count.
// ---------------------------------------------------------------------------
module uart_test_wrapper
  import ulc_pkg::*;
(
  input  logic         clk,
  input  logic         rst_n,
  input  test_ctrl_t   ctrl,
  output test_status_t status,
  // UART pins
  output logic         uart_tx,
  input  logic         uart_rx,
  output logic         loopback_en
);

  // -----------------------------------------------------------------------
  // Test byte sequence
  // -----------------------------------------------------------------------
  localparam int NUM_BYTES = 8;
  logic [7:0] test_bytes [NUM_BYTES];
  assign test_bytes[0] = 8'h55;
  assign test_bytes[1] = 8'hAA;
  assign test_bytes[2] = 8'h0F;
  assign test_bytes[3] = 8'hF0;
  assign test_bytes[4] = 8'h00;
  assign test_bytes[5] = 8'hFF;
  assign test_bytes[6] = 8'h42;
  assign test_bytes[7] = 8'hBD;

  // -----------------------------------------------------------------------
  // Simple UART TX engine (8N1, fixed baud divider)
  // -----------------------------------------------------------------------
  localparam int BAUD_DIV = 16;  // clk/baud — kept small for fast self-test

  logic [3:0]  tx_bit_idx;
  logic [15:0] tx_baud_cnt;
  logic [9:0]  tx_shift;  // start + 8 data + stop
  logic        tx_busy;

  logic        tx_start;
  logic [7:0]  tx_data;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_busy     <= 1'b0;
      tx_shift    <= 10'h3FF;
      tx_bit_idx  <= '0;
      tx_baud_cnt <= '0;
      uart_tx     <= 1'b1;
    end else if (tx_start && !tx_busy) begin
      tx_shift    <= {1'b1, tx_data, 1'b0};  // stop, data[7:0], start
      tx_busy     <= 1'b1;
      tx_bit_idx  <= '0;
      tx_baud_cnt <= '0;
      uart_tx     <= 1'b0;  // drive start bit immediately
    end else if (tx_busy) begin
      if (tx_baud_cnt == BAUD_DIV[15:0] - 1) begin
        tx_baud_cnt <= '0;
        tx_bit_idx  <= tx_bit_idx + 1;
        if (tx_bit_idx == 4'd9) begin
          tx_busy <= 1'b0;
          uart_tx <= 1'b1;
        end else begin
          uart_tx <= tx_shift[tx_bit_idx + 1];
        end
      end else begin
        tx_baud_cnt <= tx_baud_cnt + 1;
      end
    end
  end

  // -----------------------------------------------------------------------
  // Simple UART RX engine (8N1, same baud divider, samples at midpoint)
  // -----------------------------------------------------------------------
  logic [3:0]  rx_bit_idx;
  logic [15:0] rx_baud_cnt;
  logic [7:0]  rx_shift;
  logic        rx_busy;
  logic        rx_done;
  logic [7:0]  rx_data;
  logic        rx_input;

  // Loopback mux: when loopback_en, rx sees tx
  assign rx_input = loopback_en ? uart_tx : uart_rx;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_busy     <= 1'b0;
      rx_bit_idx  <= '0;
      rx_baud_cnt <= '0;
      rx_shift    <= '0;
      rx_done     <= 1'b0;
      rx_data     <= '0;
    end else begin
      rx_done <= 1'b0;

      if (!rx_busy) begin
        // Detect start bit (falling edge to 0)
        if (!rx_input) begin
          rx_busy     <= 1'b1;
          rx_bit_idx  <= '0;
          rx_baud_cnt <= BAUD_DIV[15:0] / 2;  // sample at midpoint
        end
      end else begin
        if (rx_baud_cnt == BAUD_DIV[15:0] - 1) begin
          rx_baud_cnt <= '0;
          if (rx_bit_idx == 4'd8) begin
            // Stop bit — frame complete
            rx_busy <= 1'b0;
            rx_done <= 1'b1;
            rx_data <= rx_shift;
          end else begin
            rx_shift[rx_bit_idx[2:0]] <= rx_input;
            rx_bit_idx <= rx_bit_idx + 1;
          end
        end else begin
          rx_baud_cnt <= rx_baud_cnt + 1;
        end
      end
    end
  end

  // -----------------------------------------------------------------------
  // Test FSM
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE,
    S_SEND,
    S_WAIT_TX,
    S_WAIT_RX,
    S_CHECK,
    S_DONE
  } state_t;

  state_t state, state_next;

  logic [3:0]  byte_idx;
  logic [31:0] bytes_sent;
  logic [31:0] bytes_received;
  logic [31:0] mismatch_count;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= S_IDLE;
    else
      state <= state_next;
  end

  // -----------------------------------------------------------------------
  // Datapath
  // -----------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      byte_idx       <= '0;
      bytes_sent     <= '0;
      bytes_received <= '0;
      mismatch_count <= '0;
      loopback_en    <= 1'b0;
      tx_start       <= 1'b0;
      tx_data        <= '0;
    end else begin
      tx_start <= 1'b0;

      case (state)
        S_IDLE: begin
          byte_idx       <= '0;
          bytes_sent     <= '0;
          bytes_received <= '0;
          mismatch_count <= '0;
          loopback_en    <= 1'b0;
        end

        S_SEND: begin
          loopback_en <= 1'b1;
          tx_start    <= 1'b1;
          tx_data     <= test_bytes[byte_idx[2:0]];
        end

        S_WAIT_TX: begin
          // Wait for TX to finish
        end

        S_WAIT_RX: begin
          // Wait for RX done
        end

        S_CHECK: begin
          bytes_sent     <= bytes_sent + 1;
          bytes_received <= bytes_received + 1;
          if (rx_data != test_bytes[byte_idx[2:0]])
            mismatch_count <= mismatch_count + 1;
          byte_idx <= byte_idx + 1;
        end

        default: ;
      endcase
    end
  end

  // -----------------------------------------------------------------------
  // Next-state logic
  // -----------------------------------------------------------------------
  always_comb begin
    state_next = state;
    case (state)
      S_IDLE: begin
        if (ctrl.test_enable && ctrl.test_mode && ctrl.test_start)
          state_next = S_SEND;
      end

      S_SEND:
        state_next = S_WAIT_TX;

      S_WAIT_TX: begin
        if (!tx_busy)
          state_next = S_WAIT_RX;
      end

      S_WAIT_RX: begin
        if (rx_done)
          state_next = S_CHECK;
      end

      S_CHECK: begin
        if (byte_idx == NUM_BYTES[3:0] - 1)
          state_next = S_DONE;
        else
          state_next = S_SEND;
      end

      S_DONE: begin
        if (!ctrl.test_enable)
          state_next = S_IDLE;
      end

      default: state_next = S_IDLE;
    endcase
  end

  // -----------------------------------------------------------------------
  // Output assignments
  // -----------------------------------------------------------------------
  assign status.test_done    = (state == S_DONE);
  assign status.test_pass    = (state == S_DONE) && (mismatch_count == '0);
  assign status.test_error   = (state == S_DONE && mismatch_count != '0) ? ERR_COMPARE_MISMATCH : ERR_NONE;
  assign status.test_result0 = bytes_sent;
  assign status.test_result1 = bytes_received;
  assign status.test_result2 = mismatch_count;
  assign status.test_result3 = '0;

endmodule
