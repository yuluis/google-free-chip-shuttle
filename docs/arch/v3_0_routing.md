# ULC v3.0 Expanded Analog Route Matrix

**Status:** Draft
**Version:** 3.0
**Analog voltage:** 3.3V (all analog signals swing 0-3.3V; switches use 3.3V-tolerant devices)
**Depends on:** `v3_0_overview.md`, `v3_0_tile_interface.md`, `v3_0_register_map.md`

---

## 1. Overview

The v2.4 analog route matrix connected four sources (DAC, external analog input, reference ladder, ring oscillator monitor) to three destinations (ADC input, comparator +, comparator -) plus a DAC external output. It was a flat one-level mux with 4 source codes and 3 destination selectors.

v3.0 expands this to support 6 experiment tiles. Each tile exposes up to 2 analog outputs (OUT_MAIN, TAP1) and accepts up to 2 analog inputs (STIM_A, STIM_B). The route matrix must now handle:

- **16 sources** (4 legacy + 6 tile OUT_MAIN + 6 tile TAP1)
- **19 destinations** (3 legacy + 6 tile STIM_A + 6 tile STIM_B + DAC_OUT pad + SPARE_IO pads)
- **Tile-to-tile routing** (any tile output can drive any other tile input)

A flat 16x19 crossbar would require 304 analog switches -- too large for the available routing area. Instead, v3.0 uses a **2-level mux hierarchy** to keep the switch count under 80.

---

## 2. Source and Destination Table

### Sources (FROM)

| Code | Source | Signal Name | Type | Notes |
|------|--------|-------------|------|-------|
| 0x0 | Disconnected | -- | -- | Safe default (no connection) |
| 0x1 | DAC output | `dac_out` | Shared analog | 10-bit, 5 modes |
| 0x2 | External analog input | `ana_in_pad` | Pad | ANA_IN pad on pad ring |
| 0x3 | Reference ladder | `ref_ladder_out` | Shared analog | Bandgap + resistor divider |
| 0x4 | Ring oscillator monitor | `ring_osc_mon` | Shared analog | Analog frequency proxy |
| 0x5 | Tile 0 OUT_MAIN | `tile0_out_main` | Tile output | Primary DUT output |
| 0x6 | Tile 1 OUT_MAIN | `tile1_out_main` | Tile output | Primary DUT output |
| 0x7 | Tile 2 OUT_MAIN | `tile2_out_main` | Tile output | Primary DUT output |
| 0x8 | Tile 3 OUT_MAIN | `tile3_out_main` | Tile output | Primary DUT output |
| 0x9 | Tile 4 OUT_MAIN | `tile4_out_main` | Tile output | Primary DUT output |
| 0xA | Tile 5 OUT_MAIN | `tile5_out_main` | Tile output | Primary DUT output |
| 0xB | Tile 0 TAP1 | `tile0_tap1` | Tile output | Optional internal tap |
| 0xC | Tile 1 TAP1 | `tile1_tap1` | Tile output | Optional internal tap |
| 0xD | Tile 2 TAP1 | `tile2_tap1` | Tile output | Optional internal tap |
| 0xE | Tile 3 TAP1 | `tile3_tap1` | Tile output | Optional internal tap |
| 0xF | Reserved | -- | -- | Tile 4/5 TAP1 accessible via Bank 6 local routing |

TAP1 for tiles 4 and 5 is not globally routable (insufficient 4-bit encoding space). These taps are accessible only via the per-tile TILE_ROUTE_OUT register in Bank 6, which can route them to the ADC or comparator through the local override path.

### Destinations (TO)

