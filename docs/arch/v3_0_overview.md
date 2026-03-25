# ULC v3.0 Architecture Overview

**Status:** Draft
**Process:** SKY130 (SkyWater 130nm open-source PDK)
**Wrapper:** Caravel digital wrapper (efabless)
**Die area:** 2.92 x 3.52 mm
**Gate estimate:** ~70K gates (8.5% of 820K Caravel capacity)
**Version:** 3.0 (CHIP_REV = 0x00000300)
**Revision name:** Tile Platform

---

## 1. Design Philosophy

ULC v3.0 transforms the chip from a monolithic mixed-signal lab into a **standardized analog experimentation platform**. The proven digital backbone from v2.4 becomes a bulletproof test harness. The analog side is restructured as **N identical experiment tiles**, each conforming to a standard interface contract.

The goal: anyone can design an analog circuit, drop it into a tile slot, and immediately test it using the existing digital infrastructure — sequencer, BIST, logging, host control — without touching any of the harness code.

**Key shift:**
- v2.4: "One large mixed-signal cluster" with fixed analog blocks
- v3.0: "Shared test infrastructure + multiple analog experiment tiles"

**What stays the same:**
- UART + SPI host interface
- BANK_SELECT + 8-bit offset register addressing
- Single-register R/W (no burst)
- Sequencer FSM (extended for tile orchestration)
- BIST engine, log buffer, SRAM, state snapshots
- Pad ring (38 pads, same allocation)
- 3 power domains (VDD/VSS 1.8V digital, VDD_A/VSS_A 3.3V analog, VDD_E/VSS_E)
- Per-tile power gating (register-controlled PMOS header switches)
- Safe defaults on reset
- Clock experiment zone (PLL, ring osc, clock mux)
- Dangerous zone (NVM stub)

---

## 2. Top-Level Block Diagram

```
    UART_RX ──┐                                    ┌── UART_TX
    SPI_*  ──┐│                                    │
              ▼▼                                    │
    ┌─────────────────────────────────────────────────────────────┐
    │                     HOST PERIMETER                          │
    │   UART Host Bridge ◄──► SPI Slave ◄──► Spare Pad Mux      │
    └───────────────────┬─────────────────────────────────────────┘
                        │ register bus (addr/data/wr/rd)
                        ▼
    ┌──────────────────────────────────────────────────────────────┐
    │                    DIGITAL TEST BACKBONE                     │
    │                                                              │
    │  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
    │  │ Register     │  │ Test         │  │ Tile Controller  │   │
    │  │ Bank         │  │ Sequencer    │  │                  │   │
    │  │ (8 banks,    │  │ (20-state    │  │ - tile_select    │   │
    │  │  ~108 regs)  │──│  FSM with    │──│ - enable/isolate │   │
    │  │              │  │  tile orch.) │  │ - per-tile reset │   │
    │  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘   │
    │         │                 │                    │              │
    │  ┌──────┴────┐  ┌────────┴────┐  ┌────────────┴──────────┐  │
    │  │ BIST      │  │ Experiment  │  │ State Snapshot        │  │
    │  │ Engine    │  │ Profiles    │  │ (+ tile state)        │  │
    │  │ (6 chain) │  │ (extended)  │  │                       │  │
    │  └───────────┘  └─────────────┘  └───────────────────────┘  │
    │                                                              │
    │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
    │  │ Log      │  │ SRAM     │  │ Freq     │  │ Clock      │  │
    │  │ Buffer   │  │          │  │ Counters │  │ Dividers   │  │
    │  └──────────┘  └──────────┘  └──────────┘  └────────────┘  │
    └──────────────────────────┬───────────────────────────────────┘
                               │
              ┌────────────────┼───────────────────┐
              ▼                ▼                    ▼
    ┌──────────────┐  ┌──────────────────┐  ┌──────────────┐
    │ SHARED ANALOG│  │  EXPANDED ANALOG  │  │ TILE ARRAY   │
    │ RESOURCES    │  │  ROUTE MATRIX     │  │              │
    │              │  │                   │  │  ┌────┐┌────┐│
    │ 1x DAC 10b  │──│ FROM: DAC, ext,   │──│  │ T0 ││ T1 ││
    │ 1x ADC 12b  │  │   ref, tile_out   │  │  └────┘└────┘│
    │ 1x Comparator│  │ TO: tile_in, ADC, │  │  ┌────┐┌────┐│
    │ Ref ladder   │  │   comp, spare_io  │  │  │ T2 ││ T3 ││
    │              │  │                   │  │  └────┘└────┘│
    └──────────────┘  └──────────────────┘  │  ┌────┐┌────┐│
                                             │  │ T4 ││ T5 ││
                                             │  └────┘└────┘│
                                             └──────────────┘
```

