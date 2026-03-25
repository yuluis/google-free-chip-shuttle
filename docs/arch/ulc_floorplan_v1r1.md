# ULC Floorplan Specification — v1 Revision 1

**Status:** Engineering Draft
**Process:** SkyWater SKY130 (open-source PDK)
**Wrapper:** Caravel digital wrapper (efabless Google Open MPW)
**Die area:** 2.92 x 3.52 mm (Caravel user area: ~10 mm²)
**Date:** 2026-03-25
**Supersedes:** Floorplan sections of `ulc_spine_tile_spec_v1.md`

---

## Orientation Convention

All references use standard IC die-top orientation:

- **NORTH** = top of die
- **SOUTH** = bottom of die
- **WEST** = left side
- **EAST** = right side

This convention is absolute and applies to every diagram, signal name, and directional reference in this document.

---

## 1. Refined Floorplan Description

### 1.1 Global Structure

The chip is a **tall vertical rectangle** divided into three vertical columns plus a south extension:

```
+============================================+
|          NORTH: UART + 3.3V POWER          |
|============================================|
|          |                    |             |
|  WEST    |                    |   EAST      |
|  COLUMN  |   CENTER COLUMN   |   COLUMN    |
|          |   (DIGITAL SPINE) |             |
|  4 tiles |                    |   4 tiles   |
|  stacked |   Contiguous      |   stacked   |
|  (5V)    |   N-to-S          |   (3.3V)    |
|          |                    |             |
|============================================|
|   SOUTH: USB INTERFACE + FLEXIBLE TILES    |
+============================================+
```

### 1.2 Column Definitions

**West column (left):**
- Contains exactly **4 tile slots**, stacked vertically, uniform size
- Tiles are primarily **5V-capable**
- Each tile receives VDD_5V0 from the west power trunk
- Each tile also receives VDD_3V3 for its digital wrapper
- Tile numbering: W0 (northernmost) through W3 (southernmost)

**Center column (digital spine):**
- Continuous vertical strip from north edge to south region boundary
- Single uninterrupted block — no tiles break the spine
- Contains all digital control infrastructure (Section 2)
- Operates exclusively on VDD_3V3
- Width budget: ~300um (approximately 10% of die width)

**East column (right):**
- Contains exactly **4 tile slots**, stacked vertically, uniform size
- Tiles are primarily **3.3V**
- Each tile receives VDD_3V3 from the east power trunk
- Same vertical alignment and tile count as west column
- Tile numbering: E0 (northernmost) through E3 (southernmost)

**South region (bottom extension):**
- Occupies the full die width below the three-column region
- Contains:
  - USB interface block (connects into spine)
  - Optional flexible tile slots (1-2 tiles)
- Flexible tiles may be 3.3V, 5V, or mixed-voltage
- This is the **only** region with flexible voltage assignment

### 1.3 Dimensional Budget

Die dimensions: 2920um (W) x 3520um (H).

| Region | Width | Height | Area |
|--------|-------|--------|------|
| West column | ~650um | ~2700um | ~1.76 mm² |
| Center spine | ~300um | ~2700um | ~0.81 mm² |
| East column | ~650um | ~2700um | ~1.76 mm² |
| Spine-tile channels (x2) | ~80um each | ~2700um | ~0.43 mm² |
| North pad region | ~2920um | ~250um | ~0.73 mm² |
| South region | ~2920um | ~500um | ~1.46 mm² |
| Pad ring / margins | — | — | ~3.05 mm² |
| **Total** | | | **~10 mm²** |

Each west/east tile slot: ~650um wide x ~650um tall = ~0.42 mm²
(4 tiles x 650um = 2600um, plus ~100um for inter-tile guard rings = ~2700um)

### 1.4 Authoritative Floorplan Diagram

