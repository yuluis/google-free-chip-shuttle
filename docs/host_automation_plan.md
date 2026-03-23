# ULC Host Automation Plan

## Architecture

```
host/
├── run_chip_validation.py    # Entry point — CLI, orchestration, reporting
├── ulc_driver.py             # UART transport: connect, read_reg, write_reg
├── ulc_registers.py          # Register addresses, bit-field constants, block IDs
├── ulc_tests/                # Per-block test logic (optional deep analysis)
│   ├── __init__.py
│   ├── test_sram.py
│   ├── test_adc.py
│   └── ...
└── output/                   # Generated reports (JSON, CSV)
```

### Module Responsibilities

| Module                  | Responsibility                                                  |
|-------------------------|-----------------------------------------------------------------|
| `run_chip_validation.py`| Parse CLI args, select mode/blocks, call driver, aggregate results, emit reports |
| `ulc_driver.py`         | Serial port open/close, UART frame encode/decode, `read_reg(addr)` / `write_reg(addr, val)`, timeout/retry, polling helpers |
| `ulc_registers.py`      | Named constants for all register addresses, bit masks, block IDs, command opcodes, error codes. Single source of truth for host-side register definitions. |
| `ulc_tests/`            | Optional per-block analysis that goes beyond the on-chip self-test (e.g., statistical tests on TRNG data, INL/DNL plotting for ADC). Called by `run_chip_validation.py` when `--deep-analysis` is set. |

## ulc_driver.py — Transport Abstraction

```python
class ULCDriver:
    """Low-level register access over UART or simulation backdoor."""

    def __init__(self, port: str, baud: int = 115200, timeout: float = 2.0):
        """Open serial connection. port can be:
        - /dev/ttyUSBx      (silicon / FPGA)
        - /dev/pts/x         (RTL sim with UART model)
        - sim://localhost:9000  (cocotb TCP backdoor)
        """

    def read_reg(self, addr: int) -> int: ...
    def write_reg(self, addr: int, value: int) -> None: ...
    def poll_status(self, mask: int, value: int, timeout_s: float = 5.0) -> int: ...
    def wait_idle(self, timeout_s: float = 5.0) -> None: ...
    def wait_done(self, timeout_s: float = 10.0) -> int: ...
    def reset(self) -> None: ...
    def close(self) -> None: ...
```

The `sim://` transport enables the same Python test suite to run against a cocotb testbench via TCP, against an FPGA via real UART, or against packaged silicon — no code changes needed.

## ulc_registers.py — Register Definitions

```python
# Addresses
CHIP_ID         = 0x00
CHIP_REV        = 0x04
GLOBAL_CONTROL  = 0x08
GLOBAL_STATUS   = 0x0C
BLOCK_SELECT    = 0x10
COMMAND         = 0x14
TIMEOUT_CYCLES  = 0x18
RESULT0         = 0x1C
RESULT1         = 0x20
RESULT2         = 0x24
RESULT3         = 0x28
ERROR_CODE      = 0x2C
PASS_COUNT      = 0x30
FAIL_COUNT      = 0x34
LAST_BLOCK      = 0x38
LAST_STATE      = 0x3C
LOG_PTR         = 0x40
LOG_COUNT       = 0x44

# Block IDs
BLOCK_REGBANK     = 0x00
BLOCK_SRAM        = 0x01
BLOCK_UART        = 0x02
BLOCK_SPI         = 0x03
BLOCK_I2C         = 0x04
BLOCK_GPIO        = 0x05
BLOCK_RING_OSC    = 0x06
BLOCK_CLK_DIV     = 0x07
BLOCK_TRNG        = 0x08
BLOCK_PUF         = 0x09
BLOCK_COMPARATOR  = 0x0A
BLOCK_ADC         = 0x0B
BLOCK_NVM         = 0x0C

# Command opcodes
CMD_NOP           = 0x00
CMD_RUN_SELF_TEST = 0x01
CMD_READ_RESULT   = 0x02
CMD_READ_LOG      = 0x03
CMD_WRITE_BLOCK   = 0x04
CMD_READ_BLOCK    = 0x05
CMD_PROGRAM_OTP   = 0x10
CMD_VERIFY_OTP    = 0x11
CMD_FULL_SWEEP    = 0xFF

# GLOBAL_CONTROL bits
GC_SOFT_RESET    = 1 << 0
GC_RUN_ALL       = 1 << 1
GC_STOP          = 1 << 2
GC_LOG_CLEAR     = 1 << 3
GC_ARM_DANGEROUS = 1 << 6
GC_LED_OVERRIDE  = 1 << 7

# GLOBAL_STATUS bits
GS_IDLE          = 1 << 0
GS_BUSY          = 1 << 1
GS_DONE          = 1 << 2
GS_PASS          = 1 << 3
GS_FAIL          = 1 << 4
GS_TIMEOUT       = 1 << 5
GS_ERROR         = 1 << 6
GS_ARMED         = 1 << 7
GS_LOG_OVERFLOW  = 1 << 8
GS_RUN_ALL_ACTIVE= 1 << 9

# Error codes
ERR_NONE           = 0x00
ERR_TIMEOUT        = 0x01
ERR_COMPARE        = 0x02
ERR_RANGE          = 0x03
ERR_NO_RESPONSE    = 0x04
ERR_OVERFLOW       = 0x05
ERR_UNSAFE_DENIED  = 0x06
ERR_UNSUPPORTED    = 0x07
```

