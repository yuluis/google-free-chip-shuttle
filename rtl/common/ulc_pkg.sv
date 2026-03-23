// Universal Learning Chip — shared types, constants, and register map
package ulc_pkg;

  // ---------------------------------------------------------------
  // Chip identity
  // ---------------------------------------------------------------
  localparam logic [31:0] CHIP_ID_VALUE  = 32'hULC1_0001;
  localparam logic [31:0] CHIP_REV_VALUE = 32'h0000_0001;

  // ---------------------------------------------------------------
  // Block IDs (used in TEST_BLOCK_SELECT and log entries)
  // ---------------------------------------------------------------
  typedef enum logic [7:0] {
    BLK_REGBANK     = 8'h00,
    BLK_SRAM        = 8'h01,
    BLK_UART        = 8'h02,
    BLK_SPI         = 8'h03,
    BLK_I2C         = 8'h04,
    BLK_GPIO        = 8'h05,
    BLK_RING_OSC    = 8'h06,
    BLK_CLK_DIV     = 8'h07,
    BLK_TRNG        = 8'h08,
    BLK_PUF         = 8'h09,
    BLK_COMPARATOR  = 8'h0A,
    BLK_ADC         = 8'h0B,
    BLK_NVM         = 8'h0C
  } block_id_t;

  localparam int NUM_BLOCKS = 13;

  // ---------------------------------------------------------------
  // Test commands
  // ---------------------------------------------------------------
  typedef enum logic [7:0] {
    CMD_NOP              = 8'h00,
    CMD_START_SELECTED   = 8'h01,
    CMD_ABORT            = 8'h02,
    CMD_STEP             = 8'h03,
    CMD_RERUN_LAST       = 8'h04,
    CMD_DUMP_LOG         = 8'h05
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
    ERR_UNSUPPORTED_MODE = 8'h07
  } error_code_t;

  // ---------------------------------------------------------------
  // Sequencer states
  // ---------------------------------------------------------------
  typedef enum logic [3:0] {
    SEQ_IDLE             = 4'h0,
    SEQ_ARM_CHECK        = 4'h1,
    SEQ_PREPARE_BLOCK    = 4'h2,
    SEQ_START_BLOCK      = 4'h3,
    SEQ_WAIT_FOR_DONE    = 4'h4,
    SEQ_COLLECT_RESULTS  = 4'h5,
    SEQ_WRITE_STATUS     = 4'h6,
    SEQ_APPEND_LOG       = 4'h7,
    SEQ_COMPLETE         = 4'h8,
    SEQ_ERROR            = 4'h9,
    SEQ_ABORT            = 4'hA
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

  // ---------------------------------------------------------------
  // Register addresses (byte-addressed, 32-bit registers)
  // ---------------------------------------------------------------
  localparam logic [7:0] REG_CHIP_ID           = 8'h00;
  localparam logic [7:0] REG_CHIP_REV          = 8'h04;
  localparam logic [7:0] REG_GLOBAL_CONTROL    = 8'h08;
  localparam logic [7:0] REG_GLOBAL_STATUS     = 8'h0C;
  localparam logic [7:0] REG_BLOCK_SELECT      = 8'h10;
  localparam logic [7:0] REG_COMMAND            = 8'h14;
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

  // ---------------------------------------------------------------
  // Per-block test wrapper interface (as a struct)
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
  // Dangerous block classification
  // ---------------------------------------------------------------
  function automatic logic is_dangerous_block(block_id_t blk);
    return (blk == BLK_NVM);
  endfunction

  // ---------------------------------------------------------------
  // Default timeout (in clock cycles)
  // ---------------------------------------------------------------
  localparam logic [31:0] DEFAULT_TIMEOUT = 32'd1_000_000;

endpackage
