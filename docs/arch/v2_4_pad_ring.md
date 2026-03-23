# ULC v2.4 Pad Ring

**Status:** Frozen
**Total pads:** 38
**Functional pads:** 28
**Power/ground pads:** 10
**Power domains:** 3

---

## Pad Ring Summary

```
                         TOP EDGE (13 pads)
          ┌──────────────────────────────────────────┐
          │ VDD UART_TX UART_RX SPI_SCK MOSI MISO   │
          │ CS  SPARE0  SPARE1  CLK_REF RST_N   VDD  │
          │  VSS                                      │
     ┌────┤                                           ├────┐
     │VDD │                                           │V_A │
     │GP0 │                                           │DAC │
     │GP1 │                                           │ANA │
     │GP2 │            2.92 x 3.52 mm                 │CMP │
LEFT │GP3 │               ULC v2.4                    │REF │ RIGHT
(15) │GP4 │                                           │RSC │ (7)
     │GP5 │                                           │V_A │
     │GP6 │                                           │    │
     │GP7 │                                           │    │
     │LD0 │                                           │    │
     │LD1 │                                           │    │
     │LD2 │                                           │    │
     │LD3 │                                           │    │
     │LD4 │                                           │    │
     │VSS │                                           │    │
     └────┤                                           ├────┘
          │                                           │
          │ VDD VSS PLL_REF DBG0 DBG1 VDD_E VSS_E    │
          └──────────────────────────────────────────┘
                        BOTTOM EDGE (7 pads)
```

---

## Top Edge — 13 Pads (Host Digital + Spare)

Host-facing interfaces. All digital, VDD/VSS power domain.

| Pad # | Name | Type | Direction | Domain | Description |
|-------|------|------|-----------|--------|-------------|
| T1 | VDD | Power | — | Digital | Core digital power |
| T2 | UART_TX | Digital | Output | VDD | UART transmit to host |
| T3 | UART_RX | Digital | Input | VDD | UART receive from host |
| T4 | SPI_SCK | Digital | Input | VDD | SPI clock |
| T5 | MOSI | Digital | Input | VDD | SPI master-out-slave-in |
| T6 | MISO | Digital | Output | VDD | SPI master-in-slave-out |
| T7 | CS | Digital | Input | VDD | SPI chip select (active low) |
| T8 | SPARE_IO0 | Digital | Muxed | VDD | Spare I/O 0 (default: Hi-Z) |
| T9 | SPARE_IO1 | Digital | Muxed | VDD | Spare I/O 1 (default: Hi-Z) |
| T10 | CLK_REF | Digital | Input | VDD | External reference clock input |
| T11 | RST_N | Digital | Input | VDD | Active-low chip reset |
| T12 | VSS | Power | — | Digital | Core digital ground |
| T13 | VDD | Power | — | Digital | Core digital power |

**Spare pad behavior:** SPARE_IO0 and SPARE_IO1 are tri-stated (Hi-Z) at reset. Direction and function controlled by `SPARE_PAD_CTRL` (Bank 0, offset 0x74). No programmable crossbar — direct mux only.

---

## Left Edge — 15 Pads (GPIO + LED)

General-purpose I/O and LED drivers. All digital, VDD/VSS power domain.

| Pad # | Name | Type | Direction | Domain | Description |
|-------|------|------|-----------|--------|-------------|
| L1 | VDD | Power | — | Digital | Core digital power |
| L2 | GPIO[0] | Digital | Bidir | VDD | General-purpose I/O bit 0 |
| L3 | GPIO[1] | Digital | Bidir | VDD | General-purpose I/O bit 1 |
| L4 | GPIO[2] | Digital | Bidir | VDD | General-purpose I/O bit 2 |
| L5 | GPIO[3] | Digital | Bidir | VDD | General-purpose I/O bit 3 |
| L6 | GPIO[4] | Digital | Bidir | VDD | General-purpose I/O bit 4 |
| L7 | GPIO[5] | Digital | Bidir | VDD | General-purpose I/O bit 5 |
| L8 | GPIO[6] | Digital | Bidir | VDD | General-purpose I/O bit 6 |
| L9 | GPIO[7] | Digital | Bidir | VDD | General-purpose I/O bit 7 |
| L10 | LED[0] | Digital | Output | VDD | LED driver channel 0 |
| L11 | LED[1] | Digital | Output | VDD | LED driver channel 1 |
| L12 | LED[2] | Digital | Output | VDD | LED driver channel 2 |
| L13 | LED[3] | Digital | Output | VDD | LED driver channel 3 |
| L14 | LED[4] | Digital | Output | VDD | LED driver channel 4 |
| L15 | VSS | Power | — | Digital | Core digital ground |

**GPIO direction:** Each GPIO bit has independent output-enable. Default at reset: all inputs (Hi-Z output).

**LED drivers:** Push-pull outputs. Default at reset: all LOW (LEDs off).

---