---

## 3. Architecture Components

### 3.1 Digital Test Backbone (Center — Enhanced from v2.4)

All v2.4 digital infrastructure retained. Enhancements:

| Component | Change from v2.4 |
|-----------|-----------------|
| Register Bank | +1 bank (Bank 6: Tile Control), +16 registers |
| Sequencer | +2 states (SEQ_SELECT_TILE, SEQ_CONFIGURE_TILE), tile-aware orchestration |
| Tile Controller | **New** — tile addressing, enable/isolation, per-tile reset |
| BIST Engine | +1 chain (Chain 5: tile digital control) |
| Experiment Profiles | Extended for tile-based experiments |
| State Snapshot | Extended to capture tile state in SNAP_FLAGS |
| Log Buffer | Log entries now include tile_id field |

### 3.2 Shared Analog Resources (Global — NOT duplicated per tile)

These expensive blocks exist once and are shared via the expanded route matrix:

| Resource | Specification | Supply | Notes |
|----------|--------------|--------|-------|
| DAC | 10-bit, 5 modes | **3.3V (VDD_A)** | 3.3V devices, full-swing output 0-3.3V |
| ADC | 12-bit SAR | **3.3V (VDD_A)** | 3.3V devices, 3.3V reference, 4x dynamic range vs 1.8V |
| Comparator | 1x with hysteresis | **3.3V (VDD_A)** | 3.3V input range |
| Reference Ladder | Bandgap + resistor divider | **3.3V (VDD_A)** | Higher headroom for bandgap accuracy |
| Clock Mux Tree | 5 sources x 4+1 destinations | 1.8V (VDD) | +1 destination: tile_clk |

**3.3V analog domain:** All shared analog resources and tiles operate at 3.3V (Caravel VDDA1/VDDA2). This provides 1.83x the voltage headroom vs the 1.8V digital domain, giving better dynamic range for the ADC (4x improvement in LSB-referenced SNR), wider output swing for the DAC, and more operating margin for tile DUTs (especially the OTA and LDO). Level shifters at the digital/analog boundary handle the 1.8V ↔ 3.3V translation.

The key insight: these are the most area-expensive and hardest-to-design analog blocks. Duplicating them per tile would waste die area and add risk. Instead, any tile can access any shared resource through the route matrix.

### 3.3 Analog Experiment Tiles (NEW — Core Innovation)

6 tiles in v1 (see Section 7 for reasoning). Each tile:

- Contains one analog DUT (Design Under Test)
- Conforms to the Standard Tile Interface (see `v3_0_tile_interface.md`)
- Has its own **register-controlled power switch** (PMOS header between VDDA and VDD_TILE)
- Is independently powerable, enableable, resettable, and isolatable
- Connects to shared resources only through the route matrix
- Cannot corrupt other tiles or the digital backbone (power-off = full isolation)
- Is software-identical from the host's perspective

### 3.4 Expanded Analog Route Matrix

The v2.4 route matrix supported: DAC, ext_analog_in, ref_ladder, ring_osc_mon → ADC, comp+, comp-.

v3.0 expands this to support tile I/O:

