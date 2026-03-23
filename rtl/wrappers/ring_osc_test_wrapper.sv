// ---------------------------------------------------------------------------
// ring_osc_test_wrapper.sv — Ring oscillator frequency measurement
// Enables each oscillator sequentially, counts edges over a fixed reference
// window, and checks against min/max thresholds. Reports first failure.
// ---------------------------------------------------------------------------
module ring_osc_test_wrapper
  import ulc_pkg::*;
#(
  parameter int NUM_OSC = 4
)(
  input  logic              clk,
  input  logic              rst_n,
  input  test_ctrl_t        ctrl,
  output test_status_t      status,
  // Oscillator interface
  output logic [NUM_OSC-1:0] osc_en,
  input  logic [NUM_OSC-1:0] osc_in
);

  // -----------------------------------------------------------------------
  // Measurement parameters
  // -----------------------------------------------------------------------
  localparam logic [31:0] REF_WINDOW    = 32'd1024;  // reference clock cycles
  localparam logic [31:0] MIN_THRESHOLD = 32'd64;    // minimum expected osc edges
  localparam logic [31:0] MAX_THRESHOLD = 32'd960;   // maximum expected osc edges

  // -----------------------------------------------------------------------
  // FSM
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE,
    S_ENABLE,
    S_MEASURE,
    S_CHECK,
    S_DONE
  } state_t;

  state_t state, state_next;

  // -----------------------------------------------------------------------
  // Datapath registers
  // -----------------------------------------------------------------------
  logic [$clog2(NUM_OSC)-1:0] osc_idx;
  logic [31:0]                ref_cnt;     // reference window counter
  logic [31:0]                edge_cnt;    // oscillator edge counter
  logic [NUM_OSC-1:0]         osc_in_d;    // delayed for edge detection
  logic                       all_pass;
  logic [31:0]                fail_cycles; // measured count on first failure
  logic [31:0]                fail_osc_id; // oscillator index on first failure
  logic [3:0]                 settle_cnt;  // settling time after enable

  // -----------------------------------------------------------------------
  // Edge detector per oscillator (synchroniser + rising-edge)
  // -----------------------------------------------------------------------
  logic [NUM_OSC-1:0] osc_sync1, osc_sync2, osc_sync3;
  logic [NUM_OSC-1:0] osc_rising;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      osc_sync1 <= '0;
      osc_sync2 <= '0;
      osc_sync3 <= '0;
    end else begin
      osc_sync1 <= osc_in;
      osc_sync2 <= osc_sync1;
      osc_sync3 <= osc_sync2;
    end
  end

  assign osc_rising = osc_sync2 & ~osc_sync3;

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
      osc_idx     <= '0;
      ref_cnt     <= '0;
      edge_cnt    <= '0;
      all_pass    <= 1'b1;
      fail_cycles <= '0;
      fail_osc_id <= '0;
      settle_cnt  <= '0;
    end else begin
      case (state)
        S_IDLE: begin
          osc_idx     <= '0;
          ref_cnt     <= '0;
          edge_cnt    <= '0;
          all_pass    <= 1'b1;
          fail_cycles <= '0;
          fail_osc_id <= '0;
          settle_cnt  <= '0;
        end

        S_ENABLE: begin
          // Let oscillator settle for a few cycles before measuring
          settle_cnt <= settle_cnt + 1;
          edge_cnt   <= '0;
          ref_cnt    <= '0;
        end

        S_MEASURE: begin
          ref_cnt <= ref_cnt + 1;
          if (osc_rising[osc_idx])
            edge_cnt <= edge_cnt + 1;
        end

        S_CHECK: begin
          // Compare against thresholds
          if (edge_cnt < MIN_THRESHOLD || edge_cnt > MAX_THRESHOLD) begin
            if (all_pass) begin
              fail_cycles <= edge_cnt;
              fail_osc_id <= {28'd0, osc_idx};
            end
            all_pass <= 1'b0;
          end
          // Advance to next oscillator
          settle_cnt <= '0;
          if (osc_idx < NUM_OSC[$clog2(NUM_OSC)-1:0] - 1)
            osc_idx <= osc_idx + 1;
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
          state_next = S_ENABLE;
      end

      S_ENABLE: begin
        if (settle_cnt == 4'd7)  // 8-cycle settling time
          state_next = S_MEASURE;
      end

      S_MEASURE: begin
        if (ref_cnt == REF_WINDOW - 1)
          state_next = S_CHECK;
      end

      S_CHECK: begin
        if (osc_idx == NUM_OSC[$clog2(NUM_OSC)-1:0] - 1)
          state_next = S_DONE;
        else
          state_next = S_ENABLE;
      end

      S_DONE: begin
        if (!ctrl.test_enable)
          state_next = S_IDLE;
      end

      default: state_next = S_IDLE;
    endcase
  end

  // -----------------------------------------------------------------------
  // Oscillator enable — only enable the one under test
  // -----------------------------------------------------------------------
  always_comb begin
    osc_en = '0;
    if (state == S_ENABLE || state == S_MEASURE)
      osc_en[osc_idx] = 1'b1;
  end

  // -----------------------------------------------------------------------
  // Status outputs
  // -----------------------------------------------------------------------
  assign status.test_done    = (state == S_DONE);
  assign status.test_pass    = (state == S_DONE) && all_pass;
  assign status.test_error   = (state == S_DONE && !all_pass) ? ERR_RANGE_VIOLATION : ERR_NONE;
  assign status.test_result0 = fail_cycles;
  assign status.test_result1 = MIN_THRESHOLD;
  assign status.test_result2 = MAX_THRESHOLD;
  assign status.test_result3 = fail_osc_id;

endmodule