```
                              2920 um
    ←──────────────────────────────────────────────→

    ┌──────────────────────────────────────────────┐ ─┐
    │  N0  N1  N2  N3  N4  N5  N6  N7  N8  N9 ... │  │ ~250um
    │ VDD VSS  TX  RX CLK RST SCK MOSI MISO  CS   │  │ NORTH
    │ 3V3      ←──UART──→            ←──SPI(v2)──→ │  │ PAD RING
    ├──────────────────────────────────────────────┤ ─┘
    │          │    │                │    │         │
    │  5V PWR  │ ch │  3.3V SPINE   │ ch │ 3.3V   │
    │  TRUNK   │ an │  PWR TRUNK    │ an │ PWR     │
    │  (M5)    │ ne │  (M5)         │ ne │ TRUNK   │
    │  ║       │ l  │  ║            │ l  │ (M5)    │
    │  ║       │    │  ║            │    │    ║    │
    │  ║  ┌────┤    ├──╨────────────┤    ├────┐║    │ ─┐
    │  ╠══╡ W0 │    │               │    │ E0 ╞╣    │  │ ~650um
    │  ║  │ 5V │←──→│               │←──→│3.3V║    │  │ tile slot
    │  ║  └────┤    │               │    ├────┘║    │ ─┘
    │  ║  ┌────┤    │  ┌──────────┐ │    ├────┐║    │ ─┐
    │  ╠══╡ W1 │    │  │UART Core │ │    │ E1 ╞╣    │  │
    │  ║  │ 5V │←──→│  │Cmd Decode│ │←──→│3.3V║    │  │       ~2700um
    │  ║  └────┤    │  │Reg Bank  │ │    ├────┘║    │ ─┘       MAIN
    │  ║  ┌────┤    │  │Tile I/F  │ │    ├────┐║    │ ─┐       REGION
    │  ╠══╡ W2 │    │  │Clk/Rst   │ │    │ E2 ╞╣    │  │
    │  ║  │ 5V │←──→│  │Pwr Ctrl  │ │←──→│3.3V║    │  │
    │  ║  └────┤    │  │Status Agg│ │    ├────┘║    │ ─┘
    │  ║  ┌────┤    │  └──────────┘ │    ├────┐║    │ ─┐
    │  ╠══╡ W3 │    │               │    │ E3 ╞╣    │  │
    │  ║  │ 5V │←──→│               │←──→│3.3V║    │  │
    │  ║  └────┤    │               │    ├────┘║    │ ─┘
    │  ║       │    │               │    │    ║    │
    ├──╨───────┴────┴───────────────┴────┴────╨────┤
    │                                              │ ─┐
    │             SOUTH REGION                     │  │ ~500um
    │                                              │  │
    │   ┌─────────────┐   ┌──────┐   ┌──────┐     │  │
    │   │ USB I/F     │   │ SF0  │   │ SF1  │     │  │
    │   │ (secondary  │   │(flex)│   │(flex)│     │  │
    │   │  path)      │   │      │   │      │     │  │
    │   └──────┬──────┘   └──┬───┘   └──┬───┘     │  │
    │          │             │          │          │  │
    │          └─────────────┴──────────┘          │  │
    │              connects into spine              │  │
    │                                              │ ─┘
    ├──────────────────────────────────────────────┤
    │  S0  S1  S2  S3  S4  S5  S6  S7  S8  S9 ... │ SOUTH
    │ 5V0 VSS ana  ana VSS ana  ana VSS 3V3 VSS   │ PAD RING
    └──────────────────────────────────────────────┘

    LEGEND:
    ═══  Power trunk (M5, ~25um wide, vertical N-to-S)
    ←──→ Digital control bus (28 signals per tile, M1/M2)
    ch   Routing channel (~80um, spine-to-tile signals + guard ring)
    ║    Power trunk continuation
    W0-W3: West tiles (5V primary)
    E0-E3: East tiles (3.3V primary)
    SF0-SF1: South flexible tiles (3.3V or 5V)
```

### 1.5 East-West Cross Section

Cut through any tile row (e.g., through W1/E1):

```
  WEST                                                             EAST
  PADS                                                             PADS
   │                                                                  │
   │   5V trunk    WEST TILE         SPINE          EAST TILE   3.3V  │
   │   (M5,25um)   (W1)           (300um wide)       (E1)      trunk │
   │      ║                           ║                           ║    │
   │      ║     ┌─────────────┐  ┌────╨─────────┐  ┌──────────┐  ║    │
   │      ║     │             │  │              │  │          │  ║    │
   │      ║     │  ┌───────┐  │  │              │  │  ┌────┐  │  ║    │
   │      ╠═════╪═→│5V DUT │  │  │  UART ctrl   │  │  │3.3V│  │  ║    │
   │      ║     │  │circuit │  │  │  Registers   │  │  │DUT │  │  ║    │
   │      ║     │  └───────┘  │  │  Tile I/F     │  │  └────┘  │  ║    │
   │      ║     │  ┌───────┐  │  │  Clk/Rst      │  │          │  ║    │
   │   ┌──╨──┐  │  │3.3V   │  │  │              │  │          │  ║    │
   │   │guard│  │  │wrapper │  │  │              │  │          │  ║    │
   │   │ring │  │  └───────┘  │  │              │  │          │  ║    │
   │   └──╥──┘  │             │  │              │  │          │  ║    │
   │      ║     └──────┬──────┘  └──────┬───────┘  └─────┬────┘  ║    │
   │      ║            │                │                 │       ║    │
   ▼      ▼     ┊guard ▼ ring┊  ┊guard  ▼  ring┊  ┊guard ▼ ring┊ ▼    ▼
  ═════════════════════════════════════════════════════════════════════
                              VSS MESH (full die)

        ←650um→  ←80um→  ←──300um──→  ←80um→  ←──650um──→
        W tile   channel    spine     channel    E tile
```

**What this shows:**
- The 5V power trunk runs along the west edge, taps into each west tile's VDD_5V0
- Each west tile has a 5V DUT and a 3.3V digital wrapper (both inside the tile boundary)
- An 80um routing channel separates the tile from the spine (carries 28 digital signals + guard ring)
- The spine is 300um wide, powered by its own 3.3V trunk down the center
- An identical 80um channel separates the spine from east tiles
- The 3.3V trunk runs along the east edge, taps into each east tile
- VSS mesh is continuous under everything
- Guard rings at every domain boundary

