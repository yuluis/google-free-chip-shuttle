# ULC Spine-Tile Architecture Specification — Version 1

**Status:** Draft — Initial Architecture
**Process:** SkyWater SKY130 (open-source PDK)
**Wrapper:** Caravel digital wrapper (efabless Google Open MPW)
**Die area:** 2.92 x 3.52 mm (Caravel user area: ~10 mm²)
**Date:** 2026-03-24
**Revision name:** Spine-Tile v1

---

## Directional Convention

**This document uses a single fixed orientation throughout.** All references to north/south/east/west refer to the die as viewed from above in standard IC orientation:

```
                    NORTH (top of die)
              ┌─────────────────────────┐
              │                         │
   WEST       │                         │       EAST
   (left)     │        Die area         │       (right)
              │                         │
              │                         │
              └─────────────────────────┘
                    SOUTH (bottom of die)
```

- **North edge:** Digital I/O pads (UART, SPI, clock, reset, debug)
- **West edge:** Primarily 5V-oriented experiment tiles
- **East edge:** Primarily 3.3V-oriented experiment tiles
- **South edge:** Flexible — may host either 5V or 3.3V tiles

This convention is carried consistently through all sections. Where the original verbal description had mixed directional references, they have been resolved into this single consistent plan.

---

## 1. High-Level Architecture

### 1.1 Core Concept

The ULC uses a **central digital spine + perimeter tile ring** architecture. The chip is organized around a vertical digital backbone running north-to-south through the center of the die. Around the perimeter — west, east, and south edges — lies a ring of standardized experiment tile slots. The north edge is reserved for digital I/O pads.

```
                         NORTH EDGE
              ┌─────── Digital Pads ───────┐
              │  UART  SPI  CLK  RST  DBG  │
              ├────────────┬───────────────┤
              │            │               │
    WEST      │  5V Tile   │   3.3V Tile   │  EAST
    EDGE      │  Slots     │   Slots       │  EDGE
    (5V       │            │               │  (3.3V
     tiles)   │     ┌──────┴──────┐        │   tiles)
              │     │  DIGITAL    │        │
              │     │  SPINE      │        │
              │     │             │        │
              │     │  Registers  │        │
              │     │  UART Ctrl  │        │
              │     │  Sequencer  │        │
              │     │  Clk/Rst    │        │
              │     │  Tile I/F   │        │
              │     │             │        │
              │     └──────┬──────┘        │
              │            │               │
              ├────────────┴───────────────┤
              │   Flexible Tile Slots      │
              │   (5V or 3.3V)             │
              └────────────────────────────┘
                         SOUTH EDGE
```

### 1.2 Why This Architecture

**Controllability.** Every tile connects to the central spine through a standardized interface. The spine can enable, disable, reset, configure, and observe every tile independently.

**Observability.** The spine collects status, results, and error flags from all tiles through a uniform register interface. A single UART session can interrogate any tile on the chip.

**Isolation.** Tiles are physically separated from each other by the perimeter placement. A failing or shorted tile does not directly affect its neighbors or the spine. Each tile can be power-gated independently.

**Safe bring-up.** The digital spine powers up first on a simple 3.3V supply. Tiles remain disabled until explicitly enabled through the register interface. This means the chip is alive and communicating before any experiment tile draws current.

**Modularity.** The standardized tile interface means different experiment circuits — analog amplifiers, oscillators, comparators, LDOs, digital test structures — can be designed independently and dropped into any tile slot.

**Power-domain organization.** The physical separation of 5V tiles (west) from 3.3V tiles (east) simplifies power distribution, reduces accidental domain crossing, and improves noise isolation between voltage domains.

**Debuggability.** The UART-first approach means bring-up requires only a serial terminal and a bench supply. No special equipment, no high-speed probes, no dependency on working USB or PLL.

### 1.3 Relation Between Spine and Tiles

The spine acts as a **test harness controller**. Each tile slot has a fixed set of digital control signals (enable, reset, clock, configuration bus, status bus) plus power connections (VDD_3V3, VDD_5V0, VSS). The spine drives the control signals and reads the status signals. The tile contains the experiment circuit plus a thin digital wrapper that translates spine commands into DUT-specific operations.

The spine does **not** carry analog signals. Analog stimulus and measurement connections (if needed) are routed within the tile's local area or to dedicated analog pads on the tile's adjacent die edge. This keeps the spine purely digital and avoids analog/digital coupling.

---

## 2. Bring-Up Philosophy

### 2.1 First-Boot Scenario

The intended first bring-up sequence:

1. Connect external 3.3V bench supply to VDD_3V3 and GND pads
2. Connect UART TX/RX to a USB-to-serial adapter (3.3V logic levels)
3. Power on
4. The digital spine initializes: clock starts, reset sequence completes, UART becomes responsive
5. All tiles remain **disabled and unpowered** (power gates open, enables deasserted)
6. Host sends UART commands to read chip ID, verify communication
7. Host selectively enables individual tiles one at a time
8. Host reads tile status, runs experiments, collects results

### 2.2 Key Principles

**No dependency on advanced interfaces.** USB, SPI slave, JTAG, and any other interfaces are optional enhancements. UART alone is sufficient for full chip control.

**No dependency on PLL or complex clocking.** The chip boots from an external clock or a simple internal RC oscillator. PLL, if present, is an optional tile — not part of the boot path.

**No dependency on 5V supply for digital infrastructure.** The spine runs entirely on 3.3V. The 5V rail is only needed when 5V tiles are enabled. This means the chip is fully operational with only a 3.3V supply connected.

**Deterministic startup.** On power-on-reset, every register is in a known state, every tile is disabled, every power gate is open. There is no race condition, no SRAM-dependent initialization, no firmware to load.

**Progressive enablement.** Bring-up proceeds in layers: (1) spine alive, (2) UART communicating, (3) 3.3V tiles enabled one-by-one, (4) 5V supply connected and 5V tiles enabled one-by-one. Each layer is verified before proceeding.

### 2.3 Why This Reduces Risk

- If any tile is defective, the rest of the chip still works
- If the 5V supply is absent or faulty, all 3.3V tiles and the spine still work
- If the PLL tile doesn't lock, the chip runs on the reference clock
- If an analog tile draws unexpected current, its power gate can be opened remotely via UART
- The simplest possible bring-up path (3.3V + UART) exercises the maximum amount of digital infrastructure

---

## 3. Power Architecture

### 3.1 Supply Domains

The chip has three supply rails at the die level:

| Rail | Nominal Voltage | Source | Purpose |
|------|----------------|--------|---------|
| VDD_3V3 | 3.3V | External bench supply (or Caravel VDDA) | Digital spine, 3.3V tile power, I/O |
| VDD_5V0 | 5.0V | External bench supply (dedicated pads) | 5V tile power only |
| VSS | 0V (ground) | Common ground | All domains |

**Assumption:** SKY130 I/O cells are rated for 5V-tolerant operation. The `sky130_fd_io__top_gpio_ovtv2` pads tolerate up to 5.5V. Internal thick-oxide transistors (`sky130_fd_pr__nfet_g5v0d10v5`, `sky130_fd_pr__pfet_g5v0d10v5`) handle 5V safely.

### 3.2 Regional Power Distribution

The power architecture reflects the physical partitioning of the die:

```
                    NORTH (digital pads)
              ┌─────────────────────────┐
              │  VDD_3V3 (spine power)  │
              ├─────────┬───────────────┤
              │         │               │
    VDD_5V0   │  5V     │ SPINE  3.3V   │  VDD_3V3
    trunk     │  tile   │ (3.3V  tile   │  trunk
    (west     │  power  │  only) power  │  (east
     rail)    │  region │        region │   rail)
              │         │               │
              │         │               │
              ├─────────┴───────────────┤
              │  Flexible region        │
              │  (both trunks reach)    │
              └─────────────────────────┘
                    SOUTH
```

**West power trunk:** A wide VDD_5V0 metal stripe runs vertically along the west edge, feeding 5V tile slots. A narrower VDD_3V3 stripe also runs along the west side (because 5V tiles still need 3.3V for their digital wrapper logic).

**East power trunk:** A wide VDD_3V3 metal stripe runs vertically along the east edge, feeding 3.3V tile slots. No VDD_5V0 trunk on the east side — this avoids routing 5V through 3.3V-sensitive territory.

**South flexible zone:** Both VDD_5V0 and VDD_3V3 trunks extend into the south edge, allowing south-side tiles to be either domain.

**Central spine:** Powered exclusively from VDD_3V3. The spine never sees VDD_5V0 directly.

