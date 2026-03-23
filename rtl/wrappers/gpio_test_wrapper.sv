// ---------------------------------------------------------------------------
// gpio_test_wrapper.sv — GPIO walking-one / walking-zero self-test
// Tests output latch integrity with walking-one and walking-zero patterns,
// reads back via gpio_in, and verifies LED pattern generation.
// ---------------------------------------------------------------------------
module gpio_test_wrapper
  import ulc_pkg::*;
#(
  parameter int GPIO_WIDTH = 8
)(
  input  logic                   clk,
  input  logic                   rst_n,
  input  test_ctrl_t             ctrl,
  output test_status_t           status,
  // GPIO ports
  output logic [GPIO_WIDTH-1:0]  gpio_out,
  input  logic [GPIO_WIDTH-1:0]  gpio_in,
  output logic [GPIO_WIDTH-1:0]  gpio_oe
);

  // -----------------------------------------------------------------------
  // Total patterns: GPIO_WIDTH walking-ones + GPIO_WIDTH walking-zeros
  //               + 2 all-ones/all-zeros + 2 LED patterns = 2*GPIO_WIDTH+4
  // -----------------------------------------------------------------------
  localparam int WALK_PATTERNS = 2 * GPIO_WIDTH;
  localparam int EXTRA_PATTERNS = 4;  // all-0, all-1, LED odd, LED even
  localparam int TOTAL_PATTERNS = WALK_PATTERNS + EXTRA_PATTERNS;

  // -----------------------------------------------------------------------
  // FSM
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE,
    S_DRIVE,
    S_SAMPLE,
    S_CHECK,
    S_DONE
  } state_t;

  state_t state, state_next;

  logic [7:0]                  pat_idx;
  logic [31:0]                 patterns_tested;
  logic [31:0]                 mismatch_bits;  // cumulative mismatch OR
  logic [GPIO_WIDTH-1:0]       expected_pattern;
  logic [GPIO_WIDTH-1:0]       sampled;
  logic [1:0]                  settle_cnt;  // allow output to settle

  // -----------------------------------------------------------------------
  // Pattern generator
  // -----------------------------------------------------------------------
  always_comb begin
    expected_pattern = '0;
    if (pat_idx < GPIO_WIDTH[7:0]) begin
      // Walking-one: single bit set
      expected_pattern = GPIO_WIDTH'(1) << pat_idx[($clog2(GPIO_WIDTH))-1:0];
    end else if (pat_idx < 2 * GPIO_WIDTH[7:0]) begin
      // Walking-zero: all bits set except one
      expected_pattern = ~(GPIO_WIDTH'(1) << (pat_idx[($clog2(GPIO_WIDTH))-1:0]));
    end else begin
      case (pat_idx - 2 * GPIO_WIDTH[7:0])
        8'd0: expected_pattern = '0;                           // all-zeros
        8'd1: expected_pattern = {GPIO_WIDTH{1'b1}};           // all-ones
        8'd2: expected_pattern = {(GPIO_WIDTH/2){2'b01}};      // LED even
        8'd3: expected_pattern = {(GPIO_WIDTH/2){2'b10}};      // LED odd
        default: expected_pattern = '0;
      endcase
    end
  end

  // -----------------------------------------------------------------------
  // State register
  // -----------------------------------------------------------------------
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
      pat_idx         <= '0;
      patterns_tested <= '0;
      mismatch_bits   <= '0;
      sampled         <= '0;
      settle_cnt      <= '0;
    end else begin
      case (state)
        S_IDLE: begin
          pat_idx         <= '0;
          patterns_tested <= '0;
          mismatch_bits   <= '0;
          sampled         <= '0;
          settle_cnt      <= '0;
        end

        S_DRIVE: begin
          // Allow a couple cycles for output to propagate to gpio_in
          settle_cnt <= settle_cnt + 1;
        end

        S_SAMPLE: begin
          sampled    <= gpio_in;
          settle_cnt <= '0;
        end

        S_CHECK: begin
          // Accumulate any mismatching bits
          mismatch_bits   <= mismatch_bits | {24'd0, (sampled ^ expected_pattern)};
          patterns_tested <= patterns_tested + 1;
          pat_idx         <= pat_idx + 1;
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
          state_next = S_DRIVE;
      end

      S_DRIVE: begin
        // Wait 2 cycles for settling
        if (settle_cnt == 2'd1)
          state_next = S_SAMPLE;
      end

      S_SAMPLE:
        state_next = S_CHECK;

      S_CHECK: begin
        if (pat_idx == TOTAL_PATTERNS[7:0] - 1)
          state_next = S_DONE;
        else
          state_next = S_DRIVE;
      end

      S_DONE: begin
        if (!ctrl.test_enable)
          state_next = S_IDLE;
      end

      default: state_next = S_IDLE;
    endcase
  end

  // -----------------------------------------------------------------------
  // GPIO port drives
  // -----------------------------------------------------------------------
  assign gpio_out = (state == S_DRIVE || state == S_SAMPLE) ? expected_pattern : '0;
  assign gpio_oe  = (state != S_IDLE && state != S_DONE) ? {GPIO_WIDTH{1'b1}} : '0;

  // -----------------------------------------------------------------------
  // Status outputs
  // -----------------------------------------------------------------------
  assign status.test_done    = (state == S_DONE);
  assign status.test_pass    = (state == S_DONE) && (mismatch_bits == '0);
  assign status.test_error   = (state == S_DONE && mismatch_bits != '0) ? ERR_COMPARE_MISMATCH : ERR_NONE;
  assign status.test_result0 = patterns_tested;
  assign status.test_result1 = mismatch_bits;
  assign status.test_result2 = '0;
  assign status.test_result3 = '0;

endmodule