---

## 2. Central Spine Internal Block Diagram

The spine is the sole digital control backbone. It spans the full height of the main region (~2700um) and is 300um wide. All spine logic runs on VDD_3V3.

### 2.1 Spine Block Diagram

```
    NORTH PAD INTERFACE
    ═══════════════════
    │ VDD_3V3  VSS  UART_TX  UART_RX  CLK_EXT  RST_N  SPI(v2)  DBG
    │    │      │      │        │        │        │       │        │
    ▼    ▼      ▼      ▼        ▼        ▼        ▼       ▼        ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │                                                                 │
   │  ┌──────────────────────────────────────────────────────────┐   │
   │  │                    CLOCK / RESET BLOCK                    │   │
   │  │                                                          │   │
   │  │  CLK_EXT ──┐                                             │   │
   │  │            ├──→[2:1 MUX]──→ sys_clk ──┬──→ spine logic   │   │
   │  │  RC_OSC  ──┘    (CLK_CONTROL)         │                  │   │
   │  │                                        │                  │   │
   │  │  RST_N ──→[sync]──→ rst_n_sync         │                  │   │
   │  │  soft_reset ──────→                    │                  │   │
   │  │                                        ▼                  │   │
   │  │                              [per-tile clock gates x8]    │   │
   │  │                               tile_clk[0..7]             │   │
   │  └──────────────────────────────────────────────────────────┘   │
   │                              │                                  │
   │  ┌──────────────────────────────────────────────────────────┐   │
   │  │                    UART CORE (8N1, 115200)                │   │
   │  │                                                          │   │
   │  │  UART_RX ──→ [RX shift reg] ──→ rx_byte, rx_valid       │   │
   │  │  UART_TX ←── [TX shift reg] ←── tx_byte, tx_start       │   │
   │  │                                                          │   │
   │  │  Baud generator: sys_clk / (CLK_FREQ / 115200)          │   │
   │  │  Error detect: framing, overrun → UART_ERR_COUNT         │   │
   │  └──────────────────────┬───────────────────────────────────┘   │
   │                         │ rx_byte / tx_byte                     │
   │  ┌──────────────────────┴───────────────────────────────────┐   │
   │  │                    COMMAND DECODER                         │   │
   │  │                                                          │   │
   │  │  State machine:                                          │   │
   │  │  IDLE → OPCODE → ARG1 → [ARG2] → EXECUTE → RESPOND      │   │
   │  │                                                          │   │
   │  │  Opcodes:                                                │   │
   │  │    'R' addr        → read spine reg → respond data       │   │
   │  │    'W' addr data   → write spine reg → respond ACK       │   │
   │  │    'T' tile addr   → read tile reg → respond data        │   │
   │  │    'U' tile addr d → write tile reg → respond ACK        │   │
   │  │    'S'             → global status → respond 2 bytes     │   │
   │  │    'P'             → ping → respond 'K'                  │   │
   │  │    '!'             → soft reset → respond ACK            │   │
   │  │                                                          │   │
   │  │  On bad opcode/timeout: respond 'E' + error_code         │   │
   │  └──────────────────────┬───────────────────────────────────┘   │
   │                         │ reg_addr / reg_wdata / reg_rd         │
   │  ┌──────────────────────┴───────────────────────────────────┐   │
   │  │                    REGISTER BANK                          │   │
   │  │                                                          │   │
   │  │  8-bit address space (256 regs, ~48 active)              │   │
   │  │                                                          │   │
   │  │  0x00-0x03  CHIP_ID[3:0], VERSION                        │   │
   │  │  0x04-0x07  POWER_STATUS/CONTROL, GLOBAL_STATUS, BOOT    │   │
   │  │  0x08-0x09  CLK_CONTROL, RST_CONTROL                     │   │
   │  │  0x0A-0x0D  TILE_SELECT, TILE_ENABLE_W, _E, _S           │   │
   │  │  0x10-0x14  selected tile status + result mirror          │   │
   │  │  0x18-0x1A  ERROR_FLAGS, ERROR_TILE, ERROR_CODE           │   │
   │  │  0x1C-0x1F  UART debug counters                          │   │
   │  │  0x20-0x2F  tile register window (16 regs of selected)   │   │
   │  │  0x30-0xFF  reserved                                     │   │
   │  └──────────────────────┬───────────────────────────────────┘   │
   │                         │                                       │
   │  ┌──────────────────────┴───────────────────────────────────┐   │
   │  │                TILE INTERFACE CONTROLLER                  │   │
   │  │                                                          │   │
   │  │  tile_select[3:0] → one-hot decode → 10 chip-selects    │   │
   │  │    (W0-W3 = 0..3, E0-E3 = 4..7, SF0 = 8, SF1 = 9)      │   │
   │  │                                                          │   │
   │  │  Shared bus to all tiles:                                │   │
   │  │    tile_addr[3:0]    (register address within tile)      │   │
   │  │    tile_wdata[7:0]   (write data)                        │   │
   │  │    tile_cfg_wr       (write strobe, active for 1 cycle)  │   │
   │  │                                                          │   │
   │  │  Per-tile return (muxed by tile_select):                 │   │
   │  │    tile_rdata[7:0]   (10:1 mux of all tile read buses)  │   │
   │  │    tile_status[3:0]  (active tile's status)              │   │
   │  │    tile_irq          (OR of all tile IRQs → global flag) │   │
   │  │                                                          │   │
   │  │  Per-tile control (directly from enable registers):      │   │
   │  │    tile_enable[0..9] (from TILE_ENABLE_W/E/S bits)       │   │
   │  │    tile_reset_n[0..9](individual reset, from RST_CTRL)   │   │
   │  │    tile_clk[0..9]    (gated clocks)                      │   │
   │  └──────────────────────┬───────────────────────────────────┘   │
   │                         │                                       │
   │  ┌──────────────────────┴───────────────────────────────────┐   │
   │  │                POWER CONTROL LOGIC                        │   │
   │  │                                                          │   │
   │  │  POWER_CONTROL register drives:                          │   │
   │  │    west_pwr_en  → PMOS gate driver (5V group switch)     │   │
   │  │    east_pwr_en  → PMOS gate driver (3.3V group switch)   │   │
   │  │    south_pwr_en → PMOS gate driver (south group switch)  │   │
   │  │    usb_pwr_en   → USB block power control                │   │
   │  │                                                          │   │
   │  │  POWER_STATUS register reads:                            │   │
   │  │    vdd_3v3_ok   (spine power-good, always monitored)     │   │
   │  │    vdd_5v0_ok   (5V rail presence detector)              │   │
   │  │    west_pwr_ok  (west group power-good)                  │   │
   │  │    east_pwr_ok  (east group power-good)                  │   │
   │  │    south_pwr_ok (south group power-good)                 │   │
   │  └──────────────────────┬───────────────────────────────────┘   │
   │                         │                                       │
   │  ┌──────────────────────┴───────────────────────────────────┐   │
   │  │                STATUS AGGREGATION                         │   │
   │  │                                                          │   │
   │  │  GLOBAL_STATUS:                                          │   │
   │  │    any_busy  = OR(tile_status[0] for all enabled tiles)  │   │
   │  │    any_done  = OR(tile_status[1] for all enabled tiles)  │   │
   │  │    any_error = OR(tile_status[3] for all enabled tiles)  │   │
   │  │    uart_ok   = UART core healthy                         │   │
   │  │                                                          │   │
   │  │  ERROR_FLAGS: per-group error summary                    │   │
   │  │  ERROR_TILE:  tile_id of first error source              │   │
   │  │  ERROR_CODE:  error code from that tile                  │   │
   │  └──────────────────────────────────────────────────────────┘   │
   │                         │                                       │
   │                         ▼                                       │
   │              SOUTH INTERFACE                                    │
   │              (connects to USB block + south flex tiles)          │
   └─────────────────────────────────────────────────────────────────┘
```

