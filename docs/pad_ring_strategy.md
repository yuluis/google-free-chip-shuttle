# Pad Ring Strategy

## Caravel Constraints

- 38 user GPIO pads (bidirectional)
- 4 power pads (provided by Caravel harness)
- 128 logic analyzer probes (to management SoC, no physical pads)
- 32-bit Wishbone bus (to management SoC)
- 3 user interrupt lines

## Pad Allocation (38 pads)

### Top Edge — Host Digital Interfaces (13 pads)

| Pad | Type | Block | Rationale |
|-----|------|-------|-----------|
| VDD | Power | — | Top-side core power |
| VSS | Ground | — | Top-side core ground |
| UART_TX | Digital out | UART bridge | Primary host communication |
| UART_RX | Digital in | UART bridge | Primary host communication |
| SPI_SCK | Digital out | SPI | Secondary/test interface |
| SPI_MOSI | Digital out | SPI | |
| SPI_MISO | Digital in | SPI | |
| SPI_CS | Digital out | SPI | |
| I2C_SCL | Digital I/O | I2C | Third interface option |
| I2C_SDA | Digital I/O | I2C | |
| CLK_REF | Clock in | Clock mux tree | External reference clock |
| RST_N | Digital in | Global reset | Active-low global reset |
| VDD | Power | — | Top-side power (second) |

Placement rule: Host interfaces at top — shortest route to board connector.

### Left Edge — GPIO and LED Bank (15 pads)

| Pad | Type | Block | Rationale |
|-----|------|-------|-----------|
| VDD | Power | — | Left-side power |
| GPIO[0] | Digital I/O | GPIO wrapper | General-purpose |
| GPIO[1] | Digital I/O | GPIO wrapper | |
| GPIO[2] | Digital I/O | GPIO wrapper | |
| GPIO[3] | Digital I/O | GPIO wrapper | |
| GPIO[4] | Digital I/O | GPIO wrapper | |
| GPIO[5] | Digital I/O | GPIO wrapper | |
| GPIO[6] | Digital I/O | GPIO wrapper | |
| GPIO[7] | Digital I/O | GPIO wrapper | |
| LED[0] | Digital out | LED status | Status indicators |
| LED[1] | Digital out | LED status | |
| LED[2] | Digital out | LED status | |
| LED[3] | Digital out | LED status | |
| LED[4] | Digital out | LED status | |
| VSS | Ground | — | Left-side ground |

Placement rule: GPIO/LED on left — dedicated side for parallel I/O.

### Right Edge — Analog Pads (8 pads)

| Pad | Type | Block | Rationale |
|-----|------|-------|-----------|
| VDD_A | Analog power | — | Analog domain power |
| DAC_OUT | Analog out | DAC | DAC output for external measurement |
| ANA_IN | Analog in | Analog route matrix | External analog stimulus input |
| COMP_IN | Analog in | Comparator | External comparator reference |
| ADC_REF | Analog in | ADC | External ADC reference voltage |
| ROSC_PROBE0 | Digital out | Ring oscillator | Ring osc frequency probe |
| ROSC_PROBE1 | Digital out | Ring oscillator | Second ring osc probe |
| VSS_A | Analog ground | — | Analog domain ground |

Placement rule: All analog on right edge — Zone B mixed-signal blocks are on the right side of the die. Separate analog power domain (VDD_A/VSS_A).

### Bottom Edge — Clock Experiment and Debug (8 pads)

| Pad | Type | Block | Rationale |
|-----|------|-------|-----------|
| VDD | Power | — | Bottom-side power |
| VSS | Ground | — | Bottom-side ground |
| PLL_REF | Clock in | PLL | PLL reference clock input |
| PLL_OUT | Clock out | PLL | PLL output for external measurement |
| DBG[0] | Digital I/O | Debug/scan | Debug/test access |
| DBG[1] | Digital I/O | Debug/scan | |
| VDD_E | Power | — | Dangerous zone isolated power |
| VSS_E | Ground | — | Dangerous zone isolated ground |

Placement rule: PLL pads at bottom near Zone C. Dangerous zone power isolated.

## Power Summary

| Domain | Pads | Serves |
|--------|------|--------|
| VDD / VSS | 6 pads (3×VDD, 3×VSS) | Digital core, GPIO, LED |
| VDD_A / VSS_A | 2 pads | Analog blocks (DAC, ADC, comp, ring osc) |
| VDD_E / VSS_E | 2 pads | Dangerous zone (NVM/OTP) |

## Total: 44 pad functions → 38 Caravel GPIO pads

We have 38 GPIO pads available plus Caravel's own power. Some consolidation needed:
- Use Caravel's built-in power for VDD/VSS (reduces pad count by 4-6)
- Combine ROSC probes into one multiplexed pad
- DBG can share with GPIO if needed
- PLL_OUT can be optional (measure via internal freq counter instead)

**Conservative fit: 34-36 pads needed. Comfortable within 38.**

## Logic Analyzer Usage (128 probes)

The 128 Caravel logic analyzer probes are used for internal observability without consuming GPIO pads:
- [31:0] Register bus data
- [39:32] Register bus address
- [47:40] Sequencer state + block select
- [55:48] BIST chain status
- [63:56] DAC output code (upper bits)
- [75:64] ADC result
- [79:76] Error code
- [95:80] Clock mux status + freq counter
- [111:96] Analog route state
- [127:112] Experiment status + misc flags