**VSS:** A continuous ground plane/mesh covers the entire die. VSS is not partitioned — it is a single common reference. However, the ground return paths are physically managed: 5V tile currents return primarily through west-side VSS stripes, and 3.3V tile currents through east-side VSS stripes, minimizing shared return-path coupling.

### 3.3 Power Distribution Implementation

Use **wide metal stripes on upper metal layers (M4/M5)** for power trunks:

- VDD_3V3 spine trunk: M5, running north-south through center, ~20-30 um wide
- VDD_5V0 west trunk: M5, running north-south along west edge, ~20-30 um wide
- VDD_3V3 east trunk: M5, running north-south along east edge, ~20-30 um wide
- VSS mesh: M4 + M5 grid, continuous across die
- Local tile power taps: Drop from trunks on M4/M5 down to M1/M2 within each tile

This stripe-based approach is straightforward, predictable, and avoids ad-hoc per-tile power routing.

### 3.4 Tile Power Domain Options

Each tile slot can be one of:

| Type | VDD_3V3 | VDD_5V0 | Digital wrapper | Analog DUT |
|------|---------|---------|-----------------|------------|
| 3.3V-only | Connected | Not connected | 3.3V | 3.3V |
| 5V-only | Connected (wrapper) | Connected (DUT) | 3.3V | 5V |
| Mixed-voltage | Connected | Connected | 3.3V | Mixed 3.3V/5V |

**Critical rule:** All tile digital wrapper logic (registers, FSM, status reporting) runs on 3.3V. The 5V rail is only for the analog/experimental DUT inside the tile. This means the spine-to-tile digital interface is always 3.3V, regardless of the tile's analog voltage domain.

### 3.5 3.3V / 5V Boundary Protection

Where 3.3V logic interfaces with 5V circuits inside a tile:

- **Level shifters** translate 3.3V control signals up to 5V for DUT gate drives
- **Clamp diodes** protect 3.3V inputs from 5V back-feed (use `sky130_fd_pr__diode_pd2nw_05v5`)
- **Series resistors** (200-500 ohm poly) limit transient currents during domain transitions
- **Isolation switches** (thick-oxide transmission gates) disconnect 5V DUT from 3.3V observation paths when the tile is disabled

**Design rule:** No 3.3V thin-oxide transistor gate may ever see a voltage exceeding 3.6V. All 5V signal paths inside tiles must use thick-oxide devices (`_g5v0d10v5` variants) or be clamped.

### 3.6 Power Sequencing

**Required sequence:**
1. VDD_3V3 applied first (spine boots, UART active)
2. VDD_5V0 applied second (only after spine confirms 3.3V stable)
3. Individual tiles enabled via register writes (after both supplies stable)

**Why this order matters:**
- If 5V is applied before 3.3V, the protection diodes in 5V tiles would forward-bias from VDD_5V0 into the unpowered VDD_3V3 rail, potentially back-powering the spine through an uncontrolled path
- The spine must be operational before any tile is enabled, so it can monitor for faults
- BOOT_STATUS register captures whether this sequence was followed correctly

**Recommendation for v1:** Enforce sequencing through documentation and bring-up procedure, not through on-chip sequencing hardware. Adding a supply supervisor or brown-out detector is a v2 enhancement. The v1 design is robust to supply ordering violations (protection diodes prevent damage) but may not boot cleanly if sequencing is wrong.

---

## 4. Tile Power Control

### 4.1 Approach for Version 1

**Recommended v1 strategy: register-controlled PMOS header switches per tile group, plus per-tile enable/reset.**

Rather than individual power gating for every tile (complex, area-expensive), group tiles by region:

| Group | Tiles | Power switch | Control |
|-------|-------|-------------|---------|
| West group | All west-side 5V tiles | Single PMOS header on VDD_5V0 | `TILE_PWR_WEST` register bit |
| East group | All east-side 3.3V tiles | Single PMOS header on VDD_3V3 (tile supply) | `TILE_PWR_EAST` register bit |
| South group | All south-side tiles | Single PMOS header (or two, one per domain) | `TILE_PWR_SOUTH` register bit |

Within each powered group, individual tiles are controlled via:
- **tile_enable:** Logic enable — tile wrapper FSM activates, DUT connects to routes
- **tile_reset_n:** Per-tile reset — returns tile to known state without removing power
- **tile_clk gate:** Per-tile clock gating — stops switching noise from idle tiles

### 4.2 Group Power Gating Implementation

For each group, a PMOS header switch between the supply trunk and the group's local VDD bus:

```
  VDD_5V0 trunk (west)
       │
  ┌────┴────┐
  │  PMOS   │  sky130_fd_pr__pfet_g5v0d10v5
  │  header │  W=100u/L=0.5u (multiple fingers)
  │  switch │  Gate driven by TILE_PWR_WEST register bit
  └────┬────┘  (via level shifter: 3.3V control → 5V gate drive)
       │
  VDD_5V0_LOCAL (west tile group)
       │
   ┌───┼───┬───┐
   T0  T1  T2  T3  (west-side tiles)
```

**PMOS sizing:** For a group of 4-6 tiles drawing up to 20mA total:
- Use `pfet_g5v0d10v5` (5V-tolerant PMOS), W=100u/L=0.5u
- Rds_on ~ 5-10 ohm → 100-200mV drop at 20mA (acceptable)
- Soft-start: RC filter on gate (~10us ramp) limits inrush

For the 3.3V groups, use `pfet_03v3` (3.3V PMOS), same sizing approach.

### 4.3 Tradeoffs

| Approach | Pros | Cons |
|----------|------|------|
| Group power gating (recommended v1) | Low area, simple control, natural mapping to regions | Cannot isolate one bad tile within a group without disabling siblings |
| Per-tile power gating | Maximum isolation, finest control | More switches, more area, more gate drivers, more level shifters |
| No power gating (enable-only) | Simplest, smallest | Cannot cut quiescent current of disabled tiles, back-powering risk |

**v1 recommendation:** Group power gating per region. If a specific tile within a group is problematic, use its `tile_enable` to disable it logically (stops switching, isolates outputs) even though its supply remains connected. True per-tile power gating is a v2 refinement.

### 4.4 Additional Concerns

**Inrush current:** When a group switch closes, decoupling caps on the local rail charge suddenly. The soft-start RC on the PMOS gate limits di/dt. Budget 10-50uA per tile quiescent, so group inrush is manageable.

**Lost state after power-off:** When a group is powered down, all tile registers and DUT state are lost. The spine retains the tile configuration in its own register bank and can reconfigure tiles after power-on. This is acceptable for an experiment chip.

**Back-powering risk:** If a 5V tile has its group power gate open but the 3.3V wrapper supply is still on, the DUT's 5V-connected nodes could float or couple into 3.3V paths. Mitigation: the tile wrapper's isolation switches disconnect the DUT from all external connections when `tile_enable = 0`.

**Isolation on power-down:** When a group is powered off, all tile outputs must go to a safe state (Hi-Z or clamped). The tile wrapper includes weak pull-downs on critical signals that activate when VDD_LOCAL drops below threshold.

---

## 5. Tile Interface Standard

### 5.1 Signal List

Every tile slot has the following connections to the spine:

| Signal | Direction | Width | Domain | Description |
|--------|-----------|-------|--------|-------------|
| `tile_enable` | Spine → Tile | 1 | 3.3V | Master logic enable. 0 = tile isolated. |
| `tile_reset_n` | Spine → Tile | 1 | 3.3V | Active-low reset. Synchronous to `tile_clk`. |
| `tile_clk` | Spine → Tile | 1 | 3.3V | Gated clock from spine. Stops when tile disabled. |
| `tile_cfg[7:0]` | Spine → Tile | 8 | 3.3V | Configuration/command bus. Written by spine. |
| `tile_cfg_wr` | Spine → Tile | 1 | 3.3V | Configuration write strobe. |
| `tile_addr[3:0]` | Spine → Tile | 4 | 3.3V | Register address within tile. |
| `tile_wdata[7:0]` | Spine → Tile | 8 | 3.3V | Write data to tile registers. |
| `tile_rdata[7:0]` | Tile → Spine | 8 | 3.3V | Read data from tile registers. |
| `tile_status[3:0]` | Tile → Spine | 4 | 3.3V | Status flags: [0]=busy, [1]=done, [2]=pass, [3]=error |
| `tile_irq` | Tile → Spine | 1 | 3.3V | Optional interrupt (done, error, threshold). Active-high. |
| `tile_pwr_good` | Tile → Spine | 1 | 3.3V | Local power is stable (from power-good detector or tie-high). |
| `VDD_3V3` | Power | — | 3.3V | Always-on 3.3V for tile digital wrapper. |
| `VDD_5V0` | Power | — | 5.0V | 5V supply for DUT (5V tiles only). Via group switch. |
| `VSS` | Power | — | GND | Common ground. |