### 2.2 Spine Internal Signal Flow

```
  UART_RX →── UART Core ──→ Command Decoder ──→ Register Bank ──┐
                                    │                            │
                                    ├── spine register R/W       │
                                    │                            │
                                    └── tile register R/W ──→ Tile I/F Controller
                                                                  │
                          ┌── tile_addr[3:0] ─────────────────────┤
                          ├── tile_wdata[7:0] ────────────────────┤
                          ├── tile_cfg_wr ────────────────────────┤
                          │                                       │
                          │   ┌─── W0 ←→ tile bus ────────────────┤
                          │   ├─── W1 ←→ tile bus ────────────────┤
                          │   ├─── W2 ←→ tile bus ────────────────┤
                          │   ├─── W3 ←→ tile bus ────────────────┤
                          │   ├─── E0 ←→ tile bus ────────────────┤
                          │   ├─── E1 ←→ tile bus ────────────────┤
                          │   ├─── E2 ←→ tile bus ────────────────┤
                          │   ├─── E3 ←→ tile bus ────────────────┤
                          │   ├─── SF0 ←→ tile bus ───────────────┤
                          │   └─── SF1 ←→ tile bus ───────────────┘
                          │
                          └── tile_rdata[7:0] ──→ [10:1 MUX] ──→ response
                              tile_status[3:0]
                              tile_irq

  Status Aggregation ←── all tile_status signals ──→ GLOBAL_STATUS register
  Power Control ──→ group PMOS gate drivers ──→ west/east/south power switches
  Clock/Reset ──→ per-tile clock gates + reset lines ──→ tile_clk[N], tile_reset_n[N]
```

### 2.3 Gate Budget Estimate

