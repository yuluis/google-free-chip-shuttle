// ADC self-test wrapper
// Sequences the ADC through a sweep of known input codes (via an
// internal reference path / channel select), captures digital outputs,
// checks that all codes are within expected range and that the
// output is monotonic (each reading >= previous reading).
module adc_test_wrapper
  import ulc_pkg::*;
#(
  parameter int ADC_BITS      = 12,
  parameter int NUM_STEPS     = 16,     // number of test points in the sweep
  parameter int TIMEOUT_CYCLES = 50_000
)(
  input  logic                  clk,
  input  logic                  rst_n,
  input  test_ctrl_t            ctrl,
  output test_status_t          status,
  // Block-specific ports
  input  logic [ADC_BITS-1:0]   adc_data,
  output logic                  adc_start,
  input  logic                  adc_done,
  output logic [3:0]            adc_channel
);

  localparam int MAX_CODE = (1 << ADC_BITS) - 1;

  // -------------------------------------------------------------------
  // FSM states
  // -------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE,
    S_SETUP,
    S_CONVERT,
    S_WAIT,
    S_CHECK,
    S_DONE
  } state_t;

  state_t  state;

  // Sweep step counter
  logic [$clog2(NUM_STEPS):0] step_idx;

  // Expected code for current step (linear ramp)
  // step_idx=0 → 0, step_idx=NUM_STEPS-1 → MAX_CODE
  logic [ADC_BITS-1:0]        expected_code;

  // Captured ADC data
  logic [ADC_BITS-1:0]        captured;
  logic [ADC_BITS-1:0]        prev_captured;
  logic                       has_prev;

  // Results
  logic [31:0]                first_code;
  logic [31:0]                last_code;
  logic [31:0]                mono_violations;

  // Timeout
  logic [31:0]                wait_cnt;

  // Pass/error tracking
  logic                       pass_r;
  logic [7:0]                 error_r;
  logic                       timed_out;

  // Start edge
  logic                       start_d;
  wire                        start_pulse = ctrl.test_start & ~start_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= ctrl.test_start;
  end

  // -------------------------------------------------------------------
  // Expected code computation: linear interpolation across steps
  // -------------------------------------------------------------------
  always_comb begin
    if (NUM_STEPS <= 1)
      expected_code = '0;
    else
      expected_code = ADC_BITS'((MAX_CODE * int'(step_idx)) / (NUM_STEPS - 1));
  end

  // -------------------------------------------------------------------
  // Main FSM
  // -------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= S_IDLE;
      step_idx        <= '0;
      captured        <= '0;
      prev_captured   <= '0;
      has_prev        <= 1'b0;
      first_code      <= '0;
      last_code       <= '0;
      mono_violations <= '0;
      wait_cnt        <= '0;
      pass_r          <= 1'b1;
      error_r         <= ERR_NONE;
      timed_out       <= 1'b0;
    end else begin
      case (state)
        // ----------------------------------------------------------
        S_IDLE: begin
          if (ctrl.test_enable && ctrl.test_mode && start_pulse) begin
            state           <= S_SETUP;
            step_idx        <= '0;
            has_prev        <= 1'b0;
            first_code      <= '0;
            last_code       <= '0;
            mono_violations <= '0;
            pass_r          <= 1'b1;
            error_r         <= ERR_NONE;
            timed_out       <= 1'b0;
          end
        end

        // ----------------------------------------------------------
        S_SETUP: begin
          // Set channel for this step's reference level
          wait_cnt <= '0;
          state    <= S_CONVERT;
        end

        // ----------------------------------------------------------
        S_CONVERT: begin
          // Pulse adc_start for one cycle
          state <= S_WAIT;
        end

        // ----------------------------------------------------------
        S_WAIT: begin
          wait_cnt <= wait_cnt + 32'd1;

          if (adc_done) begin
            captured <= adc_data;
            state    <= S_CHECK;
          end else if (wait_cnt >= TIMEOUT_CYCLES[31:0] - 32'd1) begin
            timed_out <= 1'b1;
            pass_r    <= 1'b0;
            error_r   <= ERR_TIMEOUT;
            state     <= S_DONE;
          end
        end

        // ----------------------------------------------------------
        S_CHECK: begin
          // Record first / last code
          if (step_idx == '0)
            first_code <= 32'(captured);
          last_code <= 32'(captured);

          // Monotonicity check (each reading should be >= previous)
          if (has_prev && (captured < prev_captured)) begin
            mono_violations <= mono_violations + 32'd1;
          end

          prev_captured <= captured;
          has_prev      <= 1'b1;

          // Range check: captured should be within tolerance of expected
          // Allow +/- 5% of full scale
          begin
            automatic logic [ADC_BITS:0] tolerance = (MAX_CODE[ADC_BITS:0] + 1) / 20;
            automatic logic signed [ADC_BITS+1:0] diff = $signed({1'b0, captured}) - $signed({1'b0, expected_code});
            if (diff > $signed({1'b0, tolerance}) || diff < -$signed({1'b0, tolerance})) begin
              pass_r  <= 1'b0;
              error_r <= ERR_RANGE_VIOLATION;
            end
          end

          if (step_idx == NUM_STEPS[$clog2(NUM_STEPS):0] - 1) begin
            // All steps complete — also fail if monotonicity violations
            if (mono_violations > '0 && error_r == ERR_NONE) begin
              pass_r  <= 1'b0;
              error_r <= ERR_COMPARE_MISMATCH;
            end
            state <= S_DONE;
          end else begin
            step_idx <= step_idx + 1;
            state    <= S_SETUP;
          end
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
  // Output drivers
  // -------------------------------------------------------------------
  assign adc_start   = (state == S_CONVERT);
  assign adc_channel = step_idx[$clog2(NUM_STEPS)-1:0];  // map step to channel

  // -------------------------------------------------------------------
  // Status outputs
  // -------------------------------------------------------------------
  assign status.test_done    = (state == S_DONE);
  assign status.test_pass    = (state == S_DONE) & pass_r;
  assign status.test_error   = (state == S_DONE) ? error_r : ERR_NONE;
  assign status.test_result0 = first_code;
  assign status.test_result1 = last_code;
  assign status.test_result2 = mono_violations;
  assign status.test_result3 = '0;

endmodule