**Sources (FROM):**
- DAC output
- External analog input (ANA_IN pad)
- Reference ladder
- Ring oscillator monitor
- Tile[N] OUT_MAIN (any tile's primary output)
- Tile[N] TAP1 (any tile's internal tap — optional)

**Destinations (TO):**
- ADC input
- Comparator positive input
- Comparator negative input
- Tile[N] STIM_A (primary stimulus)
- Tile[N] STIM_B (secondary stimulus — optional)
- Spare IO pads (via digital conversion)
- DAC_OUT pad (external output)

**Constraints:**
- Only one source per destination (no bus contention)
- Explicit mux select (no implicit connections)
- Status flag if illegal routing detected
- All routes disconnected at reset
- Tile-to-tile routing supported (e.g., tile 0 output → tile 3 input)

---

## 4. Zone Architecture (Updated)

| Zone | Location | Purpose | v2.4 | v3.0 |
|------|----------|---------|------|------|
| host_perimeter | Top edge | Host interfaces | Same | Same |
| gpio_perimeter | Left edge | GPIO + LED | Same | Same |
| digital_core | Center | Digital backbone | Same | +Tile controller, expanded regs |
| tile_array | Right side | Experiment tiles | Was: mixed_signal | **NEW: 6 tile slots** |
| shared_analog | Right, near tiles | DAC/ADC/Comp/Ref | Part of mixed_signal | **Extracted, shared** |
| clock_experiment | Bottom-left | Clock synthesis | Same | Same |
| routing_margin | Bottom center | Profile ROM + routing | Same | Same |
| dangerous_zone | Bottom-right | NVM stub | Same | Same |

---

## 5. Addressing and Register Model

### Banks (8 total — was 7)

| Bank | Name | Registers | New in v3.0? |
|------|------|-----------|-------------|
| 0 | Global | 31 | Modified: CHIP_REV updated, GLOBAL_CONTROL extended |
| 1 | Clock | 12 | Unchanged |
| 2 | Analog | 18 | Modified: route matrix extended for tiles |
| 3 | BIST | 6 | Modified: +1 chain for tiles |
| 4 | Security | 12 | Unchanged |
| 5 | Log | 7 | Modified: log entries include tile_id |
| **6** | **Tile** | **48** | **NEW: 8 regs x 6 tiles** |
| 0xA | Dangerous | 6 | Unchanged |

### Tile Register Window (Bank 6)

Each tile gets an 8-register window. All tiles are software-identical.

| Offset | Name | Per-Tile |
|--------|------|----------|
| +0x00 | TILE_CONTROL | enable, reset, start, mode[2:0] |
| +0x04 | TILE_STATUS | done, pass, error, busy, isolated |
| +0x08 | TILE_MODE | DUT-specific mode configuration |
| +0x0C | TILE_ROUTE_IN | Input routing selection (STIM_A, STIM_B sources) |
| +0x10 | TILE_ROUTE_OUT | Output routing selection (OUT_MAIN, TAP1 destinations) |
| +0x14 | TILE_PARAM | DUT-specific parameter (bias, trim, etc.) |
| +0x18 | TILE_RESULT | DUT-specific measurement result |
| +0x1C | TILE_DEBUG | DUT-specific debug / internal state |

Full register map: `v3_0_register_map.md`

---

## 6. Sequencer Upgrade

The v2.4 sequencer (18 states) is extended with 2 new states for tile orchestration:

```
SEQ_IDLE
  ↓ (cmd received)
SEQ_LOAD_EXPERIMENT
  ↓
SEQ_CONFIGURE_CLOCKS
  ↓
SEQ_APPLY_ROUTE
  ↓
SEQ_SELECT_TILE          ← NEW: select and enable target tile
  ↓
SEQ_CONFIGURE_TILE       ← NEW: write tile mode/param/route registers
  ↓
SEQ_ARM_CHECK
  ↓
SEQ_PREPARE_BLOCK → SEQ_START_BLOCK → SEQ_WAIT_FOR_DONE
  ↓
SEQ_COLLECT_RESULTS
  ↓
SEQ_WRITE_STATUS
  ↓
SEQ_APPEND_LOG           (log entry now includes tile_id)
  ↓
SEQ_COMPLETE

On error: SEQ_RESTORE_SAFE (disconnects routes, disables all tiles, resets clocks)
```

New sequencer capabilities:
- Run test on tile N (selected via BLOCK_SELECT with tile block IDs)
- Configure routing for tile stimulus/measurement
- Trigger DAC stimulus, capture ADC results for tile DUT
- Log results with tile ID for traceability
- Tile sweep: sequentially test all tiles with same configuration

New test commands:
- `CMD_SELECT_TILE` (0x20) — select tile for subsequent operations
- `CMD_TILE_SWEEP` (0x21) — run current experiment on all enabled tiles sequentially

---

## 7. Tile Count Recommendation: 6 Tiles

### Gate Budget Analysis

| Component | v2.4 Gates | v3.0 Gates | Delta |
|-----------|-----------|-----------|-------|
| Digital backbone | ~35K | ~38K | +3K (tile controller, extended regs) |
| Shared analog (DAC/ADC/Comp) | ~8K | ~8K | 0 (unchanged) |
| Route matrix | ~2K | ~4K | +2K (expanded for tiles) |
| Tile digital control (per tile) | 0 | ~1.5K x 6 = 9K | +9K |
| Tile analog DUT (per tile) | 0 | ~2K avg x 6 = 12K | +12K |
| Clock experiment | ~5K | ~5K | 0 |
| Dangerous zone | ~2K | ~2K | 0 |
| **Total** | **~52K** | **~70K** | **+18K** |

**Capacity:** 820K gates (Caravel). At 70K we use 8.5% — enormous headroom.

### Why 6 and not 8?

- **Area, not gates, is the constraint.** Tiles need analog routing space. 6 tiles fit comfortably in the right-side mixed_signal zone without crowding the shared analog resources.
- **Routing complexity scales quadratically.** 6 tiles × 2 inputs × 2 outputs = 24 route endpoints. 8 tiles = 32 endpoints. The route matrix mux tree grows fast.
- **6 covers all tile classes.** We can populate: 2x Class A (analog core), 2x Class B (timing), 1x Class C (mixed-signal), 1x Class D (power). Covers all learning objectives.
- **Expansion path clear.** v3.1 can go to 8 tiles by filling 2 reserved slots. The register map (Bank 6) has room for 8 tiles (offsets 0x00-0x3F).

### Reserved Slots

Bank 6 is sized for 8 tiles (64 register offsets). Tiles 6-7 are reserved:
- Offsets 0x30-0x37: Tile 6 (reserved)
- Offsets 0x38-0x3F: Tile 7 (reserved)

If populated later, no register map or infrastructure changes needed.

---

## 8. Tile Classification

| Class | Type | Description | Tile Slots (v1) | Learning Objective |
|-------|------|-------------|-----------------|-------------------|
| A | Analog Core | Op-amp, current mirror, filter, amplifier | 2 tiles | Analog design fundamentals |
| B | Timing | Oscillator, delay line, divider | 2 tiles | Clock generation, jitter |
| C | Mixed-Signal | ADC stage, DAC cell, comparator variant | 1 tile | Data conversion |
| D | Power | LDO, bandgap, charge pump | 1 tile (max) | Power management |

**Class D restriction:** LDO/power tiles can draw significant current. Maximum 1 Class D tile per chip. LDO tile must include current-limiting and thermal shutdown to prevent damage to shared VDD_A.

---

## 8.1 Per-Tile Power Gating

Each tile has an individually controllable power switch between the 3.3V VDDA rail and the tile's local VDD_TILE supply.

### Power Switch Implementation

| Component | Specification | Notes |
|-----------|--------------|-------|
| PMOS header | `sky130_fd_pr__pfet_03v3` W=50u/L=0.5u | ~2-3 ohm Rds_on, handles 10mA per tile |
| Gate drive | 1.8V → 3.3V level shifter | From TILE_POWER_CONTROL register bit |
| Soft-start | RC gate ramp (~10us rise time) | Limits inrush current, prevents IR drop spikes on VDDA |
| Power-good | Threshold detector on VDD_TILE | Reports stable in TILE_STATUS[13] (power_good) |
| Decoupling | MIM cap ~10pF per tile | Local bypass on VDD_TILE |

### Power Control Register (Bank 6, offset 0xF0)

`TILE_POWER_CONTROL` — global register for all tile power switches:

| Bit | Name | Type | Description |
|-----|------|------|-------------|
| [5:0] | tile_power_en | RW | Per-tile power enable (bit N = tile N) |
| [13:8] | tile_power_good | R | Per-tile power-good flags (VDD_TILE stable) |
| [16] | global_power_en | RW | Master power enable (AND'd with per-tile bits) |
| [17] | staggered_start | RW | 1 = power-on tiles sequentially with 100us spacing |
| [31:18] | -- | -- | Reserved |

### Power Sequencing (Enforced by Tile Controller)

**Power ON:**
1. Set `TILE_POWER_CONTROL[N]` = 1 (close PMOS switch)
2. Wait for `tile_power_good[N]` = 1 (VDD_TILE stable, ~50us)
3. Then `TILE_CONTROL.enable` is allowed

**Power OFF:**
1. Clear `TILE_CONTROL.enable` = 0 (disable tile logic)
2. Wait for isolation switches to open
3. Clear `TILE_POWER_CONTROL[N]` = 0 (open PMOS switch)

**Safety:** If `TILE_CONTROL.enable` is written to 1 while power is not good, the tile controller blocks it and sets `ERR_TILE_NO_POWER` (error code 0x24). The sequencer's `SEQ_SELECT_TILE` state automatically checks power-good before proceeding.

### Staggered Power-On

When `staggered_start` = 1, the tile controller powers on tiles sequentially (T0 first, then T1 after 100us, etc.) to limit peak inrush current on the VDDA rail. Total staggered start time for 6 tiles: ~600us.

---

## 9. Concrete Tile Assignments (v1)

| Slot | Class | DUT | Description |
|------|-------|-----|-------------|
| T0 | A | 5-Transistor OTA | Classic operational transconductance amplifier |
| T1 | A | Current Mirror Bank | NMOS/PMOS mirrors with ratio programming |
| T2 | B | Current-Starved Ring Oscillator | Tunable VCO with frequency output |
| T3 | B | Programmable Delay Line | Variable delay with tap outputs |
| T4 | C | Flash ADC (3-bit) | Miniature parallel ADC for comparison study |
| T5 | D | LDO-Lite | Simple 2-transistor LDO with load regulation test |

See `v3_0_tile_designs.md` for detailed designs of T0, T2, and T5.

---

## 10. Robustness Guarantees

| Guarantee | Implementation |
|-----------|---------------|
| Tile failure does NOT crash chip | Each tile has independent power switch + enable + isolation. Tile controller monitors for timeout/error, auto-isolates, and can power-off the tile. |
| All mux paths default safe | Route matrix resets to DISCONNECTED on all paths. No implicit connections. |
| All tiles unpowered at reset | TILE_POWER_CONTROL resets to 0 (all switches open). TILE_CONTROL[0] also resets to 0. |
| No floating control lines | Tile interface includes pull-down defaults on all control signals. Unused tile slots tied to safe constants. |
| Deterministic reset state | Per-tile reset via TILE_CONTROL[1] or global reset. Both produce identical initial state. |
| Snapshot works across tiles | Extended SNAP_FLAGS includes per-tile enable/error bits. |
| Logging identifies tile | Log entry block_id field encodes tile ID (0x30-0x35 for tiles 0-5). |
| Tile-to-tile isolation | Output isolation switches (analog transmission gates) controlled by tile controller. Disabled tile outputs are Hi-Z to route matrix. |

---

## 11. Block IDs (Updated)

### Existing (unchanged from v2.4)

| ID | Block | Zone |
|----|-------|------|
| 0x00-0x0E | All v2.4 blocks | Same |
| 0x10-0x11 | PLL, CLK_MUX | Same |
| 0x20 | BIST_ENGINE | Same |

### New (v3.0)

| ID | Block | Zone |
|----|-------|------|
| 0x30 | TILE_0 (OTA) | tile_array |
| 0x31 | TILE_1 (Current Mirror) | tile_array |
| 0x32 | TILE_2 (Ring Osc) | tile_array |
| 0x33 | TILE_3 (Delay Line) | tile_array |
| 0x34 | TILE_4 (Flash ADC) | tile_array |
| 0x35 | TILE_5 (LDO-Lite) | tile_array |
| 0x36-0x37 | Reserved (Tile 6-7) | tile_array |
| 0x40 | TILE_CONTROLLER | digital_core |

---

## 12. Compatibility with v2.4

| Feature | Compatibility |
|---------|--------------|
| UART protocol | Identical — 'W'/'R'/'S'/'X' commands unchanged |
| Bank 0 registers | All offsets preserved, CHIP_REV value updated |
| Banks 1-5, 0xA | Fully backward-compatible (analog bank extended, not reorganized) |
| Sequencer commands | All v2.4 commands still valid; 2 new commands added |
| Host Python driver | Minor update: add Bank 6 constants and tile block IDs |
| FPGA digital twin | Tile controller is fully digital — FPGA-verifiable |
| Experiment profiles | v2.4 profiles 0x01-0x0E still work; tile profiles added as 0x10+ |

---

## 13. What Does NOT Change

These subsystems are **frozen from v2.4** — no modifications:

- UART core and host bridge
- SPI slave interface
- GPIO bank (8-bit)
- LED driver bank (5-channel)
- NVM controller stub
- Dangerous zone isolation
- Reset controller (extended for tiles but same architecture)
- SRAM block
- TRNG / PUF (digital entropy primitives)
- Pad ring assignment (38 pads, same allocation)
- Power domains (3 domains, same pads)

---

## 14. Optional Blocks (Chip Works Without Them)

The following can be removed without breaking the chip:

| Block | Effect of Removal |
|-------|------------------|
| PLL | Clock stays on ext_ref. All tile tests work. |
| NVM | Dangerous zone inert. No other impact. |
| Debug mux | Debug pads stay in GPIO mode. |
| Spare router | Spare pads stay Hi-Z. |
| Any individual tile | Tile slot reports NOT_PRESENT in status. Sequencer skips it. |

---

## 15. Risks and Mitigations

| # | Risk | Impact | Likelihood | Mitigation |
|---|------|--------|-----------|------------|
| 1 | Route matrix too large for analog routing space | Tiles can't connect to shared resources | Medium | Size matrix for 6 tiles max. Use 2-level mux (tile group → global) to reduce switch count. |
| 2 | Tile analog DUT interferes with shared ADC/DAC | Corrupted measurements | Medium | Isolation switches (transmission gates) on every tile output. Route matrix includes isolation verification. |
| 3 | LDO tile draws excess current, damages VDDA | Power domain failure | Low | Current limiter in LDO tile. Per-tile power switch can cut power entirely. Max 1 Class D tile. |
| 4 | Tile-to-tile crosstalk through substrate | Noise on sensitive measurements | Medium | Guard rings between tiles (minimum 5um). Timing tiles placed away from analog core tiles. |
| 5 | 8-bit register offset space too small | Can't address all tile registers | None | 8 regs x 8 tiles = 64 offsets. Bank 6 fits in 0x00-0x3F. No overflow. |
| 6 | Sequencer tile sweep takes too long | Experiment timeout | Low | Tile sweep uses independent timeout per tile. Failed tiles are skipped with error log. |
| 7 | Contributed IP (future tiles) violates interface contract | Crash or contention | Medium | Tile interface is enforced by the tile controller wrapper. DUT cannot bypass isolation. Linting rules for tile submissions. |
| 8 | Analog routing parasitics degrade DAC/ADC performance | Reduced measurement accuracy | Medium | Keep shared analog resources close to tile cluster. Short routing paths. Characterize parasitics per route in experiment profiles. |
| 9 | 1.8V/3.3V level shifter delay adds latency to tile control | Slower tile response | Low | Level shifters add ~1-2ns. Irrelevant for analog settling times (microseconds). Only affects digital control path, not analog signal path. |
| 10 | PMOS power switch Rds_on causes IR drop under load | Reduced VDD_TILE voltage | Low | W=50u/L=0.5u gives ~2-3 ohm. At 5mA tile current: 10-15mV drop (0.5% of 3.3V). Acceptable. LDO tile may need larger switch (W=100u). |
| 11 | Inrush current during tile power-on causes VDDA sag | Transient affecting other active tiles | Medium | Soft-start RC ramp on gate limits di/dt. Staggered power-on mode spaces tiles by 100us. Per-tile decoupling caps absorb transients. |

---

## 16. Document Cross-References

| Document | Contents |
|----------|----------|
| `v3_0_overview.md` | This document — architecture overview |
| `v3_0_tile_interface.md` | Standard tile interface specification |
| `v3_0_register_map.md` | Complete register map including Bank 6 (Tile) |
| `v3_0_floorplan.md` | Updated floorplan with tile array placement |
| `v3_0_routing.md` | Expanded analog route matrix model |
| `v3_0_tile_designs.md` | 3 concrete tile designs (OTA, Ring Osc, LDO) |
| `v3_0_architecture.yaml` | Machine-readable architecture definition |
| `v2_4_pad_ring.md` | Pad ring (unchanged from v2.4) |
| `v2_4_reset_defaults.md` | Reset defaults (extended for tiles) |