| Block | Estimated Gates | Notes |
|-------|----------------|-------|
| UART core (TX + RX + baud gen) | ~400 | 8N1, fixed baud |
| Command decoder FSM | ~300 | 7 opcodes, 6-state FSM |
| Register bank (48 active regs) | ~1500 | 8-bit read mux, write decode |
| Tile interface controller | ~600 | 10:1 mux, chip-select decode, timing |
| Clock/reset block | ~200 | 2:1 mux, synchronizer, 10 clock gates |
| Power control logic | ~150 | 3 group enables, status read-back |
| Status aggregation | ~200 | OR trees, error latch |
| **Total spine** | **~3,350** | Comfortably fits in 300um x 2700um |

---

## 3. Tile Wrapper Definition

### 3.1 Tile Wrapper Block Diagram

Every tile (W0-W3, E0-E3, SF0-SF1) contains this standard wrapper:

```
┌──────────────────────────────────────────────────────────────────┐
│                        TILE WRAPPER                               │
│                                                                  │
│  SPINE BUS (28 digital signals, all 3.3V)                        │
│  ═══════════════════════════════════════                          │
│  │ tile_clk                                                      │
│  │ tile_reset_n                                                  │
│  │ tile_enable                                                   │
│  │ tile_addr[3:0]                                                │
│  │ tile_wdata[7:0]                                               │
│  │ tile_cfg_wr                                                   │
│  │ ←── tile_rdata[7:0]                                           │
│  │ ←── tile_status[3:0]                                          │
│  │ ←── tile_irq                                                  │
│  │ ←── tile_pwr_good                                             │
│  ▼                                                               │
│  ┌────────────────────────────────────────────┐                  │
│  │         REGISTER FILE (16 x 8-bit)          │                  │
│  │                                              │                  │
│  │  0x0  TILE_ID          (R)   set at design   │                  │
│  │  0x1  TILE_VERSION     (R)   set at design   │                  │
│  │  0x2  TILE_CONTROL     (RW)  mode/start/stop │                  │
│  │  0x3  TILE_STATUS      (R)   FSM state        │                  │
│  │  0x4  TILE_PARAM_0     (RW)  DUT param low    │                  │
│  │  0x5  TILE_PARAM_1     (RW)  DUT param high   │                  │
│  │  0x6  TILE_PARAM_2     (RW)  DUT mode/gain    │                  │
│  │  0x7  TILE_PARAM_3     (RW)  DUT flags         │                  │
│  │  0x8  TILE_RESULT_0    (R)   measurement low   │                  │
│  │  0x9  TILE_RESULT_1    (R)   measurement high  │                  │
│  │  0xA  TILE_RESULT_2    (R)   secondary data     │                  │
│  │  0xB  TILE_RESULT_3    (R)   secondary data     │                  │
│  │  0xC  TILE_DEBUG_0     (R)   observation 0      │                  │
│  │  0xD  TILE_DEBUG_1     (R)   observation 1      │                  │
│  │  0xE  TILE_ERROR       (R)   error code         │                  │
│  │  0xF  TILE_SCRATCH     (RW)  connectivity test  │                  │
│  └────────────────────────┬───────────────────────┘                  │
│                           │                                          │
│  ┌────────────────────────┴───────────────────────┐                  │
│  │              CONTROL FSM                        │                  │
│  │                                                │                  │
│  │  DISABLED ──(enable=1)──→ IDLE                 │                  │
│  │     ↑                       │                  │                  │
│  │  (enable=0                (start=1)            │                  │
│  │   or reset)                 │                  │                  │
│  │     │                       ▼                  │                  │
│  │     │                    RUNNING               │                  │
│  │     │                   /       \              │                  │
│  │     │              (dut_done) (timeout)        │                  │
│  │     │                /             \           │                  │
│  │     │               ▼               ▼          │                  │
│  │     │             DONE            ERROR        │                  │
│  │     │               │               │          │                  │
│  │     └───────────────┴───────────────┘          │                  │
│  │                                                │                  │
│  │  Timeout watchdog: counts sys_clk cycles after │                  │
│  │  start. Configurable via TILE_PARAM_3.         │                  │
│  └────────────────────────┬───────────────────────┘                  │
│                           │ dut_enable, dut_mode, dut_param          │
│                           │ dut_start, dut_done, dut_result          │
│                           ▼                                          │
│  ┌─────────────────────────────────────────────────┐                 │
│  │              ISOLATION BOUNDARY                  │                 │
│  │                                                  │                 │
│  │  3.3V wrapper side          DUT side             │                 │
│  │  ─────────────────    ──────────────────         │                 │
│  │  dut_enable ──→ [level shift?] ──→ DUT.enable    │                 │
│  │  dut_mode   ──→ [level shift?] ──→ DUT.mode      │                 │
│  │  dut_param  ──→ [level shift?] ──→ DUT.param     │                 │
│  │  dut_start  ──→ [level shift?] ──→ DUT.start     │                 │
│  │                                                  │                 │
│  │  DUT.done   ──→ [level shift?] ──→ dut_done      │                 │
│  │  DUT.result ──→ [level shift?] ──→ dut_result    │                 │
│  │                                                  │                 │
│  │  [Level shifters required only for 5V tiles]     │                 │
│  │  [3.3V tiles: direct connection, no shifters]    │                 │
│  │                                                  │                 │
│  │  Analog I/O:                                     │                 │
│  │    DUT analog pins ──→ [isolation switch] ──→ PADS               │
│  │    (switch open when tile_enable=0)              │                 │
│  └─────────────────────────────────────────────────┘                 │
│                           │                                          │
│  ┌─────────────────────────────────────────────────┐                 │
│  │           ANALOG DUT (user-designed)             │                 │
│  │                                                  │                 │
│  │  Powered by: VDD_3V3 (3.3V tile) or VDD_5V0     │                 │
│  │              (5V tile) — NOT both for DUT core    │                 │
│  │                                                  │                 │
│  │  Inputs:  mode, param, start, stim_a, stim_b     │                 │
│  │  Outputs: done, result, debug, out_main, tap      │                 │
│  │                                                  │                 │
│  │  Analog I/O exits to die-edge pads on the        │                 │
│  │  tile's outward side (west pads for W tiles,     │                 │
│  │  east pads for E tiles, south pads for SF tiles) │                 │
│  └─────────────────────────────────────────────────┘                 │
│                                                                      │
│  POWER CONNECTIONS:                                                  │
│  ┌──────────────────────────────────────────────┐                    │
│  │  VDD_3V3 ── always connected (wrapper logic)  │                    │
│  │  VDD_5V0 ── via group switch (5V tiles only)  │                    │
│  │  VSS     ── always connected (ground mesh)    │                    │
│  └──────────────────────────────────────────────┘                    │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.2 Tile Wrapper Signal Table

| Signal | Dir | Width | Domain | Description |
|--------|-----|-------|--------|-------------|
| `tile_clk` | In | 1 | 3.3V | Gated clock from spine. Stops when tile disabled. |
| `tile_reset_n` | In | 1 | 3.3V | Active-low synchronous reset. |
| `tile_enable` | In | 1 | 3.3V | Master enable. 0 = tile isolated, clock stopped. |
| `tile_addr[3:0]` | In | 4 | 3.3V | Register address (0x0-0xF). |
| `tile_wdata[7:0]` | In | 8 | 3.3V | Write data from spine. |
| `tile_cfg_wr` | In | 1 | 3.3V | Write strobe. Active 1 clock cycle. |
| `tile_rdata[7:0]` | Out | 8 | 3.3V | Read data to spine. Valid 1 cycle after addr stable. |
| `tile_status[3:0]` | Out | 4 | 3.3V | `[0]`=busy `[1]`=done `[2]`=pass `[3]`=error |
| `tile_irq` | Out | 1 | 3.3V | Interrupt. Active-high, edge-sensitive. |
| `tile_pwr_good` | Out | 1 | 3.3V | Local power stable. Tie high if no detector. |
| `VDD_3V3` | Pwr | — | 3.3V | Wrapper logic supply. Always connected. |
| `VDD_5V0` | Pwr | — | 5.0V | DUT supply for 5V tiles. Via group switch. |
| `VSS` | Pwr | — | GND | Ground. Always connected. |

**Total digital signals per tile: 28** (13 in + 14 out + 1 bidirectional power-good).

### 3.3 Tile Wrapper RTL Template

```systemverilog
module tile_wrapper #(
    parameter logic [7:0] TILE_TYPE_ID   = 8'h00,
    parameter logic [7:0] TILE_VERSION   = 8'h10,
    parameter int         TIMEOUT_CYCLES = 100_000
)(
    input  logic        tile_clk,
    input  logic        tile_reset_n,
    input  logic        tile_enable,

    input  logic [3:0]  tile_addr,
    input  logic [7:0]  tile_wdata,
    input  logic        tile_cfg_wr,
    output logic [7:0]  tile_rdata,

    output logic [3:0]  tile_status,    // busy, done, pass, error
    output logic        tile_irq,
    output logic        tile_pwr_good
);

    // --- Register file: 16 x 8-bit ---
    logic [7:0] regs [0:15];

    // --- Control FSM ---
    typedef enum logic [2:0] {
        S_DISABLED = 3'd0,
        S_IDLE     = 3'd1,
        S_RUNNING  = 3'd2,
        S_DONE     = 3'd3,
        S_ERROR    = 3'd4
    } state_t;

    state_t state, next_state;

    // --- Timeout watchdog ---
    logic [23:0] timeout_cnt;

    // --- DUT interface (connect to user experiment) ---
    logic        dut_enable;
    logic [2:0]  dut_mode;
    logic [15:0] dut_param;
    logic        dut_start;
    logic        dut_done;      // from DUT
    logic [31:0] dut_result;    // from DUT
    logic [15:0] dut_debug;     // from DUT

    // --- Read-only registers wired at design time ---
    assign regs[0] = TILE_TYPE_ID;
    assign regs[1] = TILE_VERSION;

    // --- Status output ---
    assign tile_status[0] = (state == S_RUNNING);
    assign tile_status[1] = (state == S_DONE);
    assign tile_status[2] = regs[3][2]; // pass flag
    assign tile_status[3] = (state == S_ERROR);

    // ... FSM, register R/W, timeout logic, isolation control ...

