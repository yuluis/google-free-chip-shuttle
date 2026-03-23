# ULC Test Register Map

All registers are 32-bit, byte-addressed, accessible via UART. Reset values apply after power-on or a global reset (GLOBAL_CONTROL[0]).

## Register Summary

| Addr   | Name            | R/W | Reset      | Description                          |
|--------|-----------------|-----|------------|--------------------------------------|
| `0x00` | CHIP_ID         | R   | 0x554C4300 | ASCII "ULC\0" — chip identifier      |
| `0x04` | CHIP_REV        | R   | 0x00000100 | [31:16] major, [15:8] minor, [7:0] patch |
| `0x08` | GLOBAL_CONTROL  | R/W | 0x00000000 | Global control bits                  |
| `0x0C` | GLOBAL_STATUS   | R   | 0x00000001 | Global status flags                  |
| `0x10` | BLOCK_SELECT    | R/W | 0x00000000 | Block ID for next command            |
| `0x14` | COMMAND         | R/W | 0x00000000 | Command to execute (write triggers)  |
| `0x18` | TIMEOUT_CYCLES  | R/W | 0x0000FFFF | Max cycles before timeout abort      |
| `0x1C` | RESULT0         | R   | 0x00000000 | Block result word 0                  |
| `0x20` | RESULT1         | R   | 0x00000000 | Block result word 1                  |
| `0x24` | RESULT2         | R   | 0x00000000 | Block result word 2                  |
| `0x28` | RESULT3         | R   | 0x00000000 | Block result word 3                  |
| `0x2C` | ERROR_CODE      | R   | 0x00000000 | Error code from last test            |
| `0x30` | PASS_COUNT      | R   | 0x00000000 | Cumulative pass counter              |
| `0x34` | FAIL_COUNT      | R   | 0x00000000 | Cumulative fail counter              |
| `0x38` | LAST_BLOCK      | R   | 0x000000FF | Block ID of last completed test      |
| `0x3C` | LAST_STATE      | R   | 0x00000000 | FSM state at last completion         |
| `0x40` | LOG_PTR         | R   | 0x00000000 | Current log write pointer            |
| `0x44` | LOG_COUNT       | R   | 0x00000000 | Number of unread log entries          |

## Bit-Field Details

### GLOBAL_CONTROL (0x08)

| Bit(s) | Name           | R/W | Reset | Description                                      |
|--------|----------------|-----|-------|--------------------------------------------------|
| 0      | SOFT_RESET     | W1  | 0     | Write 1: synchronous reset of all blocks, sequencer, results, log. Self-clears. |
| 1      | RUN_ALL        | R/W | 0     | Write 1: sequencer auto-runs all blocks in current mode sequentially. |
| 2      | STOP           | W1  | 0     | Write 1: abort current test, return to IDLE. Self-clears. |
| 3      | LOG_CLEAR      | W1  | 0     | Write 1: reset LOG_PTR and LOG_COUNT. Self-clears. |
| [5:4]  | TEST_MODE      | R/W | 00    | 00=SAFE_AUTO, 01=LAB_EXTENDED, 10=DANGEROUS_ARMED, 11=reserved |
| 6      | ARM_DANGEROUS  | R/W | 0     | Must be set to 1 before DANGEROUS_ARMED commands execute. Auto-clears after one command dispatch. |
| 7      | LED_OVERRIDE   | R/W | 0     | 1=host controls LEDs via bits [10:8], 0=automatic |
| [10:8] | LED_MANUAL     | R/W | 000   | Manual LED state when LED_OVERRIDE=1. [8]=green, [9]=yellow, [10]=red |
| [31:11]| reserved       | R   | 0     | Reserved, reads as 0                             |

### GLOBAL_STATUS (0x0C)

| Bit(s) | Name           | R/W | Reset | Description                                      |
|--------|----------------|-----|-------|--------------------------------------------------|
| 0      | IDLE           | R   | 1     | 1=sequencer is idle, ready for command           |
| 1      | BUSY           | R   | 0     | 1=test in progress                               |
| 2      | DONE           | R   | 0     | 1=last command completed (cleared on next command write) |
| 3      | PASS           | R   | 0     | 1=last test passed                               |
| 4      | FAIL           | R   | 0     | 1=last test failed                               |
| 5      | TIMEOUT        | R   | 0     | 1=last test aborted due to timeout               |
| 6      | ERROR          | R   | 0     | 1=error code is nonzero                          |
| 7      | ARMED          | R   | 0     | 1=dangerous mode is armed and ready              |
| 8      | LOG_OVERFLOW   | R   | 0     | 1=log FIFO overflowed, entries lost              |
| 9      | RUN_ALL_ACTIVE | R   | 0     | 1=RUN_ALL sequence is in progress                |
| [31:10]| reserved       | R   | 0     | Reserved                                         |

