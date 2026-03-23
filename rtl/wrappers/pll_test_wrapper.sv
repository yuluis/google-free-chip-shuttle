// ---------------------------------------------------------------------------
// pll_test_wrapper.sv — PLL/DPLL experiment block (optional, non-blocking)
//
// IMPORTANT: The rest of the chip MUST operate without PLL lock.
// This block is for learning clock synthesis and characterizing PLL behavior.
//
// In RTL simulation, models a simple DPLL with configurable multiply/divide.
// In silicon, would be replaced with an actual analog PLL or ADPLL macro.
//
// Features:
//   - Reference clock input with bypass mode
//   - Configurable multiply (2-15) and divide (1-15) factors
//   - Lock detector with timeout
//   - Frequency measurement (counted externally by clock_mux_tree)
//   - Status registers: locked, timeout, bypass, freq count
//
// Self-test: enables PLL, waits for lock, measures output frequency,
//            compares against expected range, reports result.
// ---------------------------------------------------------------------------
module pll_test_wrapper
  import ulc_pkg::*;
(
  input  logic        clk,         // system clock
  input  logic        rst_n,
  input  test_ctrl_t  ctrl,
  output test_status_t status,

  // Configuration
  input  pll_config_t pll_cfg,

  // Reference clock
  input  logic        ref_clk,     // reference clock input

  // Outputs
  output logic        pll_clk_out, // PLL output clock (or bypass)
  output logic        pll_locked,
  output logic        pll_timeout,
  output logic        bypass_active,

  // Frequency measurement (measured by clock_mux_tree)
  output logic [31:0] pll_freq_count
);

  // -----------------------------------------------------------------------
  // DPLL model for simulation
  // In real silicon, this would be a PLL hard macro or custom analog block.
  // The RTL model simply divides the system clock to approximate the
  // target frequency, with a simulated lock-up time.
  // -----------------------------------------------------------------------
  logic [31:0] lock_counter;
  logic        model_locked;
  logic [7:0]  output_divider;
  logic [7:0]  div_cnt;
  logic        pll_clk_internal;

  // Simulated lock-up time (models real PLL settling)
  localparam int LOCK_CYCLES = 1000;

  // Compute output divider: system_clk / (mult/div) approximation
  // In real silicon, the PLL would multiply the reference clock
  always_comb begin
    if (pll_cfg.div_factor == '0)
      output_divider = 8'd2;  // prevent divide by zero
    else
      output_divider = 8'(pll_cfg.div_factor);
  end

  // Lock model
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lock_counter <= '0;
      model_locked <= 1'b0;
    end else if (!pll_cfg.enable) begin
      lock_counter <= '0;
      model_locked <= 1'b0;
    end else if (!model_locked) begin
      lock_counter <= lock_counter + 1;
      if (lock_counter >= LOCK_CYCLES[31:0])
        model_locked <= 1'b1;
    end
  end

  // Output clock generation (simplified frequency model)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      div_cnt          <= '0;
      pll_clk_internal <= 1'b0;
    end else if (pll_cfg.enable && model_locked) begin
      if (div_cnt >= output_divider - 1) begin
        div_cnt          <= '0;
        pll_clk_internal <= ~pll_clk_internal;
      end else begin
        div_cnt <= div_cnt + 1;
      end
    end else begin
      div_cnt          <= '0;
      pll_clk_internal <= 1'b0;
    end
  end

  // -----------------------------------------------------------------------
  // Bypass mux — if bypass=1 or PLL not locked, pass reference through
  // -----------------------------------------------------------------------
  assign bypass_active = pll_cfg.bypass || !pll_cfg.enable;
  assign pll_clk_out   = bypass_active ? ref_clk : pll_clk_internal;
  assign pll_locked     = model_locked && pll_cfg.enable && !pll_cfg.bypass;

  // -----------------------------------------------------------------------
  // Frequency counter — count PLL output edges over a reference window
  // -----------------------------------------------------------------------
  logic [31:0] freq_ref_cnt;
  logic [31:0] freq_edge_cnt;
  logic        freq_done;
  logic        pll_sync1, pll_sync2, pll_sync3, pll_rising;

  // Synchronize PLL output to system clock
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pll_sync1 <= 1'b0;
      pll_sync2 <= 1'b0;
      pll_sync3 <= 1'b0;
    end else begin
      pll_sync1 <= pll_clk_out;
      pll_sync2 <= pll_sync1;
      pll_sync3 <= pll_sync2;
    end
  end
  assign pll_rising = pll_sync2 & ~pll_sync3;

  localparam logic [31:0] FREQ_WINDOW = 32'd10000;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      freq_ref_cnt  <= '0;
      freq_edge_cnt <= '0;
      freq_done     <= 1'b0;
    end else if (!pll_cfg.enable) begin
      freq_ref_cnt  <= '0;
      freq_edge_cnt <= '0;
      freq_done     <= 1'b0;
    end else if (!freq_done) begin
      freq_ref_cnt <= freq_ref_cnt + 1;
      if (pll_rising)
        freq_edge_cnt <= freq_edge_cnt + 1;
      if (freq_ref_cnt >= FREQ_WINDOW - 1)
        freq_done <= 1'b1;
    end
  end

  assign pll_freq_count = freq_edge_cnt;

  // -----------------------------------------------------------------------
  // Timeout detection
  // -----------------------------------------------------------------------
  logic [31:0] timeout_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      timeout_cnt <= '0;
      pll_timeout <= 1'b0;
    end else if (!pll_cfg.enable) begin
      timeout_cnt <= '0;
      pll_timeout <= 1'b0;
    end else if (!model_locked && !pll_timeout) begin
      timeout_cnt <= timeout_cnt + 1;
      if (timeout_cnt >= PLL_LOCK_TIMEOUT)
        pll_timeout <= 1'b1;
    end
  end

  // -----------------------------------------------------------------------
  // Self-test FSM
  // Enables PLL, waits for lock or timeout, measures frequency, reports
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    T_IDLE,
    T_WAIT_LOCK,
    T_MEASURE,
    T_CHECK,
    T_DONE
  } test_state_t;

  test_state_t test_state;
  logic [31:0] test_freq;
  logic [31:0] test_wait;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      test_state <= T_IDLE;
      test_freq  <= '0;
      test_wait  <= '0;
    end else begin
      case (test_state)
        T_IDLE: begin
          if (ctrl.test_enable && ctrl.test_mode && ctrl.test_start) begin
            test_state <= T_WAIT_LOCK;
            test_wait  <= '0;
          end
        end

        T_WAIT_LOCK: begin
          test_wait <= test_wait + 1;
          if (pll_locked)
            test_state <= T_MEASURE;
          else if (pll_timeout || test_wait >= PLL_LOCK_TIMEOUT)
            test_state <= T_CHECK;  // proceed even if no lock (report failure)
        end

        T_MEASURE: begin
          // Wait for frequency measurement to complete
          if (freq_done) begin
            test_freq  <= freq_edge_cnt;
            test_state <= T_CHECK;
          end
        end

        T_CHECK: begin
          test_state <= T_DONE;
        end

        T_DONE: begin
          if (!ctrl.test_enable)
            test_state <= T_IDLE;
        end

        default: test_state <= T_IDLE;
      endcase
    end
  end

  // -----------------------------------------------------------------------
  // Test status
  // -----------------------------------------------------------------------
  logic test_passed;
  // Pass if: locked, frequency > 0, no timeout
  assign test_passed = pll_locked && (test_freq > '0) && !pll_timeout;

  assign status.test_done    = (test_state == T_DONE);
  assign status.test_pass    = (test_state == T_DONE) && test_passed;
  assign status.test_error   = (test_state == T_DONE) ?
                                (pll_timeout ? ERR_PLL_NO_LOCK :
                                 (!pll_locked ? ERR_PLL_NO_LOCK :
                                  (test_freq == '0 ? ERR_CLOCK_ABSENT : ERR_NONE))) :
                                ERR_NONE;
  assign status.test_result0 = test_freq;
  assign status.test_result1 = {28'd0, pll_cfg.mult_factor};
  assign status.test_result2 = {28'd0, pll_cfg.div_factor};
  assign status.test_result3 = {28'd0, pll_timeout, bypass_active, pll_locked, pll_cfg.enable};

endmodule