| ID | Destination | Signal Name | Type | Notes |
|----|-------------|-------------|------|-------|
| D0 | ADC input | `adc_in_mux` | Shared analog | 12-bit SAR ADC |
| D1 | Comparator + | `comp_pos_mux` | Shared analog | Positive input |
| D2 | Comparator - | `comp_neg_mux` | Shared analog | Negative input |
| D3 | Tile 0 STIM_A | `tile0_stim_a` | Tile input | Primary stimulus |
| D4 | Tile 1 STIM_A | `tile1_stim_a` | Tile input | Primary stimulus |
| D5 | Tile 2 STIM_A | `tile2_stim_a` | Tile input | Primary stimulus |
| D6 | Tile 3 STIM_A | `tile3_stim_a` | Tile input | Primary stimulus |
| D7 | Tile 4 STIM_A | `tile4_stim_a` | Tile input | Primary stimulus |
| D8 | Tile 5 STIM_A | `tile5_stim_a` | Tile input | Primary stimulus |
| D9 | Tile 0 STIM_B | `tile0_stim_b` | Tile input | Secondary stimulus |
| D10 | Tile 1 STIM_B | `tile1_stim_b` | Tile input | Secondary stimulus |
| D11 | Tile 2 STIM_B | `tile2_stim_b` | Tile input | Secondary stimulus |
| D12 | Tile 3 STIM_B | `tile3_stim_b` | Tile input | Secondary stimulus |
| D13 | Tile 4 STIM_B | `tile4_stim_b` | Tile input | Secondary stimulus |
| D14 | Tile 5 STIM_B | `tile5_stim_b` | Tile input | Secondary stimulus |
| D15 | DAC_OUT pad | `dac_out_pad` | Pad | External analog output |
| D16 | SPARE_IO[0] | `spare_io_0` | Pad (via digital) | Analog-to-digital bridge |
| D17 | SPARE_IO[1] | `spare_io_1` | Pad (via digital) | Analog-to-digital bridge |

---

## 3. Routing Matrix (Which Source Can Reach Which Destination)

Not every source can reach every destination. The 2-level mux constrains the reachable set. The table below shows the allowed connections.

Legend: `Y` = routable, `-` = not connected, `L` = via Bank 6 local override only

### Shared Analog Destinations

| Source \ Dest | ADC | Comp+ | Comp- | DAC_OUT pad | SPARE_IO |
|---------------|-----|-------|-------|-------------|----------|
| DAC output | Y | Y | Y | Y | - |
| Ext analog in | Y | Y | Y | - | - |
| Ref ladder | Y | Y | Y | - | - |
| Ring osc mon | Y | - | - | - | - |
| Tile N OUT_MAIN | Y | Y | Y | Y | Y |
| Tile N TAP1 (0-3) | Y | Y | - | - | - |
| Tile N TAP1 (4-5) | L | L | - | - | - |

### Tile STIM Destinations

| Source \ Dest | T0 STIM_A | T1 STIM_A | T2 STIM_A | T3 STIM_A | T4 STIM_A | T5 STIM_A |
|---------------|-----------|-----------|-----------|-----------|-----------|-----------|
| DAC output | Y | Y | Y | Y | Y | Y |
| Ext analog in | Y | Y | Y | Y | Y | Y |
| Ref ladder | Y | Y | Y | Y | Y | Y |
| Ring osc mon | Y | Y | Y | Y | Y | Y |
| Tile 0 OUT_MAIN | - | Y | Y | Y | Y | Y |
| Tile 1 OUT_MAIN | Y | - | Y | Y | Y | Y |
| Tile 2 OUT_MAIN | Y | Y | - | Y | Y | Y |
| Tile 3 OUT_MAIN | Y | Y | Y | - | Y | Y |
| Tile 4 OUT_MAIN | Y | Y | Y | Y | - | Y |
| Tile 5 OUT_MAIN | Y | Y | Y | Y | Y | - |

Self-routing (Tile N OUT_MAIN to Tile N STIM_A) is blocked to prevent single-tile feedback loops. Tile-to-tile routing is fully supported for cascade experiments.

STIM_B follows the same connectivity table as STIM_A, controlled by the TILE_ROUTE_STIM_B register.

---

## 4. Contention Prevention Rules

