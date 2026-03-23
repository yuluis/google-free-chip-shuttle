# ULC v2.4 Reset Defaults and Safe-State Truth Table

**Status:** Frozen
**Purpose:** This is the most critical architecture document. It defines what "safe" means for every register, subsystem, and output of the ULC v2.4. Any implementation that deviates from these values at reset is a bug.

---

## Reset Sources

| Reset Source | Trigger | Scope | BOOT_STATUS Code |
|--------------|---------|-------|-----------------|
| Power-on reset (POR) | VDD ramp detected | Full chip (all domains) | 0x01 |
| RST_N pin | RST_N held LOW | Full chip (all domains) | 0x02 |
| Software reset (register) | Write 0xDEAD to SOFTWARE_RESET | Full chip (all domains) | 0x04 |
| Software reset (bit) | Set GLOBAL_CONTROL[9] | Full chip (all domains) | 0x08 |
| Sequencer reset | Set GLOBAL_CONTROL[10] | Sequencer FSM only | N/A (partial) |
| Analog reset | Set GLOBAL_CONTROL[11] | Analog subsystem only | N/A (partial) |
| Dangerous reset | Set GLOBAL_CONTROL[12] | Dangerous zone only | N/A (partial) |

Full-chip resets affect all registers and outputs. Partial resets (GLOBAL_CONTROL[10:12]) affect only the targeted subsystem and do not update BOOT_STATUS.

---

## Bank 0 — Global Registers

| Register | Offset | Reset Value | Safe State Description |
|----------|--------|-------------|----------------------|
| CHIP_ID | 0x00 | 0x554C4324 | Fixed identifier "ULC$" — read-only, hardwired |
| BANK_SELECT | 0x04 | 0x00000000 | Bank 0 selected — all accesses go to global registers |
| GLOBAL_CONTROL | 0x08 | 0x00000000 | **All subsystems disabled and disarmed.** global_enable=0, reset_fabric=0, arm_dangerous=0, clear_results=0, loop_mode=0, pll_enable=0, dac_enable=0, bist_enable=0, lab_mode=0, debug_mode=0. No self-clearing bits active. |
| GLOBAL_STATUS | 0x0C | (dynamic) | Reflects current state; at reset shows all-idle |
| BLOCK_SELECT | 0x10 | 0x00000000 | No block selected for sequencer |
| COMMAND | 0x14 | (write-only) | No pending command |
| TIMEOUT_CYCLES | 0x18 | 0x000F4240 | 1,000,000 cycles default timeout (~100ms at 10MHz) |
| RESULT0 | 0x1C | 0x00000000 | No results |
| RESULT1 | 0x20 | 0x00000000 | No results |
| RESULT2 | 0x24 | 0x00000000 | No results |
| RESULT3 | 0x28 | 0x00000000 | No results |
| ERROR_CODE | 0x2C | 0x00000000 | No errors |
| PASS_COUNT | 0x30 | 0x00000000 | Zero passes counted |
| FAIL_COUNT | 0x34 | 0x00000000 | Zero failures counted |
| LAST_BLOCK | 0x38 | 0x00000000 | No block has been tested |
| LAST_STATE | 0x3C | 0x00000000 | No sequencer state recorded |
| LOG_PTR | 0x40 | 0x00000000 | Log write pointer at beginning |
| LOG_COUNT | 0x44 | 0x00000000 | Zero log entries recorded |
| CHIP_REV | 0x48 | 0x00000204 | Fixed revision v2.4 — read-only, hardwired |
| EXPERIMENT_ID | 0x50 | 0x00000000 | No experiment profile selected (profile 0 = none) |
| EXPERIMENT_STATUS | 0x54 | 0x00000000 | No experiment running |
| EXPERIMENT_CONFIG | 0x58 | 0x00000000 | No experiment configuration overrides |
| SOFTWARE_RESET | 0x5C | (write-only) | No pending reset |
| SNAP_BANK_CLK | 0x60 | 0x00000000 | Snapshot cleared |
| SNAP_ROUTE_EXP | 0x64 | 0x00000000 | Snapshot cleared |
| SNAP_SEQ_ERR | 0x68 | 0x00000000 | Snapshot cleared |
| SNAP_FLAGS | 0x6C | 0x00000000 | Snapshot cleared |
| DEBUG_CONTROL | 0x70 | 0x00000000 | Debug mode off, no observation signals selected |
| SPARE_PAD_CTRL | 0x74 | 0x00000000 | Spare pads in Hi-Z (output disabled, no function muxed) |
| BOOT_STATUS | 0x78 | (captured) | Captures reset cause code at reset exit (see Reset Sources table) |

