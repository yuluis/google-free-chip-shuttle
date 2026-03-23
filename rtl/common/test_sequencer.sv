// Central test sequencer — FSM that orchestrates per-block self-tests
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
  input  logic [31:0] cycle_count
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

  assign dangerous_armed = reg_global_control[CTRL_ARM_DANGEROUS];
  assign global_enable   = reg_global_control[CTRL_GLOBAL_ENABLE];

  // Decode block select to one-hot
  always_comb begin
    blk_sel_oh = '0;
    if (active_block < NUM_BLOCKS)
      blk_sel_oh[active_block] = 1'b1;
  end

  // Sequencer write helper — queues one register write per cycle
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

  // -----------------------------------------------------------
  // FSM
  // -----------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= SEQ_IDLE;
      active_block <= 8'h0;
      timeout_ctr  <= 32'h0;
      cycle_start  <= 32'h0;
      pass_count   <= 32'h0;
      fail_count   <= 32'h0;
      blk_ctrl     <= '0;
      wr_pending   <= 1'b0;
      wr_addr_q    <= 8'h0;
      wr_data_q    <= 32'h0;
      log_wr       <= 1'b0;
      log_entry    <= '0;
    end else begin
      wr_pending <= 1'b0;
      log_wr     <= 1'b0;

      // Reset fabric
      if (reg_global_control[CTRL_RESET_FABRIC]) begin
        state       <= SEQ_IDLE;
        blk_ctrl    <= '0;
        pass_count  <= 32'h0;
        fail_count  <= 32'h0;
        timeout_ctr <= 32'h0;
      end else begin
        case (state)
          // -------------------------------------------------
          SEQ_IDLE: begin
            blk_ctrl.test_enable <= 1'b0;
            blk_ctrl.test_mode   <= 1'b0;
            blk_ctrl.test_start  <= 1'b0;
            if (cmd_strobe && reg_command == CMD_START_SELECTED && global_enable) begin
              active_block <= reg_block_select;
              state        <= SEQ_ARM_CHECK;
            end
            // Update status: not busy
            queue_write(REG_GLOBAL_STATUS, 32'h0);
          end

          // -------------------------------------------------
          SEQ_ARM_CHECK: begin
            // Check if selected block is dangerous and arming is required
            if (is_dangerous_block(block_id_t'(active_block)) && !dangerous_armed) begin
              // Deny — unsafe operation
              queue_write(REG_ERROR_CODE, {24'h0, ERR_UNSAFE_DENIED});
              state <= SEQ_ERROR;
            end else if (active_block >= NUM_BLOCKS) begin
              queue_write(REG_ERROR_CODE, {24'h0, ERR_UNSUPPORTED_MODE});
              state <= SEQ_ERROR;
            end else begin
              // Block is safe or properly armed
              state <= SEQ_PREPARE_BLOCK;
            end
            // Mark busy
            queue_write(REG_GLOBAL_STATUS, 32'h1 << STAT_BUSY);
          end

          // -------------------------------------------------
          SEQ_PREPARE_BLOCK: begin
            blk_ctrl.test_enable <= 1'b1;
            blk_ctrl.test_mode   <= 1'b1;
            blk_ctrl.test_start  <= 1'b0;
            timeout_ctr          <= 32'h0;
            cycle_start          <= cycle_count;
            queue_write(REG_LAST_BLOCK, {24'h0, active_block});
            queue_write(REG_LAST_STATE, {28'h0, SEQ_PREPARE_BLOCK});
            state <= SEQ_START_BLOCK;
          end

          // -------------------------------------------------
          SEQ_START_BLOCK: begin
            blk_ctrl.test_start <= 1'b1;
            state               <= SEQ_WAIT_FOR_DONE;
          end

          // -------------------------------------------------
          SEQ_WAIT_FOR_DONE: begin
            blk_ctrl.test_start <= 1'b0;  // pulse for one cycle
            timeout_ctr         <= timeout_ctr + 1;

            if (blk_status.test_done) begin
              state <= SEQ_COLLECT_RESULTS;
            end else if (timeout_ctr >= reg_timeout_cycles) begin
              queue_write(REG_ERROR_CODE, {24'h0, ERR_TIMEOUT});
              state <= SEQ_ERROR;
            end
          end

          // -------------------------------------------------
          SEQ_COLLECT_RESULTS: begin
            // Write all four result registers over multiple cycles
            // For simplicity, write them in a burst (sequencer write port
            // is used one register per cycle, so we chain through sub-states).
            // We'll use a small counter embedded in timeout_ctr repurposed.
            case (timeout_ctr[1:0])
              2'd0: begin
                queue_write(REG_RESULT0, blk_status.test_result0);
                timeout_ctr <= 32'd1;
              end
              2'd1: begin
                queue_write(REG_RESULT1, blk_status.test_result1);
                timeout_ctr <= 32'd2;
              end
              2'd2: begin
                queue_write(REG_RESULT2, blk_status.test_result2);
                timeout_ctr <= 32'd3;
              end
              2'd3: begin
                queue_write(REG_RESULT3, blk_status.test_result3);
                timeout_ctr <= 32'd0;
                state       <= SEQ_WRITE_STATUS;
              end
            endcase
          end

          // -------------------------------------------------
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

          // -------------------------------------------------
          SEQ_APPEND_LOG: begin
            log_entry.block_id   <= active_block;
            log_entry.error_code <= blk_status.test_error;
            log_entry.pass       <= blk_status.test_pass;
            log_entry.fail       <= ~blk_status.test_pass;
            log_entry.reserved   <= '0;
            log_entry.cycle_start<= cycle_start;
            log_entry.cycle_end  <= cycle_count;
            log_entry.result0    <= blk_status.test_result0;
            log_entry.result1    <= blk_status.test_result1;
            log_entry.result2    <= blk_status.test_result2;
            log_entry.result3    <= blk_status.test_result3;
            log_wr               <= 1'b1;
            state                <= SEQ_COMPLETE;
          end

          // -------------------------------------------------
          SEQ_COMPLETE: begin
            blk_ctrl.test_enable <= 1'b0;
            blk_ctrl.test_mode   <= 1'b0;
            // Set done + pass/fail in status
            queue_write(REG_GLOBAL_STATUS,
              (32'h1 << STAT_DONE) |
              (blk_status.test_pass ? (32'h1 << STAT_PASS) : (32'h1 << STAT_FAIL)) |
              (dangerous_armed ? (32'h1 << STAT_DANGEROUS_ARMED) : 32'h0));
            queue_write(REG_LOG_PTR, log_ptr);
            queue_write(REG_LOG_COUNT, log_count);
            state <= SEQ_IDLE;
          end

          // -------------------------------------------------
          SEQ_ERROR: begin
            blk_ctrl.test_enable <= 1'b0;
            blk_ctrl.test_mode   <= 1'b0;
            fail_count           <= fail_count + 1;
            queue_write(REG_FAIL_COUNT, fail_count + 1);
            queue_write(REG_GLOBAL_STATUS,
              (32'h1 << STAT_DONE) | (32'h1 << STAT_FAIL) |
              (timeout_ctr >= reg_timeout_cycles ? (32'h1 << STAT_TIMEOUT) : 32'h0));
            // Log the error
            log_entry.block_id   <= active_block;
            log_entry.error_code <= seq_wdata[7:0]; // from last error write
            log_entry.pass       <= 1'b0;
            log_entry.fail       <= 1'b1;
            log_entry.reserved   <= '0;
            log_entry.cycle_start<= cycle_start;
            log_entry.cycle_end  <= cycle_count;
            log_entry.result0    <= '0;
            log_entry.result1    <= '0;
            log_entry.result2    <= '0;
            log_entry.result3    <= '0;
            log_wr               <= 1'b1;
            state                <= SEQ_IDLE;
          end

          // -------------------------------------------------
          SEQ_ABORT: begin
            blk_ctrl <= '0;
            state    <= SEQ_IDLE;
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
        wr_data_q  <= {28'h0, state};
      end
    end
  end

endmodule
