# ULC Test Architecture Overview

## Purpose

The Universal Learning Chip (ULC) is a shuttle/learning chip designed to validate a broad set of digital and mixed-signal IP blocks under a **unified test architecture**. Every block is wrapped in a common test interface, controlled by a central FSM sequencer, and accessed through a single UART-based register map. This eliminates per-block bespoke test infrastructure and enables fully automated chip validation from RTL through silicon.

## Architecture

```
 ┌─────────────────────────────────────────────────────────────────────┐
 │  HOST (Python)                                                      │
 │  run_chip_validation.py  ──►  ulc_driver.py  ──►  Serial UART TX/RX│
 └──────────────────────────────────────┬──────────────────────────────┘
                                        │ UART
 ┌──────────────────────────────────────▼──────────────────────────────┐
 │  ULC CHIP                                                           │
 │                                                                     │
 │  ┌──────────┐    ┌────────────────────┐    ┌─────────────────────┐  │
 │  │  UART    │◄──►│  REGISTER MAP      │◄──►│  FSM SEQUENCER      │  │
 │  │  Bridge  │    │  (byte-addressed)  │    │  (central control)  │  │
 │  └──────────┘    └────────────────────┘    └─────────┬───────────┘  │
 │                                                      │              │
 │                    ┌─────────────────────────────────┬┘              │
 │                    │  Shared Test Wrapper Interface  │               │
 │        ┌───────────▼───────────────────────────────┐│               │
 │        │                                           ││               │
 │        │  ┌─────────┐ ┌──────┐ ┌──────┐ ┌──────┐  ││               │
 │        │  │ REGBANK │ │ SRAM │ │ UART │ │ SPI  │  ││               │
 │        │  └─────────┘ └──────┘ └──────┘ └──────┘  ││               │
 │        │  ┌──────┐ ┌──────┐ ┌────────┐ ┌───────┐  ││               │
 │        │  │ I2C  │ │ GPIO │ │RING_OSC│ │CLK_DIV│  ││               │
 │        │  └──────┘ └──────┘ └────────┘ └───────┘  ││               │
 │        │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐     ││               │
 │        │  │ TRNG │ │ PUF  │ │ COMP │ │ ADC  │     ││               │
 │        │  └──────┘ └──────┘ └──────┘ └──────┘     ││               │
 │        │  ┌──────┐                                 ││               │
 │        │  │ NVM  │                                 ││               │
 │        │  └──────┘                                 ││               │
 │        └───────────────────────────────────────────┘│               │
 │                                                     │               │
 │  ┌──────────────┐  ┌────────────┐  ┌─────────────┐ │               │
 │  │  RESULT REGS │  │  LOG FIFO  │  │  LED STATUS │ │               │
 │  │  (R0-R3)     │  │  (ptr/cnt) │  │  (pass/fail)│ │               │
 │  └──────────────┘  └────────────┘  └─────────────┘ │               │
 └─────────────────────────────────────────────────────────────────────┘
```

## Control Flow

1. **Host** writes registers via UART (block select, command, parameters).
2. **Register map** decodes writes and presents fields to the FSM sequencer.
3. **FSM sequencer** asserts the test wrapper interface for the selected block.
4. **Block wrapper** executes the self-test (stimulus generation, capture, compare).
5. **Results** written back to RESULT0-3 registers; PASS/FAIL counters updated.
6. **Log FIFO** captures block ID, pass/fail, error code, and timestamp per test.
7. **Host** reads status, results, and log entries to build the validation report.

## Design Principles

### Uniform Test Wrappers

Every block implements the same wrapper interface:

| Signal          | Dir | Width | Description                        |
|-----------------|-----|-------|------------------------------------|
| `tw_start`      | in  | 1     | Pulse to begin self-test           |
| `tw_mode`       | in  | 2     | Test mode (safe/extended/dangerous)|
| `tw_done`       | out | 1     | Asserted when test completes       |
| `tw_pass`       | out | 1     | 1 = pass, 0 = fail                |
| `tw_error_code` | out | 8     | Block-specific error code          |
| `tw_result[0:3]`| out | 4x32  | Block-specific result data         |

This uniformity means the sequencer does not need block-specific logic.

### Central FSM Sequencer

The sequencer walks through a deterministic state machine:

`IDLE → SELECT → CONFIGURE → EXECUTE → WAIT → CAPTURE → LOG → DONE`

It handles timeout enforcement, error capture, and log writes without host intervention during a test. The host only needs to write BLOCK_SELECT + COMMAND and poll GLOBAL_STATUS.

### Dangerous Mode Isolation

Irreversible operations (OTP/NVM programming) are gated by:
- A dedicated test mode (`DANGEROUS_ARMED`) that requires an explicit arming sequence.
- Hardware interlock: the arm bit auto-clears after one command execution.
- The sequencer refuses dangerous commands unless the arm handshake is complete.

### LED Status Indicators

| LED     | Meaning                          |
|---------|----------------------------------|
| Green   | Idle / all tests passed          |
| Yellow  | Test in progress                 |
| Red     | At least one failure recorded    |
| Blink   | Waiting for host (log overflow)  |

## Verification Stages

| Stage                | Environment       | Coverage Target                              |
|----------------------|-------------------|----------------------------------------------|
| RTL Unit             | Cocotb / Verilator| Each block wrapper individually; all modes   |
| Integrated RTL       | Cocotb            | Full sequencer + all blocks; UART host model |
| Gate-Level Spot      | Post-synthesis sim| Timing-sensitive paths; clock mux, async I/O |
| FPGA Emulation       | FPGA board + host | Real UART at speed; full safe + extended     |
| Silicon Validation   | Packaged chip     | All modes including dangerous (OTP)          |

## Low-Risk Design Rules

1. **Default to safe.** On reset, test mode = `SAFE_AUTO`. No block can be damaged by any command in this mode.
2. **Timeout everything.** Every test has a configurable timeout (TIMEOUT_CYCLES register). The sequencer aborts and logs `ERR_TIMEOUT` if a wrapper never asserts `tw_done`.
3. **One-shot arming.** The dangerous-arm bit self-clears after a single command dispatch. There is no persistent armed state.
4. **Log before report.** Results are written to the log FIFO before GLOBAL_STATUS is updated, ensuring the host cannot miss a result.
5. **No shared mutable state between blocks.** Each wrapper operates on its own internal resources. The shared bus is the register map only.
6. **Reset is always available.** Writing bit 0 of GLOBAL_CONTROL issues a synchronous reset to all blocks, the sequencer, and all result/log registers.
