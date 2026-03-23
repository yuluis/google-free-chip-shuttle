# Floorplan Guidelines

## Placement Rules

### A. Perimeter / Pad-Adjacent (near pad ring)

Place these near the edge because they are pad-facing or benefit from short routes to pins.

| Category | Blocks | Rationale |
|----------|--------|-----------|
| Host interfaces | UART, SPI, I2C, debug serial | Direct pad connection, minimize IO routing |
| Clock inputs | External reference, PLL reference | Clean clock entry, minimize jitter path |
| Reset | Global reset pad driver | Fast fanout to all blocks |
| GPIO / LED | GPIO bank, LED drivers | Each near its assigned pad |
| Analog front-end | DAC output buffer, ADC input mux, comparator input, ext analog input | Short analog routes to pads, avoid digital noise coupling |
| ESD / pad conditioning | Level shifters, ESD clamps | Must be pad-adjacent by definition |
| Dangerous pad-facing | NVM program pulse output (if external) | Isolated and perimeter-adjacent |

### B. Center of Die (digital backbone)

Place the shared control "brain" in the middle for shortest average distance to all subsystems.

| Block | Rationale |
|-------|-----------|
| Register bank | Central hub — all blocks read/write through it |
| Test sequencer | Orchestrates every block — equidistant access needed |
| BIST pattern engine | Drives mux chains across the die |
| Block select mux | Fan-out to all 16+ blocks |
| Experiment profiles | Combinational lookup feeding sequencer |
| Log buffer / SRAM | Shared memory — no pad affinity |
| Global counters | Measurement infrastructure |
| Switch/crossbar fabric | Routes control signals to subsystems |

### C. Side Clusters (measurable analog)

Place analog/mixed-signal blocks in a cluster on one side (right side recommended), not at the very center.

| Block | Rationale |
|-------|-----------|
| DAC | Near analog pads, away from noisy digital core |
| ADC | Near analog pads, sensitive to substrate noise |
| Comparator | Adjacent to DAC/ADC for loopback routing |
| Analog route matrix | Adjacent to DAC/ADC/comparator (the blocks it muxes) |
| Ring oscillator bank | Layout-sensitive, needs quiet environment |
| TRNG analog source | Entropy quality depends on noise isolation |
| PUF array | Process-sensitive SRAM cells |
| Reference ladder / bias | Quiet analog, near DAC/ADC |

### D. Isolated Corner / Zone (dangerous)

Put irreversible or stress-prone blocks in a small isolated region with explicit guard rings.

| Block | Rationale |
|-------|-----------|
| NVM / OTP | Irreversible programming, voltage stress |
| Pulse controller | High-current drive, noise source |
| ReRAM / SONOS (if any) | Experimental, unknown failure modes |

### E. Routing / Power Margin

Reserve explicit space for:
- Power rings (VDD/VSS) around die perimeter and crossing zones
- Vertical/horizontal power straps
- Analog isolation channels between Zone B and Zone A
- Debug routing channels
- Test bus routing
- At least 10-15% of die area for routing margin

**Do not overpack the die.**

## Zone Map (Die Coordinates)

```
 ┌──────────────────────────────────────────────────────────────┐
 │  PAD RING (top: UART, SPI, I2C, CLK_REF, RST)              │
 ├──────────────────────────────────────────────────────────────┤
 │        │                                    │                │
 │  PAD   │   ZONE A: HOST INTERFACE BAND      │   PAD         │
 │  RING  │   (UART, SPI, I2C near top pads)   │   RING        │
 │  (left │────────────────────────────────────│   (right:     │
 │  GPIO  │                                    │   analog      │
 │  LED)  │   ZONE A: DIGITAL BACKBONE         │   pads)       │
 │        │   (Register Bank, Sequencer,       │                │
 │        │    BIST Engine, Exp Profiles,       │   ZONE B:     │
 │        │    Mux, Log Buffer, SRAM,          │   MIXED-      │
 │        │    Clock Dividers, Counters)        │   SIGNAL      │
 │        │                                    │   (DAC, ADC,  │
 │        │   center of die                    │   Comp, Route │
 │        │                                    │   RingOsc,    │
 │        │                                    │   TRNG, PUF)  │
 │        │────────────────────────────────────│                │
 │        │                                    │   ZONE C:     │
 │        │   ZONE E: ROUTING / POWER MARGIN   │   CLOCK EXP   │
 │        │   (power straps, guard rings,      │   (PLL, Mux)  │
 │        │    spare routing)                  │────────────── │
 │        │                                    │   ZONE D:     │
 │        │                                    │   DANGEROUS   │
 │        │                                    │   (NVM, OTP)  │
 ├──────────────────────────────────────────────────────────────┤
 │  PAD RING (bottom: PLL_REF, PLL_OUT, DBG, power)            │
 └──────────────────────────────────────────────────────────────┘
```

## Isolation Rules

1. **Analog isolation channel** between Zone A digital core and Zone B mixed-signal. Minimum 20µm gap with guard ring.
2. **Dangerous zone guard ring** around Zone D. Separate VDD_E/VSS_E power domain.
3. **PLL isolation** — Zone C gets its own quiet power supply path if possible. PLL VCO is the noisiest analog block.
4. **No digital switching logic placed between analog pads and analog blocks.**