| Rule | Description | Enforcement |
|------|-------------|-------------|
| **One source per destination** | Each destination mux selects exactly one source. Writing a new source disconnects the previous one. | Hardware: mux is select-based, not enable-based. Only one path active per mux. |
| **Explicit select required** | No destination has an implicit connection. All muxes default to code 0x0 (disconnected). | Hardware: reset clears all routing registers to 0x00000000. |
| **Contention flag** | If software writes a routing configuration that creates a bus conflict (should not be possible with mux-based design, but checked as defense), TILE_ROUTE_STATUS[18] is set. | Hardware: contention detector (see Section 8). |
| **Feedback loop detection** | If routing creates a single-hop feedback (Tile N OUT → Tile N STIM), TILE_ROUTE_STATUS[19] is set and the route is blocked. | Hardware: comparator on tile source/dest fields. |
| **All routes disconnected at reset** | Global reset and per-tile reset both disconnect all routes involving the affected tile. Software reset (0x5C) disconnects all routes globally. | Hardware: reset signal clears all TILE_ROUTE_* registers. |
| **Disabled tile outputs are Hi-Z** | A tile with `enable = 0` presents Hi-Z on OUT_MAIN and TAP1. The route matrix sees no drive from disabled tiles. | Hardware: isolation switches in tile wrapper (see `v3_0_tile_interface.md`). |

---

## 5. Tile-to-Tile Routing

Tile-to-tile routing enables cascade experiments where one tile's output drives another tile's input. This is the core new capability in v3.0.

### How It Works

1. **Tile A** runs an experiment, producing an analog output on `out_main`.
2. The route matrix connects Tile A's `out_main` to Tile B's `stim_a` (or `stim_b`).
3. **Tile B** processes the stimulus and produces its own output.
4. Tile B's output can be routed to the ADC for measurement, to a third tile, or to an external pad.

### Configuration

To route Tile 0 OUT_MAIN to Tile 3 STIM_A:

```
Bank 2, TILE_ROUTE_STIM_A (0x70):
  bits [15:12] = 0x5    (Tile 3 STIM_A source = Tile 0 OUT_MAIN)
```

Or equivalently, via the per-tile local override:

```
Bank 6, Tile 3 base + TILE_ROUTE_IN (0x6C):
  bits [3:0] = 0x5      (stim_a_src = Tile 0 OUT_MAIN)
  bit  [8]   = 1         (use_local = 1)
```

### Cascade Chain Example

```
DAC ──► Tile 0 (OTA) ──► Tile 3 (Delay Line) ──► ADC
        STIM_A → OUT_MAIN   STIM_A → OUT_MAIN
```

Register writes:
1. `TILE_ROUTE_STIM_A[3:0]   = 0x1` -- Tile 0 STIM_A = DAC
2. `TILE_ROUTE_STIM_A[15:12] = 0x5` -- Tile 3 STIM_A = Tile 0 OUT_MAIN
3. `TILE_ROUTE_ADC_MUX[3]    = 1`   -- ADC source override = tile
4. `TILE_ROUTE_ADC_MUX[6:4]  = 3`   -- ADC tile source = Tile 3 OUT_MAIN

### Restrictions

| Restriction | Reason |
|-------------|--------|
| No self-routing (Tile N → Tile N) | Prevents uncontrolled oscillation / feedback. Detected and blocked by hardware. |
| Maximum cascade depth: 3 tiles | Not enforced in hardware, but recommended. Longer chains accumulate routing parasitics and settling time. |
| Both tiles must be enabled | A disabled tile's outputs are Hi-Z. Routing from a disabled tile delivers no signal. |
| Tile order matters for sequencer | In a cascade, upstream tiles must complete before downstream tiles start. The sequencer handles this in tile sweep mode. |

---

## 6. Implementation: 2-Level Mux Hierarchy

A flat crossbar for 16 sources x 19 destinations would require ~304 transmission gate switches and consume excessive die area. The 2-level hierarchy reduces this.

### Level 1: Tile Group Mux (Per-Group Source Selection)

Selects which signal enters the global analog bus from a group of related sources.

| Group Mux | Inputs | Output | Select Width | Switches |
|-----------|--------|--------|-------------|----------|
| GM_LEGACY | DAC, Ext, Ref, Ring Osc | `legacy_bus` | 2 bits | 4 |
| GM_TILE_OUT | Tile[0-5] OUT_MAIN | `tile_out_bus` | 3 bits | 6 |
| GM_TILE_TAP | Tile[0-3] TAP1 | `tile_tap_bus` | 2 bits | 4 |

