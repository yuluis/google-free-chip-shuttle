# Universal Learning Chip (ULC)

Tile-based analog experimentation platform for Google Open MPW shuttle (Caravel/SKY130).
Active version: v3.0. FPGA digital twin at `~/projects/cx-fpga/`.

## Directory Layout

```
rtl/common/      -- Core modules: package, register bank, sequencer, tile controller,
                    BIST engine, clock mux, analog route matrix, experiment profiles
rtl/wrappers/    -- Per-block self-test wrappers
rtl/tiles/       -- Tile wrapper + per-tile DUT modules
rtl/interfaces/  -- UART core + host bridge
rtl/top/         -- ulc_top.sv (chip integration)
tb/              -- SystemVerilog testbenches
host/            -- Python UART driver + validation runner
docs/arch/       -- Architecture specs (v2_4_* frozen, v3_0_* active)
```

## Simulation

```bash
make sim_regbank     # Register bank unit test
make sim_sequencer   # Sequencer FSM unit test
make sim_top         # Full-chip integration test
make all             # All tests
```

Requires Icarus Verilog (`iverilog`, `vvp`) with `-g2012` for SystemVerilog.

## Architecture Docs

v3.0 specs in `docs/arch/`: overview, tile interface, register map, floorplan, routing model, tile designs (OTA/RingOsc/LDO), architecture YAML. v2.4 specs frozen alongside.

## Current Status (2026-03-24)

v3.0 architecture designed. v2.4 RTL complete (31 SV files, ~7,700 lines). Sims broken (Makefile). Next: fix sims, implement tile controller + tile wrappers + 3 DUTs, extend register bank/sequencer, Caravel integration, OpenLane synthesis.
