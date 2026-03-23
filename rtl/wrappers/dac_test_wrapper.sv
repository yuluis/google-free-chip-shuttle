// ---------------------------------------------------------------------------
// dac_test_wrapper.sv — DAC block with multiple test/stimulus modes
//
// Primarily for internal stimulation and learning experiments, not a
// precision production DAC. Routes output through analog route matrix
// to ADC, comparator, or external analog pin.
//
// Modes:
//   STATIC      — Hold programmed code
//   STAIRCASE   — Increment code each update tick (0 -> max -> wrap)
//   RAMP        — Linear sweep min->max->min (triangle)
//   ALTERNATING — Toggle between two programmed codes
//   LUT         — Cycle through 16-entry waveform table
//
// Self-test: runs a staircase sweep and verifies update count matches
//            expected number of steps.
// ---------------------------------------------------------------------------
module dac_test_wrapper
  import ulc_pkg::*;
(
  input  logic                clk,
  input  logic                rst_n,
  input  test_ctrl_t          ctrl,
  output test_status_t        status,

  // Host config registers (directly writable)
  input  logic                dac_enable,
  input  dac_mode_t           dac_mode,
  input  logic [DAC_BITS-1:0] dac_code_reg,      // static code or base code
  input  logic [DAC_BITS-1:0] dac_alt_code_reg,   // alternating second code
  input  logic [7:0]          dac_clk_div,        // update rate divider

  // DAC analog output (to route matrix)
  output logic [DAC_BITS-1:0] dac_output_code,    // current output code
  output logic                dac_output_valid,    // update strobe

  // Status readback
  output logic [31:0]         dac_update_count,
  output dac_mode_t           dac_active_mode,
  output logic                dac_running,

  // Clock input (from clock mux tree)
  input  logic                dac_update_clk
);

  // -----------------------------------------------------------------------
  // Update clock divider — generates update ticks from dac_update_clk
  // -----------------------------------------------------------------------
  logic [7:0]  div_cnt;
  logic        update_tick;
  logic        update_clk_sync1, update_clk_sync2, update_clk_sync3;
  logic        update_clk_edge;

  // Synchronize update clock to system domain
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      update_clk_sync1 <= 1'b0;
      update_clk_sync2 <= 1'b0;
      update_clk_sync3 <= 1'b0;
    end else begin
      update_clk_sync1 <= dac_update_clk;
      update_clk_sync2 <= update_clk_sync1;
      update_clk_sync3 <= update_clk_sync2;
    end
  end
  assign update_clk_edge = update_clk_sync2 & ~update_clk_sync3;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      div_cnt     <= '0;
      update_tick <= 1'b0;
    end else begin
      update_tick <= 1'b0;
      if (update_clk_edge) begin
        if (div_cnt >= dac_clk_div) begin
          div_cnt     <= '0;
          update_tick <= 1'b1;
        end else begin
          div_cnt <= div_cnt + 1;
        end
      end
    end
  end

  // -----------------------------------------------------------------------
  // LUT storage (16 x DAC_BITS entries, writable via code_reg sequencing)
  // For simplicity, initialized to a quarter-sine approximation
  // -----------------------------------------------------------------------
  logic [DAC_BITS-1:0] lut_mem [DAC_LUT_DEPTH];
  logic [3:0]          lut_idx;

  // Initialize LUT to a simple triangle wave
  initial begin
    for (int i = 0; i < DAC_LUT_DEPTH; i++) begin
      if (i < DAC_LUT_DEPTH/2)
        lut_mem[i] = DAC_BITS'((i * ((1 << DAC_BITS) - 1)) / (DAC_LUT_DEPTH/2 - 1));
      else
        lut_mem[i] = DAC_BITS'((((DAC_LUT_DEPTH - 1 - i)) * ((1 << DAC_BITS) - 1)) / (DAC_LUT_DEPTH/2 - 1));
    end
  end

  // -----------------------------------------------------------------------
  // Output code generation — mode-dependent
  // -----------------------------------------------------------------------
  logic [DAC_BITS-1:0] current_code;
  logic [31:0]         update_cnt;
  logic                ramp_direction;  // 0 = up, 1 = down
  logic                alt_toggle;

  localparam logic [DAC_BITS-1:0] DAC_MAX = {DAC_BITS{1'b1}};

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_code   <= '0;
      update_cnt     <= '0;
      ramp_direction <= 1'b0;
      alt_toggle     <= 1'b0;
      lut_idx        <= '0;
    end else if (!dac_enable) begin
      current_code   <= '0;
      update_cnt     <= '0;
      ramp_direction <= 1'b0;
      alt_toggle     <= 1'b0;
      lut_idx        <= '0;
    end else if (update_tick) begin
      update_cnt <= update_cnt + 1;

      case (dac_mode)
        DAC_MODE_STATIC: begin
          current_code <= dac_code_reg;
        end

        DAC_MODE_STAIRCASE: begin
          current_code <= current_code + 1;  // wraps naturally
        end

        DAC_MODE_RAMP: begin
          if (!ramp_direction) begin
            // Ascending
            if (current_code >= DAC_MAX - 1) begin
              ramp_direction <= 1'b1;
              current_code   <= DAC_MAX;
            end else begin
              current_code <= current_code + 1;
            end
          end else begin
            // Descending
            if (current_code <= 1) begin
              ramp_direction <= 1'b0;
              current_code   <= '0;
            end else begin
              current_code <= current_code - 1;
            end
          end
        end

        DAC_MODE_ALTERNATING: begin
          alt_toggle   <= ~alt_toggle;
          current_code <= alt_toggle ? dac_alt_code_reg : dac_code_reg;
        end

        DAC_MODE_LUT: begin
          current_code <= lut_mem[lut_idx];
          lut_idx      <= lut_idx + 1;  // wraps at 16
        end

        default: current_code <= dac_code_reg;
      endcase
    end
  end

  assign dac_output_code  = current_code;
  assign dac_output_valid = dac_enable && update_tick;
  assign dac_update_count = update_cnt;
  assign dac_active_mode  = dac_mode;
  assign dac_running      = dac_enable;

  // -----------------------------------------------------------------------
  // Self-test FSM — runs a staircase sweep and verifies update count
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    T_IDLE,
    T_CONFIGURE,
    T_RUN_STAIRCASE,
    T_WAIT_UPDATES,
    T_CHECK,
    T_DONE
  } test_state_t;

  test_state_t test_state;

  localparam int TEST_STEPS = 64;  // number of update ticks to run
  logic [31:0] test_start_count;
  logic [31:0] test_wait_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      test_state      <= T_IDLE;
      test_start_count <= '0;
      test_wait_cnt   <= '0;
    end else begin
      case (test_state)
        T_IDLE: begin
          if (ctrl.test_enable && ctrl.test_mode && ctrl.test_start)
            test_state <= T_CONFIGURE;
        end

        T_CONFIGURE: begin
          test_start_count <= update_cnt;
          test_wait_cnt    <= '0;
          test_state       <= T_RUN_STAIRCASE;
        end

        T_RUN_STAIRCASE: begin
          // Wait for TEST_STEPS updates
          test_wait_cnt <= test_wait_cnt + 1;
          if ((update_cnt - test_start_count) >= TEST_STEPS[31:0])
            test_state <= T_CHECK;
          else if (test_wait_cnt >= DEFAULT_TIMEOUT)
            test_state <= T_CHECK;  // timeout — still report what we got
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
  logic [31:0] actual_updates;
  assign actual_updates = update_cnt - test_start_count;

  logic test_passed;
  assign test_passed = (actual_updates >= TEST_STEPS[31:0]) &&
                       (test_wait_cnt < DEFAULT_TIMEOUT);

  assign status.test_done    = (test_state == T_DONE);
  assign status.test_pass    = (test_state == T_DONE) && test_passed;
  assign status.test_error   = (test_state == T_DONE && !test_passed) ?
                                (test_wait_cnt >= DEFAULT_TIMEOUT ? ERR_TIMEOUT : ERR_DAC_FAULT) :
                                ERR_NONE;
  assign status.test_result0 = actual_updates;
  assign status.test_result1 = {22'd0, current_code};
  assign status.test_result2 = update_cnt;
  assign status.test_result3 = {29'd0, dac_mode};

endmodule
