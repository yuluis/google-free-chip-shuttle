// Universal Learning Chip — shared types, constants, and register map
// v2.0 — Extended with DAC, PLL, analog route matrix, clock mux tree,
//         BIST serial-pattern fabric, and experiment profiles
package ulc_pkg;

  // ---------------------------------------------------------------
  // Chip identity
  // ---------------------------------------------------------------
  localparam logic [31:0] CHIP_ID_VALUE  = 32'h554C_4332;  // 'ULC2' ASCII
  localparam logic [31:0] CHIP_REV_VALUE = 32'h0000_0002;

  // ---------------------------------------------------------------
  // Block IDs — Zone A: Digital Backbone / Safe Core
  // ---------------------------------------------------------------
  typedef enum logic [7:0] {
    BLK_REGBANK     = 8'h00,
    BLK_SRAM        = 8'h01,
    BLK_UART        = 8'h02,
    BLK_SPI         = 8'h03,
    BLK_I2C         = 8'h04,
    BLK_GPIO        = 8'h05,
    BLK_CLK_DIV     = 8'h07,
    // Zone B: Measurable Mixed-Signal
    BLK_RING_OSC    = 8'h06,
    BLK_TRNG        = 8'h08,
    BLK_PUF         = 8'h09,
    BLK_COMPARATOR  = 8'h0A,
    BLK_ADC         = 8'h0B,
    BLK_DAC         = 8'h0D,   // NEW — DAC block
    BLK_ANA_ROUTE   = 8'h0E,   // NEW — Analog route matrix (not independently tested)
    // Zone C: Experimental Clock
    BLK_PLL         = 8'h10,   // NEW — PLL/DPLL experiment
    BLK_CLK_MUX     = 8'h11,   // NEW — Clock mux tree (status only)
    // Zone D: Experimental / Dangerous
    BLK_NVM         = 8'h0C,
    // Infrastructure (not independently selectable)
    BLK_BIST_ENGINE = 8'h20    // NEW — BIST serial-pattern engine
  } block_id_t;

  localparam int NUM_BLOCKS = 16;  // testable blocks (0x00..0x11, excl infrastructure)

  // ---------------------------------------------------------------
  // Test commands
  // ---------------------------------------------------------------
  typedef enum logic [7:0] {
    CMD_NOP              = 8'h00,
    CMD_START_SELECTED   = 8'h01,
    CMD_ABORT            = 8'h02,
    CMD_STEP             = 8'h03,
    CMD_RERUN_LAST       = 8'h04,
    CMD_DUMP_LOG         = 8'h05,
    // v2 commands
    CMD_LOAD_EXPERIMENT  = 8'h10,  // Load experiment profile by ID
    CMD_APPLY_BIST       = 8'h11,  // Apply current BIST pattern
    CMD_CONFIGURE_ROUTE  = 8'h12,  // Configure analog route
    CMD_CONFIGURE_CLOCKS = 8'h13,  // Configure clock mux
    CMD_RESTORE_SAFE     = 8'h1F   // Restore all safe defaults
  } test_cmd_t;

  // ---------------------------------------------------------------
  // Error codes
  // ---------------------------------------------------------------
  typedef enum logic [7:0] {
    ERR_NONE             = 8'h00,
    ERR_TIMEOUT          = 8'h01,
    ERR_COMPARE_MISMATCH = 8'h02,
    ERR_RANGE_VIOLATION  = 8'h03,
    ERR_MISSING_RESPONSE = 8'h04,
    ERR_OVERFLOW         = 8'h05,
    ERR_UNSAFE_DENIED    = 8'h06,
    ERR_UNSUPPORTED_MODE = 8'h07,
    // v2 errors
    ERR_PLL_NO_LOCK      = 8'h10,
    ERR_ROUTE_CONTENTION = 8'h11,
    ERR_BIST_CHAIN_FAULT = 8'h12,
    ERR_CLOCK_ABSENT     = 8'h13,
    ERR_DAC_FAULT        = 8'h14
  } error_code_t;

  // ---------------------------------------------------------------
  // Sequencer states (extended)
  // ---------------------------------------------------------------
  typedef enum logic [4:0] {
    SEQ_IDLE             = 5'h00,
    SEQ_ARM_CHECK        = 5'h01,
    SEQ_PREPARE_BLOCK    = 5'h02,
    SEQ_START_BLOCK      = 5'h03,
    SEQ_WAIT_FOR_DONE    = 5'h04,
    SEQ_COLLECT_RESULTS  = 5'h05,
    SEQ_WRITE_STATUS     = 5'h06,
    SEQ_APPEND_LOG       = 5'h07,
    SEQ_COMPLETE         = 5'h08,
    SEQ_ERROR            = 5'h09,
    SEQ_ABORT            = 5'h0A,
    // v2 states
    SEQ_CONFIGURE_CLOCKS = 5'h10,
    SEQ_LOAD_BIST        = 5'h11,
    SEQ_APPLY_ROUTE      = 5'h12,
    SEQ_WAIT_PLL_LOCK    = 5'h13,
    SEQ_RUN_STIMULUS     = 5'h14,
    SEQ_CAPTURE_MEASURE  = 5'h15,
    SEQ_RESTORE_SAFE     = 5'h16,
    SEQ_LOAD_EXPERIMENT  = 5'h17
  } seq_state_t;

  // ---------------------------------------------------------------
  // Test modes
  // ---------------------------------------------------------------
  typedef enum logic [1:0] {
    MODE_SAFE_AUTO       = 2'b00,
    MODE_LAB_EXTENDED    = 2'b01,
    MODE_DANGEROUS_ARMED = 2'b10
  } test_mode_t;

  // ---------------------------------------------------------------
  // Global control register bits
  // ---------------------------------------------------------------
  localparam int CTRL_GLOBAL_ENABLE   = 0;
  localparam int CTRL_RESET_FABRIC    = 1;
  localparam int CTRL_ARM_DANGEROUS   = 2;
  localparam int CTRL_CLEAR_RESULTS   = 3;
  localparam int CTRL_LOOP_MODE       = 4;
  // v2 control bits
  localparam int CTRL_PLL_ENABLE      = 5;
  localparam int CTRL_DAC_ENABLE      = 6;
  localparam int CTRL_BIST_ENABLE     = 7;
  localparam int CTRL_LAB_MODE        = 8;  // enables combined experiments

  // ---------------------------------------------------------------
  // Global status register bits
  // ---------------------------------------------------------------
  localparam int STAT_BUSY            = 0;
  localparam int STAT_DONE            = 1;
  localparam int STAT_PASS            = 2;
  localparam int STAT_FAIL            = 3;
  localparam int STAT_TIMEOUT         = 4;
  localparam int STAT_DANGEROUS_ARMED = 5;
  localparam int STAT_OVERFLOW        = 6;
  localparam int STAT_WARNING         = 7;
  // v2 status bits
  localparam int STAT_PLL_LOCKED      = 8;
  localparam int STAT_DAC_ACTIVE      = 9;
  localparam int STAT_BIST_LOADED     = 10;
  localparam int STAT_ROUTE_ACTIVE    = 11;
  localparam int STAT_EXPERIMENT_RUNNING = 12;

  // ---------------------------------------------------------------
  // Register addresses (byte-addressed, 32-bit registers)
  // Base registers (0x00 - 0x4F)
  // ---------------------------------------------------------------
  localparam logic [7:0] REG_CHIP_ID           = 8'h00;
  localparam logic [7:0] REG_CHIP_REV          = 8'h04;
  localparam logic [7:0] REG_GLOBAL_CONTROL    = 8'h08;
  localparam logic [7:0] REG_GLOBAL_STATUS     = 8'h0C;
  localparam logic [7:0] REG_BLOCK_SELECT      = 8'h10;
  localparam logic [7:0] REG_COMMAND           = 8'h14;
  localparam logic [7:0] REG_TIMEOUT_CYCLES    = 8'h18;
  localparam logic [7:0] REG_RESULT0           = 8'h1C;
  localparam logic [7:0] REG_RESULT1           = 8'h20;
  localparam logic [7:0] REG_RESULT2           = 8'h24;
  localparam logic [7:0] REG_RESULT3           = 8'h28;
  localparam logic [7:0] REG_ERROR_CODE        = 8'h2C;
  localparam logic [7:0] REG_PASS_COUNT        = 8'h30;
  localparam logic [7:0] REG_FAIL_COUNT        = 8'h34;
  localparam logic [7:0] REG_LAST_BLOCK        = 8'h38;
  localparam logic [7:0] REG_LAST_STATE        = 8'h3C;
  localparam logic [7:0] REG_LOG_PTR           = 8'h40;
  localparam logic [7:0] REG_LOG_COUNT         = 8'h44;

  // v2 registers — Experiment & Orchestration (0x50 - 0x5F)
  localparam logic [7:0] REG_EXPERIMENT_ID     = 8'h50;
  localparam logic [7:0] REG_EXPERIMENT_STATUS = 8'h54;
  localparam logic [7:0] REG_EXPERIMENT_CONFIG = 8'h58;

  // v2 registers — BIST Pattern Engine (0x60 - 0x6F)
  localparam logic [7:0] REG_BIST_CONTROL      = 8'h60;
  localparam logic [7:0] REG_BIST_CHAIN_SEL    = 8'h64;
  localparam logic [7:0] REG_BIST_SHIFT_DATA   = 8'h68;
  localparam logic [7:0] REG_BIST_LATCH_STATUS = 8'h6C;

  // v2 registers — Clock Mux Tree (0x70 - 0x7F)
  localparam logic [7:0] REG_CLK_MUX_CONTROL   = 8'h70;
  localparam logic [7:0] REG_CLK_MUX_STATUS    = 8'h74;
  localparam logic [7:0] REG_CLK_FREQ_COUNT    = 8'h78;
  localparam logic [7:0] REG_CLK_FREQ_SELECT   = 8'h7C;

  // v2 registers — Analog Route Matrix (0x80 - 0x8F)
  localparam logic [7:0] REG_AROUTE_CONTROL    = 8'h80;
  localparam logic [7:0] REG_AROUTE_STATUS     = 8'h84;
  localparam logic [7:0] REG_AROUTE_ADC_SRC    = 8'h88;
  localparam logic [7:0] REG_AROUTE_COMP_SRC   = 8'h8C;

  // v2 registers — DAC (0x90 - 0x9F)
  localparam logic [7:0] REG_DAC_CONTROL       = 8'h90;
  localparam logic [7:0] REG_DAC_CODE          = 8'h94;
  localparam logic [7:0] REG_DAC_STATUS        = 8'h98;
  localparam logic [7:0] REG_DAC_UPDATE_COUNT  = 8'h9C;

  // v2 registers — PLL (0xA0 - 0xAF)
  localparam logic [7:0] REG_PLL_CONTROL       = 8'hA0;
  localparam logic [7:0] REG_PLL_STATUS        = 8'hA4;
  localparam logic [7:0] REG_PLL_FREQ_COUNT    = 8'hA8;
  localparam logic [7:0] REG_PLL_LOCK_TIMEOUT  = 8'hAC;

  // ---------------------------------------------------------------
  // Per-block test wrapper interface
  // ---------------------------------------------------------------
  typedef struct packed {
    logic        test_enable;
    logic        test_mode;    // 0 = normal, 1 = self-test
    logic        test_start;
  } test_ctrl_t;

  typedef struct packed {
    logic        test_done;
    logic        test_pass;
    logic [7:0]  test_error;
    logic [31:0] test_result0;
    logic [31:0] test_result1;
    logic [31:0] test_result2;
    logic [31:0] test_result3;
  } test_status_t;

  // ---------------------------------------------------------------
  // Log entry format (fits in 10 x 32-bit words = 40 bytes)
  // ---------------------------------------------------------------
  typedef struct packed {
    logic [7:0]  block_id;
    logic [7:0]  error_code;
    logic        pass;
    logic        fail;
    logic [5:0]  reserved;
    logic [31:0] cycle_start;
    logic [31:0] cycle_end;
    logic [31:0] result0;
    logic [31:0] result1;
    logic [31:0] result2;
    logic [31:0] result3;
  } log_entry_t;

  localparam int LOG_ENTRY_BITS  = $bits(log_entry_t);
  localparam int LOG_DEPTH       = 32;  // circular buffer depth

  // ---------------------------------------------------------------
  // DAC types
  // ---------------------------------------------------------------
  typedef enum logic [2:0] {
    DAC_MODE_STATIC      = 3'h0,  // hold programmed code
    DAC_MODE_STAIRCASE   = 3'h1,  // increment code each update tick
    DAC_MODE_RAMP        = 3'h2,  // linear sweep min->max->min
    DAC_MODE_ALTERNATING = 3'h3,  // toggle between two codes
    DAC_MODE_LUT         = 3'h4   // cycle through small LUT
  } dac_mode_t;

  typedef enum logic [1:0] {
    DAC_DEST_INTERNAL    = 2'h0,  // internal monitor node only
    DAC_DEST_ADC         = 2'h1,  // route to ADC input via analog mux
    DAC_DEST_COMP        = 2'h2,  // route to comparator input
    DAC_DEST_EXTERNAL    = 2'h3   // route to external analog pin
  } dac_dest_t;

  localparam int DAC_BITS = 10;
  localparam int DAC_LUT_DEPTH = 16;

  // ---------------------------------------------------------------
  // Analog route matrix types
  // ---------------------------------------------------------------
  typedef enum logic [2:0] {
    ASRC_DISCONNECTED    = 3'h0,
    ASRC_DAC_OUT         = 3'h1,
    ASRC_EXT_ANALOG_IN   = 3'h2,
    ASRC_REF_LADDER      = 3'h3,
    ASRC_RING_OSC_MON    = 3'h4
  } analog_source_t;

  typedef struct packed {
    analog_source_t adc_source;
    analog_source_t comp_pos_source;
    analog_source_t comp_neg_source;
    logic           dac_to_ext_pin;
  } analog_route_cfg_t;

  // ---------------------------------------------------------------
  // Clock mux tree types
  // ---------------------------------------------------------------
  typedef enum logic [2:0] {
    CLKSRC_EXT_REF       = 3'h0,  // external reference clock
    CLKSRC_RING_OSC      = 3'h1,  // ring oscillator bank
    CLKSRC_DIV_SYS       = 3'h2,  // divided system clock
    CLKSRC_PLL_OUT       = 3'h3,  // PLL output
    CLKSRC_TEST_GEN      = 3'h4   // test-generated clock
  } clock_source_t;

  // Per-destination clock select
  typedef struct packed {
    clock_source_t adc_clk_sel;
    clock_source_t dac_clk_sel;
    clock_source_t bist_clk_sel;
    clock_source_t exp_clk_sel;
  } clock_mux_cfg_t;

  // ---------------------------------------------------------------
  // BIST serial-pattern engine types
  // ---------------------------------------------------------------
  typedef enum logic [2:0] {
    BIST_CMD_NOP          = 3'h0,
    BIST_CMD_SHIFT_IN     = 3'h1,
    BIST_CMD_LATCH        = 3'h2,
    BIST_CMD_APPLY        = 3'h3,
    BIST_CMD_CAPTURE      = 3'h4,
    BIST_CMD_SHIFT_OUT    = 3'h5,
    BIST_CMD_CLEAR        = 3'h6
  } bist_cmd_t;

  typedef enum logic [2:0] {
    CHAIN_ANALOG_MUX      = 3'h0,  // analog route mux selects
    CHAIN_CLOCK_MUX       = 3'h1,  // clock source mux selects
    CHAIN_TEST_ENABLE     = 3'h2,  // per-block test mode enables
    CHAIN_ROUTE_CONFIG    = 3'h3,  // combined route configuration
    CHAIN_FAULT_INJECT    = 3'h4   // optional fault injection bits
  } bist_chain_t;

  localparam int BIST_CHAIN_WIDTH = 32;  // bits per chain
  localparam int BIST_NUM_CHAINS  = 5;

  // ---------------------------------------------------------------
  // Experiment profile types
  // ---------------------------------------------------------------
  typedef enum logic [7:0] {
    EXP_NONE                 = 8'h00,
    EXP_DAC_ADC_LOOPBACK     = 8'h01,
    EXP_DAC_COMP_SWEEP       = 8'h02,
    EXP_ADC_EXT_INPUT        = 8'h03,
    EXP_PLL_FREQ_MEASURE     = 8'h04,
    EXP_PLL_ADC_CLK_SWEEP    = 8'h05,
    EXP_DAC_CLK_SWEEP        = 8'h06,
    EXP_RINGOSC_COUNT        = 8'h07,
    EXP_TRNG_HEALTH          = 8'h08,
    EXP_PUF_CAPTURE          = 8'h09,
    EXP_NVM_READONLY         = 8'h0A,
    EXP_NVM_PROGRAM          = 8'h0B,  // dangerous only
    EXP_DAC_RAMP_ADC_CAPTURE = 8'h0C,
    EXP_COMP_THRESHOLD_CAL   = 8'h0D,
    EXP_CLOCK_SOURCE_COMPARE = 8'h0E
  } experiment_id_t;

  // Experiment profile configuration record
  typedef struct packed {
    experiment_id_t   exp_id;
    logic [15:0]      block_enables;     // which blocks to activate
    clock_source_t    adc_clk;
    clock_source_t    dac_clk;
    analog_source_t   adc_source;
    analog_source_t   comp_pos;
    analog_source_t   comp_neg;
    dac_mode_t        dac_mode;
    logic [15:0]      sample_count;      // measurement window
    logic             requires_pll;
    logic             requires_dangerous;
  } experiment_profile_t;

  // ---------------------------------------------------------------
  // PLL types
  // ---------------------------------------------------------------
  typedef struct packed {
    logic        enable;
    logic        bypass;          // 1 = pass reference clock through
    logic [3:0]  mult_factor;    // multiplication factor (2-15)
    logic [3:0]  div_factor;     // division factor (1-15)
  } pll_config_t;

  typedef struct packed {
    logic        locked;
    logic        timeout;
    logic        bypass_active;
    logic [31:0] freq_count;     // measured output frequency count
  } pll_status_t;

  // ---------------------------------------------------------------
  // Dangerous block classification
  // ---------------------------------------------------------------
  function automatic logic is_dangerous_block(block_id_t blk);
    return (blk == BLK_NVM);
  endfunction

  // ---------------------------------------------------------------
  // Default timeout (in clock cycles)
  // ---------------------------------------------------------------
  localparam logic [31:0] DEFAULT_TIMEOUT     = 32'd1_000_000;
  localparam logic [31:0] PLL_LOCK_TIMEOUT    = 32'd500_000;
  localparam logic [31:0] DAC_SETTLE_CYCLES   = 32'd100;

endpackage