**Total digital signals per tile:** 28 (excluding power). This is a modest routing budget — fits comfortably in the channel between spine and tile slot.

### 5.2 Tile Wrapper (Shell)

Every tile contains a standard **tile wrapper** that implements the spine interface and wraps the user-designed DUT:

```
┌─────────────────────────────────────────────────────┐
│                   TILE WRAPPER                       │
│                                                      │
│  ┌────────────────────────────┐                      │
│  │   Register Interface       │                      │
│  │   - 16 x 8-bit registers  │                      │
│  │   - addr decode            │                      │
│  │   - read mux               │                      │
│  └──────────┬─────────────────┘                      │
│             │                                        │
│  ┌──────────┴─────────────────┐                      │
│  │   Control FSM              │                      │
│  │   - DISABLED → IDLE →      │                      │
│  │     RUNNING → DONE/ERROR   │                      │
│  │   - timeout watchdog       │                      │
│  │   - auto-isolate on error  │                      │
│  └──────────┬─────────────────┘                      │
│             │  dut_ctrl / dut_status                  │
│             ▼                                        │
│  ┌────────────────────────────┐                      │
│  │                            │                      │
│  │     ANALOG DUT             │  ← User-designed     │
│  │     (experiment circuit)   │                      │
│  │                            │──── Analog I/O ──→ Pads
│  │                            │                      │
│  └────────────────────────────┘                      │
│                                                      │
│  ┌────────────────────────────┐                      │
│  │   Isolation Switches       │                      │
│  │   - disconnect DUT analog  │                      │
│  │     I/O when disabled      │                      │
│  └────────────────────────────┘                      │
│                                                      │
│  (optional) Level Shifters: 3.3V ↔ 5V               │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### 5.3 Tile Register Map (Internal to Each Tile)

Each tile wrapper exposes 16 registers via `tile_addr[3:0]`:

| Addr | Name | Access | Description |
|------|------|--------|-------------|
| 0x0 | TILE_ID | R | Tile type identifier (set at design time) |
| 0x1 | TILE_VERSION | R | Tile revision |
| 0x2 | TILE_CONTROL | RW | DUT mode[2:0], start[3], stop[4], clear_err[5] |
| 0x3 | TILE_STATUS | R | busy[0], done[1], pass[2], error[3], pwr_good[4], isolated[5] |
| 0x4 | TILE_PARAM_0 | RW | DUT parameter byte 0 (e.g., bias code low) |
| 0x5 | TILE_PARAM_1 | RW | DUT parameter byte 1 (e.g., bias code high) |
| 0x6 | TILE_PARAM_2 | RW | DUT parameter byte 2 (e.g., gain/mode) |
| 0x7 | TILE_PARAM_3 | RW | DUT parameter byte 3 (reserved/flags) |
| 0x8 | TILE_RESULT_0 | R | Result byte 0 |
| 0x9 | TILE_RESULT_1 | R | Result byte 1 |
| 0xA | TILE_RESULT_2 | R | Result byte 2 |
| 0xB | TILE_RESULT_3 | R | Result byte 3 |
| 0xC | TILE_DEBUG_0 | R | Debug observation byte 0 |
| 0xD | TILE_DEBUG_1 | R | Debug observation byte 1 |
| 0xE | TILE_ERROR | R | Error code (0 = none) |
| 0xF | TILE_SCRATCH | RW | Scratch register (connectivity test) |

**DUT designer responsibility:** Implement the analog circuit, connect it to the parameter inputs and result outputs, and assert `dut_done` when an operation completes. The wrapper handles everything else.

### 5.4 Tile Wrapper FSM

```
  DISABLED ──(tile_enable=1)──→ IDLE
     ↑                           │
  (enable=0)                  (start=1)
     │                           ↓
     │                        RUNNING
     │                       /       \
     │                  (dut_done)  (timeout)
     │                    /             \
     │                   ↓               ↓
     │                 DONE            ERROR
     │                   │               │
     │               (read result)   (read error)
     │                   │               │
     │                   └───────┬───────┘
     │                           │
     └───────────────────────────┘
                     (reset or disable)
```

---

## 6. UART Control Subsystem

### 6.1 Physical Interface

- **Baud rate:** 115200 (default), optionally configurable to 9600-921600
- **Format:** 8N1 (8 data bits, no parity, 1 stop bit)
- **Logic levels:** 3.3V (connects directly to Caravel GPIO pads)
- **Pins:** 2 — UART_TX (spine → host), UART_RX (host → spine)
- **No flow control** for v1. The command/response protocol is inherently half-duplex.

### 6.2 Command Protocol

**Recommended: simple ASCII-like binary protocol.** Each command is a single byte opcode followed by 0-2 argument bytes. Responses are 1-4 bytes. This balances human-readability (opcodes can be chosen as printable ASCII) with compactness.

| Command | Opcode | Args | Response | Description |
|---------|--------|------|----------|-------------|
| Read register | `R` (0x52) | addr[1] | data[1] | Read spine register |
| Write register | `W` (0x57) | addr[1], data[1] | `A` (0x41 = ACK) | Write spine register |
| Read tile reg | `T` (0x54) | tile[1], addr[1] | data[1] | Read tile register via spine |
| Write tile reg | `U` (0x55) | tile[1], addr[1], data[1] | `A` (ACK) | Write tile register via spine |
| Status query | `S` (0x53) | — | status[2] | Global status word |
| Ping | `P` (0x50) | — | `K` (0x4B = OK) | Connectivity test |
| Reset | `!` (0x21) | — | `A` (ACK) | Global soft reset |
| Error | — | — | `E` (0x45), code[1] | Error response |

**Why this protocol:**
- Single-letter opcodes are easy to type in a serial terminal for manual debug
- Fixed-length commands (no variable-length framing needed)
- No escape sequences, no packet CRC for v1 (simplicity over robustness)
- A CRC-protected binary protocol can be added later as an optional mode
- Total command decoder: ~200-400 gates, well within budget

### 6.3 Command Decoder Architecture

```
  UART_RX → [UART Core] → rx_byte, rx_valid
                              │
                              ▼
                     [Command FSM]
                     State: IDLE → OPCODE → ARG1 → ARG2 → EXECUTE → RESPOND
                              │
                              ├── Register read/write (spine-local)
                              ├── Tile register read/write (via tile_addr bus)
                              └── Status/ping/reset
                              │
                              ▼
                     [Response Mux] → tx_byte, tx_valid → [UART Core] → UART_TX
