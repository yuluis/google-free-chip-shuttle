# ULC v3.0 Complete Register Map

**Status:** Draft
**Total banks:** 9 (0-7, 0xA)
**Total registers:** 161 (was 92 in v2.4)
**Addressing:** BANK_SELECT + 8-bit offset
**Data width:** 32-bit
**Access types:** R (read-only), W (write-only), RW (read-write)

---

## Addressing Model

Unchanged from v2.4. UART serial protocol, BANK_SELECT (Bank 0, offset 0x04) selects active bank. Bank 0 always accessible.

---

## Serial Protocol

Unchanged from v2.4. See `v2_4_register_map.md`.

---

## Changes from v2.4

| Change | Details |
|--------|---------|
| Analog voltage | VDD_A = **3.3V** (Caravel VDDA). Shared analog + tiles operate at 3.3V. Level shifters at 1.8V/3.3V boundary. |
| Per-tile power gating | TILE_POWER_CONTROL register (Bank 6, offset 0xF0) controls PMOS header switches per tile |
| CHIP_REV | Updated to 0x00000300 (v3.0) |
| GLOBAL_CONTROL | +3 bits: tile_enable_all[15], tile_isolate_all[16], tile_sweep_mode[17] |
| GLOBAL_STATUS | +2 bits: any_tile_busy[13], any_tile_error[14] |
| Bank 2 (Analog) | Route matrix registers extended with tile source/dest fields |
| Bank 3 (BIST) | +1 chain (Chain 5: tile digital control) |
| Bank 5 (Log) | Log entries now include tile_id in block_id field |
| **Bank 6 (Tile)** | **NEW: 48 registers (8 per tile x 6 tiles)** |
| Bank 0 BLOCK_SELECT | Now accepts tile block IDs 0x30-0x35 |
| Bank 0 COMMAND | +2 commands: CMD_SELECT_TILE (0x20), CMD_TILE_SWEEP (0x21) |
| Bank 0 GLOBAL_CONTROL | +1 bit: usb_subsys_enable[18] |
| Bank 0 GLOBAL_STATUS | +2 bits: usb_healthy[16], usb_fallback[17] |
| **Bank 7 (USB/Comms)** | **NEW: 12 registers for USB subsystem + dual-interface management** |

---

## Bank 0 -- Global (31 registers)

All v2.4 registers preserved at same offsets. Changes noted.

| Offset | Name | Access | Reset Value | Change from v2.4 |
|--------|------|--------|-------------|------------------|
| 0x00 | CHIP_ID | R | 0x554C4333 | **Changed:** "ULC3" (was "ULC$") |
| 0x04 | BANK_SELECT | RW | 0x00000000 | Now accepts bank 6 |
| 0x08 | GLOBAL_CONTROL | RW | 0x00000000 | **Extended:** see below |
| 0x0C | GLOBAL_STATUS | R | -- | **Extended:** see below |
| 0x10 | BLOCK_SELECT | RW | 0x00000000 | Now accepts 0x30-0x35 (tiles) |
| 0x14 | COMMAND | W | -- | +2 commands (0x20, 0x21) |
| 0x18 | TIMEOUT_CYCLES | RW | 0x000F4240 | Unchanged |
| 0x1C-0x28 | RESULT0-3 | R | 0x00000000 | Unchanged |
| 0x2C | ERROR_CODE | R | 0x00000000 | New tile error codes added |
| 0x30-0x3C | PASS/FAIL/LAST_BLOCK/STATE | R | 0x00000000 | Unchanged |
| 0x40-0x44 | LOG_PTR/COUNT | R | 0x00000000 | Unchanged |
| 0x48 | CHIP_REV | R | **0x00000300** | **Changed:** v3.0 |
| 0x50-0x58 | EXPERIMENT_* | RW/R | 0x00000000 | Extended for tile experiments |
| 0x5C | SOFTWARE_RESET | W | -- | Unchanged |
| 0x60-0x6C | SNAP_* | R | 0x00000000 | SNAP_FLAGS extended |
| 0x70-0x74 | DEBUG/SPARE | RW | 0x00000000 | Unchanged |
| 0x78 | BOOT_STATUS | R | -- | Unchanged |

