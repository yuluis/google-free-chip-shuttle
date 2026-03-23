// Universal Learning Chip — shared types, constants, and register map
// v2.4 — Final v1-targeting refinement:
//         - Spare pads renamed: SPARE_IO0 + SPARE_IO1 (both digital)
//         - Standard digital Caravel wrapper confirmed (not analog variant)
//         - State snapshot registers now latched-on-demand (SNAP_CAPTURE bit)
//         - BOOT_STATUS register captures reset cause and initial state
//         - All other v2.3 decisions retained unchanged
package ulc_pkg;

  // ---------------------------------------------------------------
  // Chip identity
  // ---------------------------------------------------------------
  localparam logic [31:0] CHIP_ID_VALUE  = 32'h554C_4332;  // 'ULC2' ASCII
  localparam logic [31:0] CHIP_REV_VALUE = 32'h0000_0005;   // rev 5 (v2.4)

  // ---------------------------------------------------------------
  // Block IDs — Zone A: Digital Backbone / Safe Core
  // ---------------------------------------------------------------
  typedef enum logic [7:0] {
    // Zone A: Digital Backbone / Safe Core
    BLK_REGBANK     = 8'h00,
    BLK_SRAM        = 8'h01,
    BLK_UART        = 8'h02,
    BLK_SPI         = 8'h03,
    // 0x04 reserved (was I2C, removed in v2.3)
    BLK_GPIO        = 8'h05,
    BLK_CLK_DIV     = 8'h07,
    // Zone B: Measurable Mixed-Signal
    BLK_RING_OSC    = 8'h06,
    BLK_TRNG        = 8'h08,
    BLK_PUF         = 8'h09,
    BLK_COMPARATOR  = 8'h0A,
    BLK_ADC         = 8'h0B,
    BLK_DAC         = 8'h0D,
    BLK_ANA_ROUTE   = 8'h0E,   // analog route matrix (status only)
    // Zone C: Experimental Clock (optional — chip works without)
    BLK_PLL         = 8'h10,   // optional PLL/DPLL experiment
    BLK_CLK_MUX     = 8'h11,   // clock mux tree (status only)
    // Zone D: Experimental / Dangerous (optional — chip works without)
    BLK_NVM         = 8'h0C,
    // Infrastructure (not independently selectable)
    BLK_BIST_ENGINE = 8'h20
  } block_id_t;

  localparam int NUM_BLOCKS = 15;  // testable blocks (was 16, I2C removed)

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
  localparam int CTRL_SOFTWARE_RESET  = 9;  // v2.2: software reset (self-clearing)
  // v2.3 local reset bits
  localparam int CTRL_RESET_SEQUENCER = 10; // reset sequencer only
  localparam int CTRL_RESET_ANALOG    = 11; // reset DAC/ADC/comp state
  localparam int CTRL_RESET_DANGEROUS = 12; // reset + disarm dangerous zone
  localparam int CTRL_DEBUG_MODE      = 13; // switch DBG/GP pads to debug output
  localparam int CTRL_SNAP_CAPTURE    = 14; // v2.4: write 1 to latch snapshots (self-clearing)

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
  // Register addressing: BANK_SELECT + 8-bit offset
  //
  // v2.2 strategy: keep UART at 8-bit addresses. Host writes
  // BANK_SELECT (offset 0x04) to choose which register page is
  // active, then uses 8-bit offsets within that bank. Bank 0 is
  // the default and contains identity/control/status. All existing
  // 8-bit offsets from v1 remain valid in Bank 0.
  //
  // 16-bit flat addressing deferred to future UART bridge revision.
  // ---------------------------------------------------------------

  // Bank IDs
  typedef enum logic [3:0] {
    BANK_GLOBAL     = 4'h0,  // identity, control, status, sequencer, experiment
    BANK_CLOCK      = 4'h1,  // clock mux, PLL, freq counters
    BANK_ANALOG     = 4'h2,  // analog route, DAC, ADC, comparator
    BANK_BIST       = 4'h3,  // BIST engine chains
    BANK_SECURITY   = 4'h4,  // TRNG, PUF
    BANK_LOG        = 4'h5,  // log buffer, SRAM BIST
    BANK_DANGEROUS  = 4'hA   // NVM/OTP (arm required)
  } bank_id_t;

  localparam int NUM_BANKS = 7;

  // ---------------------------------------------------------------
  // Bank 0: Global — identity, control, sequencer, experiment
  // Default bank on reset. All v1 offsets preserved.
  // ---------------------------------------------------------------
  localparam logic [7:0] REG_CHIP_ID           = 8'h00;
  localparam logic [7:0] REG_BANK_SELECT       = 8'h04;  // v2.2: bank select
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
  localparam logic [7:0] REG_CHIP_REV          = 8'h48;  // moved to avoid collision
  localparam logic [7:0] REG_EXPERIMENT_ID     = 8'h50;
  localparam logic [7:0] REG_EXPERIMENT_STATUS = 8'h54;
  localparam logic [7:0] REG_EXPERIMENT_CONFIG = 8'h58;
  localparam logic [7:0] REG_SOFTWARE_RESET    = 8'h5C;  // v2.2: write 0xDEAD
  // v2.4: State snapshot registers (latched-on-demand via CTRL_SNAP_CAPTURE)
  // Write CTRL_SNAP_CAPTURE=1 to freeze; reads return coherent frozen image.
  localparam logic [7:0] REG_SNAP_BANK_CLK    = 8'h60;  // [3:0] bank_sel, [14:12] adc_clk, [17:15] dac_clk
  localparam logic [7:0] REG_SNAP_ROUTE_EXP   = 8'h64;  // [2:0] adc_src, [5:3] comp+, [8:6] comp-, [23:16] exp_id
  localparam logic [7:0] REG_SNAP_SEQ_ERR     = 8'h68;  // [4:0] seq_state, [12:8] last_error, [20:16] last_block
  localparam logic [7:0] REG_SNAP_FLAGS       = 8'h6C;  // [0] pll_locked, [1] dac_active, [2] bist_applied,
                                                          //  [3] route_active, [4] dangerous_armed, [5] debug_mode
  // v2.3: Debug and spare pad control
  localparam logic [7:0] REG_DEBUG_CONTROL    = 8'h70;  // [0] debug_mode, [3:1] dbg_clk_select, [4] dbg_clk_enable
  localparam logic [7:0] REG_SPARE_PAD_CTRL   = 8'h74;  // [3:0] spare_io0 source, [7:4] spare_io1 source,
                                                          //  [8] spare_io0_oe, [9] spare_io1_oe
  // v2.4: Boot / reset status register (read-only, captured at reset release)
  localparam logic [7:0] REG_BOOT_STATUS      = 8'h78;  // [1:0] reset_cause (0=POR, 1=RST_N, 2=SW_reset, 3=watchdog)
                                                          //  [2] debug_mode_at_boot, [3] dangerous_armed_at_boot (always 0)
                                                          //  [6:4] clk_source_at_boot (always ext_ref=0)
                                                          //  [7] strap_reserved (for future board strap pin)

  // ---------------------------------------------------------------
  // Bank 1: Clock — mux tree, PLL, freq counters
  // ---------------------------------------------------------------
  localparam logic [7:0] REG_CLK_MUX_CONTROL   = 8'h00;  // bank-relative
  localparam logic [7:0] REG_CLK_MUX_STATUS    = 8'h04;
  localparam logic [7:0] REG_CLK_FREQ_COUNT    = 8'h08;
  localparam logic [7:0] REG_CLK_FREQ_SELECT   = 8'h0C;
  localparam logic [7:0] REG_CLK_FREQ_WINDOW   = 8'h10;
  localparam logic [7:0] REG_CLK_DIV_CONTROL   = 8'h14;
  localparam logic [7:0] REG_PLL_CONTROL       = 8'h20;
  localparam logic [7:0] REG_PLL_STATUS        = 8'h24;
  localparam logic [7:0] REG_PLL_FREQ_COUNT    = 8'h28;
  localparam logic [7:0] REG_PLL_LOCK_TIMEOUT  = 8'h2C;
  // v2.3: ROSC and debug clock
  localparam logic [7:0] REG_ROSC_CONTROL     = 8'h30;  // [0] mode (0=auto, 1=override), [3:1] osc_select
  localparam logic [7:0] REG_DBG_CLK_SELECT   = 8'h34;  // [2:0] source (ext/div/rosc/pll/test), [3] enable output

  // ---------------------------------------------------------------
  // Bank 2: Analog — route matrix, DAC, ADC, comparator
  // ---------------------------------------------------------------
  localparam logic [7:0] REG_AROUTE_CONTROL    = 8'h00;
  localparam logic [7:0] REG_AROUTE_STATUS     = 8'h04;
  localparam logic [7:0] REG_AROUTE_ADC_SRC    = 8'h08;
  localparam logic [7:0] REG_AROUTE_COMP_SRC   = 8'h0C;
  localparam logic [7:0] REG_DAC_CONTROL       = 8'h20;
  localparam logic [7:0] REG_DAC_CODE          = 8'h24;
  localparam logic [7:0] REG_DAC_STATUS        = 8'h28;
  localparam logic [7:0] REG_DAC_UPDATE_COUNT  = 8'h2C;
  localparam logic [7:0] REG_DAC_ALT_CODE      = 8'h30;
  localparam logic [7:0] REG_DAC_CLK_DIV       = 8'h34;
  localparam logic [7:0] REG_ADC_CONTROL       = 8'h40;
  localparam logic [7:0] REG_ADC_RESULT        = 8'h44;
  localparam logic [7:0] REG_ADC_MIN_MAX       = 8'h48;
  localparam logic [7:0] REG_ADC_SAMPLE_COUNT  = 8'h4C;
  localparam logic [7:0] REG_COMP_CONTROL      = 8'h60;
  localparam logic [7:0] REG_COMP_STATUS       = 8'h64;
  localparam logic [7:0] REG_COMP_SWEEP_CFG    = 8'h68;
  localparam logic [7:0] REG_COMP_TRIP_RESULT  = 8'h6C;

  // ---------------------------------------------------------------
  // Bank 3: BIST — pattern engine chains
  // ---------------------------------------------------------------
  localparam logic [7:0] REG_BIST_CONTROL      = 8'h00;
  localparam logic [7:0] REG_BIST_CHAIN_SEL    = 8'h04;
  localparam logic [7:0] REG_BIST_SHIFT_DATA   = 8'h08;
  localparam logic [7:0] REG_BIST_LATCH_STATUS = 8'h0C;
  localparam logic [7:0] REG_BIST_READBACK     = 8'h10;
  localparam logic [7:0] REG_BIST_APPLY_STATUS = 8'h14;

  // ---------------------------------------------------------------
  // Bank 4: Security — TRNG, PUF
  // ---------------------------------------------------------------
  // (offsets within bank 4)
  localparam logic [7:0] REG_TRNG_CONTROL      = 8'h00;
  localparam logic [7:0] REG_TRNG_STATUS       = 8'h04;
  localparam logic [7:0] REG_TRNG_BIT_COUNT    = 8'h08;
  localparam logic [7:0] REG_TRNG_ONES_COUNT   = 8'h0C;
  localparam logic [7:0] REG_TRNG_REP_MAX      = 8'h10;
  localparam logic [7:0] REG_PUF_CONTROL       = 8'h20;
  localparam logic [7:0] REG_PUF_STATUS        = 8'h24;
  localparam logic [7:0] REG_PUF_RESP_0        = 8'h28;
  localparam logic [7:0] REG_PUF_RESP_1        = 8'h2C;
  localparam logic [7:0] REG_PUF_RESP_2        = 8'h30;
  localparam logic [7:0] REG_PUF_RESP_3        = 8'h34;
  localparam logic [7:0] REG_PUF_MISMATCH      = 8'h38;

  // ---------------------------------------------------------------
  // Bank 5: Log — log buffer, SRAM BIST
  // ---------------------------------------------------------------
  localparam logic [7:0] REG_LOG_READ_INDEX    = 8'h00;
  localparam logic [7:0] REG_LOG_ENTRY_BLOCK   = 8'h04;
  localparam logic [7:0] REG_LOG_ENTRY_T_START = 8'h08;
  localparam logic [7:0] REG_LOG_ENTRY_T_END   = 8'h0C;
  localparam logic [7:0] REG_LOG_ENTRY_R0      = 8'h10;
  localparam logic [7:0] REG_LOG_ENTRY_R1      = 8'h14;
  localparam logic [7:0] REG_SRAM_BIST_STATUS  = 8'h40;

  // ---------------------------------------------------------------
  // Bank 0xA: Dangerous — NVM/OTP (arm required)
  // ---------------------------------------------------------------
  localparam logic [7:0] REG_DANGEROUS_ARM     = 8'h00;  // write 0x41524D21
  localparam logic [7:0] REG_NVM_ADDRESS       = 8'h04;
  localparam logic [7:0] REG_NVM_WRITE_DATA    = 8'h08;
  localparam logic [7:0] REG_NVM_READ_DATA     = 8'h0C;
  localparam logic [7:0] REG_NVM_COMMAND       = 8'h10;
  localparam logic [7:0] REG_NVM_STATUS        = 8'h14;

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
  // v2.3: Debug clock output mux sources
  // Shared via DBG/GP0 (debug mode) or SPARE_DBG pad
  // ---------------------------------------------------------------
  typedef enum logic [2:0] {
    DBGCLK_DISABLED   = 3'h0,
    DBGCLK_EXT_REF    = 3'h1,
    DBGCLK_DIV_SYS    = 3'h2,
    DBGCLK_RING_OSC   = 3'h3,
    DBGCLK_PLL_OUT    = 3'h4,
    DBGCLK_TEST_GEN   = 3'h5
  } debug_clk_source_t;

  // ---------------------------------------------------------------
  // v2.4: Spare pad routing sources (both pads are digital-only)
  // Standard digital Caravel — no analog pass-through on spare pads.
  // ---------------------------------------------------------------
  typedef enum logic [3:0] {
    SPARE_SRC_HIZ        = 4'h0,  // high-impedance (safe default)
    SPARE_SRC_DBG_CLK    = 4'h1,  // debug clock mux output
    SPARE_SRC_SEQ_STATE  = 4'h2,  // sequencer state bits
    SPARE_SRC_GPIO_EXT   = 4'h3,  // extension GPIO
    SPARE_SRC_BIST_OUT   = 4'h4,  // BIST capture readback
    SPARE_SRC_ROSC_PROBE = 4'h5,  // ring oscillator probe
    SPARE_SRC_ERR_FLAG   = 4'h6   // error/status flag output
  } spare_pad_source_t;

  // ---------------------------------------------------------------
  // v2.4: Reset cause encoding for BOOT_STATUS register
  // ---------------------------------------------------------------
  typedef enum logic [1:0] {
    RST_CAUSE_POR        = 2'h0,  // power-on reset
    RST_CAUSE_PIN        = 2'h1,  // RST_N pin asserted
    RST_CAUSE_SOFTWARE   = 2'h2,  // software reset (0xDEAD)
    RST_CAUSE_WATCHDOG   = 2'h3   // reserved for future watchdog
  } reset_cause_t;

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