```

### 6.4 Built-In Self-Test Hooks

The UART subsystem includes optional debug counters:
- `UART_RX_COUNT`: Total bytes received (wraps at 255)
- `UART_TX_COUNT`: Total bytes transmitted
- `UART_ERR_COUNT`: Framing/overrun errors
- `UART_LAST_CMD`: Last opcode received

These are readable as spine registers and help diagnose communication problems.

---

## 7. Register Map Concept

### 7.1 Spine Register Map

The spine exposes a flat 8-bit address space (256 registers). Most are reserved. The v1 map:

| Addr | Name | Access | Description |
|------|------|--------|-------------|
| **Global** | | | |
| 0x00 | CHIP_ID_0 | R | Chip ID byte 0 (ASCII 'U') |
| 0x01 | CHIP_ID_1 | R | Chip ID byte 1 (ASCII 'L') |
| 0x02 | CHIP_ID_2 | R | Chip ID byte 2 (ASCII 'C') |
| 0x03 | CHIP_VERSION | R | Version (0x10 = v1.0) |
| **Power/Status** | | | |
| 0x04 | POWER_STATUS | R | 3v3_ok[0], 5v0_ok[1], tiles_pwr_west[2], east[3], south[4] |
| 0x05 | POWER_CONTROL | RW | tile_pwr_west_en[0], east_en[1], south_en[2], 5v0_en[3] |
| 0x06 | GLOBAL_STATUS | R | any_busy[0], any_done[1], any_error[2], uart_ok[3] |
| 0x07 | BOOT_STATUS | R | reset_cause[1:0], seq_ok[2], first_boot[3] |
| **Clock/Reset** | | | |
| 0x08 | CLK_CONTROL | RW | clk_src[1:0], clk_div[3:2], spare[7:4] |
| 0x09 | RST_CONTROL | RW | soft_reset[0](SC), tile_reset_all[1](SC) |
| **Tile Select** | | | |
| 0x0A | TILE_SELECT | RW | tile_id[4:0] — selects active tile for T/U commands |
| 0x0B | TILE_ENABLE_W | RW | Per-tile enable mask for west group (bit per tile) |
| 0x0C | TILE_ENABLE_E | RW | Per-tile enable mask for east group |
| 0x0D | TILE_ENABLE_S | RW | Per-tile enable mask for south group |
| **Selected Tile Shortcut** | | | |
| 0x10 | TILE_STATUS | R | Status of TILE_SELECT'd tile (mirror of tile's reg 0x3) |
| 0x11 | TILE_RESULT_0 | R | Result byte 0 of selected tile |
| 0x12 | TILE_RESULT_1 | R | Result byte 1 of selected tile |
| 0x13 | TILE_RESULT_2 | R | Result byte 2 of selected tile |
| 0x14 | TILE_RESULT_3 | R | Result byte 3 of selected tile |
| **Error Tracking** | | | |
| 0x18 | ERROR_FLAGS | R | Aggregated error flags (1 bit per tile group) |
| 0x19 | ERROR_TILE | R | Tile ID of first tile that flagged error |
| 0x1A | ERROR_CODE | R | Error code from that tile |
| **UART Debug** | | | |
| 0x1C | UART_RX_COUNT | R | Bytes received (wrapping) |
| 0x1D | UART_TX_COUNT | R | Bytes transmitted |
| 0x1E | UART_ERR_COUNT | R | Framing/overrun errors |
| 0x1F | UART_LAST_CMD | R | Last opcode byte |
| **Tile Direct Access** | | | |
| 0x20-0x2F | TILE_REG[0:15] | RW | Direct window into TILE_SELECT'd tile's 16 registers |
| **Reserved** | | | |
| 0x30-0xFF | — | — | Reserved for future expansion |

**Total active registers: ~48.** The 8-bit address space leaves ample room for expansion.

### 7.2 Addressing Model

Two ways to access tile registers:

1. **UART T/U commands:** Specify tile ID and register address directly in the command. Fast, no setup required.
2. **Register window:** Write tile ID to `TILE_SELECT`, then read/write `TILE_REG[0:15]` at spine addresses 0x20-0x2F. Useful for sequential register access within one tile.

Both methods reach the same tile registers through the same bus.

---

## 8. Clock/Reset Strategy

### 8.1 Clock Architecture

**v1: External clock input with optional on-chip RC oscillator fallback.**

```
  CLK_EXT pin ─────┐
                    │
  RC Oscillator ───┐│
  (rough, ~1 MHz)  ││
                   ▼▼
              [Clock Mux]──→ sys_clk ──→ Spine logic
               (CLK_CONTROL         ──→ [Per-tile clock gate] ──→ tile_clk[N]
                selects source)
```

- **External clock:** 1-25 MHz from an off-chip oscillator or function generator. This is the expected primary clock for bring-up. Connect to a dedicated CLK_EXT pad (north edge).
- **Internal RC oscillator:** A simple current-starved ring oscillator (~1 MHz, ±30% accuracy). Sufficient for UART at 9600 baud. Not accurate enough for high-speed operation, but ensures the chip is alive even without an external clock.
- **Clock mux:** 2:1 mux controlled by `CLK_CONTROL[1:0]`. Default on reset: internal RC (guarantees UART responsiveness on power-up).
- **No PLL in v1 boot path.** A PLL may exist as an experiment tile, but it is not in the clock tree. The spine runs directly from the mux output.

### 8.2 Clock Gating

Each tile has a dedicated clock gate (ICG cell or AND gate):

```
  sys_clk ──┐
             AND ──→ tile_clk[N]
  tile_en ──┘
```

When `tile_enable = 0`, the tile clock stops. This:
- Saves dynamic power from disabled tiles
- Eliminates switching noise from idle tiles
- Requires no special enable-synchronization because tiles must be reset after enable anyway

### 8.3 Reset Architecture

**Two reset sources:**
1. **External RST_N pin:** Active-low, directly from north-edge pad. Asynchronous assert, synchronous deassert (standard 2-FF synchronizer on release).
2. **Software reset:** Write `RST_CONTROL.soft_reset = 1` (self-clearing). Triggers same reset sequence as hardware reset.

**Reset distribution:**
- Global reset clears all spine registers to defaults and asserts reset to all tiles
- Per-tile reset available via `tile_reset_n` — resets one tile without affecting others or spine state
- `RST_CONTROL.tile_reset_all` resets all tiles but not the spine itself (useful for re-initializing experiments without losing UART state)

**Reset default state:**
- All tile enables = 0 (tiles disabled)
- All power group enables = 0 (power gates open)
- Clock source = internal RC oscillator
- UART active, waiting for commands
- All error flags cleared

### 8.4 Why This Is Appropriate

A first learning chip should avoid making the clock or reset system a debugging challenge itself. The external clock + mux + per-tile gating approach:
- Works with any signal generator or cheap crystal oscillator module
- Has zero analog design risk (no PLL in boot path)
- Is fully deterministic (no lock time, no frequency uncertainty beyond the external source)
- Degrades gracefully: even with only the internal RC, the chip can communicate via low-baud UART

---

## 9. Analog and Noise-Isolation Concerns

### 9.1 Digital Noise Management

The central spine is the noisiest block on the chip (highest switching density). Centralizing it provides a key advantage: **all digital switching noise comes from one known, bounded region.** The perimeter tiles can be placed with physical distance from the spine, and guard structures can be inserted in the channel between spine and tiles.

**Mitigation strategies:**

- **Dedicated spine decoupling:** Place MIM/MOS capacitors (total ~100pF) along the spine's VDD_3V3/VSS rails. These absorb transient current spikes from register clocking and UART toggling.
- **Guard ring around spine:** A continuous P+ substrate tap ring around the spine perimeter shorts substrate noise to VSS locally, preventing it from propagating laterally to tiles.
- **Spine-to-tile channel:** The routing channel between the spine and each tile slot should include a VSS shield stripe (M3 or M4) that acts as a Faraday-like barrier.
- **Return-current awareness:** Spine ground currents return through the central VSS mesh. Tile ground currents return through their local VSS connections. These return paths should not share the same narrow metal stripe — use separate VSS taps for spine and tile regions.

### 9.2 Tile-to-Tile Isolation

Tiles are physically separated around the perimeter. Between adjacent tile slots, include:
- **Guard ring:** P+ substrate tap ring (minimum 5um wide) between every pair of adjacent tiles
- **VSS stripe:** A metal VSS stripe running between tile slots on M3/M4
- **No shared analog metal:** Analog routing within one tile must not extend into the neighboring tile's region

### 9.3 5V / 3.3V Domain Isolation

The physical separation of 5V tiles (west) from 3.3V tiles (east) provides natural noise isolation:
- 5V switching transients occur on the west side, 3.3V-sensitive circuits are on the east side
- The central spine (3.3V digital, well-decoupled) acts as a physical buffer between the two analog domains
- South-side flexible tiles are the only region where 5V and 3.3V tiles may be adjacent — place guard rings more aggressively here

### 9.4 Sensitive Tile Placement

For especially sensitive analog tiles (precision ADC, low-noise amplifier, reference voltage):
- Place on the east side (3.3V domain, less switching noise from 5V power gating)
- Place as far from the spine as possible (corners are ideal for lowest noise)
- Ensure the tile's analog I/O pads are on the die edge closest to the tile, minimizing routing over noisy regions

For noisy tiles (ring oscillators, switching regulators, digital test structures):
- Place adjacent to the spine where digital noise is already present
- Or place in the south flexible zone where isolation constraints are more relaxed

---

## 10. Floorplanning Guidance

### 10.1 Die Budget

Caravel user area: approximately 2.9mm x 3.5mm = ~10 mm².

| Block | Budget | Notes |
|-------|--------|-------|
| Central spine | ~1.0 mm² (10%) | ~0.3mm wide x 3.5mm tall |
| Spine-to-tile channels | ~1.0 mm² (10%) | Routing, guard rings, decoupling |
| Tile slots (all sides) | ~6.0 mm² (60%) | 12-16 tile slots, ~0.4-0.5 mm² each |
| Corners | ~0.4 mm² (4%) | Power pad clusters, decoupling, test structures |
| Power trunks / margin | ~1.6 mm² (16%) | Metal stripes, filler, DRC margin |

### 10.2 Tile Slot Sizing

**Target tile slot: ~400um x 500um = 0.2 mm²** (including guard rings and local routing). This fits:
- Digital wrapper: ~100um x 200um (~2000 gates)
- Analog DUT: ~300um x 300um (ample for most experiments)
- Isolation switches, level shifters, decoupling

With this sizing:
- West edge (3.5mm tall): 5-6 tile slots
- East edge (3.5mm tall): 5-6 tile slots
- South edge (2.9mm wide, minus spine): 3-4 tile slots
- **Total: 13-16 tile slots**

### 10.3 Detailed Floor Plan with Power Stripe Organization

The diagram below shows the full die with power trunks running north-to-south, the central spine, all tile slots, and the pad ring. Power stripes are drawn as vertical bands on M4/M5.

```
                                    2.9 mm
         ←─────────────────────────────────────────────────→

         N0   N1   N2   N3   N4   N5   N6   N7   N8   N9  N10  N11  N12  N13
         VDD  VSS  TX   RX   CLK  RST  SCK  MOSI MISO CS   DBG0 DBG1 5V0  VSS
         ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐ ─┐
         │pwr │gnd │dig │dig │clk │dig │dig │dig │dig │dig │dig │dig │pwr │gnd │  │ NORTH
         │    │    │    │    │    │    │    │    │    │    │    │    │    │    │  │ PAD
         ├────┴────┴────┴──┬─┴────┴────┴────┴────┴────┴──┬─┴────┴────┴────┴────┤ ─┘ RING
         │                 │                              │                     │
         │  5V POWER       │    3.3V SPINE POWER          │    3.3V POWER       │
         │  TRUNK          │    TRUNK                     │    TRUNK            │
         │  (M5, ~25um)    │    (M5, ~25um)               │    (M5, ~25um)      │
         │  ║               │    ║                          │               ║     │
    ─┐   │  ║  ┌────────┐  │  ┌─╨──────────────────┐  │  ┌────────┐  ║     │   ─┐
     │   │  ║  │        │  │  │                      │  │  │        │  ║     │    │
     │   │  ╠══╡  W5    │←─╫──╢   UART Core         ╟──╫─→│  E0    ╞══╣     │    │
     │   │  ║  │  (5V)  │  │  │      │              │  │  │  (3.3V)│  ║     │    │
