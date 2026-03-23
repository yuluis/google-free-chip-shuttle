// Central test sequencer — FSM that orchestrates per-block self-tests
// v2: Extended with experiment profiles, BIST pattern control, clock/route
//     configuration, PLL lock wait, and safe-state restore.
module test_sequencer
  import ulc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // From register bank
  input  logic [31:0] reg_global_control,
  input  logic [7:0]  reg_block_select,
  input  logic [7:0]  reg_command,
  input  logic [31:0] reg_timeout_cycles,
  input  logic        cmd_strobe,

  // To register bank (write-back port)
  output logic        seq_wr,
  output logic [7:0]  seq_addr,
  output logic [31:0] seq_wdata,

  // Block wrapper control — active block selected by test_mux
  output test_ctrl_t  blk_ctrl,
  input  test_status_t blk_status,

  // Block select one-hot (active block)
  output logic [NUM_BLOCKS-1:0] blk_sel_oh,

  // Test log buffer interface
  output logic        log_wr,
  output log_entry_t  log_entry,
  input  logic [31:0] log_ptr,
  input  logic [31:0] log_count,

  // Free-running cycle counter
  input  logic [31:0] cycle_count,

  // --- v2: Experiment orchestration outputs ---
  // Experiment profile
  output experiment_id_t  active_experiment,
  input  experiment_profile_t loaded_profile,

  // Clock mux control
  output logic        clk_cfg_valid,
  output clock_mux_cfg_t clk_cfg_data,

  // Analog route control
  output logic        route_cfg_valid,
  output analog_route_cfg_t route_cfg_data,

  // BIST pattern commands
  output logic        bist_apply_cmd,
  output logic        bist_clear_cmd,

  // PLL status
  input  logic        pll_locked,
  input  logic        pll_timeout,

  // Analog route status
  input  logic        route_contention,

  // Safe-state restore signal
  output logic        restore_safe
);

  seq_state_t state, state_next;

  logic [31:0] timeout_ctr;
  logic [31:0] cycle_start;
  logic [31:0] pass_count;
  logic [31:0] fail_count;

  // Cached block selection
  logic [7:0]  active_block;
  logic        dangerous_armed;
  logic        global_enable;
  logic        lab_mode;

  assign dangerous_armed = reg_global_control[CTRL_ARM_DANGEROUS];
  assign global_enable   = reg_global_control[CTRL_GLOBAL_ENABLE];
  assign lab_mode        = reg_global_control[CTRL_LAB_MODE];

  // Decode block select to one-hot
  always_comb begin
    blk_sel_oh = '0;
    if (active_block < NUM_BLOCKS)
      blk_sel_oh[active_block] = 1'b1;
  end

  // Sequencer write helper
  logic        wr_pending;
  logic [7:0]  wr_addr_q;
  logic [31:0] wr_data_q;

  assign seq_wr    = wr_pending;
  assign seq_addr  = wr_addr_q;
  assign seq_wdata = wr_data_q;

  task automatic queue_write(input logic [7:0] addr, input logic [31:0] data);
    wr_pending = 1'b1;
    wr_addr_q  = addr;
    wr_data_q  = data;
  endtask

  // Experiment state
  experiment_id_t exp_id_reg;
  assign active_experiment = exp_id_reg;

  // Sub-state counter for multi-step states
  logic [3:0] sub_step;

  // -----------------------------------------------------------
  // FSM
  // -----------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= SEQ_IDLE;
      active_block     <= 8'h0;
      timeout_ctr      <= 32'h0;
      cycle_start      <= 32'h0;
      pass_count       <= 32'h0;
      fail_count       <= 32'h0;
      blk_ctrl         <= '0;
      wr_pending       <= 1'b0;
      wr_addr_q        <= 8'h0;
      wr_data_q        <= 32'h0;
      log_wr           <= 1'b0;
      log_entry        <= '0;
      exp_id_reg       <= EXP_NONE;
      clk_cfg_valid    <= 1'b0;
      clk_cfg_data     <= '0;
      route_cfg_valid  <= 1'b0;
      route_cfg_data   <= '0;
      bist_apply_cmd   <= 1'b0;
      bist_clear_cmd   <= 1'b0;
      restore_safe     <= 1'b0;
      sub_step         <= '0;
    end else begin
      wr_pending      <= 1'b0;
      log_wr          <= 1'b0;
      clk_cfg_valid   <= 1'b0;
      route_cfg_valid <= 1'b0;
      bist_apply_cmd  <= 1'b0;
      bist_clear_cmd  <= 1'b0;
      restore_safe    <= 1'b0;

      // Reset fabric
      if (reg_global_control[CTRL_RESET_FABRIC]) begin
        state       <= SEQ_IDLE;
        blk_ctrl    <= '0;
        pass_count  <= 32'h0;
        fail_count  <= 32'h0;
        timeout_ctr <= 32'h0;
        exp_id_reg  <= EXP_NONE;
      end else begin
        case (state)
          // -------------------------------------------------
          SEQ_IDLE: begin
            blk_ctrl.test_enable <= 1'b0;
            blk_ctrl.test_mode   <= 1'b0;
            blk_ctrl.test_start  <= 1'b0;
            sub_step             <= '0;

            if (cmd_strobe && global_enable) begin
              case (test_cmd_t'(reg_command))
                CMD_START_SELECTED: begin
                  active_block <= reg_block_select;
                  state        <= SEQ_ARM_CHECK;
                end
                CMD_LOAD_EXPERIMENT: begin
                  // Load experiment profile and run full orchestration
                  exp_id_reg <= experiment_id_t'(reg_block_select);
                  state      <= SEQ_LOAD_EXPERIMENT;
                end
                CMD_APPLY_BIST: begin
                  bist_apply_cmd <= 1'b1;
                end
                CMD_CONFIGURE_ROUTE: begin
                  state <= SEQ_APPLY_ROUTE;
                end
                CMD_CONFIGURE_CLOCKS: begin
                  state <= SEQ_CONFIGURE_CLOCKS;
                end
                CMD_RESTORE_SAFE: begin
                  state <= SEQ_RESTORE_SAFE;
                end
                CMD_ABORT: ;
                default: ;
              endcase
            end
            // Update status: not busy
            queue_write(REG_GLOBAL_STATUS, 32'h0);
          end

          // -------------------------------------------------
          // EXPERIMENT ORCHESTRATION (v2)
          // -------------------------------------------------
          SEQ_LOAD_EXPERIMENT: begin
            // Step 0: validate profile
            queue_write(REG_GLOBAL_STATUS, 32'h1 << STAT_BUSY);
            queue_write(REG_EXPERIMENT_ID, {24'h0, exp_id_reg});

            // Check safety: dangerous experiments need arming
            if (loaded_profile.requires_dangerous && !dangerous_armed) begin
              queue_write(REG_ERROR_CODE, {24'h0, ERR_UNSAFE_DENIED});
              state <= SEQ_ERROR;
            end else begin
              state <= SEQ_CONFIGURE_CLOCKS;
            end
          end

          SEQ_CONFIGURE_CLOCKS: begin
            // Apply clock configuration from experiment profile
            clk_cfg_valid         <= 1'b1;
            clk_cfg_data.adc_clk_sel  <= loaded_profile.adc_clk;
            clk_cfg_data.dac_clk_sel  <= loaded_profile.dac_clk;
            clk_cfg_data.bist_clk_sel <= CLKSRC_EXT_REF;
            clk_cfg_data.exp_clk_sel  <= CLKSRC_EXT_REF;

            // If experiment requires PLL, wait for lock
            if (loaded_profile.requires_pll && !pll_locked) begin
              timeout_ctr <= '0;
              state       <= SEQ_WAIT_PLL_LOCK;
            end else begin
              state <= SEQ_APPLY_ROUTE;
            end
          end

          SEQ_WAIT_PLL_LOCK: begin
            timeout_ctr <= timeout_ctr + 1;
            if (pll_locked) begin
              state <= SEQ_APPLY_ROUTE;
            end else if (pll_timeout || timeout_ctr >= PLL_LOCK_TIMEOUT) begin
              queue_write(REG_ERROR_CODE, {24'h0, ERR_PLL_NO_LOCK});
              state <= SEQ_ERROR;
            end
          end

          SEQ_APPLY_ROUTE: begin
            // Apply analog route from experiment profile
            route_cfg_valid               <= 1'b1;
            route_cfg_data.adc_source     <= loaded_profile.adc_source;
            route_cfg_data.comp_pos_source <= loaded_profile.comp_pos;
            route_cfg_data.comp_neg_source <= loaded_profile.comp_neg;
            route_cfg_data.dac_to_ext_pin <= 1'b0;

            // Check for contention
            if (route_contention) begin
              queue_write(REG_ERROR_CODE, {24'h0, ERR_ROUTE_CONTENTION});
              state <= SEQ_RESTORE_SAFE;
            end else begin
              // If running an experiment, start the target block
              if (exp_id_reg != EXP_NONE) begin
                // Select the primary block from the experiment profile
                // Use first enabled block for individual test
                active_block <= reg_block_select;
                cycle_start  <= cycle_count;
                state        <= SEQ_ARM_CHECK;
              end else begin
                // Standalone route config — just return to idle
                state <= SEQ_COMPLETE;
              end
            end
          end

          SEQ_LOAD_BIST: begin
            bist_apply_cmd <= 1'b1;
            state          <= SEQ_IDLE;
          end

          SEQ_RESTORE_SAFE: begin
            // Restore all safe defaults
            restore_safe    <= 1'b1;
            bist_clear_cmd  <= 1'b1;
            exp_id_reg      <= EXP_NONE;
            blk_ctrl        <= '0;
            // Clear route to disconnected
            route_cfg_valid <= 1'b1;
            route_cfg_data  <= '0;  // all ASRC_DISCONNECTED
            // Clock to ext ref
            clk_cfg_valid   <= 1'b1;
            clk_cfg_data    <= '0;  // all CLKSRC_EXT_REF
            queue_write(REG_EXPERIMENT_ID, {24'h0, EXP_NONE});
            state <= SEQ_IDLE;
          end

          // -------------------------------------------------
          // ORIGINAL TEST FLOW (preserved)
          // -------------------------------------------------
          SEQ_ARM_CHECK: begin
            if (is_dangerous_block(block_id_t'(active_block)) && !dangerous_armed) begin
              queue_write(REG_ERROR_CODE, {24'h0, ERR_UNSAFE_DENIED});
              state <= SEQ_ERROR;
            end else if (active_block >= NUM_BLOCKS) begin
              queue_write(REG_ERROR_CODE, {24'h0, ERR_UNSUPPORTED_MODE});
              state <= SEQ_ERROR;
            end else begin
              state <= SEQ_PREPARE_BLOCK;
            end
            queue_write(REG_GLOBAL_STATUS, 32'h1 << STAT_BUSY);
          end

          SEQ_PREPARE_BLOCK: begin
            blk_ctrl.test_enable <= 1'b1;
            blk_ctrl.test_mode   <= 1'b1;
            blk_ctrl.test_start  <= 1'b0;
            timeout_ctr          <= 32'h0;
            cycle_start          <= cycle_count;
            queue_write(REG_LAST_BLOCK, {24'h0, active_block});
            state <= SEQ_START_BLOCK;
          end

          SEQ_START_BLOCK: begin
            blk_ctrl.test_start <= 1'b1;
            state               <= SEQ_WAIT_FOR_DONE;
          end

          SEQ_WAIT_FOR_DONE: begin
            blk_ctrl.test_start <= 1'b0;
            timeout_ctr         <= timeout_ctr + 1;

            if (blk_status.test_done) begin
              timeout_ctr <= '0;
              state       <= SEQ_COLLECT_RESULTS;
            end else if (timeout_ctr >= reg_timeout_cycles) begin
              queue_write(REG_ERROR_CODE, {24'h0, ERR_TIMEOUT});
              state <= SEQ_ERROR;
            end
          end

          SEQ_COLLECT_RESULTS: begin
            case (timeout_ctr[1:0])
              2'd0: begin queue_write(REG_RESULT0, blk_status.test_result0); timeout_ctr <= 32'd1; end
              2'd1: begin queue_write(REG_RESULT1, blk_status.test_result1); timeout_ctr <= 32'd2; end
              2'd2: begin queue_write(REG_RESULT2, blk_status.test_result2); timeout_ctr <= 32'd3; end
              2'd3: begin queue_write(REG_RESULT3, blk_status.test_result3); timeout_ctr <= 32'd0; state <= SEQ_WRITE_STATUS; end
            endcase
          end

          SEQ_WRITE_STATUS: begin
            if (blk_status.test_pass) begin
              pass_count <= pass_count + 1;
              queue_write(REG_PASS_COUNT, pass_count + 1);
            end else begin
              fail_count <= fail_count + 1;
              queue_write(REG_FAIL_COUNT, fail_count + 1);
            end
            queue_write(REG_ERROR_CODE, {24'h0, blk_status.test_error});
            state <= SEQ_APPEND_LOG;
          end

          SEQ_APPEND_LOG: begin
            log_entry.block_id    <= active_block;
            log_entry.error_code  <= blk_status.test_error;
            log_entry.pass        <= blk_status.test_pass;
            log_entry.fail        <= ~blk_status.test_pass;
            log_entry.reserved    <= '0;
            log_entry.cycle_start <= cycle_start;
            log_entry.cycle_end   <= cycle_count;
            log_entry.result0     <= blk_status.test_result0;
            log_entry.result1     <= blk_status.test_result1;
            log_entry.result2     <= blk_status.test_result2;
            log_entry.result3     <= blk_status.test_result3;
            log_wr                <= 1'b1;
            state                 <= SEQ_COMPLETE;
          end

          SEQ_COMPLETE: begin
            blk_ctrl.test_enable <= 1'b0;
            blk_ctrl.test_mode   <= 1'b0;
            queue_write(REG_GLOBAL_STATUS,
              (32'h1 << STAT_DONE) |
              (blk_status.test_pass ? (32'h1 << STAT_PASS) : (32'h1 << STAT_FAIL)) |
              (dangerous_armed ? (32'h1 << STAT_DANGEROUS_ARMED) : 32'h0) |
              (pll_locked ? (32'h1 << STAT_PLL_LOCKED) : 32'h0) |
              (exp_id_reg != EXP_NONE ? (32'h1 << STAT_EXPERIMENT_RUNNING) : 32'h0));
            queue_write(REG_LOG_PTR, log_ptr);
            queue_write(REG_LOG_COUNT, log_count);

            // If running an experiment, restore safe state after
            if (exp_id_reg != EXP_NONE)
              exp_id_reg <= EXP_NONE;

            state <= SEQ_IDLE;
          end

          SEQ_ERROR: begin
            blk_ctrl.test_enable <= 1'b0;
            blk_ctrl.test_mode   <= 1'b0;
            fail_count           <= fail_count + 1;
            queue_write(REG_FAIL_COUNT, fail_count + 1);
            queue_write(REG_GLOBAL_STATUS,
              (32'h1 << STAT_DONE) | (32'h1 << STAT_FAIL) |
              (timeout_ctr >= reg_timeout_cycles ? (32'h1 << STAT_TIMEOUT) : 32'h0));
            log_entry.block_id    <= active_block;
            log_entry.error_code  <= seq_wdata[7:0];
            log_entry.pass        <= 1'b0;
            log_entry.fail        <= 1'b1;
            log_entry.reserved    <= '0;
            log_entry.cycle_start <= cycle_start;
            log_entry.cycle_end   <= cycle_count;
            log_entry.result0     <= '0;
            log_entry.result1     <= '0;
            log_entry.result2     <= '0;
            log_entry.result3     <= '0;
            log_wr                <= 1'b1;

            // Restore safe state on error
            if (exp_id_reg != EXP_NONE)
              state <= SEQ_RESTORE_SAFE;
            else
              state <= SEQ_IDLE;
          end

          SEQ_ABORT: begin
            blk_ctrl <= '0;
            if (exp_id_reg != EXP_NONE)
              state <= SEQ_RESTORE_SAFE;
            else
              state <= SEQ_IDLE;
          end

          default: state <= SEQ_IDLE;
        endcase

        // Abort command can interrupt any state
        if (cmd_strobe && reg_command == CMD_ABORT)
          state <= SEQ_ABORT;
      end

      // Update LAST_STATE continuously
      if (!wr_pending) begin
        wr_pending <= 1'b1;
        wr_addr_q  <= REG_LAST_STATE;
        wr_data_q  <= {27'h0, state};
      end
    end
  end

endmodule
