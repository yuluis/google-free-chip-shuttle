# ULC Test Modes

The ULC supports three test modes, selected via `GLOBAL_CONTROL[5:4]`. Modes control which tests the sequencer will accept, which block operations are permitted, and what safety interlocks are active.

## Mode Summary

| Mode             | Code | GLOBAL_CONTROL[5:4] | Reversible | Requires Arming | Target Use Case          |
|------------------|------|----------------------|------------|------------------|--------------------------|
| SAFE_AUTO        | 0    | 00                   | Yes        | No               | Production test, FPGA, quick validation |
| LAB_EXTENDED     | 1    | 01                   | Yes        | No               | Bench characterization, analog/entropy analysis |
| DANGEROUS_ARMED  | 2    | 10                   | **No**     | **Yes**          | OTP programming, NVM burn, destructive tests |

---

## SAFE_AUTO (Mode 0) — Default

### Description

The default mode after reset. All tests in this mode are non-destructive and fully reversible. No analog calibration or entropy collection is performed — only functional pass/fail checks.

### What Runs

- **REGBANK**: Write/read-back all registers with walking-1 and walking-0 patterns.
- **SRAM**: Checkerboard and march-C write/read/verify.
- **UART**: Internal loopback TX→RX at configured baud.
- **SPI**: Internal loopback with known byte patterns.
- **I2C**: Internal loopback, ACK/NACK verification.
- **GPIO**: Output drive → input read-back (loopback via test mux).
- **RING_OSC**: Start oscillators, verify non-zero counter after N cycles.
- **CLK_DIV**: Switch divider ratios, verify output frequency via counter.
- **TRNG**: Collect short sample, verify not stuck-at (not full entropy test).
- **PUF**: Read challenge-response, verify non-zero and non-all-ones.
- **COMPARATOR**: Apply known reference, check output polarity.
- **ADC**: Convert known reference, verify code within coarse window.
- **NVM**: Read-only verification of existing contents (no write).

### Entering

This is the default mode. To re-enter from another mode:

```
Write GLOBAL_CONTROL[5:4] = 00
```

No arming required. No preconditions.

### Exiting

Write a different mode to `GLOBAL_CONTROL[5:4]`. Safe to switch at any time when IDLE.

### Safety Guarantees

- No writes to OTP/NVM.
- No persistent state changes beyond test counters and log.
- All block operations are idempotent — re-running produces the same result.
- A global reset returns the chip to its pre-test state.

---

## LAB_EXTENDED (Mode 1)

### Description

Extends SAFE_AUTO with longer-duration tests, analog characterization sweeps, and entropy quality analysis. Still fully reversible — no OTP or NVM writes.

### Additional Tests (beyond SAFE_AUTO)

- **RING_OSC**: Measure frequency of each oscillator stage; report min/max/mean across process corners (RESULT0=min_freq, RESULT1=max_freq, RESULT2=mean_freq).
- **TRNG**: Collect 1024+ bits, compute monobit/runs statistics, report in RESULT0-1.
- **PUF**: Multi-enrollment challenge-response. Measure Hamming distance between enrollments (RESULT0=HD_intra, RESULT1=response_word).
- **COMPARATOR**: Sweep reference DAC across range, find trip point (RESULT0=trip_code).
- **ADC**: Full-range ramp, report INL/DNL in RESULT0-1, offset in RESULT2, gain error in RESULT3.
- **CLK_DIV**: Jitter measurement over extended window (RESULT0=jitter_pk_pk).
- **SRAM**: Retention test — write pattern, wait N cycles, re-read (extended timeout required).

All other blocks run their SAFE_AUTO tests unchanged.

### Entering

```
Write GLOBAL_CONTROL[5:4] = 01
```

No arming required. Sequencer must be IDLE.

### Exiting

```
Write GLOBAL_CONTROL[5:4] = 00  (or 10 for dangerous)
```

### Safety Guarantees

