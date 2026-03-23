# ULC v2.4 Complete Register Map

**Status:** Frozen
**Total banks:** 7 (0-5, 0xA)
**Total registers:** 92
**Addressing:** BANK_SELECT + 8-bit offset
**Data width:** 32-bit
**Access types:** R (read-only), W (write-only), RW (read-write)

---

## Addressing Model

All register access goes through the UART serial protocol. The active bank is selected by writing `BANK_SELECT` (Bank 0, offset 0x04). Bank 0 registers are always accessible regardless of `BANK_SELECT` value.

Address byte format: `[7:0]` = register offset within the selected bank.

Bank 0 registers occupy the offset range 0x00-0x78. Other banks use their own offset spaces starting at 0x00.

---

## Serial Protocol

| Command | TX Bytes | RX Bytes | Description |
|---------|----------|----------|-------------|
| Write | `'W'` addr[1] data[4] | `'A'` | Write 32-bit value to register |
| Read | `'R'` addr[1] | `'D'` data[4] | Read 32-bit value from register |
| Status | `'S'` | `'S'` status[4] | Read global status word |
| Reset | `'X'` | `'A'` | Trigger software reset |

- All multi-byte values are big-endian over the wire.
- `addr` is the 8-bit offset within the currently selected bank.
- Bank 0 offsets are accessed directly; all other banks require `BANK_SELECT` to be set first.

---

## Bank 0 — Global (31 registers)

System-wide control, status, sequencer interface, experiment control, snapshots, and debug.

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x00 | CHIP_ID | R | 0x554C4324 | ASCII "ULC$" — chip identifier |
| 0x04 | BANK_SELECT | RW | 0x00000000 | Active bank selector (0-5, 0xA) |
| 0x08 | GLOBAL_CONTROL | RW | 0x00000000 | Master control register (see bit definitions below) |
| 0x0C | GLOBAL_STATUS | R | — | Aggregated status from all subsystems |
| 0x10 | BLOCK_SELECT | RW | 0x00000000 | Target block for sequencer commands |
| 0x14 | COMMAND | W | — | Sequencer command trigger |
| 0x18 | TIMEOUT_CYCLES | RW | 0x000F4240 | Sequencer timeout in clock cycles (default = 1,000,000) |
| 0x1C | RESULT0 | R | 0x00000000 | Sequencer result word 0 |
| 0x20 | RESULT1 | R | 0x00000000 | Sequencer result word 1 |
| 0x24 | RESULT2 | R | 0x00000000 | Sequencer result word 2 |
| 0x28 | RESULT3 | R | 0x00000000 | Sequencer result word 3 |
| 0x2C | ERROR_CODE | R | 0x00000000 | Last error code from sequencer |
| 0x30 | PASS_COUNT | R | 0x00000000 | Cumulative pass count |
| 0x34 | FAIL_COUNT | R | 0x00000000 | Cumulative fail count |
| 0x38 | LAST_BLOCK | R | 0x00000000 | Block ID of last sequencer operation |
| 0x3C | LAST_STATE | R | 0x00000000 | Final state of last sequencer operation |
| 0x40 | LOG_PTR | R | 0x00000000 | Current write pointer in event log |
| 0x44 | LOG_COUNT | R | 0x00000000 | Number of log entries recorded |
| 0x48 | CHIP_REV | R | 0x00000204 | Chip revision (v2.4 = 0x0204) |
| 0x50 | EXPERIMENT_ID | RW | 0x00000000 | Active experiment profile (0-14, 0=none) |
| 0x54 | EXPERIMENT_STATUS | R | 0x00000000 | Current experiment execution status |
| 0x58 | EXPERIMENT_CONFIG | RW | 0x00000000 | Per-experiment configuration overrides |
| 0x5C | SOFTWARE_RESET | W | — | Write magic value 0x0000DEAD to trigger software reset |
| 0x60 | SNAP_BANK_CLK | R | 0x00000000 | Snapshot: bank select + clock state |
| 0x64 | SNAP_ROUTE_EXP | R | 0x00000000 | Snapshot: routing + experiment state |
| 0x68 | SNAP_SEQ_ERR | R | 0x00000000 | Snapshot: sequencer + error state |
| 0x6C | SNAP_FLAGS | R | 0x00000000 | Snapshot: aggregated flag bits |
| 0x70 | DEBUG_CONTROL | RW | 0x00000000 | Debug mode configuration |
| 0x74 | SPARE_PAD_CTRL | RW | 0x00000000 | Spare pad direction and mux control |
| 0x78 | BOOT_STATUS | R | — | Reset cause and boot status (captured at reset exit) |

### GLOBAL_CONTROL Bit Definitions (Bank 0, offset 0x08)

