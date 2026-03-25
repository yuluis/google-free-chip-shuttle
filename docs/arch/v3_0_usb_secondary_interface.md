# ULC v3.0 USB Secondary Interface Requirements

**Status:** Draft
**Scope:** Board + chip-level requirements for optional USB-backed secondary communications
**Philosophy:** UART first. USB later. Fallback always available.

---

## 1. Overview

ULC v3.0 supports two operational communications paths:

| Path | Role | Required? | Available at Reset? |
|------|------|-----------|-------------------|
| **Primary UART** | Bring-up, debug, recovery, register access | Yes — always | Yes — immediately |
| **Secondary USB** | Convenience host interface, optional board power | No — optional | No — must be explicitly enabled |

The primary UART is the guaranteed control channel. USB is a convenience layer that may provide board power and a secondary serial/control path, but only after successful initialization. USB failure never blocks primary UART access.

**What this is NOT:**
- Not a replacement for UART
- Not required for first bring-up
- Not a direct 5V interface to the chip
- Not dependent on the on-chip LDO tile

---

## 2. Power Model

### Board-Level Power Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │                    BOARD                     │
                    │                                             │
  USB 5V ──[opt]──►│──► Board 3.3V LDO ──► VDD_A (3.3V analog)  │
                    │         │                                   │
                    │         └──► Board 1.8V LDO ──► VDD (1.8V) │
                    │                                             │
  Bench PSU ──────►│──► Same regulators (alternate source)       │
                    │                                             │
                    │  USB_VBUS_SENSE ──► Resistor divider ──►    │
                    │    GPIO or ADC input (power source detect)  │
                    └─────────────────────────────────────────────┘
```

| Requirement | Specification |
|-------------|--------------|
| USB VBUS input | 5V ±5% from USB host (Type-A or Type-C w/ UFP) |
| Board 3.3V regulator | 5V → 3.3V LDO (e.g., AMS1117-3.3), 500mA+, supplies VDD_A |
| Board 1.8V regulator | 3.3V → 1.8V LDO (e.g., AP2112K-1.8), 300mA+, supplies VDD |
| Chip 5V tolerance | **None.** Chip never sees 5V. All 5V-to-rail conversion is board-level. |
| Alternative power | Bench PSU / battery → same regulator inputs. USB not required. |
| On-chip LDO tile (T5) | Experiment only. NOT used for primary power. Board regulators are primary. |
| USB VBUS detection | Resistor divider (10K/10K) from VBUS → readable via GPIO or analog input |
| Power source reporting | Optional: `POWER_SOURCE_STATUS` register reports USB-powered vs bench-powered |

### Power Sequencing

1. Board power applied (USB or bench) → regulators produce 3.3V and 1.8V
2. Chip resets (RST_N released) → UART active, USB disabled
3. Host enables USB subsystem via register write over UART
4. USB enumerates → secondary serial available

**The chip does not care where board power comes from.** USB 5V and bench PSU are interchangeable at the regulator input.

---

## 3. Communications Model

### Primary UART (Unchanged)

| Property | Value |
|----------|-------|
| Pads | UART_TX (T2), UART_RX (T3) — dedicated, fixed |
| Baud | 115200 baud, 8N1 |
| Protocol | 'W'/'R'/'S'/'X' single-register R/W |
| Available at reset | Yes — immediately |
| Can be disabled | Only by explicit software write (not recommended) |
| Used for | Bring-up, recovery, debug, register access, safe control |

### Secondary USB

| Property | Value |
|----------|-------|
| Pads | SPARE_IO0 (T8) = USB_DP, SPARE_IO1 (T9) = USB_DM (alternate function) |
| Speed | USB Full-Speed (12 Mbps) |
| Device class | CDC-ACM (virtual serial port) |
| Protocol | Same register R/W protocol tunneled over USB-serial |
| Available at reset | No — disabled, pads in spare GPIO mode |
| Enabled by | `USB_CONTROL.usb_enable` register write (over primary UART) |
| Used for | Convenience host access, higher-speed transfer, secondary console |

### Switchover / Fallback Policy

| Rule | Behavior |
|------|----------|
| At reset | UART active, USB disabled, USB serial inactive |
| After USB enable | USB enumerates, CDC-ACM appears on host, USB serial available |
| Default dual-path | Both UART and USB-serial active simultaneously. No conflict — separate interfaces to same register bus. |
| USB preferred mode | Optional: `USB_COMM_PREF` bit promotes USB as the preferred response path. UART remains active. |
| USB auto-promote | Optional: `AUTO_USB_PROMOTE_EN` — if set, USB automatically becomes preferred once `USB_HEALTHY` asserts. UART still active. |
| USB failure | `USB_ERROR` asserts → system reverts to UART-only. `USB_FALLBACK_ACTIVE` flag set. |
| USB removal | VBUS loss detected → USB subsystem auto-disables. UART continues unaffected. |
| UART never auto-disabled | UART can only be disabled by explicit register write. Default: always on. |

### Register Bus Arbitration

Both UART and USB interfaces feed into the same register bus. Simple priority:

```
UART Host Bridge ──┐
                   ├──► Register Bus Arbiter ──► Register Bank
