# ULC v3.0 Standard Tile Interface Specification

**Status:** Draft
**Version:** 3.0
**Applies to:** All analog experiment tiles (T0-T5, reserved T6-T7)

---

## 1. Purpose

Every experiment tile must conform to this interface. The tile controller wraps each DUT with a standard digital control slice and analog routing endpoints. This allows the sequencer, register bank, route matrix, and logging system to treat all tiles identically.

A tile designer only needs to implement the **Analog DUT** and specify its **parameter map**. Everything else — enable/disable, isolation, routing, result collection, error handling — is handled by the standard tile wrapper.

---

## 2. Tile Block Diagram

```
                 ┌─────────────────────────────────────────────┐
                 │              TILE WRAPPER (standard)         │
                 │                                             │
  DIGITAL BUS ──►│  ┌──────────────────────────────────┐      │
  (from tile     │  │      Digital Control Slice        │      │
   controller)   │  │                                    │      │
                 │  │  enable ──┐                        │      │
                 │  │  reset  ──┤  FSM: idle/run/done    │      │
                 │  │  start  ──┤  timeout watchdog      │      │
                 │  │  mode   ──┤  error capture         │      │
                 │  │           │                        │      │
                 │  │  done   ◄─┤  status aggregation    │      │
                 │  │  pass   ◄─┤                        │      │
                 │  │  error  ◄─┤                        │      │
                 │  │  busy   ◄─┘                        │      │
                 │  └──────────────┬─────────────────────┘      │
                 │                 │ dut_ctrl / dut_status       │
                 │                 ▼                             │
                 │  ┌──────────────────────────────────┐        │
                 │  │                                    │        │
  STIM_A ──[SW]──│──│►  ANALOG DUT (user-designed)       │        │
  STIM_B ──[SW]──│──│►                                   │──[SW]──│──► OUT_MAIN
                 │  │                            tap1  ──│──[SW]──│──► TAP1
                 │  │                            tap2  ──│──[SW]──│──► TAP2
                 │  │                                    │        │
  CLK_TILE ─────│──│►  (optional clock input)            │        │
                 │  │                                    │        │
                 │  └──────────────────────────────────┘        │
                 │                                             │
                 │  [SW] = isolation switch (transmission gate) │
                 │        controlled by enable signal           │
                 └─────────────────────────────────────────────┘
```

---

## 3. Signal Table

### 3.1 Digital Control Interface (Mandatory)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `tile_enable` | In | 1 | Master enable. 0 = tile fully isolated and powered down. |
| `tile_reset` | In | 1 | Local reset (active-high). Resets DUT to known state. |
| `tile_mode` | In | 3 | DUT operating mode (tile-specific interpretation). |
| `tile_start` | In | 1 | Pulse to begin DUT operation/measurement. |
| `tile_param` | In | 32 | DUT-specific parameter (bias code, trim, gain setting, etc.). |
| `tile_done` | Out | 1 | Asserted when DUT operation completes. |
| `tile_pass` | Out | 1 | Self-test passed (valid only when done=1). |
| `tile_error` | Out | 1 | Error detected (valid only when done=1). |
| `tile_busy` | Out | 1 | DUT is running (between start and done). |
| `tile_error_code` | Out | 4 | Specific error type (0=none, see table below). |
| `tile_result` | Out | 32 | Primary measurement result. |
| `tile_debug` | Out | 32 | Secondary / debug observation word. |

### 3.2 Analog I/O Interface (Via Route Matrix)

| Signal | Direction | Width | Type | Description |
|--------|-----------|-------|------|-------------|
| `stim_a` | In | 1 | Analog | Primary stimulus input. From DAC, ref, ext, or another tile. |
| `stim_b` | In | 1 | Analog | Secondary stimulus input (optional). Tied to VSS_A if unused. |
| `out_main` | Out | 1 | Analog | Primary DUT output. Routable to ADC, comp, or ext pad. |
| `tap1` | Out | 1 | Analog | Internal observation point 1 (optional). Hi-Z if unused. |
| `tap2` | Out | 1 | Analog | Internal observation point 2 (optional). Hi-Z if unused. |
| `clk_tile` | In | 1 | Digital | Clock input for timing-class tiles. From clock mux tree. |

### 3.3 Power Interface

| Signal | Direction | Type | Description |
|--------|-----------|------|-------------|
| `vdd_tile` | In | Power | Tile power, 3.3V nominal (derived from VDDA via PMOS header switch). |
| `vss_tile` | In | Power | Tile ground (connected to VSS_A). |

**Power gating:** Each tile's VDD_TILE is supplied through a dedicated PMOS power switch (`sky130_fd_pr__pfet_03v3`, W=50u/L=0.5u) controlled by the `TILE_POWER_CONTROL` register. When the switch is open, VDD_TILE is disconnected from VDDA and the tile is fully de-energized.

