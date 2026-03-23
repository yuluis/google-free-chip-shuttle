# Universal Learning Chip (ULC)

Low-risk automatic test architecture for a multi-block shuttle/learning chip.

## Architecture

Single shared control plane: **Host (Python/UART) -> UART Bridge -> Register Bank -> Test Sequencer (FSM) -> Test Mux -> Per-Block Wrappers -> Results/Log Buffer**

## Key Design Decisions

- **FSM-based sequencer** (no embedded CPU) — deterministic, small, easy to simulate
- **Uniform test wrapper interface** — every block uses the same control/status signals
- **Three test modes**: SAFE_AUTO (default), LAB_EXTENDED, DANGEROUS_ARMED
- **Dangerous blocks (NVM/OTP)** require explicit arming — cannot run in normal flow
- **UART host bridge** with simple packet protocol (Write='W'+addr+4B, Read='R'+addr->4B)
- **Circular log buffer** (32 entries) for postmortem analysis

## Directory Layout

```
rtl/common/      — Package, register bank, sequencer, mux, log buffer, LED status
rtl/wrappers/    — Per-block self-test wrappers (13 blocks)
rtl/interfaces/  — UART core + host bridge
rtl/top/         — ulc_top.sv (chip integration)
tb/              — SystemVerilog testbenches
host/            — Python validation runner + driver + register map
docs/            — Architecture docs, register map, block test matrix
```

## Simulation

```bash
make sim_regbank     # Register bank unit test
make sim_sequencer   # Sequencer FSM unit test
make sim_top         # Full-chip integration test
make all             # All tests
```

Requires Icarus Verilog (`iverilog`, `vvp`) with `-g2012` for SystemVerilog.

## Host Validation

```bash
cd host
pip install -r requirements.txt
python run_chip_validation.py --port /dev/ttyUSB0
python run_chip_validation.py --port /dev/ttyUSB0 --json results.json --csv results.csv
```

## Register Map

See `docs/test_register_map.md`. Key addresses: CHIP_ID=0x00, GLOBAL_CONTROL=0x08, BLOCK_SELECT=0x10, COMMAND=0x14, RESULT0-3=0x1C-0x28, ERROR_CODE=0x2C.

## Block IDs

REGBANK=0, SRAM=1, UART=2, SPI=3, I2C=4, GPIO=5, RING_OSC=6, CLK_DIV=7, TRNG=8, PUF=9, COMPARATOR=10, ADC=11, NVM=12
