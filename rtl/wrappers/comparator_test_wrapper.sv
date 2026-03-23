// Analog comparator threshold self-test wrapper
// Sweeps a threshold code from 0 to 2^THRESHOLD_BITS-1, detects the
// trip point where comp_out changes state, repeats the measurement
// several times, and reports the average trip code.
module comparator_test_wrapper
  import ulc_pkg::*;
#(
  parameter int THRESHOLD_BITS  = 8,
  parameter int SETTLE_CYCLES   = 16,   // cycles to wait after changing threshold
  parameter int NUM_SWEEPS      = 4,    // number of sweep repetitions
  parameter int EXPECTED_TRIP   = 128   // expected trip code (mid-range default)
)(
  input  logic                         clk,
  input  logic                         rst_n,
  input  test_ctrl_t                   ctrl,
  output test_status_t                 status,
  // Block-specific ports
  input  logic                         comp_out,
  output logic [THRESHOLD_BITS-1:0]    threshold_code
);

  localparam int MAX_CODE = (1 << THRESHOLD_BITS) - 1;

  // -------------------------------------------------------------------
  // FSM states
  // -------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE,
    S_SWEEP_INIT,
    S_SETTLE,
    S_SAMPLE,
    S_NEXT_CODE,
    S_CHECK,
    S_DONE
  } state_t;

  state_t  state;

  // Threshold sweep counter
  logic [THRESHOLD_BITS-1:0] code_cnt;

  // Settle counter
  logic [31:0]               settle_cnt;

  // Comparator previous value (to detect transition)
  logic                      comp_prev;
  logic                      trip_found;
  logic [THRESHOLD_BITS-1:0] trip_code;

  // Sweep repetition tracking
  logic [$clog2(NUM_SWEEPS):0] sweep_idx;
  logic [31:0]               trip_sum;      // sum of trip codes across sweeps
  logic [31:0]               trip_count;    // number of successful trip detections

  // Start edge
  logic                      start_d;
  wire                       start_pulse = ctrl.test_start & ~start_d;

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
      code_cnt    <= '0;
      settle_cnt  <= '0;
      comp_prev   <= 1'b0;
      trip_found  <= 1'b0;
      trip_code   <= '0;
      sweep_idx   <= '0;
      trip_sum    <= '0;
      trip_count  <= '0;
    end else begin
      case (state)
        // ----------------------------------------------------------
        S_IDLE: begin
          if (ctrl.test_enable && ctrl.test_mode && start_pulse) begin
            state      <= S_SWEEP_INIT;
            sweep_idx  <= '0;
            trip_sum   <= '0;
            trip_count <= '0;
          end
        end

        // ----------------------------------------------------------
        S_SWEEP_INIT: begin
          code_cnt   <= '0;
          trip_found <= 1'b0;
          trip_code  <= '0;
          settle_cnt <= '0;
          comp_prev  <= 1'b0;
          state      <= S_SETTLE;
        end

        // ----------------------------------------------------------
        S_SETTLE: begin
          settle_cnt <= settle_cnt + 32'd1;
          if (settle_cnt >= SETTLE_CYCLES[31:0] - 32'd1) begin
            state <= S_SAMPLE;
          end
        end

        // ----------------------------------------------------------
        S_SAMPLE: begin
          // Detect transition: comp_out changed from previous code
          if (code_cnt != '0 && comp_out != comp_prev && !trip_found) begin
            trip_found <= 1'b1;
            trip_code  <= code_cnt;
          end
          comp_prev <= comp_out;
          state     <= S_NEXT_CODE;
        end

        // ----------------------------------------------------------
        S_NEXT_CODE: begin
          if (code_cnt == MAX_CODE[THRESHOLD_BITS-1:0]) begin
            // Sweep complete
            if (trip_found) begin
              trip_sum   <= trip_sum + {32-THRESHOLD_BITS > 0 ? {(32-THRESHOLD_BITS){1'b0}} : 1'b0, trip_code};
              trip_count <= trip_count + 32'd1;
            end

            if (sweep_idx == NUM_SWEEPS[$clog2(NUM_SWEEPS):0] - 1)
              state <= S_CHECK;
            else begin
              sweep_idx <= sweep_idx + 1;
              state     <= S_SWEEP_INIT;
            end
          end else begin
            code_cnt   <= code_cnt + 1;
            settle_cnt <= '0;
            state      <= S_SETTLE;
          end
        end

        // ----------------------------------------------------------
        S_CHECK: begin
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
  // Drive threshold output
  // -------------------------------------------------------------------
  assign threshold_code = code_cnt;

  // -------------------------------------------------------------------
  // Average trip code (simple divide)
  // -------------------------------------------------------------------
  logic [31:0] avg_trip;
  assign avg_trip = (trip_count != '0) ? trip_sum / trip_count : '0;

  // -------------------------------------------------------------------
  // Pass/fail: trip detected and within tolerance of expected
  // -------------------------------------------------------------------
  localparam int TRIP_TOLERANCE = 10;

  wire trip_in_range = (trip_count > '0) &&
                       (avg_trip + TRIP_TOLERANCE[31:0] >= EXPECTED_TRIP[31:0]) &&
                       (avg_trip <= EXPECTED_TRIP[31:0] + TRIP_TOLERANCE[31:0]);

  wire pass = (state == S_DONE) && trip_in_range;

  wire [7:0] err_code = (trip_count == '0)  ? ERR_MISSING_RESPONSE :
                          (!trip_in_range)    ? ERR_COMPARE_MISMATCH :
                          ERR_NONE;

  // -------------------------------------------------------------------
  // Status outputs
  // -------------------------------------------------------------------
  assign status.test_done    = (state == S_DONE);
  assign status.test_pass    = pass;
  assign status.test_error   = (state == S_DONE) ? err_code : ERR_NONE;
  assign status.test_result0 = avg_trip;
  assign status.test_result1 = 32'(EXPECTED_TRIP);
  assign status.test_result2 = trip_count;
  assign status.test_result3 = '0;

endmodule
