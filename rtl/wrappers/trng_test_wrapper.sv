// TRNG health screening self-test wrapper
// Collects COLLECT_BITS from the entropy source, then runs:
//   (a) Repetition count test — max consecutive identical bits
//   (b) Adaptive proportion test — ones count in a sliding window
//   (c) Stuck detection — entropy_valid never asserted
// Reports health flags and raw metrics.
module trng_test_wrapper
  import ulc_pkg::*;
#(
  parameter int COLLECT_BITS    = 1024,
  parameter int REP_LIMIT       = 24,    // max allowed consecutive identical bits
  parameter int PROP_LO         = 410,   // minimum ones in COLLECT_BITS (≈40%)
  parameter int PROP_HI         = 614,   // maximum ones in COLLECT_BITS (≈60%)
  parameter int TIMEOUT_CYCLES  = 100_000
)(
  input  logic        clk,
  input  logic        rst_n,
  input  test_ctrl_t  ctrl,
  output test_status_t status,
  // Block-specific ports
  input  logic        entropy_bit,
  input  logic        entropy_valid
);

  // -------------------------------------------------------------------
  // FSM states
  // -------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE,
    S_COLLECT,
    S_EVALUATE,
    S_DONE
  } state_t;

  state_t  state;

  // Collection counters
  logic [31:0] bit_count;
  logic [31:0] ones_count;

  // Repetition tracking
  logic        last_bit;
  logic [31:0] rep_current;   // current consecutive run length
  logic [31:0] rep_max;       // maximum observed run length

  // Stuck detection — counts cycles with no entropy_valid
  logic [31:0] idle_cycles;
  logic        stuck;

  // Timeout
  logic [31:0] timeout_cnt;

  // Health flags
  logic        rep_fail;
  logic        prop_fail;

  // Start edge
  logic        start_d;
  wire         start_pulse = ctrl.test_start & ~start_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= ctrl.test_start;
  end

  // -------------------------------------------------------------------
  // Main FSM
  // -------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      bit_count   <= '0;
      ones_count  <= '0;
      last_bit    <= 1'b0;
      rep_current <= 32'd1;
      rep_max     <= '0;
      idle_cycles <= '0;
      stuck       <= 1'b0;
      timeout_cnt <= '0;
      rep_fail    <= 1'b0;
      prop_fail   <= 1'b0;
    end else begin
      case (state)
        // ----------------------------------------------------------
        S_IDLE: begin
          if (ctrl.test_enable && ctrl.test_mode && start_pulse) begin
            state       <= S_COLLECT;
            bit_count   <= '0;
            ones_count  <= '0;
            rep_current <= 32'd1;
            rep_max     <= '0;
            idle_cycles <= '0;
            stuck       <= 1'b0;
            timeout_cnt <= '0;
            rep_fail    <= 1'b0;
            prop_fail   <= 1'b0;
          end
        end

        // ----------------------------------------------------------
        S_COLLECT: begin
          timeout_cnt <= timeout_cnt + 32'd1;

          if (entropy_valid) begin
            idle_cycles <= '0;
            bit_count   <= bit_count + 32'd1;

            // Count ones
            if (entropy_bit)
              ones_count <= ones_count + 32'd1;

            // Repetition tracking
            if (bit_count == '0) begin
              // First bit — initialize
              last_bit    <= entropy_bit;
              rep_current <= 32'd1;
            end else if (entropy_bit == last_bit) begin
              rep_current <= rep_current + 32'd1;
              if ((rep_current + 32'd1) > rep_max)
                rep_max <= rep_current + 32'd1;
            end else begin
              last_bit    <= entropy_bit;
              rep_current <= 32'd1;
            end

            // Check if collection complete
            if (bit_count == COLLECT_BITS[31:0] - 32'd1)
              state <= S_EVALUATE;
          end else begin
            idle_cycles <= idle_cycles + 32'd1;
          end

          // Timeout — stuck source
          if (timeout_cnt >= TIMEOUT_CYCLES[31:0] - 32'd1) begin
            stuck <= 1'b1;
            state <= S_EVALUATE;
          end
        end

        // ----------------------------------------------------------
        S_EVALUATE: begin
          // Repetition count test
          if (rep_max > REP_LIMIT[31:0])
            rep_fail <= 1'b1;

          // Adaptive proportion test
          if (!stuck) begin
            if (ones_count < PROP_LO[31:0] || ones_count > PROP_HI[31:0])
              prop_fail <= 1'b1;
          end

          state <= S_DONE;
        end

        // ----------------------------------------------------------
        S_DONE: begin
          if (!ctrl.test_enable)
            state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  // -------------------------------------------------------------------
  // Health flags word: bit0=rep_fail, bit1=proportion_fail, bit2=stuck
  // -------------------------------------------------------------------
  wire [31:0] health_flags = {29'd0, stuck, prop_fail, rep_fail};

  // -------------------------------------------------------------------
  // Pass/fail: pass only if no flags set
  // -------------------------------------------------------------------
  wire all_pass = (state == S_DONE) & ~rep_fail & ~prop_fail & ~stuck;

  // Error code selection
  wire [7:0] err_code = stuck      ? ERR_TIMEOUT :
                         (rep_fail | prop_fail) ? ERR_RANGE_VIOLATION :
                         ERR_NONE;

  // -------------------------------------------------------------------
  // Status outputs
  // -------------------------------------------------------------------
  assign status.test_done    = (state == S_DONE);
  assign status.test_pass    = all_pass;
  assign status.test_error   = (state == S_DONE) ? err_code : ERR_NONE;
  assign status.test_result0 = bit_count;
  assign status.test_result1 = rep_max;
  assign status.test_result2 = ones_count;
  assign status.test_result3 = health_flags;

endmodule