## Command-Line Interface

```
usage: run_chip_validation.py [-h] -p PORT [-b BAUD] [-m {safe,extended,dangerous}]
                               [--blocks BLOCK [BLOCK ...]] [--all]
                               [--deep-analysis] [--arm-dangerous]
                               [--timeout SECONDS] [--output-json FILE]
                               [--output-csv FILE] [-v]

ULC Chip Validation

required:
  -p PORT               Serial port (e.g., /dev/ttyUSB0, sim://localhost:9000)

optional:
  -b BAUD               Baud rate (default: 115200)
  -m MODE               Test mode: safe (default), extended, dangerous
  --blocks BLOCK ...    Run only specified blocks (e.g., SRAM ADC TRNG)
  --all                 Run all blocks in selected mode (default if no --blocks)
  --deep-analysis       Enable host-side statistical analysis (TRNG, ADC, PUF)
  --arm-dangerous       Required flag to confirm dangerous mode intent
  --timeout SECONDS     Per-block timeout in seconds (default: 10)
  --output-json FILE    Write results to JSON file
  --output-csv FILE     Write results to CSV file
  -v, --verbose         Verbose console output
```

Dangerous mode requires both `-m dangerous` and `--arm-dangerous` to prevent accidental use.

## Test Execution Flow

```
1. CONNECT        Open serial port, verify UART link
2. IDENTIFY       Read CHIP_ID, CHIP_REV — abort if unexpected
3. RESET          Write GLOBAL_CONTROL.SOFT_RESET, wait for IDLE
4. CONFIGURE      Set TEST_MODE, TIMEOUT_CYCLES
5. SAFE SUITE     For each block in safe list:
                    a. Write BLOCK_SELECT
                    b. Write COMMAND = RUN_SELF_TEST
                    c. Poll GLOBAL_STATUS for DONE
                    d. Read RESULT0-3, ERROR_CODE
                    e. Record pass/fail
6. EXTENDED       (if mode=extended or dangerous)
                    Same loop with extended timeout
7. DANGEROUS      (if mode=dangerous and --arm-dangerous)
                    For each dangerous block:
                    a. Arm (write ARM_DANGEROUS, verify ARMED)
                    b. Execute command
                    c. Verify ARM auto-cleared
8. DRAIN LOG      Read all log entries via CMD_READ_LOG
9. REPORT         Aggregate results, emit JSON/CSV/console
10. DISCONNECT    Close serial port
```

## Output Formats

### Console (default)

```
ULC Validation Report
Chip: ULC  Rev: 1.0.0  Port: /dev/ttyUSB0  Mode: safe
─────────────────────────────────────────────────────
 Block        Result   Error   R0         R1         R2         R3
 REGBANK      PASS     0x00    0x00000000 0x00000000 0x00000000 0x00000000
 SRAM         PASS     0x00    0x00001000 0x00001000 0x00000000 0x00000000
 UART         PASS     0x00    0x00000040 0x00000000 0x00000000 0x00000000
 ...
 ADC          FAIL     0x03    0x000007F2 0x00000800 0x0000000A 0x00000003
─────────────────────────────────────────────────────
 PASS: 12  FAIL: 1  Total: 13
```

### JSON (--output-json)

```json
{
  "chip_id": "ULC",
  "chip_rev": "1.0.0",
  "port": "/dev/ttyUSB0",
  "mode": "safe",
  "timestamp": "2026-03-22T14:30:00Z",
  "summary": {"pass": 12, "fail": 1, "total": 13},
  "blocks": [
    {
      "name": "REGBANK",
      "block_id": "0x00",
      "result": "PASS",
      "error_code": 0,
      "results": ["0x00000000", "0x00000000", "0x00000000", "0x00000000"],
      "duration_ms": 12
    }
  ],
  "log_entries": [...]
}
```

### CSV (--output-csv)

```
block_name,block_id,result,error_code,result0,result1,result2,result3,duration_ms
REGBANK,0x00,PASS,0x00,0x00000000,0x00000000,0x00000000,0x00000000,12
SRAM,0x01,PASS,0x00,0x00001000,0x00001000,0x00000000,0x00000000,45
```

## Reuse Across Environments

| Environment     | Transport             | Port Argument            | Notes                          |
|-----------------|-----------------------|--------------------------|--------------------------------|
| RTL Simulation  | Cocotb TCP backdoor   | `sim://localhost:9000`   | Cocotb drives UART model or provides register backdoor |
| FPGA Emulation  | Real UART via USB     | `/dev/ttyUSB0`           | Full speed, real clock         |
| Silicon          | Real UART via USB     | `/dev/ttyUSB0`           | Same as FPGA; includes dangerous mode |
| RTL (UART model)| PTY from sim          | `/dev/pts/N`             | Sim exposes UART as pseudo-terminal |

The same `run_chip_validation.py` invocation works unchanged across all four environments. Only the `-p` argument changes.