| Bit | Name | Type | Description |
|-----|------|------|-------------|
| [0] | global_enable | RW | Master enable for all subsystems |
| [1] | reset_fabric | RW | Hold BIST fabric in reset |
| [2] | arm_dangerous | RW | Arm dangerous zone (requires DANGEROUS_ARM magic too) |
| [3] | clear_results | RW | Clear PASS_COUNT, FAIL_COUNT, RESULT0-3 |
| [4] | loop_mode | RW | Sequencer loops current experiment continuously |
| [5] | pll_enable | RW | Enable PLL (when available) |
| [6] | dac_enable | RW | Enable DAC output |
| [7] | bist_enable | RW | Enable BIST fabric |
| [8] | lab_mode | RW | Enable lab/bench mode (relaxed timeouts) |
| [9] | software_reset | W/SC | Self-clearing: triggers software reset sequence |
| [10] | reset_sequencer | W/SC | Self-clearing: reset sequencer FSM only |
| [11] | reset_analog | W/SC | Self-clearing: reset analog subsystem only |
| [12] | reset_dangerous | W/SC | Self-clearing: reset dangerous zone only |
| [13] | debug_mode | RW | Enable debug observation outputs |
| [14] | snap_capture | W/SC | Self-clearing: capture state snapshot |
| [31:15] | — | — | Reserved (read as 0) |

SC = Self-Clearing (bit auto-clears after action completes).

---

## Bank 1 — Clock (12 registers)

Clock multiplexing, frequency measurement, dividers, PLL control, ring oscillator.

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x00 | CLK_MUX_CONTROL | RW | 0x00000000 | Clock source selection mux |
| 0x04 | CLK_MUX_STATUS | R | — | Current mux state and glitch-free status |
| 0x08 | CLK_FREQ_COUNT | R/W | 0x00000000 | Write to trigger measurement; read for result |
| 0x0C | CLK_FREQ_SELECT | RW | 0x00000000 | Select which clock to measure |
| 0x10 | CLK_FREQ_WINDOW | RW | 0x00002710 | Measurement window in reference cycles (default = 10,000) |
| 0x14 | CLK_DIV_CONTROL | RW | 0x00000000 | Programmable clock divider ratio |
| 0x20 | PLL_CONTROL | RW | 0x00000000 | PLL configuration (dividers, enable, bypass) |
| 0x24 | PLL_STATUS | R | 0x00000000 | PLL status (running, frequency estimate) |
| 0x28 | PLL_FREQ_COUNT | R | 0x00000000 | PLL output frequency count result |
| 0x2C | PLL_LOCK_TIMEOUT | RW | 0x00000000 | Timeout for PLL frequency verification |
| 0x30 | ROSC_CONTROL | RW | 0x00000000 | Ring oscillator enable and trim |
| 0x34 | DBG_CLK_SELECT | RW | 0x00000000 | Debug clock output pad source selection |

---

## Bank 2 — Analog (18 registers)

Analog routing, DAC, ADC, and comparator subsystems.

### Analog Routing

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x00 | AROUTE_CONTROL | RW | 0x00000000 | Analog route matrix master control |
| 0x04 | AROUTE_STATUS | R | 0x00000000 | Current routing state |
| 0x08 | AROUTE_ADC_SRC | RW | 0x00000000 | ADC input source selection |
| 0x0C | AROUTE_COMP_SRC | RW | 0x00000000 | Comparator input source selection |

### DAC

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x20 | DAC_CONTROL | RW | 0x00000000 | DAC enable, mode (static/sweep/alt), output enable |
| 0x24 | DAC_CODE | RW | 0x00000000 | DAC output code (primary) |
| 0x28 | DAC_STATUS | R | 0x00000000 | DAC operational status |
| 0x2C | DAC_UPDATE_COUNT | R | 0x00000000 | Number of DAC updates since last reset |
| 0x30 | DAC_ALT_CODE | RW | 0x00000000 | DAC alternate code (for toggling modes) |
| 0x34 | DAC_CLK_DIV | RW | 0x00000000 | DAC update clock divider |

### ADC

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x40 | ADC_CONTROL | RW | 0x00000000 | ADC enable, trigger mode, conversion start |
| 0x44 | ADC_RESULT | R | 0x00000000 | Last ADC conversion result |
| 0x48 | ADC_MIN_MAX | R | 0x00000000 | Tracked min [31:16] and max [15:0] since last clear |
| 0x4C | ADC_SAMPLE_COUNT | R | 0x00000000 | Number of conversions completed |

### Comparator

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x60 | COMP_CONTROL | RW | 0x00000000 | Comparator enable, hysteresis, polarity |
| 0x64 | COMP_STATUS | R | 0x00000000 | Comparator output state, edge history |
| 0x68 | COMP_SWEEP_CFG | RW | 0x00000000 | Comparator sweep configuration (DAC sweep + compare) |
| 0x6C | COMP_TRIP_RESULT | R | 0x00000000 | DAC code at last comparator trip point |

