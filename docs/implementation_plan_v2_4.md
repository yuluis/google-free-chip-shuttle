# Implementation Plan — v2.4

## Architecture Reference
- Frozen at v2.4 (CHIP_REV 0x00000005)
- Source of truth: `docs/arch/v2_4_*.md`
- Repo: github.com/yuluis/google-free-chip-shuttle

## Phase Checklist

### Phase 1 — Documentation Freeze + Scaffolding
- [ ] docs/arch/v2_4_overview.md
- [ ] docs/arch/v2_4_register_map.md
- [ ] docs/arch/v2_4_pad_ring.md
- [ ] docs/arch/v2_4_floorplan.md
- [ ] docs/arch/v2_4_reset_defaults.md
- [ ] docs/arch/v2_4_test_matrix.md
- [ ] docs/implementation_plan_v2_4.md (this file)

### Phase 2 — Register Map + UART Control Plane
- [ ] rtl/common/register_bank.sv (7-bank, 92 regs, BANK_SELECT)
- [ ] rtl/interfaces/uart_host_bridge.sv (8-bit addr, R/W/S/X protocol)
- [ ] rtl/common/reset_controller.sv (global + software + local resets)
- [ ] rtl/common/state_snapshot.sv (latched-on-demand, BOOT_STATUS)
- [ ] tb/tb_register_bank.sv
- [ ] tb/tb_uart_regmap.sv (UART → bank select → read/write full loop)

### Phase 3 — Digital Backbone
- [ ] rtl/common/test_sequencer.sv (rewrite to v2.4 spec)
- [ ] rtl/common/bist_pattern_engine.sv (update to bank 3 interface)
- [ ] rtl/common/ctrl_mux_core.sv (simple register-addressed mux)
- [ ] rtl/common/block_select_mux.sv (15:1)
- [ ] rtl/common/log_buffer.sv (32-entry, bank 5 readback)
- [ ] rtl/common/sram_bist.sv (March pattern, error capture)
- [ ] rtl/common/freq_counter.sv (selectable source measurement)
- [ ] rtl/common/clock_divider.sv (/2, /4, /8, /16)
- [ ] tb/tb_sequencer.sv
- [ ] tb/tb_bist_engine.sv
- [ ] tb/tb_log_buffer.sv

### Phase 4 — FPGA Validation Harness (PolarFire)
- [ ] rtl/top/fpga_top.sv
- [ ] host/run_chip_validation.py (updated for BANK_SELECT protocol)
- [ ] host/ulc_driver.py (register R/W + bank select helper)
- [ ] docs/fpga_validation.md

### Phase 5 — Mixed-Signal Control Stubs
- [ ] rtl/stubs/dac_stub.sv
- [ ] rtl/stubs/adc_stub.sv
- [ ] rtl/stubs/comparator_stub.sv
- [ ] rtl/stubs/analog_route_stub.sv
- [ ] rtl/stubs/pll_stub.sv
- [ ] rtl/stubs/ring_osc_stub.sv
- [ ] rtl/stubs/trng_stub.sv
- [ ] rtl/stubs/puf_stub.sv
- [ ] rtl/stubs/dangerous_stub.sv
- [ ] rtl/common/debug_clock_mux.sv
- [ ] rtl/common/spare_pad_router.sv
- [ ] rtl/common/rosc_probe_mux.sv

### Phase 6 — Integration + Review
- [ ] rtl/top/ulc_top.sv (full integration)
- [ ] tb/tb_top_smoke.sv
- [ ] Updated YAML architecture if any deviations

## Coding Rules
1. Preserve v2.4 names
2. Digital Caravel wrapper only
3. No I2C
4. No PLL_OUT pad
5. No 16-bit UART addressing
6. No burst protocol
7. Optional blocks must be bypassable
8. Small, reviewable commits