W    │   │  ║  └────────┘  │  │ ┌────┴─────────┐    │  │  └────────┘  ║     │    │   E
E    │   │  ║  ┌────────┐  │  │ │ Cmd Decoder   │    │  │  ┌────────┐  ║     │    │   A
S    │   │  ╠══╡  W4    │←─╫──╢ └────┬─────────┘    ╟──╫─→│  E1    ╞══╣     │    │   S
T    │   │  ║  │  (5V)  │  │  │      │              │  │  │  (3.3V)│  ║     │    │   T
     │   │  ║  └────────┘  │  │ ┌────┴─────────┐    │  │  └────────┘  ║     │    │
P    │   │  ║  ┌────────┐  │  │ │ Register Bank │    │  │  ┌────────┐  ║     │    │   P
A    │   │  ╠══╡  W3    │←─╫──╢ │ (spine regs)  │    ╟──╫─→│  E2    ╞══╣     │    │   A
D    │   │  ║  │  (5V)  │  │  │ └────┬─────────┘    │  │  │  (3.3V)│  ║     │    │   D
S 3.5│   │  ║  └────────┘  │  │      │              │  │  └────────┘  ║     │ 3.5│   S
  mm │   │  ║  ┌────────┐  │  │ ┌────┴─────────┐    │  │  ┌────────┐  ║     │ mm │
     │   │  ╠══╡  W2    │←─╫──╢ │ Tile I/F Ctrl │    ╟──╫─→│  E3    ╞══╣     │    │
     │   │  ║  │  (5V)  │  │  │ │ (mux/decode)  │    │  │  │  (3.3V)│  ║     │    │
     │   │  ║  └────────┘  │  │ └────┬─────────┘    │  │  └────────┘  ║     │    │
     │   │  ║  ┌────────┐  │  │      │              │  │  ┌────────┐  ║     │    │
     │   │  ╠══╡  W1    │←─╫──╢ ┌────┴─────────┐    ╟──╫─→│  E4    ╞══╣     │    │
     │   │  ║  │  (5V)  │  │  │ │ Clk/Rst Gen   │    │  │  │  (3.3V)│  ║     │    │
     │   │  ║  └────────┘  │  │ └──────────────┘    │  │  └────────┘  ║     │    │
     │   │  ║  ┌────────┐  │  │                      │  │  ┌────────┐  ║     │    │
     │   │  ╠══╡  W0    │←─╫──╢                      ╟──╫─→│  E5    ╞══╣     │    │
     │   │  ║  │  (5V)  │  │  │                      │  │  │  (3.3V)│  ║     │   ─┘
    ─┘   │  ║  └────────┘  │  └──────────┬───────────┘  │  └────────┘  ║     │
         │  ║               │              │              │               ║     │
         ├──╨──┬────────┬──┴──┬────────┬──┴──┬────────┬──┴──┬────────┬──╨─────┤ ─┐
         │ CNR │  S0    │     │  S1    │     │  S2    │     │  S3    │  CNR   │  │ SOUTH
         │  W  │ (flex) │     │ (flex) │     │ (flex) │     │ (flex) │   E    │  │ TILES
         ├─────┴────────┴─────┴────────┴─────┴────────┴─────┴────────┴────────┤ ─┘
         │ SW0  SW1  SW2  SW3  SS0  SS1  SS2  SS3  SE0  SE1  SE2  SE3        │
         │ 5V   gnd  ana  ana  gnd  ana  ana  gnd  ana  ana  gnd  3v3        │ SOUTH
         └────────────────────────────────────────────────────────────────────┘ PAD RING

    ═══  VDD_5V0 power trunk (M5, west side)       ← 5V domain
    ═══  VDD_3V3 power trunk (M5, center + east)   ← 3.3V domain
    ←──→ Digital control bus (28 signals, M1/M2)    ← Spine ↔ Tile
    VSS ground mesh covers entire die (M4 horiz + M5 vert, not drawn)
```

**Power stripe cross-section (east-west cut through middle of die):**

```
    WEST PADS                                                      EAST PADS
    │                                                                     │
    │   5V          5V                 3.3V                3.3V     3.3V  │
    │   trunk       tile local         spine               tile     trunk │
    │   (M5)        (M3/M4)           (M5)                local    (M5)  │
    │    ║           ║                  ║                    ║        ║    │
    ▼    ▼           ▼                  ▼                    ▼        ▼    ▼
   ─────╫───────────╫──────────────────╫────────────────────╫────────╫─────
   VSS  ║   ┌───────╨────────┐  ┌─────╨──────┐  ┌─────────╨──┐    ║  VSS
   mesh ║   │   WEST TILE    │  │   DIGITAL   │  │  EAST TILE  │    ║  mesh
        ║   │   (5V DUT)     │  │   SPINE     │  │  (3.3V DUT) │    ║
        ║   │                │  │   (3.3V)    │  │              │    ║
        ║   │  ┌──────────┐  │  │             │  │  ┌────────┐ │    ║
        ║   │  │ 5V DUT   │  │  │  registers  │  │  │3.3V DUT│ │    ║
        ║───┤  │ circuit   │  │  │  UART ctrl  │  │  │ circuit │ ├───║
        ║   │  └──────────┘  │  │  tile I/F    │  │  └────────┘ │    ║
        ║   │  ┌──────────┐  │  │  clk/rst     │  │             │    ║
        ║   │  │3.3V wrap │  │  │             │  │             │    ║
        ║   │  │(digital)  │  │  │             │  │             │    ║
        ║   │  └──────────┘  │  │             │  │             │    ║
   ─────╫───└────────────────┘──└─────────────┘──└─────────────┘────╫─────
        ║        guard ring      guard ring       guard ring         ║
        ║                                                            ║

    5V power flows:   N12 pad → west M5 trunk → drops into west tile VDD_5V0
    3.3V power flows: N0 pad  → center M5 trunk (spine) + east M5 trunk → east tiles
    VSS flows:        N1/N13 pads → full-die M4/M5 mesh → all blocks
