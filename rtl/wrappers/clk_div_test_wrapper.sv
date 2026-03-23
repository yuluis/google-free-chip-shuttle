// Clock divider / mux self-test wrapper
// Selects each clock source and divider setting, measures the output
// frequency via a free-running counter over a fixed reference window,
// and confirms the measured divide ratio matches the expected value.
module clk_div_test_wrapper
  import ulc_pkg::*;
#(
  parameter int NUM_SOURCES    = 4,
  parameter int REF_WINDOW     = 1024,   // reference-clock cycles per measurement
  parameter int TOLERANCE      = 2       // allowed count deviation
)(
  input  logic                       clk,
  input  logic                       rst_n,
  input  test_ctrl_t                 ctrl,
  output test_status_t               status,
  // Block-specific ports
  output logic [$clog2(NUM_SOURCES)-1:0] clk_sel,
  input  logic                       clk_meas_in
);

  // -------------------------------------------------------------------
  // FSM states
  // -------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE,
    S_SELECT,
    S_MEASURE,
    S_CHECK,
    S_DONE
  } state_t;

  state_t                    state, state_next;

  // Source / divider iteration
  logic [$clog2(NUM_SOURCES)-1:0] src_idx;

  // Measurement counters
  logic [31:0]               ref_cnt;      // counts reference clk ticks
  logic [31:0]               meas_cnt;     // counts clk_meas_in edges

  // Edge detection on measured clock
  logic                      meas_d;
  logic                      meas_edge;

  // Expected count for each source (simple model: source 0 = /1, 1 = /2 ...)
  // Expected edges in REF_WINDOW = REF_WINDOW / (src_idx + 1)
  logic [31:0]               expected_count;

  // Latched results for reporting
  logic [31:0]               result0_r, result1_r, result2_r;
  logic                      pass_r;
  logic [7:0]                error_r;

  // Start edge detection
  logic                      start_d;
  wire                       start_pulse = ctrl.test_start & ~start_d;

  // -------------------------------------------------------------------
  // Edge detector for clk_meas_in (sampled by system clk)
  // -------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      meas_d <= 1'b0;
    else
      meas_d <= clk_meas_in;
  end
  assign meas_edge = clk_meas_in & ~meas_d;  // rising-edge detect

  // -------------------------------------------------------------------
  // Start-pulse latch
  // -------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= ctrl.test_start;
  end

  // -------------------------------------------------------------------
  // Expected count computation
  // -------------------------------------------------------------------
  assign expected_count = REF_WINDOW / (32'(src_idx) + 32'd1);

  // -------------------------------------------------------------------
  // FSM sequential
  // -------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      src_idx   <= '0;
      ref_cnt   <= '0;
      meas_cnt  <= '0;
      pass_r    <= 1'b1;
      error_r   <= ERR_NONE;
      result0_r <= '0;
      result1_r <= '0;
      result2_r <= '0;
    end else begin
      case (state)
        // ----------------------------------------------------------
        S_IDLE: begin
          if (ctrl.test_enable && ctrl.test_mode && start_pulse) begin
            state     <= S_SELECT;
            src_idx   <= '0;
            pass_r    <= 1'b1;
            error_r   <= ERR_NONE;
            result0_r <= '0;
            result1_r <= '0;
            result2_r <= '0;
          end
        end

        // ----------------------------------------------------------
        S_SELECT: begin
          // Apply clock select; allow a few cycles to settle
          ref_cnt  <= '0;
          meas_cnt <= '0;
          state    <= S_MEASURE;
        end

        // ----------------------------------------------------------
        S_MEASURE: begin
          ref_cnt <= ref_cnt + 32'd1;
          if (meas_edge)
            meas_cnt <= meas_cnt + 32'd1;

          if (ref_cnt == REF_WINDOW[31:0] - 32'd1)
            state <= S_CHECK;
        end

        // ----------------------------------------------------------
        S_CHECK: begin
          // Compare measured vs expected within tolerance
          if ((meas_cnt > expected_count + TOLERANCE[31:0]) ||
              (meas_cnt + TOLERANCE[31:0] < expected_count)) begin
            pass_r    <= 1'b0;
            error_r   <= ERR_COMPARE_MISMATCH;
            // Latch failing source info
            result0_r <= 32'(src_idx);
            result1_r <= meas_cnt;
            result2_r <= expected_count;
            state     <= S_DONE;
          end else begin
            // This source passed; latch latest good result
            result0_r <= 32'(src_idx);
            result1_r <= meas_cnt;
            result2_r <= expected_count;

            if (src_idx == NUM_SOURCES[$clog2(NUM_SOURCES)-1:0] - 1) begin
              state <= S_DONE;      // all sources tested
            end else begin
              src_idx <= src_idx + 1;
              state   <= S_SELECT;  // next source
            end
          end
        end

        // ----------------------------------------------------------
        S_DONE: begin
          // Hold until de-asserted
          if (!ctrl.test_enable)
            state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  // -------------------------------------------------------------------
  // Output mux select drives block port
  // -------------------------------------------------------------------
  assign clk_sel = src_idx;

  // -------------------------------------------------------------------
  // Status outputs
  // -------------------------------------------------------------------
  assign status.test_done    = (state == S_DONE);
  assign status.test_pass    = (state == S_DONE) & pass_r;
  assign status.test_error   = (state == S_DONE) ? error_r : ERR_NONE;
  assign status.test_result0 = result0_r;
  assign status.test_result1 = result1_r;
  assign status.test_result2 = result2_r;
  assign status.test_result3 = '0;

endmodule
