// Test register bank — shared register file for the ULC test framework
// Provides read/write access from the host bridge and internal updates
// from the test sequencer.
module test_register_bank
  import ulc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Host-side bus (from UART bridge)
  input  logic        host_wr,
  input  logic        host_rd,
  input  logic [7:0]  host_addr,
  input  logic [31:0] host_wdata,
  output logic [31:0] host_rdata,
  output logic        host_rvalid,

  // Sequencer write port (higher priority than host for status regs)
  input  logic        seq_wr,
  input  logic [7:0]  seq_addr,
  input  logic [31:0] seq_wdata,

  // Direct register outputs to sequencer
  output logic [31:0] reg_global_control,
  output logic [31:0] reg_global_status,
  output logic [7:0]  reg_block_select,
  output logic [7:0]  reg_command,
  output logic [31:0] reg_timeout_cycles,
  output logic [31:0] reg_result0,
  output logic [31:0] reg_result1,
  output logic [31:0] reg_result2,
  output logic [31:0] reg_result3,
  output logic [7:0]  reg_error_code,
  output logic [31:0] reg_pass_count,
  output logic [31:0] reg_fail_count,
  output logic [7:0]  reg_last_block,
  output logic [3:0]  reg_last_state,
  output logic [31:0] reg_log_ptr,
  output logic [31:0] reg_log_count,

  // Command strobe — pulses for one cycle when host writes COMMAND
  output logic        cmd_strobe
);

  // Internal register storage
  logic [31:0] r_global_control;
  logic [31:0] r_global_status;
  logic [31:0] r_block_select;
  logic [31:0] r_command;
  logic [31:0] r_timeout_cycles;
  logic [31:0] r_result [0:3];
  logic [31:0] r_error_code;
  logic [31:0] r_pass_count;
  logic [31:0] r_fail_count;
  logic [31:0] r_last_block;
  logic [31:0] r_last_state;
  logic [31:0] r_log_ptr;
  logic [31:0] r_log_count;

  // Assign outputs
  assign reg_global_control = r_global_control;
  assign reg_global_status  = r_global_status;
  assign reg_block_select   = r_block_select[7:0];
  assign reg_command        = r_command[7:0];
  assign reg_timeout_cycles = r_timeout_cycles;
  assign reg_result0        = r_result[0];
  assign reg_result1        = r_result[1];
  assign reg_result2        = r_result[2];
  assign reg_result3        = r_result[3];
  assign reg_error_code     = r_error_code[7:0];
  assign reg_pass_count     = r_pass_count;
  assign reg_fail_count     = r_fail_count;
  assign reg_last_block     = r_last_block[7:0];
  assign reg_last_state     = r_last_state[3:0];
  assign reg_log_ptr        = r_log_ptr;
  assign reg_log_count      = r_log_count;

  // Command strobe generation
  logic cmd_strobe_r;
  assign cmd_strobe = cmd_strobe_r;

  // -----------------------------------------------------------
  // Write logic (sequencer has priority over host for status regs)
  // -----------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_global_control <= 32'h0;
      r_global_status  <= 32'h0;
      r_block_select   <= 32'h0;
      r_command        <= 32'h0;
      r_timeout_cycles <= DEFAULT_TIMEOUT;
      r_result[0]      <= 32'h0;
      r_result[1]      <= 32'h0;
      r_result[2]      <= 32'h0;
      r_result[3]      <= 32'h0;
      r_error_code     <= 32'h0;
      r_pass_count     <= 32'h0;
      r_fail_count     <= 32'h0;
      r_last_block     <= 32'h0;
      r_last_state     <= 32'h0;
      r_log_ptr        <= 32'h0;
      r_log_count      <= 32'h0;
      cmd_strobe_r     <= 1'b0;
    end else begin
      cmd_strobe_r <= 1'b0;

      // Sequencer writes (status, results, counters, log pointers)
      if (seq_wr) begin
        case (seq_addr)
          REG_GLOBAL_STATUS: r_global_status <= seq_wdata;
          REG_RESULT0:       r_result[0]     <= seq_wdata;
          REG_RESULT1:       r_result[1]     <= seq_wdata;
          REG_RESULT2:       r_result[2]     <= seq_wdata;
          REG_RESULT3:       r_result[3]     <= seq_wdata;
          REG_ERROR_CODE:    r_error_code    <= seq_wdata;
          REG_PASS_COUNT:    r_pass_count    <= seq_wdata;
          REG_FAIL_COUNT:    r_fail_count    <= seq_wdata;
          REG_LAST_BLOCK:    r_last_block    <= seq_wdata;
          REG_LAST_STATE:    r_last_state    <= seq_wdata;
          REG_LOG_PTR:       r_log_ptr       <= seq_wdata;
          REG_LOG_COUNT:     r_log_count     <= seq_wdata;
          default: ;
        endcase
      end

      // Host writes (control, block select, command, timeout)
      if (host_wr) begin
        case (host_addr)
          REG_GLOBAL_CONTROL: r_global_control <= host_wdata;
          REG_BLOCK_SELECT:   r_block_select   <= host_wdata;
          REG_COMMAND: begin
            r_command    <= host_wdata;
            cmd_strobe_r <= 1'b1;
          end
          REG_TIMEOUT_CYCLES: r_timeout_cycles <= host_wdata;
          default: ;
        endcase
      end

      // Auto-clear command after strobe
      if (cmd_strobe_r)
        r_command <= 32'h0;

      // Clear results on CTRL_CLEAR_RESULTS
      if (r_global_control[CTRL_CLEAR_RESULTS]) begin
        r_result[0]      <= 32'h0;
        r_result[1]      <= 32'h0;
        r_result[2]      <= 32'h0;
        r_result[3]      <= 32'h0;
        r_error_code     <= 32'h0;
        r_pass_count     <= 32'h0;
        r_fail_count     <= 32'h0;
        r_global_control[CTRL_CLEAR_RESULTS] <= 1'b0;
      end
    end
  end

  // -----------------------------------------------------------
  // Read logic
  // -----------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      host_rdata  <= 32'h0;
      host_rvalid <= 1'b0;
    end else begin
      host_rvalid <= host_rd;
      if (host_rd) begin
        case (host_addr)
          REG_CHIP_ID:        host_rdata <= CHIP_ID_VALUE;
          REG_CHIP_REV:       host_rdata <= CHIP_REV_VALUE;
          REG_GLOBAL_CONTROL: host_rdata <= r_global_control;
          REG_GLOBAL_STATUS:  host_rdata <= r_global_status;
          REG_BLOCK_SELECT:   host_rdata <= r_block_select;
          REG_COMMAND:        host_rdata <= r_command;
          REG_TIMEOUT_CYCLES: host_rdata <= r_timeout_cycles;
          REG_RESULT0:        host_rdata <= r_result[0];
          REG_RESULT1:        host_rdata <= r_result[1];
          REG_RESULT2:        host_rdata <= r_result[2];
          REG_RESULT3:        host_rdata <= r_result[3];
          REG_ERROR_CODE:     host_rdata <= r_error_code;
          REG_PASS_COUNT:     host_rdata <= r_pass_count;
          REG_FAIL_COUNT:     host_rdata <= r_fail_count;
          REG_LAST_BLOCK:     host_rdata <= r_last_block;
          REG_LAST_STATE:     host_rdata <= r_last_state;
          REG_LOG_PTR:        host_rdata <= r_log_ptr;
          REG_LOG_COUNT:      host_rdata <= r_log_count;
          default:            host_rdata <= 32'hDEAD_BEEF;
        endcase
      end
    end
  end

endmodule