### BLOCK_SELECT (0x10)

| Bit(s) | Name     | R/W | Description                          |
|--------|----------|-----|--------------------------------------|
| [7:0]  | BLOCK_ID | R/W | Block ID (see Block IDs table below) |
| [31:8] | reserved | R   | Reserved                             |

### COMMAND (0x14)

Writing to this register triggers the sequencer. The sequencer latches BLOCK_SELECT and TEST_MODE at the time of the COMMAND write.

| Bit(s) | Name    | R/W | Description                                       |
|--------|---------|-----|---------------------------------------------------|
| [7:0]  | CMD     | R/W | Command opcode                                    |
| [31:8] | PARAM   | R/W | Command-specific parameter field                  |

**Command opcodes:**

| Opcode | Name           | Description                                    |
|--------|----------------|------------------------------------------------|
| 0x00   | NOP            | No operation                                   |
| 0x01   | RUN_SELF_TEST  | Execute self-test on selected block             |
| 0x02   | READ_RESULT    | Re-read last result (no re-execution)          |
| 0x03   | READ_LOG       | Pop one entry from the log FIFO into RESULT0-3 |
| 0x04   | WRITE_BLOCK    | Write PARAM to block-specific config register  |
| 0x05   | READ_BLOCK     | Read block-specific register into RESULT0      |
| 0x10   | PROGRAM_OTP    | Program OTP (dangerous mode only)              |
| 0x11   | VERIFY_OTP     | Verify OTP contents                            |
| 0xFF   | FULL_SWEEP     | Alias for RUN_ALL — run all blocks sequentially|

### ERROR_CODE (0x2C)

| Value | Name               | Description                                    |
|-------|--------------------|------------------------------------------------|
| 0x00  | ERR_NONE           | No error                                       |
| 0x01  | ERR_TIMEOUT        | Block did not assert `tw_done` within TIMEOUT_CYCLES |
| 0x02  | ERR_COMPARE        | Data compare mismatch (SRAM, register, NVM)    |
| 0x03  | ERR_RANGE          | Measured value outside expected range (ADC, comparator, ring osc) |
| 0x04  | ERR_NO_RESPONSE    | Block did not respond to start signal          |
| 0x05  | ERR_OVERFLOW       | Internal counter or FIFO overflow              |
| 0x06  | ERR_UNSAFE_DENIED  | Dangerous command attempted without arming     |
| 0x07  | ERR_UNSUPPORTED    | Command not supported for selected block/mode  |
| 0x08+ | Block-specific     | Defined per block (see block test matrix)      |

### TIMEOUT_CYCLES (0x18)

| Bit(s)  | Name    | R/W | Description                              |
|---------|---------|-----|------------------------------------------|
| [31:0]  | CYCLES  | R/W | Timeout threshold in clock cycles. 0 = no timeout (use with caution). |

### LOG Entry Format (read via CMD 0x03 into RESULT0-3)

| Register | Field                                          |
|----------|-------------------------------------------------|
| RESULT0  | [7:0] block_id, [15:8] error_code, [16] pass, [17] fail, [31:18] reserved |
| RESULT1  | [31:0] cycle_timestamp                         |
| RESULT2  | [31:0] block result word 0 (snapshot)          |
| RESULT3  | [31:0] block result word 1 (snapshot)          |

## Block IDs

| Block ID | Name        | Description              |
|----------|-------------|--------------------------|
| 0x00     | REGBANK     | Register bank            |
| 0x01     | SRAM        | Static RAM               |
| 0x02     | UART        | UART transceiver         |
| 0x03     | SPI         | SPI controller           |
| 0x04     | I2C         | I2C controller           |
| 0x05     | GPIO        | General purpose I/O      |
| 0x06     | RING_OSC    | Ring oscillators         |
| 0x07     | CLK_DIV     | Clock divider/mux        |
| 0x08     | TRNG        | True random number gen   |
| 0x09     | PUF         | Physical unclonable func |
| 0x0A     | COMPARATOR  | Analog comparator        |
| 0x0B     | ADC         | Analog-to-digital conv   |
| 0x0C     | NVM         | Non-volatile / OTP mem   |
