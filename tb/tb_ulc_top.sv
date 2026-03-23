// Full-chip testbench — drives ULC through UART host bridge
// Runs the safe test suite end-to-end
`timescale 1ns / 1ps

module tb_ulc_top;
  import ulc_pkg::*;

  localparam int CLK_FREQ  = 50_000_000;
  localparam int BAUD_RATE = 1_000_000;  // fast baud for sim
  localparam int BIT_PERIOD = 1_000_000_000 / BAUD_RATE;  // ns

  logic clk, rst_n;
  logic uart_rx, uart_tx;
  logic [4:0] led;

  // Stub connections for block I/O
  logic [7:0]  gpio_in;
  logic [31:0] sram_rdata;
  logic [3:0]  osc_in;
  logic        clk_meas_in;
  logic        entropy_bit, entropy_valid;
  logic [127:0] puf_response;
  logic        puf_valid;
  logic        comp_out;
  logic [11:0] adc_data;
  logic        adc_done;
  logic [31:0] nvm_rdata;
  logic        nvm_busy;
  logic        spi_miso;
  logic        i2c_sda_i;

  // DUT
  ulc_top #(
    .CLK_FREQ  (CLK_FREQ),
    .BAUD_RATE (BAUD_RATE)
  ) dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .uart_rx      (uart_rx),
    .uart_tx      (uart_tx),
    .led          (led),
    .gpio_out     (),
    .gpio_in      (gpio_in),
    .gpio_oe      (),
    .sram_addr    (),
    .sram_wdata   (),
    .sram_rdata   (sram_rdata),
    .sram_we      (),
    .sram_en      (),
    .osc_en       (),
    .osc_in       (osc_in),
    .clk_sel      (),
    .clk_meas_in  (clk_meas_in),
    .entropy_bit  (entropy_bit),
    .entropy_valid(entropy_valid),
    .puf_challenge(),
    .puf_response (puf_response),
    .puf_valid    (puf_valid),
    .comp_out     (comp_out),
    .threshold_code(),
    .adc_data     (adc_data),
    .adc_start    (),
    .adc_done     (adc_done),
    .adc_channel  (),
    .nvm_addr     (),
    .nvm_wdata    (),
    .nvm_rdata    (nvm_rdata),
    .nvm_we       (),
    .nvm_re       (),
    .nvm_program  (),
    .nvm_busy     (nvm_busy),
    .spi_clk_o    (),
    .spi_mosi     (),
    .spi_miso     (spi_miso),
    .spi_cs_n     (),
    .i2c_scl_o    (),
    .i2c_sda_o    (),
    .i2c_sda_i    (i2c_sda_i)
  );

  // ---------------------------------------------------------------
  // Clock generation (50 MHz)
  // ---------------------------------------------------------------
  initial clk = 0;
  always #10 clk = ~clk;

  // ---------------------------------------------------------------
  // Stimulus helpers — UART byte-level
  // ---------------------------------------------------------------
  task automatic uart_send_byte(input logic [7:0] data);
    integer i;
    // Start bit
    uart_rx = 1'b0;
    #(BIT_PERIOD);
    // Data bits (LSB first)
    for (i = 0; i < 8; i++) begin
      uart_rx = data[i];
      #(BIT_PERIOD);
    end
    // Stop bit
    uart_rx = 1'b1;
    #(BIT_PERIOD);
  endtask

  task automatic uart_recv_byte(output logic [7:0] data);
    integer i;
    // Wait for start bit
    @(negedge uart_tx);
    #(BIT_PERIOD / 2);  // mid-bit
    #(BIT_PERIOD);       // skip start bit
    for (i = 0; i < 8; i++) begin
      data[i] = uart_tx;
      #(BIT_PERIOD);
    end
    // Stop bit
    #(BIT_PERIOD);
  endtask

  // Write register: 'W' addr d3 d2 d1 d0 -> ACK
  task automatic reg_write(input logic [7:0] addr, input logic [31:0] data);
    logic [7:0] ack;
    uart_send_byte(8'h57);  // 'W'
    uart_send_byte(addr);
    uart_send_byte(data[31:24]);
    uart_send_byte(data[23:16]);
    uart_send_byte(data[15:8]);
    uart_send_byte(data[7:0]);
    uart_recv_byte(ack);
    if (ack !== 8'h06)
      $display("ERROR: Expected ACK (0x06), got 0x%02h", ack);
  endtask

  // Read register: 'R' addr -> d3 d2 d1 d0
  task automatic reg_read(input logic [7:0] addr, output logic [31:0] data);
    logic [7:0] b3, b2, b1, b0;
    uart_send_byte(8'h52);  // 'R'
    uart_send_byte(addr);
    uart_recv_byte(b3);
    uart_recv_byte(b2);
    uart_recv_byte(b1);
    uart_recv_byte(b0);
    data = {b3, b2, b1, b0};
  endtask

  // ---------------------------------------------------------------
  // Default stub behavior
  // ---------------------------------------------------------------
  initial begin
    gpio_in       = 8'h00;
    sram_rdata    = 32'h0;
    osc_in        = 4'b0;
    clk_meas_in   = 1'b0;
    entropy_bit   = 1'b0;
    entropy_valid = 1'b0;
    puf_response  = '0;
    puf_valid     = 1'b0;
    comp_out      = 1'b0;
    adc_data      = 12'h0;
    adc_done      = 1'b0;
    nvm_rdata     = 32'h0;
    nvm_busy      = 1'b0;
    spi_miso      = 1'b0;
    i2c_sda_i     = 1'b1;
  end

  // Simple SRAM model
  logic [31:0] sram_mem [0:1023];
  always_ff @(posedge clk) begin
    if (dut.sram_en) begin
      if (dut.sram_we)
        sram_mem[dut.sram_addr] <= dut.sram_wdata;
      else
        sram_rdata <= sram_mem[dut.sram_addr];
    end
  end

  // GPIO loopback
  assign gpio_in = dut.gpio_out;

  // SPI loopback (MOSI -> MISO)
  assign spi_miso = dut.spi_mosi;

  // ---------------------------------------------------------------
  // Main test sequence
  // ---------------------------------------------------------------
  logic [31:0] rdata;
  int pass_total, fail_total;

  initial begin
    uart_rx = 1'b1;
    rst_n   = 1'b0;
    pass_total = 0;
    fail_total = 0;

    repeat (20) @(posedge clk);
    rst_n = 1'b1;
    repeat (10) @(posedge clk);

    $display("=== ULC Full-Chip Test ===");

    // Read CHIP_ID
    reg_read(REG_CHIP_ID, rdata);
    $display("CHIP_ID  = 0x%08h (expect 0x%08h)", rdata, CHIP_ID_VALUE);
    if (rdata === CHIP_ID_VALUE) pass_total++; else fail_total++;

    // Read CHIP_REV
    reg_read(REG_CHIP_REV, rdata);
    $display("CHIP_REV = 0x%08h (expect 0x%08h)", rdata, CHIP_REV_VALUE);
    if (rdata === CHIP_REV_VALUE) pass_total++; else fail_total++;

    // Enable test fabric
    reg_write(REG_GLOBAL_CONTROL, 32'h1 << CTRL_GLOBAL_ENABLE);

    // --- Test block 0: Register bank self-test ---
    $display("\n--- Block 0: Register Bank ---");
    reg_write(REG_BLOCK_SELECT, {24'h0, BLK_REGBANK});
    reg_write(REG_COMMAND, {24'h0, CMD_START_SELECTED});
    // Poll for done
    rdata = 0;
    while (!(rdata[STAT_DONE])) begin
      reg_read(REG_GLOBAL_STATUS, rdata);
    end
    $display("  STATUS = 0x%08h  PASS=%0d", rdata, rdata[STAT_PASS]);
    reg_read(REG_ERROR_CODE, rdata);
    $display("  ERROR  = 0x%02h", rdata[7:0]);
    if (rdata[7:0] == ERR_NONE) pass_total++; else fail_total++;

    // --- Test block 1: SRAM BIST ---
    $display("\n--- Block 1: SRAM ---");
    reg_write(REG_BLOCK_SELECT, {24'h0, BLK_SRAM});
    reg_write(REG_COMMAND, {24'h0, CMD_START_SELECTED});
    rdata = 0;
    while (!(rdata[STAT_DONE])) begin
      reg_read(REG_GLOBAL_STATUS, rdata);
    end
    reg_read(REG_ERROR_CODE, rdata);
    $display("  ERROR  = 0x%02h", rdata[7:0]);
    reg_read(REG_RESULT3, rdata);
    $display("  Patterns completed = %0d", rdata);
    if (rdata >= 4) pass_total++; else fail_total++;

    // --- Test block 5: GPIO ---
    $display("\n--- Block 5: GPIO ---");
    reg_write(REG_BLOCK_SELECT, {24'h0, BLK_GPIO});
    reg_write(REG_COMMAND, {24'h0, CMD_START_SELECTED});
    rdata = 0;
    while (!(rdata[STAT_DONE])) begin
      reg_read(REG_GLOBAL_STATUS, rdata);
    end
    reg_read(REG_ERROR_CODE, rdata);
    $display("  ERROR  = 0x%02h", rdata[7:0]);
    if (rdata[7:0] == ERR_NONE) pass_total++; else fail_total++;

    // --- Test NVM without arming (should be denied) ---
    $display("\n--- Block 12: NVM (unarmed — expect denial) ---");
    reg_write(REG_BLOCK_SELECT, {24'h0, BLK_NVM});
    reg_write(REG_COMMAND, {24'h0, CMD_START_SELECTED});
    rdata = 0;
    while (!(rdata[STAT_DONE])) begin
      reg_read(REG_GLOBAL_STATUS, rdata);
    end
    reg_read(REG_ERROR_CODE, rdata);
    $display("  ERROR  = 0x%02h (expect 0x%02h = UNSAFE_DENIED)", rdata[7:0], ERR_UNSAFE_DENIED);
    if (rdata[7:0] == ERR_UNSAFE_DENIED) pass_total++; else fail_total++;

    // --- Summary ---
    $display("\n=== SUMMARY: %0d passed, %0d failed ===", pass_total, fail_total);
    if (fail_total == 0)
      $display("ALL TESTS PASSED");
    else
      $display("FAILURES DETECTED");

    #1000;
    $finish;
  end

  // Timeout watchdog
  initial begin
    #100_000_000;
    $display("TIMEOUT — simulation exceeded limit");
    $finish;
  end

endmodule
