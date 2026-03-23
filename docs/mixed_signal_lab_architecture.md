# ULC v2 — Mixed-Signal Lab-on-Chip Architecture

## Overview

The Universal Learning Chip v2 is a self-testable mixed-signal characterization platform targeting the Google Open MPW shuttle (Caravel/SKY130). It behaves like a lab-on-chip: all blocks are testable independently or in combination through a common BIST/sequencer infrastructure.

## Zone Architecture

### Zone A — Digital Backbone / Safe Core
The always-functional core. Everything needed for basic chip operation.

| Block | Purpose |
|-------|---------|
| UART Host Bridge | Primary host communication (115200 8N1) |
| Register Bank | 40+ memory-mapped 32-bit config/status registers |
| Test Sequencer | 18-state FSM orchestrating all tests and experiments |
| BIST Pattern Engine | Serial-pattern control of muxes and test paths (5 chains × 32 bits) |
| Test Mux | 16:1 block select multiplexer |
| Log Buffer | 32-entry circular postmortem log |
| SRAM + BIST | 1K×32 memory with March-pattern BIST |
| GPIO / LED | 8-bit GPIO + 5 status LEDs |
| Clock Dividers | /2, /4, /8, /16 from system clock |
| Experiment Profiles | 15 predefined experiment configurations |

### Zone B — Measurable Mixed-Signal
Analog and mixed-signal blocks with full digital observability.

| Block | Purpose |
|-------|---------|
| DAC | 10-bit DAC with 5 modes (static, staircase, ramp, alternating, LUT) |
| ADC | 12-bit ADC with monotonicity and linearity testing |
| Comparator | Threshold sweep with trip-point detection |
| Analog Route Matrix | 4-input mux per destination, contention prevention |
| Ring Oscillator Bank | 4 oscillators for process speed characterization |
| TRNG | Entropy source with SP 800-90B health checks |
| PUF | 128-bit Physical Unclonable Function with stability scoring |

### Zone C — Experimental Clock
Optional clock synthesis — chip works without it.

| Block | Purpose |
|-------|---------|
| PLL/DPLL | Configurable multiply/divide, lock detect, timeout |
| Clock Mux Tree | 5 sources × 4 destinations, per-destination select |
| Frequency Counters | Measure any clock source against system reference |

### Zone D — Experimental / Dangerous
Irreversible operations. Isolated, explicitly armed.

| Block | Purpose |
|-------|---------|
| NVM/OTP | One-time programmable memory test (requires CTRL_ARM_DANGEROUS) |

### Zone E — Routing / Power / Margin
Physical layout infrastructure (not modeled in RTL).

## Key Design Rules

1. **PLL is optional** — chip must test without PLL lock (ext ref and ring osc always available)
2. **Dangerous blocks isolated** — NVM requires explicit arming bit; BIST patterns cannot arm dangerous ops
3. **Safe defaults on reset** — all routes disconnected, DAC disabled, PLL bypassed, BIST cleared
4. **Error recovery** — sequencer restores safe state after any experiment failure
5. **Dual control** — registers and BIST chains both control muxes; BIST takes priority when active

## Experiment Flow

```
Host sends CMD_LOAD_EXPERIMENT with profile ID
  → Sequencer loads profile (block enables, clock sources, routes, DAC mode)
  → SEQ_CONFIGURE_CLOCKS: set clock mux tree
  → SEQ_WAIT_PLL_LOCK: (only if profile.requires_pll)
  → SEQ_APPLY_ROUTE: configure analog route matrix
  → SEQ_ARM_CHECK: verify safety for selected block
  → SEQ_PREPARE_BLOCK → SEQ_START_BLOCK → SEQ_WAIT_FOR_DONE
  → SEQ_COLLECT_RESULTS → SEQ_WRITE_STATUS → SEQ_APPEND_LOG
  → SEQ_COMPLETE (auto-clears experiment ID)
  → On error: SEQ_RESTORE_SAFE (disconnects routes, clears BIST, resets clocks)
```

## Register Map Summary

| Range | Group | Count |
|-------|-------|-------|
| 0x00–0x4F | Base (chip ID, control, status, results, log) | 18 regs |
| 0x50–0x5F | Experiment orchestration | 3 regs |
| 0x60–0x6F | BIST pattern engine | 4 regs |
| 0x70–0x7F | Clock mux tree | 4 regs |
| 0x80–0x8F | Analog route matrix | 4 regs |
| 0x90–0x9F | DAC | 4 regs |
| 0xA0–0xAF | PLL | 4 regs |
| **Total** | | **41 registers** |

## Risk Assessment

| Feature | Risk | Notes |
|---------|------|-------|
| Digital backbone (UART, regs, sequencer, GPIO, SRAM) | Low | Proven RTL patterns |
| BIST pattern engine | Low | Simple shift registers |
| Clock mux tree | Low | Muxes with safe fallback |
| DAC (digital portion) | Low | Counter/FSM logic only |
| Analog route matrix (digital control) | Low | Mux select logic |
| Experiment profiles | Low | Combinational lookup table |
| DAC (analog output in silicon) | Medium | Requires careful layout |
| ADC/Comparator (analog in silicon) | Medium | Process-dependent |
| Ring oscillators | Medium | Layout-sensitive |
| PLL/DPLL | High | May not lock — chip designed to work without it |
| NVM/OTP programming | High | Irreversible — isolated with safety interlock |