---

## Bank 1 — Clock Registers

| Register | Offset | Reset Value | Safe State Description |
|----------|--------|-------------|----------------------|
| CLK_MUX_CONTROL | 0x00 | 0x00000000 | Clock source = external reference (ext_ref). PLL and ROSC bypassed. |
| CLK_MUX_STATUS | 0x04 | (dynamic) | Reports ext_ref selected, glitch-free mux idle |
| CLK_FREQ_COUNT | 0x08 | 0x00000000 | No measurement in progress; result cleared |
| CLK_FREQ_SELECT | 0x0C | 0x00000000 | Measurement target = ext_ref (source 0) |
| CLK_FREQ_WINDOW | 0x10 | 0x00002710 | 10,000 reference cycles measurement window |
| CLK_DIV_CONTROL | 0x14 | 0x00000000 | Divider ratio = 1 (passthrough, no division) |
| PLL_CONTROL | 0x20 | 0x00000000 | PLL disabled, bypass mode. No divider configuration. |
| PLL_STATUS | 0x24 | 0x00000000 | PLL not running, no frequency estimate |
| PLL_FREQ_COUNT | 0x28 | 0x00000000 | No PLL frequency measurement result |
| PLL_LOCK_TIMEOUT | 0x2C | 0x00000000 | No timeout configured (PLL disabled) |
| ROSC_CONTROL | 0x30 | 0x00000000 | Ring oscillator disabled, trim = 0 |
| DBG_CLK_SELECT | 0x34 | 0x00000000 | Debug clock output = none (pad driven LOW) |

**Clock subsystem safe state:** The chip runs on ext_ref only. PLL is disabled and bypassed. Ring oscillator is off. Clock mux passes ext_ref directly to the clock tree. No internal clock generation is active.

---

## Bank 2 — Analog Registers

| Register | Offset | Reset Value | Safe State Description |
|----------|--------|-------------|----------------------|
| AROUTE_CONTROL | 0x00 | 0x00000000 | **All analog routes DISCONNECTED.** No internal analog paths enabled. |
| AROUTE_STATUS | 0x04 | 0x00000000 | All switches open |
| AROUTE_ADC_SRC | 0x08 | 0x00000000 | ADC input source = none (disconnected) |
| AROUTE_COMP_SRC | 0x0C | 0x00000000 | Comparator input source = none (disconnected) |
| DAC_CONTROL | 0x20 | 0x00000000 | **DAC disabled.** Output not driven. Mode = STATIC (no sweep, no toggling). |
| DAC_CODE | 0x24 | 0x00000000 | DAC code = 0 (minimum output, but output is disabled anyway) |
| DAC_STATUS | 0x28 | 0x00000000 | DAC idle, not running |
| DAC_UPDATE_COUNT | 0x2C | 0x00000000 | Zero updates |
| DAC_ALT_CODE | 0x30 | 0x00000000 | Alternate code = 0 |
| DAC_CLK_DIV | 0x34 | 0x00000000 | DAC update divider = 1 (passthrough) |
| ADC_CONTROL | 0x40 | 0x00000000 | **ADC idle.** Not enabled, no conversion pending. |
| ADC_RESULT | 0x44 | 0x00000000 | No conversion result |
| ADC_MIN_MAX | 0x48 | 0x00000000 | Min/max tracking cleared |
| ADC_SAMPLE_COUNT | 0x4C | 0x00000000 | Zero samples |
| COMP_CONTROL | 0x60 | 0x00000000 | Comparator disabled, no hysteresis, default polarity |
| COMP_STATUS | 0x64 | 0x00000000 | Comparator output unknown (disabled), edge history cleared |
| COMP_SWEEP_CFG | 0x68 | 0x00000000 | No sweep configured |
| COMP_TRIP_RESULT | 0x6C | 0x00000000 | No trip point recorded |