```

### 10.4 Corner Usage

| Corner | Recommended Use |
|--------|----------------|
| Northwest (CNR_NW) | VDD_5V0 entry decoupling, 5V group power gate PMOS |
| Northeast (CNR_NE) | VDD_3V3 analog decoupling, 3.3V group power gate |
| Southwest (CNR_W) | 5V/VSS pad cluster, process corner test structures |
| Southeast (CNR_E) | 3.3V/VSS pad cluster, digital scan test structures |

### 10.5 Complete Pad Ring and Tile-to-Pad Mapping

The Caravel frame provides 38 configurable GPIO pads. Below is the full pad allocation showing which pads connect to which tiles.

**North edge pads (digital, directly into spine):**

```
    ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
    │ N0 │ N1 │ N2 │ N3 │ N4 │ N5 │ N6 │ N7 │ N8 │ N9 │N10 │N11 │N12 │N13 │
    │VDD │VSS │ TX │ RX │CLK │RST │SCK │MOSI│MISO│ CS │DBG0│DBG1│5V0 │VSS │
    │3V3 │    │    │    │EXT │ N  │    │    │    │  N │    │    │    │    │
    └──┬─┴──┬─┴──┬─┴──┬─┴──┬─┴──┬─┴──┬─┴──┬─┴──┬─┴──┬─┴──┬─┴──┬─┴──┬─┴──┬─┘
       │    │    │    │    │    │    │    │    │    │    │    │    │    │
       │    │    └──┬─┘    │    │    └────────┬────────┘    │    │    │
       │    │       │      │    │             │             │    │    │
       ▼    ▼       ▼      ▼    ▼             ▼             ▼    ▼    ▼
    ┌──────────────────────────────────────────────────────────────────────┐
    │ VDD_3V3─→spine  UART─→spine  CLK─→spine  SPI─→spine(v2)  VDD_5V0  │
    │ VSS─→mesh       RST─→spine                    DBG─→spine  VSS─→mesh│
    └──────────────────────────────────────────────────────────────────────┘
                         SPINE (north interface)
```

**West edge pads (5V tile analog I/O):**

Each west tile has 1-2 dedicated analog pads on the west die edge for direct DUT connections.

```
                WEST DIE EDGE
    ┌─────┐
    │WP0  │ VDD_5V0  ─→ west power trunk (redundant 5V entry)
    ├─────┤
    │WP1  │ VSS      ─→ west ground tap
    ├─────┤                           ┌─────────┐
    │WP2  │ W5_ANA0 ─────────────────→│  W5     │
    ├─────┤                           │  (5V    │
    │WP3  │ W5_ANA1 ─────────────────→│  tile)  │
    ├─────┤                           └─────────┘
    │WP4  │ W4_ANA0 ─────────────────→┌─────────┐
    ├─────┤                           │  W4     │
    │WP5  │ W4_ANA1 ─────────────────→│  (5V)   │
    ├─────┤                           └─────────┘
    │WP6  │ W3_ANA0 ─────────────────→┌─────────┐
    ├─────┤                           │  W3     │
    │WP7  │ W3_ANA1 ─────────────────→│  (5V)   │
    ├─────┤                           └─────────┘
    │WP8  │ W2_ANA0 ─────────────────→┌─────────┐
    ├─────┤                           │  W2     │
    │WP9  │ W2_ANA1 ─────────────────→│  (5V)   │
    ├─────┤                           └─────────┘
    │WP10 │ W1_ANA0 ─────────────────→┌─────────┐
    ├─────┤                           │  W1     │
    │WP11 │ W1_ANA1 ─────────────────→│  (5V)   │
    ├─────┤                           └─────────┘
    │WP12 │ W0_ANA0 ─────────────────→┌─────────┐
    ├─────┤                           │  W0     │
    │WP13 │ W0_ANA1 ─────────────────→│  (5V)   │
    └─────┘                           └─────────┘

    West pads: 2 power + 12 analog = 14 pads
    Each tile gets 2 analog pads (input + output or 2x observation)
```

**East edge pads (3.3V tile analog I/O):**

```
                                                        EAST DIE EDGE
                                                        ┌─────┐
    3.3V entry (redundant) ─────────────────────────────│EP0  │ VDD_3V3
                                                        ├─────┤
    east ground tap ────────────────────────────────────│EP1  │ VSS
    ┌─────────┐                                         ├─────┤
    │  E0     │─────────────────────────────────────────│EP2  │ E0_ANA0
    │  (3.3V  │─────────────────────────────────────────│EP3  │ E0_ANA1
    │  tile)  │                                         ├─────┤
    └─────────┘                                         │     │
    ┌─────────┐                                         │     │
    │  E1     │─────────────────────────────────────────│EP4  │ E1_ANA0
    │  (3.3V) │─────────────────────────────────────────│EP5  │ E1_ANA1
    └─────────┘                                         ├─────┤
    ┌─────────┐                                         │     │
    │  E2     │─────────────────────────────────────────│EP6  │ E2_ANA0
    │  (3.3V) │─────────────────────────────────────────│EP7  │ E2_ANA1
    └─────────┘                                         ├─────┤
    ┌─────────┐                                         │     │
    │  E3     │─────────────────────────────────────────│EP8  │ E3_ANA0
    │  (3.3V) │─────────────────────────────────────────│EP9  │ E3_ANA1
    └─────────┘                                         ├─────┤
    ┌─────────┐                                         │     │
    │  E4     │─────────────────────────────────────────│EP10 │ E4_ANA0
    │  (3.3V) │─────────────────────────────────────────│EP11 │ E4_ANA1
    └─────────┘                                         ├─────┤
    ┌─────────┐                                         │     │
    │  E5     │─────────────────────────────────────────│EP12 │ E5_ANA0
    │  (3.3V) │─────────────────────────────────────────│EP13 │ E5_ANA1
    └─────────┘                                         └─────┘

    East pads: 2 power + 12 analog = 14 pads
```

**South edge pads (flexible tile analog I/O + power):**

```
    ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
    │  S0     │  │  S1     │  │  S2     │  │  S3     │
    │ (flex)  │  │ (flex)  │  │ (flex)  │  │ (flex)  │
    └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘
         │            │            │            │
    ┌────▼────┬───────▼──┬────────▼──┬─────────▼──┬──────────┐
    │SP0 SP1 │SP2  SP3  │SP4  SP5  │SP6  SP7   │SP8  SP9  │  SOUTH
    │5V0 VSS │S0a  S0a  │S1a  S1a  │S2a  S2a   │S3a  S3a  │  PAD
    │pwr gnd │ana0 ana1 │ana0 ana1 │ana0 ana1  │ana0 ana1  │  RING
    └────────┴──────────┴──────────┴───────────┴───────────┘

    South pads: 2 power + 8 analog = 10 pads
```

### 10.6 Full Pad Budget Summary

| Edge | Pad Count | Breakdown |
|------|-----------|-----------|
| North | 14 | 2 power (VDD_3V3, VSS) + 1 power (VDD_5V0) + 1 ground + 6 digital (UART, CLK, RST) + 4 digital (SPI/spare) |
| West | 14 | 2 power (VDD_5V0, VSS) + 12 analog (2 per tile × 6 tiles) |
| East | 14 | 2 power (VDD_3V3, VSS) + 12 analog (2 per tile × 6 tiles) |
| South | 10 | 2 power (VDD_5V0, VSS) + 8 analog (2 per tile × 4 tiles) |
| **Total** | **52** | **8 power/ground + 6 digital spine + 4 SPI/spare + 32 tile analog + 2 debug** |

**Note:** Caravel provides 38 GPIO pads. The budget above exceeds 38 by using additional dedicated analog and power pads from the Caravel analog pin allocation (Caravel provides separate analog pads outside the GPIO count). If constrained to 38, reduce to 1 analog pad per tile (22 tile pads) and consolidate power entries.

### 10.7 Physical Connectivity Map — Spine to All Tiles

This diagram shows the digital control bus fan-out from the spine to every tile, plus the power trunk taps.

```
                    ┌──────────────────────────────┐
                    │         DIGITAL SPINE          │
                    │                                │
                    │  ┌─────────────────────────┐   │
                    │  │  Tile Interface Ctrl     │   │
                    │  │                          │   │
                    │  │  tile_select[4:0] ──→ decode │
                    │  │          │                │   │
                    │  │    ┌─────┴──────┐         │   │
                    │  │    │ 16:1 MUX   │         │   │
                    │  │    │ (one-hot   │         │   │
                    │  │    │  enables)  │         │   │
                    │  │    └──┬──┬──┬───┘         │   │
                    │  └───────┼──┼──┼─────────────┘   │
                    │          │  │  │                  │
                    └──────────┼──┼──┼──────────────────┘
                      ┌────────┘  │  └────────┐
                      │           │           │
              ┌───────┴──┐  ┌────┴────┐  ┌───┴───────┐
              │ WEST BUS  │  │SOUTH BUS│  │ EAST BUS  │
              │ (active    │  │(active  │  │ (active   │
              │  when W    │  │ when S  │  │  when E   │
              │  selected) │  │ select) │  │  selected)│
              └─┬──┬──┬──┬┘  └┬──┬──┬─┘  └┬──┬──┬──┬─┘
                │  │  │  │    │  │  │     │  │  │  │
                ▼  ▼  ▼  ▼    ▼  ▼  ▼     ▼  ▼  ▼  ▼

  28 signals per tile:
  ┌────────────────────────────────────────────────────────────┐
  │ tile_clk     ──→  (gated sys_clk)                         │
  │ tile_reset_n ──→  (from spine reset controller)            │
  │ tile_enable  ──→  (from TILE_ENABLE_W/E/S register bit)   │
  │ tile_addr[3:0]──→ (from spine register access logic)      │
  │ tile_wdata[7:0]──→(write data bus, active on cfg_wr)      │
  │ tile_cfg_wr  ──→  (write strobe, one cycle pulse)         │
  │ ←── tile_rdata[7:0] (read data, active one cycle later)   │
  │ ←── tile_status[3:0] (busy/done/pass/error, continuous)   │
  │ ←── tile_irq         (edge-sensitive interrupt)            │
  │ ←── tile_pwr_good    (power-good from local detector)     │
  └────────────────────────────────────────────────────────────┘

  Power per tile (physical, not digital bus):
  ┌────────────────────────────────────────────────────────────┐
  │ VDD_3V3 ── always connected (wrapper logic)                │
  │ VDD_5V0 ── through group PMOS switch (5V tiles only)       │
  │ VSS     ── always connected (ground mesh)                  │
  └────────────────────────────────────────────────────────────┘
