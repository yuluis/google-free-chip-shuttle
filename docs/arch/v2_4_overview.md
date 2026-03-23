# ULC v2.4 Architecture Overview

**Status:** Frozen
**Process:** SKY130 (SkyWater 130nm open-source PDK)
**Wrapper:** Caravel digital wrapper (efabless)
**Die area:** 2.92 x 3.52 mm
**Gate count:** ~51.7K gates (6.3% of 820K Caravel capacity)
**Version:** 2.4

---

## 1. Design Philosophy

The Universal Learning Chip v2.4 is a silicon teaching and experimentation vehicle. Every subsystem is designed to be independently testable, safely defaulted, and observable via a single UART host interface. The chip prioritizes debuggability and safe-state guarantees over performance.

---

## 2. Block Count and Zone Organization

32 blocks are organized across 7 physical zones:

| Zone | Location | Purpose | Blocks |
|------|----------|---------|--------|
| `host_perimeter` | Top edge | Host digital interfaces (UART, SPI, spare I/O) | UART controller, SPI controller, spare pad mux |
| `gpio_perimeter` | Left edge | General-purpose I/O and LED drivers | GPIO bank (8-bit), LED driver bank (5-channel) |
| `digital_core` | Center | Digital backbone: sequencer, register file, BIST, log, security | Register file, sequencer, BIST fabric, event logger, SRAM, TRNG, PUF |
| `mixed_signal` | Right cluster | Analog interfaces and routing | DAC, ADC, comparator, analog route matrix |
| `clock_experiment` | Bottom-left | Clock generation and measurement (placed away from analog) | PLL wrapper, ring oscillator, clock mux, frequency counter, clock divider |
| `routing_margin` | Bottom center | Routing margin and experiment profile controller | Experiment profile ROM, profile decoder |
| `dangerous_zone` | Bottom-right corner | Isolated, separate power domain, destructive operations | NVM controller (stubbed) |

---

## 3. Addressing Model

- **BANK_SELECT + 8-bit offset** addressing scheme
- 7 banks (0-5, 0xA)
- 92 total registers
- Single-register read/write via UART serial protocol
- Bank 0 is always accessible (global/system registers)
- BANK_SELECT (Bank 0, offset 0x04) selects the active bank for all non-Bank-0 accesses

---

## 4. Serial Protocol

All host communication uses a simple UART protocol:

| Command | Format | Response |
|---------|--------|----------|
| Write | `'W'` addr data[4 bytes] | `'A'` (ack) |
| Read | `'R'` addr | `'D'` data[4 bytes] |
| Status | `'S'` | `'S'` status[4 bytes] |
| Reset | `'X'` | `'A'` (ack) |

Single-register R/W only. No burst mode. No DMA.

---

## 5. Pad Ring Summary

38 total pads across 4 edges:

| Edge | Count | Function |
|------|-------|----------|
| Top | 13 | Host digital (UART, SPI), spare I/O, clock ref, reset, power |
| Left | 15 | GPIO[0:7], LED[0:4], power |
| Right | 7 | Analog I/O (DAC, ADC, comparator, ROSC mux), analog power |
| Bottom | 7 | Clock experiment (PLL ref), debug/GP pads, dangerous power |

- 28 functional pads + 10 power/ground pads
- 3 power domains: VDD/VSS (digital core), VDD_A/VSS_A (analog), VDD_E/VSS_E (dangerous)

---

## 6. Power Domains

| Domain | Rails | Supplies | Zone |
|--------|-------|----------|------|
| Digital core | VDD / VSS | 1.8V nominal | All digital logic, host, GPIO, clock |
| Analog | VDD_A / VSS_A | 1.8V nominal (isolated) | Mixed-signal cluster (DAC, ADC, comparator, analog routing) |
| Dangerous/Experimental | VDD_E / VSS_E | 1.8V nominal (isolated) | Dangerous zone only (NVM stub) |

Each domain has independent power pad pairs. Analog and dangerous domains can be powered down independently without affecting the digital core.

---

## 7. Features NOT Present (by design)

The following features are intentionally excluded or stubbed in v2.4:

| Feature | Status | Rationale |
|---------|--------|-----------|
| PLL lock detect | Stubbed | No reliable lock indicator in SKY130 ring PLL; frequency counter used instead |
| NVM / OTP | Stubbed | NVM controller present but no functional memory element; protocol exercisable |
| Debug clock mux | Not implemented | Clock observability via frequency counter and DBG/GP pads only |
| Spare pad router | Not implemented | Spare pads directly muxed, no programmable crossbar |
| Lock detect circuit | Not implemented | Replaced by software frequency-count verification |

The chip **must work without** these features. All experiment profiles and BIST chains operate correctly with external reference clock only.

---

## 8. Experiment Profiles

15 experiment profiles are defined, each configuring a specific combination of blocks for a targeted test or demonstration. Profiles are selected via `EXPERIMENT_ID` (Bank 0, offset 0x50) and activated through the sequencer.

Each profile specifies:
- Which blocks to enable
- Configuration register presets
- Pass/fail criteria
- Timeout value

See `v2_4_test_matrix.md` for the full profile-to-block mapping.

---

## 9. BIST Fabric

- 5-chain serial-pattern BIST architecture
- Each chain covers a group of related flip-flops
- Serial shift-in, apply, capture, shift-out cycle
- Pattern generator and checker in `digital_core`
- Chain selection via `BIST_CHAIN_SEL` (Bank 3)
- Independent of experiment profiles (can run standalone)

---

## 10. State Snapshots

Latched-on-demand state snapshots capture a consistent view of chip state:

- Triggered by setting `snap_capture` (GLOBAL_CONTROL[14], self-clearing)
- Four snapshot registers in Bank 0: `SNAP_BANK_CLK` (0x60), `SNAP_ROUTE_EXP` (0x64), `SNAP_SEQ_ERR` (0x68), `SNAP_FLAGS` (0x6C)
- Snapshots are frozen until the next capture trigger
- Used for coherent debug reads across multiple subsystems

---

## 11. Boot Behavior

On power-up or software reset:
1. All registers reset to safe defaults (see `v2_4_reset_defaults.md`)
2. `BOOT_STATUS` register (Bank 0, offset 0x78) captures the reset cause
3. All outputs driven to safe state (Hi-Z for spare pads, GPIO defaults, DAC code 0)
4. UART interface becomes responsive
5. No blocks are enabled until host explicitly sets `global_enable`

---

## 12. Document Cross-References

| Document | Contents |
|----------|----------|
| `v2_4_register_map.md` | Complete register map, all 7 banks, 92 registers |
| `v2_4_pad_ring.md` | Pad ring pinout, edge assignments, power domains |
| `v2_4_floorplan.md` | Zone placement, routing rules, isolation requirements |
| `v2_4_reset_defaults.md` | Safe-state truth table for every register and subsystem |
| `v2_4_test_matrix.md` | 15-block test matrix with pass criteria and measurement notes |