Total Level 1 switches: **14**

### Level 2: Global Destination Mux (Routes Group Bus to Destination)

Each destination selects from the group bus outputs (not individual sources).

| Destination Mux | Inputs | Select Width | Switches |
|-----------------|--------|-------------|----------|
| ADC input | `legacy_bus`, `tile_out_bus`, `tile_tap_bus` | 2 bits | 3 |
| Comp+ | `legacy_bus`, `tile_out_bus`, `tile_tap_bus` | 2 bits | 3 |
| Comp- | `legacy_bus`, `tile_out_bus` | 1 bit | 2 |
| Per-tile STIM_A (x6) | `legacy_bus`, `tile_out_bus` | 1 bit + 3-bit tile select | 2 x 6 = 12 |
| Per-tile STIM_B (x6) | `legacy_bus`, `tile_out_bus` | 1 bit + 3-bit tile select | 2 x 6 = 12 |
| DAC_OUT pad | `tile_out_bus` (pass-through) | 3-bit tile select | 1 |
| SPARE_IO (x2) | `tile_out_bus` | 3-bit tile select | 2 |

Total Level 2 switches: **35**

### Combined

| Level | Switches | Mux instances |
|-------|----------|---------------|
| Level 1 (Group) | 14 | 3 |
| Level 2 (Dest) | 35 | 17 |
| **Total** | **49** | **20** |

Plus per-tile STIM_A/B each need a sub-mux to select which specific tile output (within the `tile_out_bus` group) to route. This adds a 6:1 sub-select per tile stimulus, implemented as part of the Level 1 GM_TILE_OUT mux being driven per-destination rather than globally shared. In practice, each tile STIM_A/B gets its own 10:1 mux (4 legacy + 5 other tiles + disconnected), yielding **~60 switches per STIM bank** (6 tiles x 10 inputs), but many inputs share the same transmission gate paths through the hierarchy.

**Estimated total analog switches: ~75** (well under the 100-switch area budget for the routing zone).

### Block Diagram

```
                    LEVEL 1                           LEVEL 2
              ┌─────────────┐
  DAC ───────►│             │
  Ext ───────►│ GM_LEGACY   │──► legacy_bus ──┬──► ADC mux ──────► ADC
  Ref ───────►│  (4:1)      │                 ├──► Comp+ mux ────► Comp+
  Ring Osc ──►│             │                 ├──► Comp- mux ────► Comp-
              └─────────────┘                 ├──► T0 STIM_A mux ► T0.stim_a
                                              ├──► T0 STIM_B mux ► T0.stim_b
              ┌─────────────┐                 │    ...
  T0.out ────►│             │                 └──► T5 STIM_B mux ► T5.stim_b
  T1.out ────►│ GM_TILE_OUT │──► tile_out_bus ┬──► ADC mux
  T2.out ────►│  (6:1)      │                 ├──► Comp+ mux
  T3.out ────►│             │                 ├──► T0 STIM_A mux
  T4.out ────►│             │                 ├──► DAC_OUT pad mux
  T5.out ────►│             │                 └──► SPARE_IO mux
              └─────────────┘
              ┌─────────────┐
  T0.tap1 ──►│             │
  T1.tap1 ──►│ GM_TILE_TAP │──► tile_tap_bus ┬──► ADC mux
  T2.tap1 ──►│  (4:1)      │                 └──► Comp+ mux
  T3.tap1 ──►│             │
              └─────────────┘
```

Note: The per-tile STIM muxes are shown simplified. Each tile's STIM_A mux actually selects among: disconnected, 4 legacy sources, and 5 other tiles' OUT_MAIN (10:1 effective, implemented as legacy_bus vs. tile_out_bus at Level 2, with the Level 1 GM_TILE_OUT programmed per-destination context).

---

## 7. Register Interface

All routing registers reside in **Bank 2 (Analog)**. The full bit-field definitions are in `v3_0_register_map.md`. This section summarizes the routing-specific registers.