### GLOBAL_CONTROL Extended Bits (Bank 0, offset 0x08)

Bits [0:14] unchanged from v2.4. New bits:

| Bit | Name | Type | Description |
|-----|------|------|-------------|
| [15] | tile_enable_all | RW | Master enable for all tiles (AND'd with per-tile enables) |
| [16] | tile_isolate_all | W/SC | Self-clearing: force-isolate all tiles immediately |
| [17] | tile_sweep_mode | RW | Sequencer sweeps all enabled tiles when running tile experiments |
| [31:18] | -- | -- | Reserved (read as 0) |

### GLOBAL_STATUS Extended Bits (Bank 0, offset 0x0C)

Bits [0:12] unchanged from v2.4. New bits:

| Bit | Name | Description |
|-----|------|-------------|
| [13] | any_tile_busy | OR of all tile busy signals |
| [14] | any_tile_error | OR of all tile error signals |
| [15] | tile_sweep_active | Tile sweep in progress |

### New Test Commands

| Code | Name | Description |
|------|------|-------------|
| 0x20 | CMD_SELECT_TILE | Select tile (BLOCK_SELECT = 0x30-0x35) for subsequent operations |
| 0x21 | CMD_TILE_SWEEP | Run current experiment on all enabled tiles sequentially |

### New Error Codes

| Code | Name | Description |
|------|------|-------------|
| 0x20 | ERR_TILE_TIMEOUT | Tile DUT did not complete |
| 0x21 | ERR_TILE_OVERCURRENT | Tile current limit triggered |
| 0x22 | ERR_TILE_NOT_PRESENT | Selected tile slot is empty |
| 0x23 | ERR_TILE_ISOLATED | Tile is force-isolated |
| 0x24 | ERR_TILE_NO_POWER | Tile enable attempted while VDD_TILE not stable |

---

## Bank 1 -- Clock (13 registers -- was 12)

All v2.4 registers unchanged. One addition:

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x00-0x34 | (all v2.4 regs) | | | Unchanged |
| **0x38** | **CLK_TILE_SELECT** | **RW** | **0x00000000** | **Tile clock source selection (which clock drives clk_tile)** |

`CLK_TILE_SELECT[2:0]`: same encoding as `clock_source_t` (0=ext_ref, 1=ring_osc, 2=div_sys, 3=pll_out, 4=test_gen).

---

## Bank 2 -- Analog (24 registers -- was 18)

All v2.4 registers preserved at same offsets. 6 new registers for tile routing.

### Existing (unchanged)

| Offset | Name | Description |
|--------|------|-------------|
| 0x00-0x0C | AROUTE_CONTROL/STATUS/ADC_SRC/COMP_SRC | Unchanged |
| 0x20-0x34 | DAC_* | Unchanged |
| 0x40-0x4C | ADC_* | Unchanged |
| 0x60-0x6C | COMP_* | Unchanged |

### New: Tile Routing Registers

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x70 | TILE_ROUTE_STIM_A | RW | 0x00000000 | STIM_A source for each tile (4 bits per tile, 6 tiles) |
| 0x74 | TILE_ROUTE_STIM_B | RW | 0x00000000 | STIM_B source for each tile (4 bits per tile) |
| 0x78 | TILE_ROUTE_ADC_MUX | RW | 0x00000000 | ADC input source extension: tile outputs selectable |
| 0x7C | TILE_ROUTE_COMP_MUX | RW | 0x00000000 | Comp input source extension: tile outputs selectable |
| 0x80 | TILE_ROUTE_STATUS | R | 0x00000000 | Tile routing status (contention, active flags) |
| 0x84 | TILE_ROUTE_EXT_OUT | RW | 0x00000000 | Select which tile output routes to DAC_OUT/SPARE pads |

### TILE_ROUTE_STIM_A Encoding (offset 0x70)

```
[3:0]   = Tile 0 STIM_A source
[7:4]   = Tile 1 STIM_A source
[11:8]  = Tile 2 STIM_A source
[15:12] = Tile 3 STIM_A source
[19:16] = Tile 4 STIM_A source
[23:20] = Tile 5 STIM_A source
[31:24] = Reserved
```

Source encoding (4 bits per tile):

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

Same encoding for TILE_ROUTE_STIM_B (offset 0x74).

### TILE_ROUTE_ADC_MUX Extension (offset 0x78)

Extends the v2.4 ADC source selection to include tile outputs:

```
[2:0]  = ADC source (v2.4 encoding: 0=disc, 1=DAC, 2=ext, 3=ref, 4=rosc)
[3]    = Override: 1 = use tile source instead of [2:0]
[6:4]  = Tile output to route to ADC (0-5 = tile 0-5 OUT_MAIN)
[7]    = Use TAP1 instead of OUT_MAIN
[31:8] = Reserved
```

### TILE_ROUTE_STATUS (offset 0x80)

```
[5:0]   = Per-tile STIM_A connected flags
[11:6]  = Per-tile STIM_B connected flags
[17:12] = Per-tile OUT_MAIN connected flags
[18]    = Contention detected (any bus conflict)
[19]    = Tile-to-tile loop detected (potential feedback)
[31:20] = Reserved
```

---

## Bank 3 -- BIST (7 registers -- was 6)

All v2.4 registers unchanged. Chain count increased from 5 to 6.

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x00-0x14 | (all v2.4 regs) | | | Unchanged |
| **0x18** | **BIST_TILE_STATUS** | **R** | **0x00000000** | **Per-tile BIST chain capture results** |

`BIST_CHAIN_SEL` now accepts value 5 (Chain 5: tile digital control chain).

Chain 5 bit mapping:
```
[5:0]   = Per-tile enable bits (captured from tile controller)
[11:6]  = Per-tile isolation bits
[17:12] = Per-tile error flags
[23:18] = Per-tile done flags
[31:24] = Reserved
```

---

## Bank 4 -- Security (12 registers)

**Unchanged from v2.4.** See `v2_4_register_map.md`.

---

## Bank 5 -- Log (7 registers)

**Register offsets unchanged.** Log entry format extended:

The `LOG_ENTRY_BLOCK` field (offset 0x04) now encodes tile IDs:
- Block IDs 0x00-0x20: same as v2.4
- Block IDs 0x30-0x35: tile 0-5
- Block ID 0x40: tile controller

This requires no register changes — the existing block_id field naturally accommodates the new IDs.

---

## Bank 6 -- Tile Control (NEW -- 48 registers)

8 registers per tile, 6 tiles. All tiles software-identical.

### Tile Address Mapping

| Tile | Base Offset | Range |
|------|------------|-------|
| Tile 0 | 0x00 | 0x00-0x07 (word-addressed: 0x00-0x1C) |
| Tile 1 | 0x20 | 0x20-0x3C |
| Tile 2 | 0x40 | 0x40-0x5C |
| Tile 3 | 0x60 | 0x60-0x7C |
| Tile 4 | 0x80 | 0x80-0x9C |
| Tile 5 | 0xA0 | 0xA0-0xBC |
| (Tile 6) | 0xC0 | Reserved |
| (Tile 7) | 0xE0 | Reserved |

**Note:** Word-addressed (each register offset is +4 bytes). The spacing is 0x20 (32 bytes = 8 registers x 4 bytes) per tile.

### Per-Tile Register Definition

Offsets shown relative to tile base.

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| +0x00 | TILE_CONTROL | RW | 0x00000000 | Tile control register (see bits below) |
| +0x04 | TILE_STATUS | R | 0x00000000 | Tile status register (see bits below) |
| +0x08 | TILE_MODE | RW | 0x00000000 | DUT-specific mode configuration |
| +0x0C | TILE_ROUTE_IN | RW | 0x00000000 | Input routing (local override, see below) |
| +0x10 | TILE_ROUTE_OUT | RW | 0x00000000 | Output routing (local override, see below) |
| +0x14 | TILE_PARAM | RW | 0x00000000 | DUT-specific parameter word |
| +0x18 | TILE_RESULT | R | 0x00000000 | DUT primary measurement result |
| +0x1C | TILE_DEBUG | R | 0x00000000 | DUT debug / observation word |

### TILE_CONTROL Bit Definitions

| Bit | Name | Type | Description |
|-----|------|------|-------------|
| [0] | enable | RW | Tile master enable (0=disabled+isolated) |
| [1] | reset | W/SC | Self-clearing local reset pulse |
| [2] | start | W/SC | Self-clearing start pulse |
| [5:3] | mode | RW | DUT mode selection (tile-specific) |
| [6] | force_isolate | RW | Force-isolate tile (override enable) |
| [7] | auto_restore | RW | Auto-restore safe state on error (default=1 after reset) |
| [31:8] | -- | -- | Reserved |

### TILE_STATUS Bit Definitions

| Bit | Name | Description |
|-----|------|-------------|
| [0] | enabled | Tile is enabled and not isolated |
| [1] | busy | DUT operation in progress |
| [2] | done | DUT operation complete |
| [3] | pass | Self-test passed |
| [4] | error | Error detected |
| [7:5] | error_code_lo | Error code [2:0] |
| [8] | isolated | Tile is isolated (force_isolate or disabled) |
| [9] | stim_a_connected | STIM_A has a source routed |
| [10] | stim_b_connected | STIM_B has a source routed |
| [11] | out_connected | OUT_MAIN has a destination |
| [12] | present | Tile physically present (1) or absent (0) |
| [13] | power_good | VDD_TILE is stable (from power-good detector) |
| [14] | powered | PMOS power switch is closed |
| [17:15] | fsm_state | Tile wrapper FSM state (debug): 0=UNPOWERED, 1=DISABLED, 2=IDLE, 3=RUNNING, 4=DONE, 5=ERROR |
| [31:18] | -- | Reserved |

### TILE_MODE Register

| Bit | Name | Description |
|-----|------|-------------|
| [2:0] | mode | Same as TILE_CONTROL[5:3] (alias for convenience) |
| [7:3] | submode | DUT-specific sub-mode (tile-defined) |
| [31:8] | config | DUT-specific configuration word |

### TILE_ROUTE_IN Register (Per-Tile Local Override)

This register provides per-tile routing control as an alternative to the global TILE_ROUTE_STIM_A/B registers in Bank 2.

| Bit | Name | Description |
|-----|------|-------------|
| [3:0] | stim_a_src | STIM_A source (same encoding as Bank 2 TILE_ROUTE_STIM_A) |
| [7:4] | stim_b_src | STIM_B source |
| [8] | use_local | 1 = use this register; 0 = use Bank 2 global routing |
| [31:9] | -- | Reserved |

### TILE_ROUTE_OUT Register (Per-Tile Local Override)

| Bit | Name | Description |
|-----|------|-------------|
| [2:0] | out_dest | OUT_MAIN destination (0=disconnected, 1=ADC, 2=comp+, 3=comp-, 4=ext_pad, 5=spare_io0) |
| [5:3] | tap1_dest | TAP1 destination (same encoding) |
| [6] | use_local | 1 = use this register; 0 = use Bank 2 global routing |
| [31:7] | -- | Reserved |

### TILE_PARAM Register

Interpretation is tile-specific. Common convention:

| Bit | Common Usage |
|-----|-------------|
| [9:0] | Bias/trim code (10-bit, matching DAC resolution) |
| [15:10] | Gain/ratio setting |
| [23:16] | Timeout multiplier (0=use default) |
| [31:24] | Tile-specific flags |

### TILE_RESULT Register

| Bit | Common Usage |
|-----|-------------|
| [15:0] | Primary measurement value |
| [31:16] | Secondary measurement or metadata |

### TILE_DEBUG Register

| Bit | Common Usage |
|-----|-------------|
| [15:0] | Internal node observation |
| [31:16] | FSM state, cycle count, or diagnostic |
| Special | 0xDEADBEEF = tile not present |

### Global Tile Power Register (Bank 6, offset 0xF0)

This register is NOT per-tile — it controls power for all tiles from a single address.

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0xF0 | TILE_POWER_CONTROL | RW | 0x00000000 | Per-tile power switch control |

**Bit definitions:**

| Bit | Name | Type | Description |
|-----|------|------|-------------|
| [5:0] | tile_power_en | RW | Per-tile PMOS switch enable (bit N = tile N). 0 = switch open (unpowered). |
| [7:6] | -- | -- | Reserved |
| [13:8] | tile_power_good | R | Per-tile power-good flags (VDD_TILE stable). Read-only. |
| [15:14] | -- | -- | Reserved |
| [16] | global_power_en | RW | Master power enable (AND'd with per-tile bits). 0 = all tiles unpowered. |
| [17] | staggered_start | RW | 1 = power-on tiles sequentially (100us spacing). 0 = simultaneous. |
| [31:18] | -- | -- | Reserved |

**Reset state:** All zeros — all tiles unpowered at reset. Host must explicitly power on tiles.

**Power sequencing:**
1. Write `global_power_en` = 1, `tile_power_en[N]` = 1
2. Poll `tile_power_good[N]` until = 1 (~50us settling)
3. Then write `TILE_CONTROL.enable` = 1 (per-tile register)

If enable is written while power_good = 0, the tile controller blocks it and reports ERR_TILE_NO_POWER.

---

## Bank 7 -- USB / Communications (NEW -- 12 registers)

Optional USB subsystem and dual-interface management. USB disabled at reset.

| Offset | Name | Access | Reset Value | Description |
|--------|------|--------|-------------|-------------|
| 0x00 | USB_CONTROL | RW | 0x00000000 | USB subsystem control |
| 0x04 | USB_STATUS | R | 0x00000000 | USB subsystem status |
| 0x08 | USB_ERROR | R | 0x00000000 | USB error flags |
| 0x0C | USB_CONFIG | RW | 0x00000000 | USB device configuration |
| 0x10 | COMM_CONTROL | RW | 0x00000001 | Dual-interface management (uart_enable=1 default) |
| 0x14 | COMM_STATUS | R | 0x00000000 | Communications path status |
| 0x18 | USB_FRAME_COUNT | R | 0x00000000 | USB SOF frame counter |
| 0x1C | USB_EP_STATUS | R | 0x00000000 | USB endpoint status (CDC-ACM) |
| 0x20 | COMM_LAST_HOST | R | 0x00000000 | Last active host path |
| 0x24 | POWER_SOURCE | R | 0x00000000 | Board power source status |
| 0x28 | USB_DEBUG | R | 0x00000000 | USB PHY/SIE debug |
| 0x2C | USB_RESERVED | R | 0x00000000 | Reserved |

### USB_CONTROL (Bank 7, offset 0x00)

| Bit | Name | Type | Description |
|-----|------|------|-------------|
| [0] | usb_enable | RW | USB subsystem master enable. 0=disabled, pads in GPIO mode. |
| [1] | usb_local_reset | W/SC | Self-clearing USB local reset (SIE + PHY, not full chip). |
| [2] | usb_clk_en | RW | USB 48 MHz clock enable. |
| [3] | usb_pullup_en | RW | Enable 1.5K pull-up on USB_DP (signals device presence). |
| [4] | usb_phy_test | RW | PHY loopback test mode. |
| [31:5] | -- | -- | Reserved |

### USB_STATUS (Bank 7, offset 0x04)

| Bit | Name | Description |
|-----|------|-------------|
| [0] | usb_enabled | USB subsystem is enabled |
| [1] | usb_clk_ok | USB clock running and stable |
| [2] | usb_attached | USB cable attached (VBUS detected) |
| [3] | usb_enumerated | USB device enumerated by host |
| [4] | usb_configured | USB CDC-ACM ready |
| [5] | usb_suspended | USB bus suspended |
| [6] | usb_healthy | Fully operational (attached+enumerated+configured+no error) |
| [7] | usb_active | USB serial path actively transferring |

### USB_ERROR (Bank 7, offset 0x08)

| Bit | Name | Description |
|-----|------|-------------|
| [0] | usb_err_crc | CRC error on received packet |
| [1] | usb_err_timeout | Transaction timeout |
| [2] | usb_err_bitstuff | Bit-stuffing error |
| [3] | usb_err_overflow | Endpoint buffer overflow |
| [4] | usb_err_no_clk | USB clock not available |
| [5] | usb_err_phy | PHY-level error |
| [6] | usb_err_vbus_lost | VBUS dropped during operation |
| [7] | usb_err_any | OR of all error bits |

### COMM_CONTROL (Bank 7, offset 0x10)

| Bit | Name | Type | Description |
|-----|------|------|-------------|
| [0] | uart_enable | RW | UART enable. **Default: 1 (always on).** |
| [1] | usb_comm_enable | RW | USB serial enable. Default: 0. |
| [2] | usb_comm_pref | RW | USB preferred for responses. Default: 0 (UART preferred). |
| [3] | auto_usb_promote_en | RW | Auto-promote USB once healthy. Default: 0. |
| [4] | uart_disable_allowed | RW | Safety latch: if 0, uart_enable cannot be cleared. Default: 0. |
| [31:5] | -- | -- | Reserved |

### COMM_STATUS (Bank 7, offset 0x14)

| Bit | Name | Description |
|-----|------|-------------|
| [0] | uart_active | UART interface active |
| [1] | usb_serial_active | USB serial interface active |
| [2] | usb_fallback_active | USB fell back to UART (error/removal) |
| [3] | dual_path_active | Both UART and USB serial available |
| [5:4] | preferred_path | 00=UART, 01=USB, 10=both, 11=reserved |
| [7:6] | last_active_path | 00=none, 01=UART, 10=USB, 11=both |

### POWER_SOURCE (Bank 7, offset 0x24)

| Bit | Name | Description |
|-----|------|-------------|
| [0] | usb_vbus_present | USB VBUS detected (board-level sense) |
| [1] | bench_power_present | Non-USB power detected (board-dependent) |
| [3:2] | power_source | 00=unknown, 01=bench, 10=USB, 11=both |
| [31:4] | -- | Reserved |

### Bank 0 GLOBAL_CONTROL Extension (USB bits)

| Bit | Name | Type | Description |
|-----|------|------|-------------|
| [18] | usb_subsys_enable | RW | Global USB enable (AND'd with USB_CONTROL.usb_enable) |

### Bank 0 GLOBAL_STATUS Extension (USB bits)

| Bit | Name | Description |
|-----|------|-------------|
| [16] | usb_healthy | Copy of USB_STATUS.usb_healthy |
| [17] | usb_fallback | Copy of COMM_STATUS.usb_fallback_active |

---

## Bank 0xA -- Dangerous (6 registers)

**Unchanged from v2.4.** See `v2_4_register_map.md`.

---

## Register Count Summary

| Bank | Name | v2.4 Regs | v3.0 Regs | Delta |
|------|------|-----------|-----------|-------|
| 0 | Global | 31 | 31 | 0 (bits extended, no new offsets) |
| 1 | Clock | 12 | 13 | +1 (CLK_TILE_SELECT) |
| 2 | Analog | 18 | 24 | +6 (tile routing) |
| 3 | BIST | 6 | 7 | +1 (tile BIST status) |
| 4 | Security | 12 | 12 | 0 |
| 5 | Log | 7 | 7 | 0 |
| **6** | **Tile** | **0** | **49** | **+49 (new bank: 48 per-tile + 1 power control)** |
| **7** | **USB / Comms** | **0** | **12** | **+12 (new bank: USB control/status/comms)** |
| 0xA | Dangerous | 6 | 6 | 0 |
| **Total** | | **92** | **161** | **+69** |

---

## Backward Compatibility

| Aspect | Compatible? | Notes |
|--------|------------|-------|
| Bank 0 offsets | Yes | All offsets preserved; new bits in reserved fields |
| Banks 1-5 offsets | Yes | Existing offsets unchanged; new registers added at unused offsets |
| Bank 0xA | Yes | Identical |
| UART protocol | Yes | Same 'W'/'R'/'S'/'X' commands |
| Bank 7 (USB) | N/A | New bank — USB subsystem optional, not present in v2.4 |
| Host driver | Minor update | Add Bank 6 (tile) + Bank 7 (USB) constants and block IDs |
| FPGA twin | Yes | Tile controller + USB SIE are purely digital |