USB Serial Bridge ─┘
```

- UART has priority (lower latency, guaranteed path)
- USB accesses wait if UART is mid-transaction (max 1 byte time ≈ 87us at 115200)
- No deadlock possible — both are single-register atomic operations

---

## 4. Pad Budget Impact

### Current Pad Usage (v3.0 before USB)

| Edge | Functional | Power | Total | Notes |
|------|------------|-------|-------|-------|
| Top | 10 | 3 | 13 | UART, SPI, **SPARE_IO0, SPARE_IO1**, CLK_REF, RST_N |
| Left | 13 | 2 | 15 | GPIO[0:7], LED[0:4] |
| Right | 5 | 2 | 7 | Analog: DAC_OUT, ANA_IN, COMP_IN, ADC_REF, ROSC_MUX |
| Bottom | 3 | 4 | 7 | PLL_REF, DBG/GP0, DBG/GP1 |
| **Total** | **28** | **10** | **38** | |

### USB Pad Allocation: Zero New Pads

**SPARE_IO0 (T8) and SPARE_IO1 (T9) gain an alternate function:**

| Pad | Default Mode (reset) | Alternate Mode (USB enabled) |
|-----|---------------------|----------------------------|
| T8 (SPARE_IO0) | Spare GPIO, Hi-Z | USB_DP (Full-Speed data+) |
| T9 (SPARE_IO1) | Spare GPIO, Hi-Z | USB_DM (Full-Speed data-) |

**Mode switching:** Controlled by `USB_CONTROL.usb_enable`. When USB is disabled, pads function as normal spare GPIO. When USB is enabled, the pad mux routes USB transceiver signals instead.

### Analog Opportunity Cost

| Resource | Impact |
|----------|--------|
| Analog pads (right edge) | **Zero** — no analog pads consumed |
| Tile slots | **Zero** — USB controller is digital, lives in digital_core zone |
| Shared analog (DAC/ADC/Comp) | **Zero** — USB is purely digital |
| Spare IO when USB active | **Lost** — SPARE_IO0/IO1 unavailable as GPIO while USB is enabled |
| Spare IO when USB disabled | **None** — pads revert to spare GPIO at reset |

### Minimum Digital Interface Pad Set

| Pad | Function | Required? |
|-----|----------|-----------|
| UART_TX (T2) | Primary transmit | Yes — always |
| UART_RX (T3) | Primary receive | Yes — always |
| SPI_SCK/MOSI/MISO/CS (T4-T7) | SPI slave | Yes — bring-up flexibility |
| CLK_REF (T10) | Reference clock | Yes — chip operation |
| RST_N (T11) | Reset | Yes — chip operation |
| SPARE_IO0 (T8) | Spare GPIO / USB_DP | Dual-function |
| SPARE_IO1 (T9) | Spare GPIO / USB_DM | Dual-function |
| **Total dedicated digital** | | **9 fixed + 2 dual-function = 11** |

No additional pads needed for USB.

---

## 5. Register / Control Changes

### New Bank: Bank 7 — USB / Communications

12 registers for USB subsystem control and dual-interface management.

| Offset | Name | Access | Reset | Description |
|--------|------|--------|-------|-------------|
| 0x00 | USB_CONTROL | RW | 0x00 | USB subsystem control |
| 0x04 | USB_STATUS | R | 0x00 | USB subsystem status |
| 0x08 | USB_ERROR | R | 0x00 | USB error flags |
| 0x0C | USB_CONFIG | RW | 0x00 | USB device configuration |
| 0x10 | COMM_CONTROL | RW | 0x00 | Dual-interface management |
| 0x14 | COMM_STATUS | R | 0x00 | Communications status |
| 0x18 | USB_FRAME_COUNT | R | 0x00 | USB SOF frame counter (enumeration proof) |
| 0x1C | USB_EP_STATUS | R | 0x00 | Endpoint status (CDC-ACM) |
| 0x20 | COMM_LAST_HOST | R | 0x00 | Last active host path |
| 0x24 | POWER_SOURCE | R | 0x00 | Board power source status |
| 0x28 | USB_DEBUG | R | 0x00 | USB PHY / SIE debug |
| 0x2C | USB_RESERVED | R | 0x00 | Reserved |

#### USB_CONTROL (Bank 7, offset 0x00)

| Bit | Name | Type | Description |
|-----|------|------|-------------|
| [0] | usb_enable | RW | USB subsystem master enable. 0=disabled (pads in GPIO mode). |
| [1] | usb_local_reset | W/SC | Self-clearing USB local reset. Resets USB SIE + PHY without full chip reset. |
| [2] | usb_clk_en | RW | USB 48 MHz clock enable (from PLL or clock divider). |
| [3] | usb_pullup_en | RW | Enable 1.5K pull-up on USB_DP (signals device presence to host). |
| [4] | usb_phy_test | RW | USB PHY test mode (loopback). |
| [7:5] | -- | -- | Reserved |

#### USB_STATUS (Bank 7, offset 0x04)

| Bit | Name | Description |
|-----|------|-------------|
| [0] | usb_enabled | USB subsystem is enabled |
| [1] | usb_clk_ok | USB clock is running and stable |
| [2] | usb_attached | USB cable attached (VBUS detected) |
| [3] | usb_enumerated | USB device enumerated by host |
| [4] | usb_configured | USB device configured (CDC-ACM ready) |
| [5] | usb_suspended | USB bus suspended |
| [6] | usb_healthy | USB fully operational (attached + enumerated + configured + no error) |
| [7] | usb_active | USB serial path actively receiving/transmitting |

#### USB_ERROR (Bank 7, offset 0x08)

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

#### COMM_CONTROL (Bank 7, offset 0x10)

| Bit | Name | Type | Description |
|-----|------|------|-------------|
| [0] | uart_enable | RW | UART interface enable. **Default: 1 (always on).** |
| [1] | usb_comm_enable | RW | USB serial interface enable. Default: 0. |
| [2] | usb_comm_pref | RW | USB preferred for responses. Default: 0 (UART preferred). |
| [3] | auto_usb_promote_en | RW | Auto-promote USB to preferred once healthy. Default: 0. |
| [4] | uart_disable_allowed | RW | If 0, writes to uart_enable[0]=0 are blocked. Default: 0 (UART cannot be disabled). Safety latch. |
| [7:5] | -- | -- | Reserved |

#### COMM_STATUS (Bank 7, offset 0x14)

| Bit | Name | Description |
|-----|------|-------------|
| [0] | uart_active | UART interface is active (transmitting or receiving) |
| [1] | usb_serial_active | USB serial interface is active |
| [2] | usb_fallback_active | USB was preferred but fell back to UART due to error/removal |
| [3] | dual_path_active | Both UART and USB serial are simultaneously available |
| [5:4] | preferred_path | 00=UART, 01=USB, 10=both (dual), 11=reserved |
| [7:6] | last_active_path | 00=none, 01=UART, 10=USB, 11=both |

#### POWER_SOURCE (Bank 7, offset 0x24)

| Bit | Name | Description |
|-----|------|-------------|
| [0] | usb_vbus_present | USB VBUS detected (board-level sense) |
| [1] | bench_power_present | Non-USB power source detected (optional, board-dependent) |
| [3:2] | power_source | 00=unknown, 01=bench, 10=USB, 11=both |
| [7:4] | -- | Reserved |

### Bank 0 GLOBAL_CONTROL Extension

| Bit | Name | Type | Description |
|-----|------|------|-------------|
| [18] | usb_subsys_enable | RW | Global USB subsystem enable (AND'd with USB_CONTROL.usb_enable) |

### Bank 0 GLOBAL_STATUS Extension

| Bit | Name | Description |
|-----|------|-------------|
| [16] | usb_healthy | Copy of USB_STATUS.usb_healthy for quick polling |
| [17] | usb_fallback | Copy of COMM_STATUS.usb_fallback_active |

### Updated Bank Summary

| Bank | Name | v3.0 Regs | v3.0+USB Regs | Delta |
|------|------|-----------|---------------|-------|
| 0-6, 0xA | (all existing) | 149 | 149 | 0 (existing bits extended, no new offsets) |
| **7** | **USB / Communications** | **0** | **12** | **+12** |
| **Total** | | **149** | **161** | **+12** |

---

## 6. Bring-Up Modes

### Mode 0 — Safe Bring-Up (Default at Reset)

```
Power source: Bench PSU or USB VBUS (board doesn't care)
Chip state:   UART active, SPI active, USB disabled
USB pads:     SPARE_IO mode (Hi-Z)
USB serial:   Inactive
Recovery:     Full UART access
```

This is the guaranteed starting point. The chip is fully operational over UART. USB does not exist from the chip's perspective.

### Mode 1 — USB Power Present, USB Disabled

```
Power source: USB VBUS providing board power
Chip state:   UART active, USB subsystem still disabled
USB pads:     SPARE_IO mode (Hi-Z)
USB serial:   Inactive
Recovery:     Full UART access
```

Useful for staged bring-up: USB provides power but UART is the control channel. Board jumper may select USB power path.

### Mode 2 — USB Enabled, UART Still Active

```
Power source: Any
Chip state:   UART active, USB subsystem enabled and enumerated
USB pads:     USB_DP / USB_DM (alternate function active)
USB serial:   Active — host sees CDC-ACM serial port
Recovery:     UART still fully active as parallel path
```

Dual-path mode. Host can talk over UART or USB. Default: UART preferred for responses.

### Mode 3 — USB Preferred Convenience Mode

```
Power source: Any (typically USB)
Chip state:   UART active (background), USB preferred for normal I/O
USB pads:     USB_DP / USB_DM
USB serial:   Primary convenience interface
Recovery:     UART always available — send any command to reclaim
```

Software sets `usb_comm_pref=1` or `auto_usb_promote_en=1`. USB becomes the "normal" interface. UART remains active as rescue channel.

### Mode 4 — USB Fault / Recovery

```
Power source: May have lost USB VBUS
Chip state:   USB disabled/reset, UART active
USB pads:     Reverted to SPARE_IO mode (Hi-Z)
USB serial:   Inactive
Recovery:     Full UART access, same as Mode 0
```

Triggered by: USB error, VBUS loss, explicit USB local reset, or `usb_enable=0`. System reverts to UART-only. `USB_FALLBACK_ACTIVE` flag set in COMM_STATUS.

### Mode Transition Diagram

```
             ┌──────────────────────────────────────────────┐
             │                                              │
             ▼                                              │
  ┌──────────────┐    enable USB    ┌──────────────────┐    │
  │   Mode 0     │ ──────────────► │    Mode 2         │    │
  │ Safe Bring-Up│                  │ USB+UART Dual     │    │
  │ (UART only)  │ ◄────────────── │                    │    │
  └──────┬───────┘   USB disable    └────────┬─────────┘    │
         │           or fault                │              │
         │                              promote USB         │
         │                                   │              │
  ┌──────┴───────┐                  ┌────────▼─────────┐    │
  │   Mode 1     │                  │    Mode 3         │    │
  │ USB-Powered  │                  │ USB Preferred     │    │
  │ UART Control │                  │ (UART fallback)   │    │
  └──────────────┘                  └────────┬─────────┘    │
                                             │              │
                                        USB fault           │
                                             │              │
                                    ┌────────▼─────────┐    │
                                    │    Mode 4         │────┘
                                    │ USB Fault/Recovery│
                                    │ (back to UART)    │
                                    └──────────────────┘
```

---

## 7. USB On-Chip Architecture

### Block Diagram

```
  SPARE_IO0/USB_DP ──┐
  SPARE_IO1/USB_DM ──┤
                     ▼
  ┌──────────────────────────────────────────────┐
  │               USB SUBSYSTEM                   │
  │               (optional block)                │
  │                                               │
  │  ┌────────────┐  ┌───────────────────────┐   │
  │  │ Pad Mux    │  │ USB FS PHY            │   │
  │  │            │  │ (digital transceiver)  │   │
  │  │ GPIO ◄─┐  │  │ - NRZI encode/decode   │   │
  │  │ USB  ◄─┘  │──│ - bit stuffing          │   │
  │  │ (select)  │  │ - sync detect           │   │
  │  └────────────┘  │ - SE0/J/K generation   │   │
  │                  └───────────┬─────────────┘   │
  │                              │                 │
  │                  ┌───────────▼─────────────┐   │
  │                  │ USB SIE                  │   │
  │                  │ (Serial Interface Engine) │   │
  │                  │ - packet assembly        │   │
  │                  │ - CRC16 check            │   │
  │                  │ - endpoint routing        │   │
  │                  │ - handshake (ACK/NAK)    │   │
  │                  └───────────┬─────────────┘   │
  │                              │                 │
  │                  ┌───────────▼─────────────┐   │
  │                  │ CDC-ACM Device           │   │
  │                  │ - EP0: control           │   │
  │                  │ - EP1: bulk IN (TX)      │   │
  │                  │ - EP2: bulk OUT (RX)     │   │
  │                  │ - EP3: interrupt (notify)│   │
  │                  └───────────┬─────────────┘   │
  │                              │                 │
  │                  ┌───────────▼─────────────┐   │
  │                  │ USB Serial Bridge        │   │
  │                  │ - byte stream ↔ register │   │
  │                  │   bus (same protocol as  │   │
  │                  │   UART host bridge)      │   │
  │                  └───────────┬─────────────┘   │
  │                              │                 │
  └──────────────────────────────┼─────────────────┘
                                 │
                                 ▼
                     Register Bus Arbiter
                         │         │
                    UART Bridge    │
                                   ▼
                            Register Bank
```

### Gate Estimate

| Component | Est. Gates | Notes |
|-----------|-----------|-------|
| USB FS PHY (digital) | ~1,500 | NRZI, bit-stuffing, sync, SE0 |
| USB SIE | ~3,000 | Packet assembly, CRC, handshake |
| CDC-ACM device | ~2,000 | Descriptors, endpoint FSM, 64B buffers |
| USB serial bridge | ~500 | Byte stream adapter |
| Pad mux extension | ~100 | 2-pad alternate function |
| Register bus arbiter | ~200 | Priority mux, busy detection |
| **Total USB subsystem** | **~7,300** | |

**Updated chip total:** ~70K (existing) + ~7.3K (USB) = **~77K gates (9.4% Caravel)**

### USB Clock Requirement

USB Full-Speed requires a 48 MHz clock (±0.25%). Options:

| Source | Accuracy | Notes |
|--------|----------|-------|
| On-chip PLL | Depends on PLL design | Must be calibrated. PLL already exists in clock_experiment zone. |
| External 48 MHz | Best | Board-level crystal/oscillator. Routed via CLK_REF or PLL_REF with divider bypass. |
| Clock recovery from USB SOF | ±500ppm | SOF packets at 1ms intervals. Can discipline on-chip PLL. Good enough for FS. |

**Recommendation:** Use on-chip PLL locked to external CLK_REF. USB 48 MHz = PLL output with appropriate divider. If PLL is not locked, USB cannot enumerate — this is safe (falls back to UART-only).

### USB Block ID

| ID | Block | Zone |
|----|-------|------|
| 0x50 | USB_SUBSYSTEM | digital_core |

---

## 8. Robustness Guarantees

| Guarantee | Implementation |
|-----------|---------------|
| USB cannot strand the chip | UART is always on at reset. UART can only be disabled by explicit write with safety latch (`uart_disable_allowed`). USB failure auto-reverts to UART. |
| USB failure does not crash chip | USB subsystem is wrapped and isolated. USB local reset does not affect chip reset. USB errors are contained in Bank 7 registers. |
| USB cannot hang register bus | Register bus arbiter has timeout. If USB bridge is stuck, UART can still access registers (priority path). |
| USB cannot hang sequencer | Sequencer does not depend on USB. All sequencer commands work over UART. |
| USB disabled = zero impact | When `usb_enable=0`, USB clock is gated, PHY is disabled, pad mux routes to GPIO. Zero dynamic power, zero functional impact. |
| USB pads safe at reset | SPARE_IO0/IO1 in Hi-Z GPIO mode. No USB signaling until explicitly enabled. |
| Power loss recovery | USB VBUS loss auto-detected. USB subsystem auto-disables. Chip continues on whatever power remains. |
| No 5V on chip | All 5V-to-rail conversion is board-level. Chip sees only 3.3V and 1.8V. |
| LDO tile not required | Board regulators provide primary power. On-chip LDO is an experiment tile only. |

---

## 9. Risks and Mitigations

| # | Risk | Impact | Likelihood | Mitigation |
|---|------|--------|-----------|------------|
| 1 | USB PHY signal integrity insufficient for FS | USB fails to enumerate | Medium | Board-level series resistors (22 ohm) and ESD protection. Conservative output driver sizing. Fall back to UART. |
| 2 | 48 MHz clock accuracy insufficient | USB clock out of spec | Medium | External crystal reference. SOF-based clock recovery. PLL lock detection gates USB enable. |
| 3 | USB CDC-ACM driver bugs | Host can't communicate | Low | CDC-ACM is a well-defined USB class. Use proven open-source SIE RTL (e.g., usb_cdc from TinyFPGA). UART always available as fallback. |
| 4 | USB subsystem draws too much power | Drains power budget from tiles | Low | USB clock gated when disabled. Total USB power < 5mW (digital logic at 1.8V). Negligible vs analog tile budget. |
| 5 | USB auto-promote locks out debug | Can't reach chip for recovery | None | UART cannot auto-disable. Safety latch `uart_disable_allowed` defaults to 0. Must be explicitly set to even allow UART disable. |
| 6 | Pad mux glitches during USB enable | Spurious signals on USB lines | Low | Pad mux is glitch-free (registered output enable). USB PHY holds reset until mux is stable. |
| 7 | USB enumeration fails on some hosts | Works on some PCs, not others | Medium | CDC-ACM is universally supported. Include standard USB descriptors. Test on Linux/macOS/Windows. Worst case: UART works. |
| 8 | Register bus contention between UART and USB | Corrupted register access | None | Arbiter enforces mutual exclusion. UART has strict priority. Single-register atomic operations prevent interleaving. |

---

## 10. YAML Architecture Patch

Add to `v3_0_architecture.yaml`:

```yaml
# --- USB Secondary Interface (v3.0 addendum) ---
communications:
  primary:
    interface: UART
    pads: [UART_TX, UART_RX]  # T2, T3
    baud: 115200
    protocol: "W/R/S/X single-register"
    available_at_reset: true
    can_be_disabled: "only with explicit safety latch"
    role: "bring-up, debug, recovery, register access"

  secondary:
    interface: USB
    speed: full_speed_12mbps
    device_class: CDC-ACM
    pads: [SPARE_IO0, SPARE_IO1]  # T8, T9 (alternate function)
    pad_mode: dual_function  # GPIO default, USB when enabled
    available_at_reset: false
    enabled_by: USB_CONTROL.usb_enable
    role: "convenience host interface, secondary serial"
    block_id: 0x50
    gate_estimate: 7300
    clock_requirement: 48MHz  # from PLL or external

  arbitration:
    model: priority_mux
    priority: UART  # UART always wins
    dual_path: true  # both can be active simultaneously
    timeout_cycles: 1000  # arbiter timeout

  switchover:
    auto_promote: configurable  # AUTO_USB_PROMOTE_EN register bit
    uart_always_available: true
    usb_fallback_to_uart: automatic  # on USB error/removal
    uart_disable_requires: explicit_safety_latch

board_power:
  usb_vbus:
    voltage: 5.0
    role: optional_board_power_source
    never_reaches_chip: true
  board_regulators:
    - {input: "5V (USB or bench)", output: "3.3V", rail: VDD_A}
    - {input: "3.3V", output: "1.8V", rail: VDD}
  on_chip_ldo_tile:
    role: experiment_only
    not_required_for: primary_power

usb_subsystem:
  register_bank: 7
  registers: 12
  offset_range: [0x00, 0x2C]
  components:
    - usb_fs_phy          # digital transceiver
    - usb_sie             # serial interface engine
    - usb_cdc_acm         # device class
    - usb_serial_bridge   # register bus adapter
    - pad_mux_extension   # spare IO alternate function
    - register_bus_arbiter

operational_modes:
  - {id: 0, name: safe_bringup,    uart: active, usb: disabled,  description: "Default at reset"}
  - {id: 1, name: usb_power_only,  uart: active, usb: disabled,  description: "USB provides board power, UART controls"}
  - {id: 2, name: dual_path,       uart: active, usb: active,    description: "Both interfaces available"}
  - {id: 3, name: usb_preferred,   uart: active, usb: preferred, description: "USB convenience mode, UART fallback"}
  - {id: 4, name: usb_fault,       uart: active, usb: disabled,  description: "USB failed, reverted to UART"}
```

---

## 11. Document Cross-References

| Document | Contents |
|----------|----------|
| `docs/arch/v3_0_usb_secondary_interface.md` | This document — requirements and design |
| `docs/bringup/uart_first_usb_later.md` | Step-by-step bring-up sequence |
| `docs/board/usb_power_and_secondary_comm.md` | Board-level schematic requirements |
| `docs/arch/v3_0_register_map.md` | Bank 7 register definitions |
| `docs/arch/v3_0_architecture.yaml` | Machine-readable architecture |
| `docs/arch/v3_0_overview.md` | Chip architecture overview |