| Offset | Name | Access | Reset | Description |
|--------|------|--------|-------|-------------|
| 0x70 | TILE_ROUTE_STIM_A | RW | 0x00000000 | STIM_A source per tile (4 bits x 6 tiles, bits [23:0]) |
| 0x74 | TILE_ROUTE_STIM_B | RW | 0x00000000 | STIM_B source per tile (4 bits x 6 tiles, bits [23:0]) |
| 0x78 | TILE_ROUTE_ADC_MUX | RW | 0x00000000 | ADC input source extension for tile outputs |
| 0x7C | TILE_ROUTE_COMP_MUX | RW | 0x00000000 | Comparator input source extension for tile outputs |
| 0x80 | TILE_ROUTE_STATUS | R | 0x00000000 | Routing status: per-tile connected flags, contention, loop detect |
| 0x84 | TILE_ROUTE_EXT_OUT | RW | 0x00000000 | Tile output routing to DAC_OUT pad and SPARE_IO pads |

### TILE_ROUTE_STIM_A (0x70) -- Source Encoding

4 bits per tile, packed into bits [23:0]:

```
[3:0]   = Tile 0 STIM_A source
[7:4]   = Tile 1 STIM_A source
[11:8]  = Tile 2 STIM_A source
[15:12] = Tile 3 STIM_A source
[19:16] = Tile 4 STIM_A source
[23:20] = Tile 5 STIM_A source
[31:24] = Reserved (read as 0)
```

| Code | Source |
|------|--------|
| 0x0 | Disconnected |
| 0x1 | DAC output |
| 0x2 | External analog input (ANA_IN pad) |
| 0x3 | Reference ladder |
| 0x4 | Ring oscillator monitor |
| 0x5 | Tile 0 OUT_MAIN |
| 0x6 | Tile 1 OUT_MAIN |
| 0x7 | Tile 2 OUT_MAIN |
| 0x8 | Tile 3 OUT_MAIN |
| 0x9 | Tile 4 OUT_MAIN |
| 0xA | Tile 5 OUT_MAIN |
| 0xB-0xF | Reserved |

TILE_ROUTE_STIM_B (0x74) uses the same encoding.

### TILE_ROUTE_ADC_MUX (0x78)

Extends the v2.4 ADC source selector to include tile outputs:

```
[2:0]  = ADC source (v2.4 encoding: 0=disc, 1=DAC, 2=ext, 3=ref, 4=rosc)
[3]    = tile_override: 1 = use tile source from [6:4] instead of [2:0]
[6:4]  = Tile index (0-5) — which tile's OUT_MAIN routes to ADC
[7]    = use_tap1: 1 = route TAP1 instead of OUT_MAIN (tiles 0-3 only)
[31:8] = Reserved
```

When `tile_override = 0`, the v2.4 ADC source encoding applies unchanged. When `tile_override = 1`, the ADC reads from the selected tile output.

### TILE_ROUTE_COMP_MUX (0x7C)

Same structure as TILE_ROUTE_ADC_MUX, applied to the comparator:

```
[2:0]  = Comp+ source (v2.4 encoding)
[3]    = tile_override_pos: 1 = use tile for comp+
[6:4]  = Tile index for comp+ (0-5)
[7]    = use_tap1_pos: 1 = TAP1 instead of OUT_MAIN
[10:8] = Comp- source (v2.4 encoding)
[11]   = tile_override_neg: 1 = use tile for comp-
[14:12]= Tile index for comp- (0-5)
[15]   = use_tap1_neg: 1 = TAP1 instead of OUT_MAIN
[31:16]= Reserved
```

### TILE_ROUTE_STATUS (0x80) -- Read Only

```
[5:0]   = Per-tile STIM_A connected (1 = source is not disconnected)
[11:6]  = Per-tile STIM_B connected
[17:12] = Per-tile OUT_MAIN connected (has a destination)
[18]    = contention_detected (any destination driven by >1 source)
[19]    = loop_detected (Tile N OUT → Tile N STIM feedback)
[20]    = disabled_source (route references a disabled tile's output)
[31:21] = Reserved
```

### TILE_ROUTE_EXT_OUT (0x84)