**Analog subsystem safe state:** All analog routes are disconnected. DAC output is disabled with code 0 and mode STATIC. ADC is idle with no conversion. Comparator is disabled. No analog signal path is active. The DAC_OUT pad is not driven (weak pull to VSS_A in pad frame).

---

## Bank 3 — BIST Registers

| Register | Offset | Reset Value | Safe State Description |
|----------|--------|-------------|----------------------|
| BIST_CONTROL | 0x00 | (write-only) | No BIST operation pending |
| BIST_CHAIN_SEL | 0x04 | 0x00000000 | Chain 0 selected (but BIST not enabled) |
| BIST_SHIFT_DATA | 0x08 | 0x00000000 | Shift register cleared |
| BIST_LATCH_STATUS | 0x0C | 0x00000000 | All chain latches cleared |
| BIST_READBACK | 0x10 | 0x00000000 | Readback data cleared |
| BIST_APPLY_STATUS | 0x14 | 0x00000000 | No apply results |

**BIST subsystem safe state:** All 5 chains are cleared. No shift, apply, or capture operation is in progress. BIST fabric is idle. The fabric is not in reset (reset_fabric in GLOBAL_CONTROL is 0), but bist_enable is also 0, so no BIST activity occurs.

---

## Bank 4 — Security Registers

| Register | Offset | Reset Value | Safe State Description |
|----------|--------|-------------|----------------------|
| TRNG_CONTROL | 0x00 | 0x00000000 | TRNG disabled, no entropy collection |
| TRNG_STATUS | 0x04 | 0x00000000 | Not ready, no health alerts |
| TRNG_BIT_COUNT | 0x08 | 0x00000000 | Zero bits generated |
| TRNG_ONES_COUNT | 0x0C | 0x00000000 | Zero ones counted |
| TRNG_REP_MAX | 0x10 | 0x00000000 | No repetition data |
| PUF_CONTROL | 0x20 | 0x00000000 | PUF disabled, no challenge issued |
| PUF_STATUS | 0x24 | 0x00000000 | Not ready, no valid response |
| PUF_RESP_0 | 0x28 | 0x00000000 | Response word 0 cleared |
| PUF_RESP_1 | 0x2C | 0x00000000 | Response word 1 cleared |
| PUF_RESP_2 | 0x30 | 0x00000000 | Response word 2 cleared |
| PUF_RESP_3 | 0x34 | 0x00000000 | Response word 3 cleared |
| PUF_MISMATCH | 0x38 | 0x00000000 | Zero mismatches |

**Security subsystem safe state:** TRNG and PUF are both disabled. No entropy is being collected. No challenge-response is active. All response registers are cleared.

---

## Bank 5 — Log Registers

| Register | Offset | Reset Value | Safe State Description |
|----------|--------|-------------|----------------------|
| LOG_READ_INDEX | 0x00 | 0x00000000 | Read pointer at entry 0 |
| LOG_ENTRY_BLOCK | 0x04 | 0x00000000 | No log entry data |
| LOG_ENTRY_T_START | 0x08 | 0x00000000 | No log entry data |
| LOG_ENTRY_T_END | 0x0C | 0x00000000 | No log entry data |
| LOG_ENTRY_R0 | 0x10 | 0x00000000 | No log entry data |
| LOG_ENTRY_R1 | 0x14 | 0x00000000 | No log entry data |
| SRAM_BIST_STATUS | 0x40 | 0x00000000 | SRAM self-test not run; status cleared |

**Log subsystem safe state:** Log is empty (ptr=0, count=0). SRAM has not been self-tested. Log read index points to entry 0.

---

## Bank 0xA — Dangerous Registers

| Register | Offset | Reset Value | Safe State Description |
|----------|--------|-------------|----------------------|
| DANGEROUS_ARM | 0x00 | 0x00000000 | **DISARMED.** Magic value not present. |
| NVM_ADDRESS | 0x04 | 0x00000000 | Address cleared |
| NVM_WRITE_DATA | 0x08 | 0x00000000 | Write data cleared |
| NVM_READ_DATA | 0x0C | 0x00000000 | Read data cleared |
| NVM_COMMAND | 0x10 | (write-only) | No command pending |
| NVM_STATUS | 0x14 | 0x00000000 | Idle, not armed, no error |