## Right Edge — 7 Pads (Analog)

Mixed-signal interfaces. VDD_A/VSS_A power domain.

| Pad # | Name | Type | Direction | Domain | Description |
|-------|------|------|-----------|--------|-------------|
| R1 | VDD_A | Power | — | Analog | Analog power |
| R2 | DAC_OUT | Analog | Output | VDD_A | DAC analog output |
| R3 | ANA_IN | Analog | Input | VDD_A | General analog input (routed via AROUTE) |
| R4 | COMP_IN | Analog | Input | VDD_A | Comparator external input |
| R5 | ADC_REF | Analog | Input | VDD_A | ADC reference voltage input |
| R6 | ROSC_MUX | Digital | Muxed | VDD_A | Ring oscillator output / analog debug (digital level, muxed) |
| R7 | VSS_A | Power | — | Analog | Analog ground |

**ROSC_MUX:** Digital-level output on analog power domain. Default at reset: driven LOW. Mux controlled by `ROSC_CONTROL` (Bank 1, offset 0x30).

**DAC_OUT:** Analog output. At reset: code 0, output disabled (pulled to VSS_A through weak keeper).

---

## Bottom Edge — 7 Pads (Clock + Debug + Dangerous Power)

Clock experiment, debug/general-purpose, and dangerous zone power.

| Pad # | Name | Type | Direction | Domain | Description |
|-------|------|------|-----------|--------|-------------|
| B1 | VDD | Power | — | Digital | Core digital power |
| B2 | VSS | Power | — | Digital | Core digital ground |
| B3 | PLL_REF | Clock | Input | VDD | PLL reference clock input |
| B4 | DBG/GP0 | Digital | Muxed | VDD | Debug output 0 / GPIO (default: GPIO input) |
| B5 | DBG/GP1 | Digital | Muxed | VDD | Debug output 1 / GPIO (default: GPIO input) |
| B6 | VDD_E | Power | — | Dangerous | Dangerous zone power |
| B7 | VSS_E | Power | — | Dangerous | Dangerous zone ground |

**DBG/GP pads:** Default mode at reset is GPIO (input). When `debug_mode` (GLOBAL_CONTROL[13]) is set, these pads switch to debug observation outputs controlled by `DEBUG_CONTROL` (Bank 0, offset 0x70). Mode switch is glitch-free.

---

## Power Domain Summary

| Domain | Rails | Pad Locations | Pads | Supplies |
|--------|-------|---------------|------|----------|
| Digital | VDD / VSS | Top (T1, T12, T13), Left (L1, L15), Bottom (B1, B2) | 7 | Core digital logic, host interfaces, GPIO, LED, clock, debug |
| Analog | VDD_A / VSS_A | Right (R1, R7) | 2 | DAC, ADC, comparator, analog routing, ROSC mux |
| Dangerous | VDD_E / VSS_E | Bottom (B6, B7) | 2 | NVM controller stub, dangerous zone logic |

**Total power pads:** 10 (4 VDD + 3 VSS + VDD_A + VSS_A + VDD_E/VSS_E pair = actually 5 supply + 4 ground + 1 dangerous supply pair = 10 unique pads across 3 domains)

**Isolation:** Analog and dangerous power domains have fully independent pad pairs. Digital domain has multiple distributed VDD/VSS pads for IR drop reduction.

---

## Pad Count Verification

| Edge | Total | Functional | Power/Ground |
|------|-------|------------|--------------|
| Top | 13 | 10 | 3 (VDD x2, VSS x1) |
| Left | 15 | 13 | 2 (VDD x1, VSS x1) |
| Right | 7 | 5 | 2 (VDD_A, VSS_A) |
| Bottom | 7 | 3 | 4 (VDD, VSS, VDD_E, VSS_E) |
| **Total** | **38** | **28** | **10** |

---

## Default Pad States at Reset

| Pad Group | Reset State | Notes |
|-----------|-------------|-------|
| UART_TX | Idle HIGH | UART idle line state |
| UART_RX | Input | Directly to UART receiver |
| SPI (SCK, MOSI, CS) | Input | SPI slave, directly to controller |
| MISO | Hi-Z | Tri-stated until CS asserted |
| SPARE_IO[0:1] | Hi-Z | Tri-stated, no function selected |
| CLK_REF | Input | Reference clock, always connected |
| RST_N | Input | Reset, always connected |
| GPIO[0:7] | Input (Hi-Z output) | Output drivers disabled |
| LED[0:4] | LOW | LEDs off |
| DAC_OUT | Disabled (code 0) | Analog output off |
| ANA_IN | Input | Analog, high impedance |
| COMP_IN | Input | Analog, high impedance |
| ADC_REF | Input | Analog, high impedance |
| ROSC_MUX | LOW | Digital output, inactive |
| PLL_REF | Input | Clock input |
| DBG/GP[0:1] | Input (GPIO mode) | Default GPIO, not debug |