Routes tile outputs to external pads:

```
[2:0]  = DAC_OUT pad source tile (0-5, or 7 = disconnected)
[3]    = dac_out_enable: 1 = drive DAC_OUT pad from selected tile
[6:4]  = SPARE_IO[0] source tile (0-5, or 7 = disconnected)
[7]    = spare_io0_enable
[10:8] = SPARE_IO[1] source tile (0-5, or 7 = disconnected)
[11]   = spare_io1_enable
[31:12]= Reserved
```

---

## 8. Contention Detection Logic

The route matrix includes a lightweight contention detector that runs combinationally (no clock needed) and flags illegal configurations in TILE_ROUTE_STATUS.

### Checks Performed

| Check | Condition | Flag |
|-------|-----------|------|
| **Self-route** | TILE_ROUTE_STIM_A for Tile N selects Tile N OUT_MAIN (e.g., Tile 2 STIM_A = 0x7, which is Tile 2 OUT) | `loop_detected` (bit 19) |
| **Self-route (STIM_B)** | Same check on TILE_ROUTE_STIM_B | `loop_detected` (bit 19) |
| **Comp+/- same source** | TILE_ROUTE_COMP_MUX comp+ and comp- resolve to the same physical signal | `contention_detected` (bit 18) |
| **Disabled source** | Any STIM_A/B source field points to a tile whose `tile_enable = 0` | `disabled_source` (bit 20) |
| **ADC tile override pointing to disabled tile** | TILE_ROUTE_ADC_MUX `tile_override = 1` and selected tile is disabled | `disabled_source` (bit 20) |

### Self-Route Detection Logic (per tile)

```
For tile N (N = 0..5):
  stim_a_src = TILE_ROUTE_STIM_A[(N*4+3):(N*4)]
  tile_out_code = 0x5 + N
  self_route_a = (stim_a_src == tile_out_code)

  stim_b_src = TILE_ROUTE_STIM_B[(N*4+3):(N*4)]
  self_route_b = (stim_b_src == tile_out_code)

  loop_detected |= (self_route_a | self_route_b)
```

### Hardware Cost

The contention detector is purely combinational (comparators + OR tree). Estimated at ~200 gates, negligible relative to the ~4K gate route matrix budget.

### Software Response

When `contention_detected` or `loop_detected` is set:

1. The sequencer checks TILE_ROUTE_STATUS during SEQ_APPLY_ROUTE.
2. If any flag is set, the sequencer transitions to SEQ_RESTORE_SAFE (disconnects all routes).
3. ERROR_CODE is set to 0x24 (ERR_ROUTE_CONTENTION) or 0x25 (ERR_ROUTE_LOOP).
4. Host can also poll TILE_ROUTE_STATUS after any register write for immediate feedback.

The `disabled_source` flag is a **warning**, not a hard error. The sequencer logs it but does not abort. This allows pre-configuring routes before enabling tiles.

---

## 9. Example Routing Configurations

### Example 1: DAC Stimulus and ADC Measurement (Single Tile)

**Goal:** Drive Tile 0 (OTA) with DAC output, measure its response on the ADC.

```
Signal path: DAC ──► Tile 0 STIM_A ──► [OTA DUT] ──► Tile 0 OUT_MAIN ──► ADC
```

Register writes:

| Step | Register | Value | Description |
|------|----------|-------|-------------|
| 1 | Bank 2, TILE_ROUTE_STIM_A (0x70) | 0x00000001 | Tile 0 STIM_A = DAC (code 0x1) |
| 2 | Bank 2, TILE_ROUTE_ADC_MUX (0x78) | 0x00000008 | tile_override=1, tile_index=0, use_tap1=0 |
| 3 | Bank 6, Tile 0 TILE_CONTROL (0x00) | 0x00000001 | Enable Tile 0 |
| 4 | Bank 2, DAC_CONTROL (0x20) | (set DAC mode/code) | Configure DAC output level |
| 5 | Bank 6, Tile 0 TILE_CONTROL (0x00) | 0x00000005 | Start Tile 0 (enable + start) |
| 6 | Poll Bank 6, TILE_STATUS (0x04) | -- | Wait for done=1 |
| 7 | Read Bank 2, ADC_RESULT (0x48) | -- | Read ADC measurement |