```

**How a UART command reaches a tile:**

```
  Host serial terminal
       │
       │  "T 05 02"  (read tile 5, register 0x2)
       ▼
    UART_RX pad (N3)
       │
       ▼
    UART Core (deserialize)
       │
       ▼
    Command Decoder (parse opcode 'T', tile=5, addr=2)
       │
       ├──→ TILE_SELECT = 5      (selects E5 in east group)
       ├──→ tile_addr = 0x2      (TILE_CONTROL register)
       ├──→ tile_cfg_wr = 0      (this is a read)
       │
       ▼
    Tile Interface Controller
       │
       ├──→ asserts chip-select for tile E5
       ├──→ drives tile_addr[3:0] = 0x2 on east bus
       ├──→ waits 1 cycle
       ├──→ captures tile_rdata[7:0] from E5's wrapper
       │
       ▼
    Response Mux
       │
       ├──→ sends rdata byte to UART Core
       │
       ▼
    UART_TX pad (N2)
       │
       ▼
    Host sees response byte
```

### 10.8 Routing Practicality

- **Spine-to-tile digital signals:** Route on M1/M2 through the channel between spine and tile slots. 28 signals per tile × ~1um pitch = ~28um channel width. Budget 50-80um for the channel including guard rings and power taps.
- **Power trunks:** M4/M5, running vertically (north-south) along west edge, center, and east edge. Each trunk ~25um wide.
- **Power trunk taps:** Drop from M5 trunk to M3/M4 local distribution within each tile. Use vias at regular intervals (~200um spacing).
- **VSS mesh:** M4 horizontal + M5 vertical grid, ~50um pitch, covering entire die.
- **Analog signals within tiles:** Route on M3/M4 within the tile's bounding box. Do not cross tile boundaries. Each tile's analog pads are on the nearest die edge — routing distance is minimal (~100-400um).
- **Analog pads:** Tiles on the west/east/south edges have direct access to die-edge pads on their outward side. Analog routing stays within the tile's footprint and exits perpendicular to the die edge.
- **Cross-die routing avoided:** No analog signal crosses the spine. No 5V signal crosses into the 3.3V east region. South flexible tiles may carry either domain but are locally contained.

---

## 11. First-Version Recommendations

### 11.1 Definitely Include (MVP)

| Feature | Rationale |
|---------|-----------|
| Central digital spine with UART | Core controllability — required for any bring-up |
| Register map (global + tile window) | Software interface for all control and observation |
| 14-16 tile slots with standard interface | Provides experiment capacity |
| Per-tile enable, reset, clock gate | Minimum viable tile control |
| Group power gating (west/east/south) | Safe power management without excessive complexity |
| 3.3V + 5V dual-rail power distribution | Enables both voltage domains for experiments |
| External clock input + internal RC fallback | Reliable clocking without PLL dependency |
| Global reset + per-tile reset | Deterministic initialization |
| Guard rings between all tiles | Noise isolation |
| 3-4 simple experiment tiles (known-good designs) | Ensures at least some tiles work on first silicon |
| UART debug counters | Helps diagnose communication issues |

### 11.2 Postpone to v2

| Feature | Why Postpone |
|---------|-------------|
| USB interface | Not needed for bring-up; adds significant complexity (SIE, PHY, CDC stack) |
| SPI slave interface | UART is sufficient for v1 throughput; SPI adds another test surface |
| PLL | Complex analog block; better as a tile experiment than boot dependency |
| Per-tile power gating | Group gating is sufficient; per-tile adds area and gate-driver complexity |
| CRC on UART protocol | Simple protocol is easier to debug; add CRC as optional mode later |
| DMA or burst transfer | Not needed at 115200 baud throughput |
| Supply sequencing hardware | Enforce via procedure in v1; add supervisor in v2 |
| On-chip ADC/DAC for tile measurement | Use external instruments for v1; integrate shared ADC/DAC in v2 |
| Scan chain / JTAG | Useful but not essential with UART register access |

### 11.3 Optional (Include If Effort Is Low)

| Feature | Notes |
|---------|-------|
| SPI slave pads (active but not populated in v1) | Reserve the pads; implement SPI logic only if gate budget allows |
| Chip ID in one-hot fuse / metal option | Zero risk, useful for identifying samples |
| Watchdog timer | Simple counter, ~50 gates, auto-resets if spine hangs |
| LED driver output | One GPIO driving an off-chip LED for heartbeat — useful for "is it alive?" |
| Analog mux to spare pad | Route one observation point from any tile to a spare pad for scope probing |

---

## 12. Deliverables

### A. Concise Architecture Summary

The ULC v1 is a learning-oriented mixed-signal experimentation chip on SKY130 (Caravel shuttle). It uses a **central digital spine** running north-to-south as the control backbone, surrounded by a **perimeter ring of 14-16 experiment tile slots** on the west, east, and south edges. The north edge carries digital I/O pads. The spine provides UART-based register access, per-tile enable/reset/clock control, group power gating, and status aggregation. Tiles conform to a standard 28-signal interface and contain a reusable digital wrapper plus a user-designed analog DUT. Power is dual-rail (3.3V + 5V) with west-side tiles favoring 5V and east-side tiles favoring 3.3V. First bring-up requires only a 3.3V supply and a UART connection.

### B. Prioritized Feature List for v1

1. UART control subsystem (command decoder, register interface)
2. Spine register map (global control, tile select, status aggregation)
3. Tile interface standard (28-signal bus, wrapper FSM, internal registers)
4. Clock system (external clock + internal RC + mux + per-tile gating)
5. Reset system (external pin + software reset + per-tile reset)
6. Group power gating (3 groups: west, east, south)
7. Power distribution (3.3V spine, 3.3V east trunk, 5V west trunk, VSS mesh)
8. 3-4 known-good experiment tiles (ring oscillator, current mirror, resistor DAC, digital loopback)
9. Guard rings and noise isolation structures
10. Debug features (UART counters, status registers, spare pad mux)

### C. Major Technical Risks

| # | Risk | Impact | Likelihood | Mitigation |
|---|------|--------|-----------|------------|
| 1 | 5V supply back-powering 3.3V domain through protection diodes | Spine damage or latch-up | Medium | Enforce supply sequencing; include series resistance on cross-domain paths |
| 2 | Internal RC oscillator frequency too far off for UART | Cannot communicate at boot | Low | Use conservative baud rate (9600) with RC; switch to external clock ASAP |
| 3 | Group power gate PMOS sizing insufficient | Excessive IR drop to tiles | Low | Oversize PMOS (W=100u); characterize worst-case tile current |
| 4 | Substrate noise from spine corrupts sensitive analog tiles | Failed analog experiments | Medium | Guard rings, physical separation, dedicated decoupling, careful placement |
| 5 | Tile wrapper bug affects all tiles | All tiles non-functional | Medium | Thorough simulation; include one digital-loopback tile that tests wrapper independently |
| 6 | 5V thick-oxide device models inaccurate in SKY130 | 5V tiles don't work as designed | Medium | Conservative design margins; test 5V devices in a simple tile first |
| 7 | Pad ring routing congestion at north edge | Cannot connect all signals | Low | Budget pad allocation early; use Caravel GPIO mux for flexibility |
| 8 | Metal density violations on power trunks | DRC failures blocking tapeout | Low | Add fill patterns; check density rules early |

### D. Open Design Decisions

1. **Exact tile count and allocation:** How many tiles per side? Which specific experiments in v1?
2. **Internal RC oscillator design:** Use ring oscillator or relaxation oscillator? Target frequency?
3. **PMOS header sizing:** Final W/L based on per-tile current budget (need tile current estimates)
4. **South-side tile domain assignment:** Which south tiles are 5V vs 3.3V?
5. **Analog pad allocation:** Which die-edge pads are analog I/O for which tiles?
6. **Shared measurement resources:** Include a shared analog mux + spare pad for observation, or defer?
7. **UART baud rate detection:** Fixed 115200, or auto-baud? (recommend fixed for simplicity)
8. **Tile scratch register test:** Require each tile to pass scratch R/W test at bring-up, or optional?
9. **Watchdog timer:** Include or defer?
10. **Metal stack usage:** Confirm M5 is available in Caravel user area for power trunks

### E. Suggested Block Diagram (with power and pad connectivity)

```
    N0   N1   N2   N3   N4   N5        N6-N9         N10  N11  N12  N13
    VDD  VSS  TX   RX   CLK  RST       SPI(v2)       DBG  DBG  5V0  VSS
     │    │    │    │    │    │          │              │    │    │    │
     │    │    └──┬─┘    │    │          │              │    │    │    │
     ▼    ▼       ▼      ▼    ▼          ▼              ▼    ▼    ▼    ▼
    ═══VDD_3V3═══════════════════════════════════════════════VDD_5V0═══
    ═══VSS mesh══════════════════════════════════════════════VSS mesh══
     │                                                            │
     │  5V trunk (M5)                          3.3V trunk (M5)    │
     │    ║                                           ║           │
     │    ║  WP2───→┌──────┐  ┌──────────────────┐  ┌──────┐←──EP2  │
     │    ╠════════→│ W5   │←→│                    │←→│ E0   │←══════╣
     │    ║  WP3───→│ (5V) │  │   UART Core       │  │(3.3V)│←──EP3  │
     │    ║         └──────┘  │       │            │  └──────┘        │
     │    ║  WP4───→┌──────┐  │  ┌────┴────────┐  │  ┌──────┐←──EP4  │
     │    ╠════════→│ W4   │←→│  │ Cmd Decoder  │  │←→│ E1   │←══════╣
     │    ║  WP5───→│ (5V) │  │  └────┬────────┘  │  │(3.3V)│←──EP5  │
     │    ║         └──────┘  │       │            │  └──────┘        │
     │    ║  WP6───→┌──────┐  │  ┌────┴────────┐  │  ┌──────┐←──EP6  │
     │    ╠════════→│ W3   │←→│  │Register Bank│  │←→│ E2   │←══════╣
     │    ║  WP7───→│ (5V) │  │  │(spine regs) │  │  │(3.3V)│←──EP7  │
     │    ║         └──────┘  │  └────┬────────┘  │  └──────┘        │
     │    ║  WP8───→┌──────┐  │       │            │  ┌──────┐←──EP8  │
     │    ╠════════→│ W2   │←→│  ┌────┴────────┐  │←→│ E3   │←══════╣
     │    ║  WP9───→│ (5V) │  │  │Tile I/F Ctrl│  │  │(3.3V)│←──EP9  │
     │    ║         └──────┘  │  │ (mux/decode) │  │  └──────┘        │
     │    ║  WP10──→┌──────┐  │  └────┬────────┘  │  ┌──────┐←──EP10 │
     │    ╠════════→│ W1   │←→│       │            │←→│ E4   │←══════╣
     │    ║  WP11──→│ (5V) │  │  ┌────┴────────┐  │  │(3.3V)│←──EP11 │
     │    ║         └──────┘  │  │ Clk/Rst Gen  │  │  └──────┘        │
     │    ║  WP12──→┌──────┐  │  └─────────────┘  │  ┌──────┐←──EP12 │
     │    ╠════════→│ W0   │←→│                    │←→│ E5   │←══════╣
     │    ║  WP13──→│ (5V) │  │                    │  │(3.3V)│←──EP13 │
     │    ║         └──────┘  └─────────┬──────────┘  └──────┘        │
     │    ║                             │                       ║     │
     │    ║    SP2──→┌──────┐  ┌──────┐│┌──────┐  ┌──────┐←──SP8    │
     │    ╠════════→│ S0   │←→│ S1   │←→│ S2   │←→│ S3   │←══════╣
     │    ║    SP3──→│(flex)│  │(flex)│ │(flex)│  │(flex)│←──SP9    │
     │              └──────┘  └──────┘ └──────┘  └──────┘          │
     │                                                              │
    SP0  SP1                                                 SP8  SP9
    5V0  VSS              SOUTH PAD RING                     3V3  VSS

    LEGEND:
    ═══╣  Power trunk tap (M5 → tile local supply)
    ←→    Digital control bus (28 signals, M1/M2, spine ↔ tile)
    ───→  Analog pad wire (short, within tile footprint to die edge)
    WPn   West pad number n
    EPn   East pad number n
    SPn   South pad number n