endmodule
```

### 3.4 Behavioral Rules

1. **Disable tolerance:** When `tile_enable` = 0, the tile must present safe outputs: `tile_rdata` = 0x00, `tile_status` = 4'b0000, `tile_irq` = 0, all analog isolation switches open.
2. **Clean reset:** After `tile_reset_n` deasserts, the tile must be in `S_DISABLED` (if enable=0) or `S_IDLE` (if enable=1) within 2 clock cycles. All registers return to defaults.
3. **Power-gate survival:** If the tile's group power gate opens, all internal state is lost. The spine retains the tile's configuration in its own register bank and can reconfigure after power restores.
4. **Scratch test:** Writing to `TILE_SCRATCH` (0xF) and reading back the same value confirms the digital bus to this tile is functional.

---

## 4. Power Distribution Strategy

### 4.1 Rail Topology

```
                    NORTH PADS
                    ┌──VDD_3V3 (N0)──┐
                    │                │
                    │  ┌──VDD_5V0 (N12)──┐
                    │  │                  │
                    ▼  ▼                  │
    5V TRUNK ◄══════╪══╪                  │
    (M5, west)      │  │                  │
                    │  │                  │
    3.3V SPINE ◄════╪══╝                  │
    TRUNK (M5,      │                     │
    center)         │                     │
                    │                     │
    3.3V EAST ◄═════╝                     │
    TRUNK (M5,                            │
    east)                                 │
                                          │
                    ▼                     ▼
                 SOUTH PADS (redundant 5V0/3V3 entries)