- All guarantees of SAFE_AUTO still apply.
- Tests take longer (adjust TIMEOUT_CYCLES accordingly; recommended 0x00FFFFFF).
- No OTP/NVM writes. No irreversible operations.

---

## DANGEROUS_ARMED (Mode 2)

### Description

Enables irreversible operations: OTP programming, NVM burns, and potentially destructive stress tests. Hardware interlocks prevent accidental execution.

### Additional Tests (beyond LAB_EXTENDED)

- **NVM**: Program OTP bits with test pattern, then verify read-back. **Irreversible.**
- **NVM**: Endurance cycling on re-writable NVM regions (if present).
- **GPIO**: Stress test — high-frequency toggling at max drive strength.
- **SRAM**: Stress — write with marginal timing to probe retention limits.

### Entering — Arming Sequence

Dangerous mode requires a two-step arming handshake to prevent accidental OTP burns:

**Step 1: Set mode**
```
Write GLOBAL_CONTROL[5:4] = 10
```

**Step 2: Arm**
```
Write GLOBAL_CONTROL[6] = 1   (ARM_DANGEROUS bit)
```

**Step 3: Verify**
```
Read GLOBAL_STATUS[7]  — must read 1 (ARMED)
```

**Step 4: Execute**
```
Write COMMAND with desired opcode (e.g., 0x10 PROGRAM_OTP)
```

After the command dispatches, `GLOBAL_CONTROL[6]` (ARM_DANGEROUS) **auto-clears**. To execute another dangerous command, repeat Steps 2-4.

### Full Arming Sequence (Host Pseudocode)

```python
# Enter dangerous mode
write_reg(GLOBAL_CONTROL, read_reg(GLOBAL_CONTROL) | (0b10 << 4))

# Arm
write_reg(GLOBAL_CONTROL, read_reg(GLOBAL_CONTROL) | (1 << 6))

# Verify armed
status = read_reg(GLOBAL_STATUS)
assert status & (1 << 7), "Chip did not arm"

# Execute
write_reg(BLOCK_SELECT, BLOCK_NVM)
write_reg(COMMAND, CMD_PROGRAM_OTP | (pattern << 8))

# Wait for completion
while not (read_reg(GLOBAL_STATUS) & (1 << 2)):  # DONE
    pass

# ARM bit is now auto-cleared — must re-arm for next dangerous command
```

### Exiting

```
Write GLOBAL_CONTROL[5:4] = 00
```

ARM_DANGEROUS is also cleared. The chip returns to safe state.

### Safety Guarantees

- Dangerous commands are rejected with `ERR_UNSAFE_DENIED` (error code 6) unless the ARM bit is set **and** GLOBAL_STATUS[7] confirms ARMED.
- The ARM bit auto-clears after every command dispatch — no persistent armed state.
- Mode can be exited at any time when IDLE, instantly disabling dangerous operations.
- All non-dangerous commands (self-tests from SAFE/EXTENDED) still work normally in this mode.

---

## Mode Transition Diagram

```
                 ┌──────────────┐
    Reset ──────►│  SAFE_AUTO   │◄──────────────────────────┐
                 │  (mode 00)   │                           │
                 └──────┬───────┘                           │
                        │ write mode=01                     │ write mode=00
                        ▼                                   │
                 ┌──────────────┐                           │
                 │ LAB_EXTENDED │                           │
                 │  (mode 01)   │                           │
                 └──────┬───────┘                           │
                        │ write mode=10                     │
                        ▼                                   │
                 ┌──────────────────┐    arm + verify       │
                 │ DANGEROUS_ARMED  │───────────────►[ARMED]│
                 │  (mode 10)       │◄───auto-clear─────────┤
                 └──────────────────┘                       │
                        │ write mode=00 ────────────────────┘
```

Direct transitions between any two modes are allowed (SAFE↔LAB, SAFE↔DANGEROUS, LAB↔DANGEROUS) as long as the sequencer is IDLE. The arming step is only required before executing dangerous commands, not for entering the mode itself.
