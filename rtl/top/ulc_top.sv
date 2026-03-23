// Universal Learning Chip — Top-level integration
// Connects: UART bridge -> register bank -> sequencer -> test_mux -> block wrappers
//           + log buffer + LED status
module ulc_top
  import ulc_pkg::*;
#(
  parameter int CLK_FREQ  = 50_000_000,
  parameter int BAUD_RATE = 115_200
)(
  input  logic       clk,
  input  logic       rst_n,

  // UART
  input  logic       uart_rx,
  output logic       uart_tx,

  // LEDs
  output logic [4:0] led,

  // GPIO
  output logic [7:0] gpio_out,
  input  logic [7:0] gpio_in,
  output logic [7:0] gpio_oe,

  // SRAM interface (external macro or model)
  output logic [9:0]  sram_addr,
  output logic [31:0] sram_wdata,
  input  logic [31:0] sram_rdata,
  output logic        sram_we,
  output logic        sram_en,

  // Ring oscillator inputs
  output logic [3:0]  osc_en,
  input  logic [3:0]  osc_in,

  // Clock mux measurement
  output logic [1:0]  clk_sel,
  input  logic        clk_meas_in,

  // TRNG entropy source
  input  logic        entropy_bit,
  input  logic        entropy_valid,

  // PUF
  output logic [7:0]  puf_challenge,
  input  logic [127:0] puf_response,
  input  logic        puf_valid,

  // Comparator
  input  logic        comp_out,
  output logic [7:0]  threshold_code,

  // ADC
  input  logic [11:0] adc_data,
  output logic        adc_start,
  input  logic        adc_done,
  output logic [2:0]  adc_channel,

  // NVM / OTP
  output logic [7:0]  nvm_addr,
  output logic [31:0] nvm_wdata,
  input  logic [31:0] nvm_rdata,
  output logic        nvm_we,
  output logic        nvm_re,
  output logic        nvm_program,
  input  logic        nvm_busy,

  // SPI (directly exposed for external loopback testing)
  output logic        spi_clk_o,
  output logic        spi_mosi,
  input  logic        spi_miso,
  output logic        spi_cs_n,

  // I2C
  output logic        i2c_scl_o,
  output logic        i2c_sda_o,
  input  logic        i2c_sda_i
);

  // ---------------------------------------------------------------
  // Free-running cycle counter
  // ---------------------------------------------------------------
  logic [31:0] cycle_count;
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) cycle_count <= '0;
    else        cycle_count <= cycle_count + 1;

  // ---------------------------------------------------------------
  // UART host bridge -> register bus
  // ---------------------------------------------------------------
  logic        host_wr, host_rd;
  logic [7:0]  host_addr;
  logic [31:0] host_wdata, host_rdata;
  logic        host_rvalid;

  uart_host_bridge #(
    .CLK_FREQ  (CLK_FREQ),
    .BAUD_RATE (BAUD_RATE)
  ) u_bridge (
    .clk        (clk),
    .rst_n      (rst_n),
    .uart_rx    (uart_rx),
    .uart_tx    (uart_tx),
    .reg_wr     (host_wr),
    .reg_rd     (host_rd),
    .reg_addr   (host_addr),
    .reg_wdata  (host_wdata),
    .reg_rdata  (host_rdata),
    .reg_rvalid (host_rvalid)
  );

  // ---------------------------------------------------------------
  // Register bank
  // ---------------------------------------------------------------
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

  test_register_bank u_regbank (
    .clk               (clk),
    .rst_n             (rst_n),
    .host_wr           (host_wr),
    .host_rd           (host_rd),
    .host_addr         (host_addr),
    .host_wdata        (host_wdata),
    .host_rdata        (host_rdata),
    .host_rvalid       (host_rvalid),
    .seq_wr            (seq_wr),
    .seq_addr          (seq_addr),
    .seq_wdata         (seq_wdata),
    .reg_global_control(reg_global_control),
    .reg_global_status (reg_global_status),
    .reg_block_select  (reg_block_select),
    .reg_command       (reg_command),
    .reg_timeout_cycles(reg_timeout_cycles),
    .reg_result0       (reg_result0),
    .reg_result1       (reg_result1),
    .reg_result2       (reg_result2),
    .reg_result3       (reg_result3),
    .reg_error_code    (reg_error_code),
    .reg_pass_count    (reg_pass_count),
    .reg_fail_count    (reg_fail_count),
    .reg_last_block    (reg_last_block),
    .reg_last_state    (reg_last_state),
    .reg_log_ptr       (reg_log_ptr),
    .reg_log_count     (reg_log_count),
    .cmd_strobe        (cmd_strobe)
  );

  // ---------------------------------------------------------------
  // Test sequencer
  // ---------------------------------------------------------------
  test_ctrl_t                  blk_ctrl;
  test_status_t                blk_status_muxed;
  logic [NUM_BLOCKS-1:0]       blk_sel_oh;

  logic        log_wr;
  log_entry_t  log_entry;
  logic [31:0] log_buf_ptr, log_buf_count;

  test_sequencer u_sequencer (
    .clk               (clk),
    .rst_n             (rst_n),
    .reg_global_control(reg_global_control),
    .reg_block_select  (reg_block_select),
    .reg_command       (reg_command),
    .reg_timeout_cycles(reg_timeout_cycles),
    .cmd_strobe        (cmd_strobe),
    .seq_wr            (seq_wr),
    .seq_addr          (seq_addr),
    .seq_wdata         (seq_wdata),
    .blk_ctrl          (blk_ctrl),
    .blk_status        (blk_status_muxed),
    .blk_sel_oh        (blk_sel_oh),
    .log_wr            (log_wr),
    .log_entry         (log_entry),
    .log_ptr           (log_buf_ptr),
    .log_count         (log_buf_count),
    .cycle_count       (cycle_count)
  );

  // ---------------------------------------------------------------
  // Test log buffer
  // ---------------------------------------------------------------
  log_entry_t log_rd_entry;

  test_log_buffer u_log (
    .clk       (clk),
    .rst_n     (rst_n),
    .wr_en     (log_wr),
    .wr_entry  (log_entry),
    .rd_index  (5'h0),  // TODO: host read index via extra register
    .rd_entry  (log_rd_entry),
    .log_ptr   (log_buf_ptr),
    .log_count (log_buf_count)
  );

  // ---------------------------------------------------------------
  // Test mux
  // ---------------------------------------------------------------
  test_ctrl_t   ctrl_per_block [NUM_BLOCKS];
  test_status_t status_per_block [NUM_BLOCKS];

  test_mux u_mux (
    .blk_sel_oh (blk_sel_oh),
    .ctrl_in    (blk_ctrl),
    .ctrl_out   (ctrl_per_block),
    .status_in  (status_per_block),
    .status_out (blk_status_muxed)
  );

  // ---------------------------------------------------------------
  // Block wrappers
  // ---------------------------------------------------------------

  // 0: Register bank self-test
  regbank_test_wrapper u_test_regbank (
    .clk    (clk),
    .rst_n  (rst_n),
    .ctrl   (ctrl_per_block[BLK_REGBANK]),
    .status (status_per_block[BLK_REGBANK])
  );

  // 1: SRAM BIST
  sram_test_wrapper u_test_sram (
    .clk       (clk),
    .rst_n     (rst_n),
    .ctrl      (ctrl_per_block[BLK_SRAM]),
    .status    (status_per_block[BLK_SRAM]),
    .sram_addr (sram_addr),
    .sram_wdata(sram_wdata),
    .sram_rdata(sram_rdata),
    .sram_we   (sram_we),
    .sram_en   (sram_en)
  );

  // 2: UART loopback
  logic uart_loopback_en;
  uart_test_wrapper u_test_uart (
    .clk         (clk),
    .rst_n       (rst_n),
    .ctrl        (ctrl_per_block[BLK_UART]),
    .status      (status_per_block[BLK_UART]),
    .uart_tx     (),  // internal loopback — not routed externally
    .uart_rx     (1'b1),
    .loopback_en (uart_loopback_en)
  );

  // 3: SPI loopback
  spi_test_wrapper u_test_spi (
    .clk      (clk),
    .rst_n    (rst_n),
    .ctrl     (ctrl_per_block[BLK_SPI]),
    .status   (status_per_block[BLK_SPI]),
    .spi_clk_o(spi_clk_o),
    .spi_mosi (spi_mosi),
    .spi_miso (spi_miso),
    .spi_cs_n (spi_cs_n)
  );

  // 4: I2C
  i2c_test_wrapper u_test_i2c (
    .clk      (clk),
    .rst_n    (rst_n),
    .ctrl     (ctrl_per_block[BLK_I2C]),
    .status   (status_per_block[BLK_I2C]),
    .i2c_scl_o(i2c_scl_o),
    .i2c_sda_o(i2c_sda_o),
    .i2c_sda_i(i2c_sda_i)
  );

  // 5: GPIO
  gpio_test_wrapper u_test_gpio (
    .clk     (clk),
    .rst_n   (rst_n),
    .ctrl    (ctrl_per_block[BLK_GPIO]),
    .status  (status_per_block[BLK_GPIO]),
    .gpio_out(gpio_out),
    .gpio_in (gpio_in),
    .gpio_oe (gpio_oe)
  );

  // 6: Ring oscillators
  ring_osc_test_wrapper u_test_rosc (
    .clk    (clk),
    .rst_n  (rst_n),
    .ctrl   (ctrl_per_block[BLK_RING_OSC]),
    .status (status_per_block[BLK_RING_OSC]),
    .osc_en (osc_en),
    .osc_in (osc_in)
  );

  // 7: Clock divider / mux
  clk_div_test_wrapper u_test_clkdiv (
    .clk        (clk),
    .rst_n      (rst_n),
    .ctrl       (ctrl_per_block[BLK_CLK_DIV]),
    .status     (status_per_block[BLK_CLK_DIV]),
    .clk_sel    (clk_sel),
    .clk_meas_in(clk_meas_in)
  );

  // 8: TRNG
  trng_test_wrapper u_test_trng (
    .clk           (clk),
    .rst_n         (rst_n),
    .ctrl          (ctrl_per_block[BLK_TRNG]),
    .status        (status_per_block[BLK_TRNG]),
    .entropy_bit   (entropy_bit),
    .entropy_valid (entropy_valid)
  );

  // 9: PUF
  puf_test_wrapper u_test_puf (
    .clk           (clk),
    .rst_n         (rst_n),
    .ctrl          (ctrl_per_block[BLK_PUF]),
    .status        (status_per_block[BLK_PUF]),
    .puf_challenge (puf_challenge),
    .puf_response  (puf_response),
    .puf_valid     (puf_valid)
  );

  // 10: Comparator
  comparator_test_wrapper u_test_comp (
    .clk           (clk),
    .rst_n         (rst_n),
    .ctrl          (ctrl_per_block[BLK_COMPARATOR]),
    .status        (status_per_block[BLK_COMPARATOR]),
    .comp_out      (comp_out),
    .threshold_code(threshold_code)
  );

  // 11: ADC
  adc_test_wrapper u_test_adc (
    .clk        (clk),
    .rst_n      (rst_n),
    .ctrl       (ctrl_per_block[BLK_ADC]),
    .status     (status_per_block[BLK_ADC]),
    .adc_data   (adc_data),
    .adc_start  (adc_start),
    .adc_done   (adc_done),
    .adc_channel(adc_channel)
  );

  // 12: NVM (dangerous)
  nvm_test_wrapper u_test_nvm (
    .clk            (clk),
    .rst_n          (rst_n),
    .ctrl           (ctrl_per_block[BLK_NVM]),
    .status         (status_per_block[BLK_NVM]),
    .dangerous_armed(reg_global_control[CTRL_ARM_DANGEROUS]),
    .nvm_addr       (nvm_addr),
    .nvm_wdata      (nvm_wdata),
    .nvm_rdata      (nvm_rdata),
    .nvm_we         (nvm_we),
    .nvm_re         (nvm_re),
    .nvm_program    (nvm_program),
    .nvm_busy       (nvm_busy)
  );

  // ---------------------------------------------------------------
  // LED status
  // ---------------------------------------------------------------
  led_status u_led (
    .clk            (clk),
    .rst_n          (rst_n),
    .global_status  (reg_global_status),
    .global_control (reg_global_control),
    .cycle_count    (cycle_count),
    .led            (led)
  );

endmodule