### Example 2: Tile-to-Tile Cascade

**Goal:** Route Tile 0 (OTA) output into Tile 3 (Delay Line) input. Measure Tile 3 output on ADC.

```
Signal path: DAC ──► T0 STIM_A ──► [OTA] ──► T0 OUT ──► T3 STIM_A ──► [Delay] ──► T3 OUT ──► ADC
```

Register writes:

| Step | Register | Value | Description |
|------|----------|-------|-------------|
| 1 | Bank 2, TILE_ROUTE_STIM_A (0x70) | 0x00005001 | T0 STIM_A = DAC (0x1), T3 STIM_A = T0 OUT (0x5) |
| 2 | Bank 2, TILE_ROUTE_ADC_MUX (0x78) | 0x00000038 | tile_override=1, tile_index=3 |
| 3 | Bank 6, Tile 0 TILE_CONTROL | 0x00000001 | Enable Tile 0 |
| 4 | Bank 6, Tile 3 TILE_CONTROL | 0x00000001 | Enable Tile 3 |
| 5 | Configure DAC | -- | Set stimulus level |
| 6 | Start Tile 0, wait for done | -- | OTA output settles |
| 7 | Start Tile 3, wait for done | -- | Delay line processes signal |
| 8 | Read ADC_RESULT | -- | Measure Tile 3 output |

TILE_ROUTE_STIM_A breakdown:
- Bits [3:0] = 0x1 (Tile 0 STIM_A = DAC)
- Bits [7:4] = 0x0 (Tile 1 STIM_A = disconnected)
- Bits [11:8] = 0x0 (Tile 2 STIM_A = disconnected)
- Bits [15:12] = 0x5 (Tile 3 STIM_A = Tile 0 OUT_MAIN)
- Bits [23:16] = 0x0 (Tiles 4-5 disconnected)

### Example 3: External Signal Characterization

**Goal:** Feed an external analog signal into Tile 2 (Ring Oscillator), measure its output on the comparator positive input against a reference on the comparator negative input.

```
Signal path: ANA_IN pad ──► T2 STIM_A ──► [Ring Osc] ──► T2 OUT ──► Comp+
             Ref Ladder ──► Comp-
```

Register writes:

| Step | Register | Value | Description |
|------|----------|-------|-------------|
| 1 | Bank 2, TILE_ROUTE_STIM_A (0x70) | 0x00000200 | Tile 2 STIM_A = Ext analog (0x2) at bits [11:8] |
| 2 | Bank 2, TILE_ROUTE_COMP_MUX (0x7C) | 0x00000328 | Comp+ = tile override, tile 2; Comp- = ref ladder (code 3) |
| 3 | Bank 6, Tile 2 TILE_CONTROL | 0x00000001 | Enable Tile 2 |
| 4 | Start Tile 2, wait for done | -- | Ring oscillator settles |
| 5 | Read Bank 2, COMP_STATUS (0x68) | -- | Read comparator result |

TILE_ROUTE_COMP_MUX breakdown:
- Bits [2:0] = 0x0 (comp+ legacy source = disconnected, overridden)
- Bit [3] = 1 (tile_override_pos = 1)
- Bits [6:4] = 0x2 (comp+ tile = Tile 2)
- Bit [7] = 0 (use OUT_MAIN, not TAP1)
- Bits [10:8] = 0x3 (comp- legacy source = ref ladder)
- Bit [11] = 0 (comp- not using tile override)

---

## 10. Physical Routing Constraints

### Metal Layer Allocation

| Layer | Usage | Rationale |
|-------|-------|-----------|
| M1 | Digital control routing (mux selects, enable signals) | Standard digital; avoids analog signal interference |
| M2 | Digital control routing (continued) | Standard digital |
| M3 | **Analog route matrix signals** (primary) | Preferred analog layer in SKY130 -- lower sheet resistance, wider minimum width |
| M4 | **Analog route matrix signals** (secondary / crossovers) | For crossing M3 routes; used where M3 alone cannot complete all paths |
| M5 | Power distribution (VDD_A, VSS_A to tiles) | Top metal for low-resistance power delivery |