**Dangerous zone safe state:** The zone is fully disarmed. Both arming conditions are false (GLOBAL_CONTROL[2]=0 AND DANGEROUS_ARM != magic). All NVM commands are rejected. Even if VDD_E is powered, no destructive operation can occur without the dual-key arming sequence.

---

## Subsystem-Level Safe States

| Subsystem | Reset State | What "Safe" Means |
|-----------|-------------|-------------------|
| **UART** | Idle, TX line HIGH | Ready to accept commands; not transmitting |
| **SPI** | Slave mode, MISO Hi-Z | Not driving bus; waiting for CS assertion |
| **Clock tree** | ext_ref passthrough | No PLL, no ROSC, no division — external clock only |
| **PLL** | Disabled, bypass | Not oscillating; input passed through mux untouched |
| **Ring oscillator** | Disabled | Not oscillating; no current draw beyond leakage |
| **DAC** | Disabled, code 0, STATIC | Output pad not driven; no analog voltage produced |
| **ADC** | Idle | No conversion; input disconnected via AROUTE |
| **Comparator** | Disabled | Output undefined but unused; inputs disconnected |
| **Analog routing** | All disconnected | No analog signal paths exist; all switches open |
| **GPIO** | All inputs (Hi-Z output) | No pins driving externally |
| **LEDs** | All LOW | All LEDs off |
| **Spare pads** | Hi-Z | Tri-stated; no function muxed |
| **DBG/GP pads** | GPIO mode, input | Acting as general inputs, not debug outputs |
| **BIST fabric** | Idle, chains cleared | No test patterns loaded or applied |
| **TRNG** | Disabled | No entropy collection; zero power beyond leakage |
| **PUF** | Disabled | No challenge active; responses cleared |
| **Sequencer** | Idle | No experiment running; waiting for COMMAND |
| **Event logger** | Empty | Ptr=0, count=0; SRAM contents undefined but not read |
| **Experiment profiles** | None selected (ID=0) | No profile active; no blocks configured by profile |
| **Dangerous zone** | Fully disarmed | Dual-key not satisfied; all NVM commands rejected |
| **Snapshots** | Cleared | All snapshot registers read as 0 |
| **Debug** | Off | No observation outputs; DBG/GP in GPIO mode |

---

## Output Pin Safe States

| Output | Reset State | Level | Notes |
|--------|-------------|-------|-------|
| UART_TX | Idle | HIGH | UART idle = mark = HIGH |
| MISO | Tri-state | Hi-Z | SPI slave, CS not asserted |
| SPARE_IO0 | Tri-state | Hi-Z | No function selected |
| SPARE_IO1 | Tri-state | Hi-Z | No function selected |
| GPIO[0:7] | Input mode | Hi-Z (output) | Output drivers disabled |
| LED[0:4] | Output LOW | LOW | LEDs off |
| DAC_OUT | Disabled | ~0V (weak pull) | DAC off, pad frame weak pull to VSS_A |
| ROSC_MUX | Output LOW | LOW | ROSC disabled, pad driven LOW |
| DBG/GP0 | GPIO input | Hi-Z (output) | GPIO mode, output disabled |
| DBG/GP1 | GPIO input | Hi-Z (output) | GPIO mode, output disabled |

---

## Critical Invariants at Reset

These conditions MUST be true immediately after any full-chip reset. Violation of any invariant is a silicon bug.

1. **No subsystem is enabled.** GLOBAL_CONTROL = 0x00000000.
2. **No analog path is connected.** All AROUTE switches open.
3. **DAC output is disabled and code is zero.**
4. **Dangerous zone is disarmed.** Both keys are inactive.
5. **Clock source is external reference only.** PLL and ROSC are off.
6. **All output pads are in their safe state** (see table above).
7. **Pass/fail counters are zero.** No stale results from previous session.
8. **Log is empty.** Ptr=0, count=0.
9. **BOOT_STATUS captures the reset cause.** Must be non-zero after any reset.
10. **CHIP_ID and CHIP_REV are correct.** Hardwired, not resetable.
11. **UART is responsive.** The host can issue 'S' (status) immediately after reset.
12. **Spare pads are Hi-Z.** No unintended output drive.