```

### 4.2 Trunk Specifications

| Trunk | Metal Layer | Width | Location | Feeds |
|-------|------------|-------|----------|-------|
| VDD_5V0 west | M5 | ~25um | West edge, x ≈ 50um from pad ring | W0-W3 DUT supply, south 5V tiles |
| VDD_3V3 spine | M5 | ~25um | Center, x ≈ 1460um (die midline) | Spine logic, all tile wrappers |
| VDD_3V3 east | M5 | ~25um | East edge, x ≈ 2870um from west | E0-E3 supply, south 3.3V tiles |
| VSS mesh | M4 (horiz) + M5 (vert) | ~10um stripes, 50um pitch | Full die coverage | All blocks |

### 4.3 Group Power Switches

| Group | Switch Type | PMOS Device | Size | Controls |
|-------|-----------|-------------|------|----------|
| West (5V) | VDD_5V0 header | `sky130_fd_pr__pfet_g5v0d10v5` | W=100u/L=0.5u | W0-W3 DUT VDD_5V0 |
| East (3.3V tile) | VDD_3V3 header | `sky130_fd_pr__pfet_03v3` | W=100u/L=0.5u | E0-E3 tile VDD_3V3 |
| South (flex) | Dual headers | Both types | W=50u/L=0.5u each | SF0-SF1 supply |

**Note:** The spine's own VDD_3V3 is **not** gated. The spine is always powered when VDD_3V3 is applied.

### 4.4 Power Flow Diagram

```
    VDD_3V3 (bench) ──→ N0 pad ──→ spine trunk (M5, center)
                                    │
                                    ├──→ spine logic (always on)
                                    ├──→ all tile wrappers (3.3V digital, always on)
                                    ├──→ east trunk (M5) ──→ [PMOS east] ──→ E0-E3 tile DUT
                                    └──→ south 3.3V ──→ [PMOS south] ──→ SF tiles (3.3V mode)

    VDD_5V0 (bench) ──→ N12 pad ──→ west trunk (M5, west edge)
                                    │
                                    └──→ [PMOS west] ──→ W0-W3 tile DUT (5V supply)
                                    └──→ south 5V ──→ [PMOS south] ──→ SF tiles (5V mode)

    VSS (bench) ──→ N1, N13, south pads ──→ full-die ground mesh
