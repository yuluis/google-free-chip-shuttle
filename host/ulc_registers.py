"""ULC register map and constants — mirrors ulc_pkg.sv."""

# Chip identity — matches ulc_pkg.sv CHIP_ID_VALUE
CHIP_ID_VALUE = 0x554C4331  # 'ULC1' in ASCII hex
CHIP_REV_VALUE = 0x00000001

# Register addresses (byte-addressed)
REG_CHIP_ID        = 0x00
REG_CHIP_REV       = 0x04
REG_GLOBAL_CONTROL = 0x08
REG_GLOBAL_STATUS  = 0x0C
REG_BLOCK_SELECT   = 0x10
REG_COMMAND        = 0x14
REG_TIMEOUT_CYCLES = 0x18
REG_RESULT0        = 0x1C
REG_RESULT1        = 0x20
REG_RESULT2        = 0x24
REG_RESULT3        = 0x28
REG_ERROR_CODE     = 0x2C
REG_PASS_COUNT     = 0x30
REG_FAIL_COUNT     = 0x34
REG_LAST_BLOCK     = 0x38
REG_LAST_STATE     = 0x3C
REG_LOG_PTR        = 0x40
REG_LOG_COUNT      = 0x44

# Block IDs
BLK_REGBANK    = 0x00
BLK_SRAM       = 0x01
BLK_UART       = 0x02
BLK_SPI        = 0x03
BLK_I2C        = 0x04
BLK_GPIO       = 0x05
BLK_RING_OSC   = 0x06
BLK_CLK_DIV    = 0x07
BLK_TRNG       = 0x08
BLK_PUF        = 0x09
BLK_COMPARATOR = 0x0A
BLK_ADC        = 0x0B
BLK_NVM        = 0x0C

BLOCK_NAMES = {
    BLK_REGBANK:    "Register Bank",
    BLK_SRAM:       "SRAM",
    BLK_UART:       "UART",
    BLK_SPI:        "SPI",
    BLK_I2C:        "I2C",
    BLK_GPIO:       "GPIO",
    BLK_RING_OSC:   "Ring Oscillator",
    BLK_CLK_DIV:    "Clock Divider",
    BLK_TRNG:       "TRNG",
    BLK_PUF:        "PUF",
    BLK_COMPARATOR: "Comparator",
    BLK_ADC:        "ADC",
    BLK_NVM:        "NVM/OTP",
}

# Safe blocks (run in SAFE_AUTO mode)
SAFE_BLOCKS = [
    BLK_REGBANK, BLK_SRAM, BLK_UART, BLK_SPI, BLK_I2C,
    BLK_GPIO, BLK_RING_OSC, BLK_CLK_DIV, BLK_TRNG, BLK_PUF,
    BLK_COMPARATOR, BLK_ADC,
]

# Dangerous blocks (require arming)
DANGEROUS_BLOCKS = [BLK_NVM]

# Commands
CMD_NOP            = 0x00
CMD_START_SELECTED = 0x01
CMD_ABORT          = 0x02
CMD_STEP           = 0x03
CMD_RERUN_LAST     = 0x04
CMD_DUMP_LOG       = 0x05

# Global control bits
CTRL_GLOBAL_ENABLE = 0
CTRL_RESET_FABRIC  = 1
CTRL_ARM_DANGEROUS = 2
CTRL_CLEAR_RESULTS = 3
CTRL_LOOP_MODE     = 4

# Global status bits
STAT_BUSY            = 0
STAT_DONE            = 1
STAT_PASS            = 2
STAT_FAIL            = 3
STAT_TIMEOUT         = 4
STAT_DANGEROUS_ARMED = 5
STAT_OVERFLOW        = 6
STAT_WARNING         = 7

# Error codes
ERR_NONE             = 0x00
ERR_TIMEOUT          = 0x01
ERR_COMPARE_MISMATCH = 0x02
ERR_RANGE_VIOLATION  = 0x03
ERR_MISSING_RESPONSE = 0x04
ERR_OVERFLOW         = 0x05
ERR_UNSAFE_DENIED    = 0x06
ERR_UNSUPPORTED_MODE = 0x07

ERROR_NAMES = {
    ERR_NONE:             "None",
    ERR_TIMEOUT:          "Timeout",
    ERR_COMPARE_MISMATCH: "Compare Mismatch",
    ERR_RANGE_VIOLATION:  "Range Violation",
    ERR_MISSING_RESPONSE: "Missing Response",
    ERR_OVERFLOW:         "Overflow",
    ERR_UNSAFE_DENIED:    "Unsafe Operation Denied",
    ERR_UNSUPPORTED_MODE: "Unsupported Mode",
}