### Trace Length Constraints

| Route Type | Maximum Trace Length | Reason |
|------------|---------------------|--------|
| Tile OUT_MAIN to ADC | 300 um | ADC input capacitance budget: ~1 pF. Longer traces add parasitic C degrading ADC accuracy. |
| Tile OUT_MAIN to Comp+/- | 300 um | Same capacitance concern for comparator input. |
| Legacy source (DAC/Ext/Ref) to tile STIM | 400 um | DAC output can drive higher capacitance; slightly relaxed. |
| Tile-to-tile (OUT to STIM) | 500 um | Cascade paths tolerate more parasitics since downstream tile buffers the signal. |
| Tile to DAC_OUT pad | 600 um | External pad has large capacitance anyway (~5 pF); trace adds marginal C. |

### Layout Placement Strategy

```
     ┌──────────────────────────────────────────┐
     │                                          │
     │    ┌────────────────┐   ┌────────┐       │
     │    │                │   │ Shared │       │
     │    │   DIGITAL      │   │ Analog │       │
     │    │   BACKBONE     │   │ (DAC,  │       │
     │    │                │   │  ADC,  │       │
     │    │                │   │  Comp, │       │
     │    │                │   │  Ref)  │       │
     │    └────────────────┘   └───┬────┘       │
     │                             │ <200um      │
     │                      ┌──────┴──────┐     │
     │                      │ ROUTE MATRIX│     │
     │                      │  (mux hier) │     │
     │                      └──────┬──────┘     │
     │               ┌─────────────┼──────────┐ │
     │               │  TILE ARRAY            │ │
     │               │  ┌────┐┌────┐┌────┐    │ │
     │               │  │ T0 ││ T1 ││ T2 │    │ │
     │               │  └────┘└────┘└────┘    │ │
     │               │  ┌────┐┌────┐┌────┐    │ │
     │               │  │ T3 ││ T4 ││ T5 │    │ │
     │               │  └────┘└────┘└────┘    │ │
     │               └────────────────────────┘ │
     └──────────────────────────────────────────┘
```

Key placement rules:
- Shared analog resources are placed **adjacent to the route matrix** (< 200 um separation).
- The route matrix sits **between shared analog and the tile array** to minimize worst-case trace lengths.
- Tiles are arranged in a 3x2 grid with guard rings (>= 5 um P+ to substrate) between each pair.
- Timing-class tiles (T2, T3) are placed in the bottom row, away from analog-sensitive tiles (T0, T1) to reduce substrate-coupled noise.
- The Class D tile (T5, LDO-Lite) is placed in a corner with dedicated power taps and extra guard ring spacing (>= 10 um).

### Parasitic Budget

| Parameter | Budget | Notes |
|-----------|--------|-------|
| Route matrix switch on-resistance | < 500 ohm | SKY130 transmission gate (`sky130_fd_sc_hd__einvp`) typical Ron ~200 ohm |
| Worst-case path resistance (2 switches + trace) | < 1.5 K ohm | Level 1 switch + Level 2 switch + M3 trace |
| Parasitic capacitance per route | < 500 fF | M3 trace + switch drain/source capacitance |
| Settling time (worst case, 10-bit accuracy) | < 1 us | RC = 1.5K x 500fF = 750 ps; 10-tau settling at ~7.5 ns. Margin is large. |

---

## 11. Cross-References

| Document | Relevance |
|----------|-----------|
| `v3_0_overview.md` | Architecture overview, Section 3.4 (route matrix summary) |
| `v3_0_tile_interface.md` | Tile I/O signals (stim_a, stim_b, out_main, tap1, tap2) |
| `v3_0_register_map.md` | Full bit-field definitions for Bank 2 tile routing registers |
| `v2_4_register_map.md` | v2.4 analog routing registers (backward compatibility baseline) |
| `analog_route_matrix.md` | v2.4 route matrix spec (predecessor to this document) |