**Voltage domains:**
- Tile analog DUT circuits: **3.3V** (VDD_TILE / VSS_TILE)
- Tile digital control slice: **1.8V** (VDD / VSS), with level shifters at the boundary
- All analog I/O signals (STIM_A, STIM_B, OUT_MAIN, TAP1, TAP2): **3.3V swing**
- Isolation switches: 3.3V transmission gates (`sky130_fd_pr__nfet_03v3_nvt` + `pfet_03v3`)

**Power-on sequence:** TILE_POWER_CONTROL[N] must be set and power_good must be asserted before tile_enable is accepted. See `v3_0_overview.md` Section 8.1.

---

## 4. Isolation Requirements

Every analog signal crossing the tile boundary passes through an **isolation switch** (transmission gate in SKY130):

| Path | Switch | Default State | Controlled By |
|------|--------|---------------|---------------|
| STIM_A → DUT | SW_STIM_A | **OPEN** (disconnected) | tile_enable |
| STIM_B → DUT | SW_STIM_B | **OPEN** | tile_enable |
| DUT → OUT_MAIN | SW_OUT_MAIN | **OPEN** | tile_enable |
| DUT → TAP1 | SW_TAP1 | **OPEN** | tile_enable |
| DUT → TAP2 | SW_TAP2 | **OPEN** | tile_enable |

**When tile is unpowered (TILE_POWER_CONTROL[N] = 0):**
- PMOS header switch open — VDD_TILE floating/discharged
- All isolation switches open (gate pulled to VDDA via weak pull-up)
- DUT is fully de-energized — zero quiescent current
- DUT inputs pulled to VSS_A via weak keepers
- DUT outputs Hi-Z to route matrix
- All digital status outputs = 0

**When tile is powered but disabled (power_good=1, tile_enable=0):**
- VDD_TILE = 3.3V (PMOS switch closed)
- All isolation switches open
- DUT is powered but idle — quiescent current only
- Digital control slice holds reset

**When tile is powered and enabled (power_good=1, tile_enable=1):**
- Isolation switches close (DUT connects to route matrix)
- Digital control slice exits reset
- DUT ready to accept start command

---

## 5. Tile State Machine (Standard — In Tile Wrapper)

Every tile wrapper implements this 6-state FSM:

```
  UNPOWERED ──(power_good=1)──► DISABLED ──(enable=1)──► IDLE
     ▲                             ▲                       │
     │                             │                    (start=1)
  (power_off)                   (enable=0)                 │
     │                             │                       ▼
     │                             │                     RUNNING
     │                             │                    /       \
     │                             │               (done)    (timeout)
     │                             │                /             \
     │                             │               ▼               ▼
     │                             │             DONE            ERROR
     │                             │               │               │
     │                             │           (read result)  (read error)
     │                             │               │               │
     │                             │               └───────┬───────┘
     │                             │                       │
     │                             │                   (reset or
     │                             │                    new start)
     │                             │                       │
     │                             └───────────────────────┘
     │                                        │
     └────────────────────────────────────────┘
                              (power_off from any state)
```

| State | tile_busy | tile_done | tile_error | power_good | Description |
|-------|-----------|-----------|------------|------------|-------------|
| UNPOWERED | 0 | 0 | 0 | 0 | VDD_TILE disconnected, zero current |
| DISABLED | 0 | 0 | 0 | 1 | Powered but tile_enable=0, isolated |
| IDLE | 0 | 0 | 0 | 1 | Enabled, waiting for start |
| RUNNING | 1 | 0 | 0 | 1 | DUT operation in progress |
| DONE | 0 | 1 | 0 | 1 | Operation complete, result valid |
| ERROR | 0 | 1 | 1 | 1 | Error detected, error_code valid |

**Timeout:** The tile wrapper includes a local watchdog counter. If the DUT does not assert its internal `dut_done` within `TILE_TIMEOUT` cycles (configured via TILE_PARAM or global default), the wrapper transitions to ERROR with `error_code = TILE_ERR_TIMEOUT`.

---

## 6. Error Codes (Per-Tile)

| Code | Name | Description |
|------|------|-------------|
| 0x0 | TILE_ERR_NONE | No error |
| 0x1 | TILE_ERR_TIMEOUT | DUT did not complete within timeout |
| 0x2 | TILE_ERR_RANGE | Measurement result out of expected range |
| 0x3 | TILE_ERR_UNSTABLE | Output oscillating or not settling |
| 0x4 | TILE_ERR_OVERCURRENT | Current limit triggered (Class D tiles) |
| 0x5 | TILE_ERR_NO_STIMULUS | STIM_A not connected when required |
| 0x6 | TILE_ERR_NO_POWER | Enable attempted while VDD_TILE not stable |
| 0x7 | TILE_ERR_POWER_LOST | VDD_TILE dropped below threshold during operation |
| 0x8-0xE | Reserved | |
| 0xF | TILE_ERR_UNKNOWN | Unclassified error |

---

## 7. Mode Encoding (3 bits — Tile-Specific)

The `tile_mode[2:0]` field is interpreted differently by each tile type. The tile designer defines the mode table in the tile's specification document.