```

### 4.5 Cross-Domain Protection Rules

| Rule | Implementation |
|------|---------------|
| 3.3V gate must never see >3.6V | Thick-oxide devices on all 5V signal paths inside tiles |
| 5V DUT output observed by 3.3V logic | Resistive divider or level-down shifter inside tile wrapper |
| 3.3V control drives 5V DUT input | Level-up shifter (3.3V → 5V) inside tile wrapper |
| Disabled 5V tile backfeed into 3.3V | Isolation switches open; clamp diodes to VDD_3V3 on wrapper side |
| 5V trunk does not enter east region | Physical: 5V trunk stays on west half. No M5 5V stripe crosses center. |
| 3.3V trunk does not carry 5V current | Separate trunk. Only 3.3V wrapper taps from the center/east trunks. |

### 4.6 Power Sequencing

| Step | Action | Requirement |
|------|--------|-------------|
| 1 | Apply VDD_3V3 to north pads | Spine boots. UART responsive. All tiles disabled, all power gates open. |
| 2 | UART: verify spine (read CHIP_ID, POWER_STATUS) | Confirms 3.3V domain healthy. |
| 3 | UART: enable east group power (`POWER_CONTROL.east_pwr_en = 1`) | East tiles receive 3.3V DUT supply. |
| 4 | UART: enable individual east tiles (`TILE_ENABLE_E` bits) | Tiles boot and become addressable. |
| 5 | Apply VDD_5V0 to north pads | 5V rail now available. |
| 6 | UART: verify 5V present (`POWER_STATUS.vdd_5v0_ok`) | Confirms 5V rail stable. |
| 7 | UART: enable west group power (`POWER_CONTROL.west_pwr_en = 1`) | West tiles receive 5V DUT supply. |
| 8 | UART: enable individual west tiles (`TILE_ENABLE_W` bits) | 5V tiles boot. |
| 9 | UART: enable USB block (south region, optional) | Secondary path validated. |

**3.3V-only operation is fully functional.** Steps 5-8 are only needed if 5V experiments are required. The chip is useful with only a 3.3V bench supply connected.

---

## 5. Risks, Conflicts, and Layout Challenges

### 5.1 Critical Risks

| # | Risk | Severity | Likelihood | Mitigation |
|---|------|----------|-----------|------------|
| 1 | **5V backfeed into 3.3V domain** if VDD_5V0 applied before VDD_3V3 | High | Medium | Protection diodes limit damage; enforce sequencing via procedure. Add series Schottky or poly R on cross-domain tile paths. |
| 2 | **Spine single point of failure** — any spine bug kills all tile access | High | Medium | Include digital loopback tile (known-good wrapper, no analog DUT) to isolate wrapper bugs from spine bugs. Keep spine minimal. |
| 3 | **Tile wrapper bug** replicated across all 10 tiles | High | Medium | Thorough simulation of wrapper in isolation. Scratch register test exercises full bus path per tile. |
| 4 | **Internal RC oscillator** too inaccurate for UART | Medium | Low | Use 9600 baud with RC (needs only ±5% accuracy). Switch to external clock immediately after initial contact. |
| 5 | **5V thick-oxide model inaccuracy** in SKY130 | Medium | Medium | Conservative margins on 5V tile designs. First 5V tile should be a simple resistor/diode test structure, not a complex circuit. |
| 6 | **Substrate noise from spine** corrupts analog tiles | Medium | Medium | Guard rings at every boundary. Dedicated decoupling on spine rails. Physical separation (80um channel). |

### 5.2 Layout Conflicts

| Conflict | Description | Resolution |
|----------|-------------|------------|
| **Spine width pressure** | 300um may be tight if register count grows significantly | Keep v1 register map minimal (~48 regs). Spine can expand into south region if needed. |
| **Channel congestion** | 28 signals per tile on M1/M2, plus guard ring, plus power taps, in 80um | Route at minimum pitch (~0.5um M1). Budget: 28 signals x 0.5um = 14um for signals, leaving 66um for guard ring, power taps, and spacing. Feasible. |
| **South region contention** | USB block + 2 flex tiles + south pads compete for ~500um of height | USB block: ~300um x 400um. Flex tiles: 2 x 400um x 400um. Total ~300um height if tiles are narrower. Tight but feasible. |
| **Pad count** | 4 edges × die perimeter ÷ pad pitch may not provide enough pads for 2 analog per tile | Caravel provides 38 GPIO + dedicated analog pads. Budget: 10 digital (north) + 8 west analog + 8 east analog + 6 south analog + 6 power/ground = 38. Exactly fits if using 2 pads per main tile and 1 per south tile. |
| **5V trunk proximity to east tiles** | 5V trunk on west edge must not have stray coupling into east region | Trunk is on M5 at x ≈ 50um. East tiles start at x ≈ 2200um. Distance > 2mm. No coupling risk. |

### 5.3 Open Design Decisions Requiring Resolution

| # | Decision | Options | Recommendation |
|---|----------|---------|----------------|
| 1 | South flex tile count | 1 or 2 tiles alongside USB block | 2 tiles (tight fit, but USB block is narrow) |
| 2 | Tile-to-tile numbering | Sequential (W0=0, W1=1,...) or by-group (W=0-3, E=4-7, S=8-9) | By-group: W0-W3 = tile IDs 0-3, E0-E3 = 4-7, SF0-SF1 = 8-9 |
| 3 | South tile voltage | Fixed per slot or register-configurable | Register-configurable via POWER_CONTROL. South region has both trunk taps available. |
| 4 | Analog pad allocation per tile | 2 pads per main tile, 1 per south tile | Start with 2 per main tile. Reduce to 1 if pad budget is exceeded. |
| 5 | USB block size | Minimal stub vs. full CDC-ACM | Minimal stub for v1 (register interface only, no full USB stack). Full CDC in v2. |
| 6 | RC oscillator target frequency | 1 MHz vs. 10 MHz | 1 MHz (safe for 9600 baud, lower power, simpler design) |
| 7 | Watchdog timer | Include in spine or defer | Include — ~50 gates, resets spine if command decoder hangs |

---

*End of floorplan specification — ULC Spine-Tile v1r1*