```

### F. Tile Wrapper Signal List

```systemverilog
module tile_wrapper #(
    parameter TILE_TYPE_ID  = 8'h00,  // Set per tile design
    parameter TILE_VERSION  = 8'h10,  // Set per tile revision
    parameter TIMEOUT_CYCLES = 100_000
)(
    // === Spine Interface (all 3.3V domain) ===
    input  logic        tile_clk,        // Gated clock from spine
    input  logic        tile_reset_n,    // Active-low reset
    input  logic        tile_enable,     // Master enable

    // Register access
    input  logic [3:0]  tile_addr,       // Register address (0-15)
    input  logic [7:0]  tile_wdata,      // Write data
    input  logic        tile_cfg_wr,     // Write strobe
    output logic [7:0]  tile_rdata,      // Read data

    // Status
    output logic [3:0]  tile_status,     // [0]=busy [1]=done [2]=pass [3]=error
    output logic        tile_irq,        // Interrupt request
    output logic        tile_pwr_good,   // Power OK (from detector or tie-high)

    // === Power (directly to tile) ===
    // VDD_3V3, VDD_5V0, VSS — not modeled in RTL; physical connections

    // === DUT Interface (directly to analog experiment) ===
    // These are tile-specific and defined by the DUT designer.
    // The wrapper provides:
    //   - dut_enable, dut_reset_n, dut_mode[2:0], dut_param[15:0]
    //   - dut_start (pulse), dut_done (from DUT)
    //   - dut_result[31:0] (from DUT)
    //   - dut_debug[15:0] (from DUT)
    //   - Analog I/O: wired directly to tile's edge pads via isolation switches
);

    // Internal: register file, FSM, timeout watchdog, isolation control
    // See Section 5.3 for register definitions
    // See Section 5.4 for FSM state diagram

endmodule
```

---

## Appendix: Assumptions Made

1. **Caravel user area** is approximately 2.9mm x 3.5mm with access to 38 GPIO pads (configurable via Caravel's GPIO configuration registers).
2. **SKY130 thick-oxide devices** (`_g5v0d10v5` variants) are available and characterized for 5V operation.
3. **Metal stack** has 5 layers (M1-M5) with M5 available for user power distribution in the Caravel frame.
4. **No proprietary IP** is assumed — all blocks are custom RTL or SKY130 primitives.
5. **Tile current budget:** ~5mA per tile average, ~20mA peak per group (sizing for power gating).
6. **UART baud rate accuracy:** ±3% is achievable with the internal RC at 9600 baud, which is sufficient for boot-up communication. External clock provides exact baud rates.
7. **The Caravel harness** provides its own power-on-reset and clock infrastructure, but the ULC spine generates its own internal reset sequence and does not depend on Caravel's management SoC being functional.
8. **Guard ring spacing** of 5um between tiles is sufficient for substrate isolation at this technology node and these voltage levels.

---

*End of specification — ULC Spine-Tile Architecture v1*