**Convention:**
| Mode | Common Meaning |
|------|---------------|
| 0b000 | Default / standard operation |
| 0b001 | Self-test mode (automated pass/fail) |
| 0b010 | Characterization mode (sweep parameter) |
| 0b011 | Power-down / low-power mode |
| 0b100-0b111 | Tile-specific |

---

## 8. DUT Designer Responsibilities

A tile DUT designer must provide:

| Deliverable | Description |
|-------------|------------|
| Schematic / netlist | The analog DUT circuit |
| `dut_done` signal | Assert when operation completes |
| `dut_result[31:0]` | Primary measurement output |
| `dut_debug[31:0]` | Debug / secondary observation (optional, tie to 0 if unused) |
| Mode table | What each mode[2:0] value does |
| Parameter description | What TILE_PARAM bits mean for this DUT |
| Expected signal ranges | Input/output voltage/current ranges |
| Area estimate | Approximate transistor count |
| Stimulus requirements | What should drive STIM_A / STIM_B |

The DUT designer does **NOT** need to implement:
- Enable/disable logic
- Isolation switches
- Reset handling
- Timeout watchdog
- Error aggregation
- Register interface
- Route matrix connections

All of that is in the standard tile wrapper.

---

## 9. Tile Wrapper RTL Template

```systemverilog
module tile_wrapper #(
  parameter int TILE_ID = 0,
  parameter int TIMEOUT_DEFAULT = 100_000
)(
  input  logic        clk,
  input  logic        rst_n,

  // Digital control (from tile controller)
  input  logic        tile_enable,
  input  logic        tile_reset,
  input  logic [2:0]  tile_mode,
  input  logic        tile_start,
  input  logic [31:0] tile_param,

  output logic        tile_done,
  output logic        tile_pass,
  output logic        tile_error,
  output logic        tile_busy,
  output logic [3:0]  tile_error_code,
  output logic [31:0] tile_result,
  output logic [31:0] tile_debug,

  // Analog I/O (directly to isolation switches, then route matrix)
  input  wire         stim_a,       // analog: from route matrix via switch
  input  wire         stim_b,       // analog: from route matrix via switch
  output wire         out_main,     // analog: to route matrix via switch
  output wire         tap1,         // analog: observation tap
  output wire         tap2,         // analog: observation tap

  // Clock (for timing-class tiles)
  input  logic        clk_tile
);

  // --- Isolation switches (transmission gates in silicon) ---
  // Modeled as gated pass-through in RTL
  // In synthesis: replaced with sky130_fd_sc_hd__einvp / analog switch cells

  // --- Standard tile FSM ---
  // (DISABLED, IDLE, RUNNING, DONE, ERROR)
  // Instantiates DUT, manages lifecycle

  // --- DUT instance ---
  // tile_dut_<name> u_dut (
  //   .clk       (clk),
  //   .rst_n     (rst_n & tile_enable & ~tile_reset),
  //   .mode      (tile_mode),
  //   .param     (tile_param),
  //   .start     (tile_start & tile_enable),
  //   .stim_a    (stim_a_switched),
  //   .stim_b    (stim_b_switched),
  //   .out_main  (out_main_raw),
  //   .tap1      (tap1_raw),
  //   .tap2      (tap2_raw),
  //   .clk_tile  (clk_tile),
  //   .dut_done  (dut_done),
  //   .dut_result(dut_result),
  //   .dut_debug (dut_debug)
  // );

endmodule
```

---

## 10. Physical Interface Rules

| Rule | Value | Rationale |
|------|-------|-----------|
| Guard ring between tiles | >= 5um (P+ to substrate) | Substrate noise isolation |
| Tile-to-shared-analog distance | <= 200um | Minimize routing parasitics |
| Analog routing metal | M3/M4 preferred | Avoid M1/M2 digital congestion |
| Digital control routing | M1/M2 | Standard digital routing |
| PMOS power switch per tile | `pfet_03v3` W=50u/L=0.5u | ~2-3 ohm Rds_on, placed adjacent to tile |
| Decoupling cap per tile | MIM ~10pF on VDD_TILE | Local bypass, placed inside tile guard ring |
| Level shifters per tile | 1.8V ↔ 3.3V at digital boundary | ~12 level shifter cells per tile (control + status) |
| Maximum tile area | 200um x 150um | Fit 6 tiles in right-side zone |

---

## 11. Not-Present Tile Behavior

Reserved tile slots (T6, T7) and any physically absent tile must:

| Signal | Value |
|--------|-------|
| tile_done | 0 |
| tile_pass | 0 |
| tile_error | 0 |
| tile_busy | 0 |
| tile_error_code | 4'h0 |
| tile_result | 32'h0000_0000 |
| tile_debug | 32'hDEAD_BEEF (sentinel: not present) |
| out_main, tap1, tap2 | Hi-Z |

The sequencer checks `tile_debug == 32'hDEAD_BEEF` to detect absent tiles and skips them during sweeps.