---

## Bank 3 — BIST (6 registers)

Built-in self-test: 5-chain serial-pattern fabric.

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x00 | BIST_CONTROL | W | — | BIST command: shift, apply, capture, reset |
| 0x04 | BIST_CHAIN_SEL | RW | 0x00000000 | Active chain selection (0-4) |
| 0x08 | BIST_SHIFT_DATA | RW | 0x00000000 | Serial shift-in/shift-out data register |
| 0x0C | BIST_LATCH_STATUS | R | 0x00000000 | Latch capture state per chain |
| 0x10 | BIST_READBACK | R | 0x00000000 | Readback of last captured chain data |
| 0x14 | BIST_APPLY_STATUS | R | 0x00000000 | Result of last apply cycle per chain |

---

## Bank 4 — Security (12 registers)

True random number generator (TRNG) and physically unclonable function (PUF).

### TRNG

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x00 | TRNG_CONTROL | RW | 0x00000000 | TRNG enable, mode, conditioning |
| 0x04 | TRNG_STATUS | R | 0x00000000 | TRNG ready, health status |
| 0x08 | TRNG_BIT_COUNT | R | 0x00000000 | Total bits generated since enable |
| 0x0C | TRNG_ONES_COUNT | R | 0x00000000 | Count of '1' bits (for bias checking) |
| 0x10 | TRNG_REP_MAX | R | 0x00000000 | Maximum consecutive identical bits observed |

### PUF

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x20 | PUF_CONTROL | RW | 0x00000000 | PUF enable, challenge trigger |
| 0x24 | PUF_STATUS | R | 0x00000000 | PUF ready, response valid |
| 0x28 | PUF_RESP_0 | R | 0x00000000 | PUF response word 0 |
| 0x2C | PUF_RESP_1 | R | 0x00000000 | PUF response word 1 |
| 0x30 | PUF_RESP_2 | R | 0x00000000 | PUF response word 2 |
| 0x34 | PUF_RESP_3 | R | 0x00000000 | PUF response word 3 |
| 0x38 | PUF_MISMATCH | R | 0x00000000 | Bit mismatch count across repeated challenges |

---

## Bank 5 — Log (7 registers)

Event log readback and SRAM BIST status.

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x00 | LOG_READ_INDEX | RW | 0x00000000 | Log entry read pointer (set to desired index) |
| 0x04 | LOG_ENTRY_BLOCK | R | 0x00000000 | Block ID of log entry at current read index |
| 0x08 | LOG_ENTRY_T_START | R | 0x00000000 | Start timestamp of log entry |
| 0x0C | LOG_ENTRY_T_END | R | 0x00000000 | End timestamp of log entry |
| 0x10 | LOG_ENTRY_R0 | R | 0x00000000 | Result word 0 of log entry |
| 0x14 | LOG_ENTRY_R1 | R | 0x00000000 | Result word 1 of log entry |
| 0x40 | SRAM_BIST_STATUS | R | 0x00000000 | SRAM self-test result (pass/fail, address of first failure) |

---

## Bank 0xA — Dangerous (6 registers)

Isolated zone with separate power domain. Requires dual-key arming.

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x00 | DANGEROUS_ARM | RW | 0x00000000 | Write magic 0x41524D21 ("ARM!") to arm; read back arm state |
| 0x04 | NVM_ADDRESS | RW | 0x00000000 | NVM target address |
| 0x08 | NVM_WRITE_DATA | RW | 0x00000000 | NVM write data register |
| 0x0C | NVM_READ_DATA | R | 0x00000000 | NVM read data result |
| 0x10 | NVM_COMMAND | W | — | NVM operation command (read/write/erase) |
| 0x14 | NVM_STATUS | R | 0x00000000 | NVM controller status (busy, error, ready) |

### Arming Sequence

The dangerous zone requires TWO conditions to be active:
1. `GLOBAL_CONTROL[2]` (arm_dangerous) = 1
2. `DANGEROUS_ARM` register contains magic value 0x41524D21

If either condition is not met, all NVM commands are rejected and `NVM_STATUS` reports `NOT_ARMED`.

---

## Register Count Summary

| Bank | Name | Registers | Offset Range |
|------|------|-----------|--------------|
| 0 | Global | 31 | 0x00 - 0x78 |
| 1 | Clock | 12 | 0x00 - 0x34 |
| 2 | Analog | 18 | 0x00 - 0x6C |
| 3 | BIST | 6 | 0x00 - 0x14 |
| 4 | Security | 12 | 0x00 - 0x38 |
| 5 | Log | 7 | 0x00 - 0x40 |
| 0xA | Dangerous | 6 | 0x00 - 0x14 |
| **Total** | | **92** | |
