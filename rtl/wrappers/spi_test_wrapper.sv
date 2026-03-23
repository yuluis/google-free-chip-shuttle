// ---------------------------------------------------------------------------
// spi_test_wrapper.sv — SPI loopback self-test
// Transfers known 8-bit words with internal MOSI-to-MISO loopback and
// compares received data. Reports transfer count and mismatch count.
// ---------------------------------------------------------------------------
module spi_test_wrapper
  import ulc_pkg::*;
(
  input  logic         clk,
  input  logic         rst_n,
  input  test_ctrl_t   ctrl,
  output test_status_t status,
  // SPI pins
  output logic         spi_clk_o,
  output logic         spi_mosi,
  input  logic         spi_miso,
  output logic         spi_cs_n
);

  // -----------------------------------------------------------------------
  // Test data words
  // -----------------------------------------------------------------------
  localparam int NUM_WORDS = 8;
  logic [7:0] test_words [NUM_WORDS];
  assign test_words[0] = 8'hA5;
  assign test_words[1] = 8'h5A;
  assign test_words[2] = 8'hFF;
  assign test_words[3] = 8'h00;
  assign test_words[4] = 8'h0F;
  assign test_words[5] = 8'hF0;
  assign test_words[6] = 8'h33;
  assign test_words[7] = 8'hCC;

  // -----------------------------------------------------------------------
  // SPI clock divider (divide system clock by 4 for SPI clock)
  // -----------------------------------------------------------------------
  localparam int SPI_DIV = 4;

  logic [1:0]  clk_div_cnt;
  logic        spi_clk_en;  // pulse at SPI clock edge

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clk_div_cnt <= '0;
    end else if (state == S_SHIFT) begin
      clk_div_cnt <= clk_div_cnt + 1;
    end else begin
      clk_div_cnt <= '0;
    end
  end

  assign spi_clk_en = (clk_div_cnt == SPI_DIV[1:0] - 1);

  // -----------------------------------------------------------------------
  // SPI shift engine (CPOL=0, CPHA=0, MSB first)
  // -----------------------------------------------------------------------
  logic [7:0] tx_shift;
  logic [7:0] rx_shift;
  logic [3:0] bit_cnt;
  logic       spi_clk_reg;
  logic       shift_done;

  // Internal loopback: MOSI feeds back to MISO path
  logic       loopback_miso;
  assign loopback_miso = spi_mosi;  // internal loopback

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_shift    <= '0;
      rx_shift    <= '0;
      bit_cnt     <= '0;
      spi_clk_reg <= 1'b0;
      shift_done  <= 1'b0;
    end else begin
      shift_done <= 1'b0;

      if (state == S_LOAD) begin
        tx_shift    <= test_words[word_idx[2:0]];
        rx_shift    <= '0;
        bit_cnt     <= '0;
        spi_clk_reg <= 1'b0;
      end else if (state == S_SHIFT && spi_clk_en) begin
        if (!spi_clk_reg) begin
          // Rising edge: sample MISO, drive MOSI already set
          rx_shift    <= {rx_shift[6:0], loopback_miso};
          spi_clk_reg <= 1'b1;
        end else begin
          // Falling edge: shift out next bit
          spi_clk_reg <= 1'b0;
          tx_shift    <= {tx_shift[6:0], 1'b0};
          bit_cnt     <= bit_cnt + 1;
          if (bit_cnt == 4'd7)
            shift_done <= 1'b1;
        end
      end
    end
  end

  assign spi_clk_o = spi_clk_reg;
  assign spi_mosi  = tx_shift[7];

  // -----------------------------------------------------------------------
  // Test FSM
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE,
    S_LOAD,
    S_SHIFT,
    S_COMPARE,
    S_DONE
  } state_t;

  state_t state, state_next;

  logic [3:0]  word_idx;
  logic [31:0] transfer_count;
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
      word_idx       <= '0;
      transfer_count <= '0;
      mismatch_count <= '0;
    end else begin
      case (state)
        S_IDLE: begin
          word_idx       <= '0;
          transfer_count <= '0;
          mismatch_count <= '0;
        end

        S_COMPARE: begin
          transfer_count <= transfer_count + 1;
          if (rx_shift != test_words[word_idx[2:0]])
            mismatch_count <= mismatch_count + 1;
          word_idx <= word_idx + 1;
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
          state_next = S_LOAD;
      end

      S_LOAD:
        state_next = S_SHIFT;

      S_SHIFT: begin
        if (shift_done)
          state_next = S_COMPARE;
      end

      S_COMPARE: begin
        if (word_idx == NUM_WORDS[3:0] - 1)
          state_next = S_DONE;
        else
          state_next = S_LOAD;
      end

      S_DONE: begin
        if (!ctrl.test_enable)
          state_next = S_IDLE;
      end

      default: state_next = S_IDLE;
    endcase
  end

  // -----------------------------------------------------------------------
  // CS_N control
  // -----------------------------------------------------------------------
  assign spi_cs_n = (state == S_IDLE || state == S_DONE) ? 1'b1 : 1'b0;

  // -----------------------------------------------------------------------
  // Output assignments
  // -----------------------------------------------------------------------
  assign status.test_done    = (state == S_DONE);
  assign status.test_pass    = (state == S_DONE) && (mismatch_count == '0);
  assign status.test_error   = (state == S_DONE && mismatch_count != '0) ? ERR_COMPARE_MISMATCH : ERR_NONE;
  assign status.test_result0 = transfer_count;
  assign status.test_result1 = mismatch_count;
  assign status.test_result2 = '0;
  assign status.test_result3 = '0;

endmodule
