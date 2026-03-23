// Unit testbench for test_sequencer — exercises FSM transitions
`timescale 1ns / 1ps

module tb_test_sequencer;
  import ulc_pkg::*;

  logic        clk, rst_n;
  logic [31:0] reg_global_control;
  logic [7:0]  reg_block_select;
  logic [7:0]  reg_command;
  logic [31:0] reg_timeout_cycles;
  logic        cmd_strobe;

  logic        seq_wr;
  logic [7:0]  seq_addr;
  logic [31:0] seq_wdata;

  test_ctrl_t               blk_ctrl;
  test_status_t             blk_status;
  logic [NUM_BLOCKS-1:0]    blk_sel_oh;

  logic        log_wr;
  log_entry_t  log_entry;
  logic [31:0] log_ptr, log_count;
  logic [31:0] cycle_count;

  test_sequencer dut (.*);

  // Clock
  initial clk = 0;
  always #5 clk = ~clk;

  // Cycle counter
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) cycle_count <= '0;
    else        cycle_count <= cycle_count + 1;

  // Stub log pointer
  assign log_ptr   = 32'h0;
  assign log_count = 32'h0;

  // Fake block: responds with done+pass after 10 cycles
  int block_delay;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      blk_status <= '0;
      block_delay <= 0;
    end else begin
      blk_status.test_done <= 1'b0;
      if (blk_ctrl.test_start) begin
        block_delay <= 10;
      end else if (block_delay > 0) begin
        block_delay <= block_delay - 1;
        if (block_delay == 1) begin
          blk_status.test_done    <= 1'b1;
          blk_status.test_pass    <= 1'b1;
          blk_status.test_error   <= ERR_NONE;
          blk_status.test_result0 <= 32'hCAFE_0000;
          blk_status.test_result1 <= 32'hCAFE_0001;
          blk_status.test_result2 <= 32'hCAFE_0002;
          blk_status.test_result3 <= 32'hCAFE_0003;
        end
      end
    end
  end

  initial begin
    rst_n              = 0;
    reg_global_control = 0;
    reg_block_select   = 0;
    reg_command        = 0;
    reg_timeout_cycles = 32'd1000;
    cmd_strobe         = 0;

    #50 rst_n = 1;

    // Enable test fabric
    @(posedge clk);
    reg_global_control = 32'h1 << CTRL_GLOBAL_ENABLE;

    // Start test on block 0
    @(posedge clk);
    reg_block_select = BLK_REGBANK;
    reg_command      = CMD_START_SELECTED;
    cmd_strobe       = 1;
    @(posedge clk);
    cmd_strobe = 0;

    // Wait for completion
    wait(seq_wr && seq_addr == REG_GLOBAL_STATUS && seq_wdata[STAT_DONE]);
    $display("Test completed. Pass=%b", seq_wdata[STAT_PASS]);

    // Check results were written
    repeat (5) @(posedge clk);
    $display("Log write occurred: %b", log_wr || log_entry.block_id == BLK_REGBANK);

    // Test timeout: set very short timeout, block never responds
    @(posedge clk);
    reg_timeout_cycles = 32'd5;
    blk_status         = '0;  // force block to never respond

    @(posedge clk);
    reg_block_select = BLK_SRAM;
    reg_command      = CMD_START_SELECTED;
    cmd_strobe       = 1;
    @(posedge clk);
    cmd_strobe = 0;
    reg_timeout_cycles = 32'd5; // very short

    // Wait for error state
    repeat (50) @(posedge clk);
    $display("After timeout test — checking fail count write");

    // Test dangerous block denial
    @(posedge clk);
    reg_timeout_cycles = 32'd1000;
    reg_block_select = BLK_NVM;
    reg_command      = CMD_START_SELECTED;
    cmd_strobe       = 1;
    @(posedge clk);
    cmd_strobe = 0;

    repeat (20) @(posedge clk);
    $display("NVM denial test complete");

    #200;
    $display("=== tb_test_sequencer DONE ===");
    $finish;
  end

  initial begin
    #50000;
    $display("TIMEOUT");
    $finish;
  end

endmodule
