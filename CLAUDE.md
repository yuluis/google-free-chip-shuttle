# Universal Learning Chip (ULC) v2

Mixed-signal lab-on-chip for the Google Open MPW shuttle (Caravel/SKY130).
Self-testable characterization platform with 25 blocks across 5 zones.

## Architecture

```
Host (Python/UART) → UART Bridge → Register Bank (41 regs)
                                  → Test Sequencer (18-state FSM)
                                    → Experiment Profiles (15 presets)
                                    → BIST Pattern Engine (5 chains × 32 bits)
                                    → Clock Mux Tree (5 src × 4 dest)
                                    → Analog Route Matrix (DAC↔ADC↔Comp↔Ext)
                                    → Test Mux → 16 Block Wrappers
                                    → Log Buffer (32 entries)
```

## Zone Architecture

| Zone | Purpose | Blocks |
|------|---------|--------|
| A — Digital Backbone | Always-functional core | UART, SPI, I2C, register bank, sequencer, BIST engine, experiment profiles, mux, log buffer, SRAM, GPIO, LED, clock dividers |
| B — Mixed-Signal | Analog with digital observability | DAC (10-bit), ADC (12-bit), comparator, analog route matrix, ring osc, TRNG, PUF, ref ladder |
| C — Clock Experiment | Optional — chip works without it | PLL/DPLL, clock mux tree, lock detect |
| D — Dangerous | Isolated, explicitly armed | NVM/OTP, pulse controller |
| E — Routing/Margin | Physical layout only | Power, routing, analog isolation |

## Key Design Decisions

- **FSM-based sequencer** (no embedded CPU) — 18 states including experiment orchestration
- **Uniform test wrapper interface** — every block uses the same test_ctrl_t / test_status_t
- **Three test modes**: SAFE_AUTO, LAB_EXTENDED, DANGEROUS_ARMED
- **PLL is non-blocking** — chip works without PLL lock; clock mux auto-falls back to ext ref
- **BIST serial-pattern fabric** — compact mux control, reproducible test configs from host
- **Experiment profiles** — 15 predefined configurations (clock + route + DAC mode + block enables)
- **Analog loopback matrix** — DAC→ADC, DAC→Comp, ext→ADC internal routing
- **Safe defaults on reset** — routes disconnected, DAC disabled, PLL bypassed, BIST cleared
- **Error recovery** — sequencer auto-restores safe state after failure
- **Dangerous isolation** — NVM requires CTRL_ARM_DANGEROUS; BIST cannot arm dangerous ops

## Directory Layout

```
rtl/common/      — Package, register bank, sequencer, mux, log buffer, LED,
                   BIST pattern engine, clock mux tree, analog route matrix,
                   experiment profiles
rtl/wrappers/    — Per-block self-test wrappers (15 blocks)
rtl/interfaces/  — UART core + host bridge
rtl/top/         — ulc_top.sv (chip integration)
tb/              — SystemVerilog testbenches
host/            — Python validation runner + driver + register map
docs/            — Architecture docs (6 docs)
```

## Simulation

```bash
make sim_regbank     # Register bank unit test
make sim_sequencer   # Sequencer FSM unit test
make sim_top         # Full-chip integration test
make all             # All tests
```

Requires Icarus Verilog (`iverilog`, `vvp`) with `-g2012` for SystemVerilog.

## Register Map

41 registers across 7 groups:

| Range | Group |
|-------|-------|
| 0x00–0x4F | Base: chip ID, control, status, results, log |
| 0x50–0x5F | Experiment: profile ID, status, config |
| 0x60–0x6F | BIST: control, chain select, shift data, latch status |
| 0x70–0x7F | Clock Mux: mux control, status, freq count, freq select |
| 0x80–0x8F | Analog Route: control, status, ADC source, comp source |
| 0x90–0x9F | DAC: control, code, status, update count |
| 0xA0–0xAF | PLL: control, status, freq count, lock timeout |

## Block IDs

Zone A: REGBANK=0x00, SRAM=0x01, UART=0x02, SPI=0x03, I2C=0x04, GPIO=0x05, CLK_DIV=0x07
Zone B: RING_OSC=0x06, TRNG=0x08, PUF=0x09, COMPARATOR=0x0A, ADC=0x0B, DAC=0x0D, ANA_ROUTE=0x0E
Zone C: PLL=0x10, CLK_MUX=0x11
Zone D: NVM=0x0C
Infra: BIST_ENGINE=0x20

## Experiment Profiles

| ID | Name | Blocks | Risk |
|----|------|--------|------|
| 0x01 | DAC_ADC_LOOPBACK | DAC+ADC | Low |
| 0x02 | DAC_COMP_SWEEP | DAC+Comp | Low |
| 0x04 | PLL_FREQ_MEASURE | PLL | Medium |
| 0x05 | PLL_ADC_CLK_SWEEP | PLL+ADC+DAC | Medium |
| 0x0B | NVM_PROGRAM | NVM | **Dangerous** |

See `docs/experiment_profiles.md` for all 15.

## Gate Estimate

~52K gates total. Caravel capacity: ~820K gates. Utilization: 6.3%.

## Documentation

| File | Contents |
|------|----------|
| docs/mixed_signal_lab_architecture.md | Full architecture overview and risk assessment |
| docs/dac_adc_loopback.md | DAC modes, routes, loopback experiments |
| docs/pll_clock_experiments.md | PLL config, clock mux, frequency measurement |
| docs/bist_serial_pattern_fabric.md | BIST chains, commands, bit mapping, safety |
| docs/analog_route_matrix.md | Route table, contention rules, register map |
| docs/experiment_profiles.md | All 15 profiles with blocks, clocks, routes |

## Shuttle Target

Google Open MPW (Caravel/SKY130). User area: 2.92mm × 3.52mm, 38 GPIO pads.
Design fits with large margins on pins (28–34 needed) and gates (6.3% utilization).
