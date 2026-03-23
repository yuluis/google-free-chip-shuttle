// Unit testbench for test_register_bank — verifies read/write behavior
`timescale 1ns / 1ps

module tb_register_bank;
  import ulc_pkg::*;

  logic        clk, rst_n;
  logic        host_wr, host_rd;
  logic [7:0]  host_addr;
  logic [31:0] host_wdata, host_rdata;
  logic        host_rvalid;

  logic        seq_wr;
  logic [7:0]  seq_addr;
  logic [31:0] seq_wdata;

  logic [31:0] reg_global_control, reg_global_status;
  logic [7:0]  reg_block_select, reg_command, reg_error_code;
  logic [7:0]  reg_last_block;
  logic [3:0]  reg_last_state;
  logic [31:0] reg_timeout_cycles;
  logic [31:0] reg_result0, reg_result1, reg_result2, reg_result3;
  logic [31:0] reg_pass_count, reg_fail_count;
  logic [31:0] reg_log_ptr, reg_log_count;
  logic        cmd_strobe;

  test_register_bank dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  task automatic do_write(input logic [7:0] addr, input logic [31:0] data);
    @(posedge clk);
    host_wr    = 1;
    host_addr  = addr;
    host_wdata = data;
    @(posedge clk);
    host_wr = 0;
  endtask

  task automatic do_read(input logic [7:0] addr, output logic [31:0] data);
    @(posedge clk);
    host_rd   = 1;
    host_addr = addr;
    @(posedge clk);
    host_rd = 0;
    @(posedge clk);  // wait for rvalid
    data = host_rdata;
  endtask

  logic [31:0] rval;
  int errors;

  initial begin
    rst_n      = 0;
    host_wr    = 0;
    host_rd    = 0;
    host_addr  = 0;
    host_wdata = 0;
    seq_wr     = 0;
    seq_addr   = 0;
    seq_wdata  = 0;
    errors     = 0;

    #30 rst_n = 1;
    #10;

    // Test 1: Read CHIP_ID
    do_read(REG_CHIP_ID, rval);
    if (rval !== CHIP_ID_VALUE) begin
      $display("FAIL: CHIP_ID = 0x%08h, expected 0x%08h", rval, CHIP_ID_VALUE);
      errors++;
    end

    // Test 2: Read CHIP_REV
    do_read(REG_CHIP_REV, rval);
    if (rval !== CHIP_REV_VALUE) begin
      $display("FAIL: CHIP_REV = 0x%08h, expected 0x%08h", rval, CHIP_REV_VALUE);
      errors++;
    end

    // Test 3: Write and read back GLOBAL_CONTROL
    do_write(REG_GLOBAL_CONTROL, 32'h0000_001F);
    do_read(REG_GLOBAL_CONTROL, rval);
    if (rval !== 32'h0000_001F) begin
      $display("FAIL: GLOBAL_CONTROL = 0x%08h, expected 0x0000001F", rval);
      errors++;
    end

    // Test 4: Write BLOCK_SELECT
    do_write(REG_BLOCK_SELECT, {24'h0, 8'h05});
    if (reg_block_select !== 8'h05) begin
      $display("FAIL: block_select = 0x%02h, expected 0x05", reg_block_select);
      errors++;
    end

    // Test 5: Command strobe
    do_write(REG_COMMAND, {24'h0, CMD_START_SELECTED});
    @(posedge clk);
    if (!cmd_strobe) begin
      $display("FAIL: cmd_strobe not asserted");
      errors++;
    end
    @(posedge clk);
    // Command should auto-clear
    if (reg_command !== 8'h00) begin
      $display("FAIL: command not auto-cleared, = 0x%02h", reg_command);
      errors++;
    end

    // Test 6: Sequencer write to RESULT0
    @(posedge clk);
    seq_wr    = 1;
    seq_addr  = REG_RESULT0;
    seq_wdata = 32'hBEEF_CAFE;
    @(posedge clk);
    seq_wr = 0;
    do_read(REG_RESULT0, rval);
    if (rval !== 32'hBEEF_CAFE) begin
      $display("FAIL: RESULT0 = 0x%08h, expected 0xBEEFCAFE", rval);
      errors++;
    end

    // Test 7: Read unknown address returns DEAD_BEEF
    do_read(8'hFC, rval);
    if (rval !== 32'hDEAD_BEEF) begin
      $display("FAIL: unknown addr read = 0x%08h, expected 0xDEADBEEF", rval);
      errors++;
    end

    // Test 8: Default timeout value
    do_read(REG_TIMEOUT_CYCLES, rval);
    if (rval !== DEFAULT_TIMEOUT) begin
      $display("FAIL: default timeout = 0x%08h, expected 0x%08h", rval, DEFAULT_TIMEOUT);
      errors++;
    end

    #50;
    if (errors == 0)
      $display("=== tb_register_bank PASSED ===");
    else
      $display("=== tb_register_bank FAILED (%0d errors) ===", errors);
    $finish;
  end

endmodule
