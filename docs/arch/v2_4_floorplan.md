# ULC v2.4 Floorplan

**Status:** Frozen
**Die area:** 2.92 x 3.52 mm
**Process:** SKY130
**Wrapper:** Caravel digital
**Zones:** 7
**Blocks:** 32

---

## Zone Map

```
    ┌─────────────────────────────────────────────────────────────┐
    │                    TOP EDGE (13 pads)                       │
    │              Host digital + spare + clk + rst               │
    ├─────────────────────────────────────────────────────────────┤
    │                                                             │
    │   ┌───────────────────────────────────────┐  ┌──────────┐  │
    │   │         host_perimeter                │  │          │  │
    │   │   UART controller, SPI controller,    │  │          │  │
L   │   │   spare pad mux, command decoder      │  │          │  │
E   │   └───────────────────────────────────────┘  │          │  │  R
F   │                                               │ mixed_   │  │  I
T   │   ┌───────────────────────────────────────┐  │ signal   │  │  G
    │   │                                       │  │          │  │  H
E   │   │          digital_core                 │  │ DAC      │  │  T
D   │   │                                       │  │ ADC      │  │
G   │   │  Register file    Sequencer           │  │ Comp     │  │  E
E   │   │  BIST fabric      Event logger        │  │ ARoute   │  │  D
    │   │  SRAM             TRNG                │  │          │  │  G
(15)│   │  Experiment ctrl  PUF                 │  │          │  │  E
    │   │                                       │  │          │  │
p   │   └───────────────────────────────────────┘  └──────────┘  │  (7)
a   │                                                             │
d   │   ┌──────────────────┐ ┌──────────┐ ┌──────────────────┐  │  p
s   │   │ clock_experiment │ │ routing_ │ │  dangerous_zone  │  │  a
    │   │                  │ │ margin   │ │                  │  │  d
    │   │ PLL wrapper      │ │          │ │ NVM controller   │  │  s
    │   │ Ring oscillator  │ │ Profile  │ │ (stubbed)        │  │
    │   │ Clock mux        │ │ ROM +    │ │                  │  │
    │   │ Freq counter     │ │ decoder  │ │ ISOLATED         │  │
    │   │ Clock divider    │ │          │ │ VDD_E / VSS_E    │  │
    │   └──────────────────┘ └──────────┘ └──────────────────┘  │
    │                                                             │
    ├─────────────────────────────────────────────────────────────┤
    │                   BOTTOM EDGE (7 pads)                      │
    │            Clock + debug/GP + dangerous power               │
    └─────────────────────────────────────────────────────────────┘
```

---

## Zone Definitions and Placement Rules

### 1. host_perimeter (Top)

**Location:** Top edge, directly adjacent to top pads.
**Blocks:** UART controller, SPI controller, spare pad mux, command decoder.
**Area budget:** ~15% of user area.

**Placement rules:**
- Must be within 2 metal track pitches of top pad ring for short bonding wire paths
- UART controller placed closest to UART_TX/UART_RX pads (T2, T3)
- SPI controller placed closest to SPI pads (T4-T7)
- Spare pad mux placed adjacent to SPARE_IO0/SPARE_IO1 (T8, T9)
- Command decoder sits between host interfaces and digital_core, acting as the protocol bridge
- All blocks in this zone are purely digital; no analog isolation required

### 2. gpio_perimeter (Left)

**Location:** Left edge, directly adjacent to left pads.
**Blocks:** GPIO bank (8-bit bidirectional), LED driver bank (5-channel).
**Area budget:** ~8% of user area.

**Placement rules:**
- GPIO cells placed adjacent to GPIO[0:7] pads (L2-L9) in order
- LED drivers placed adjacent to LED[0:4] pads (L10-L14) in order
- Output drivers must be close to pads to minimize output impedance variation
- ESD structures are in the pad frame (Caravel), not in the user area
- GPIO and LED logic is thin (mostly I/O cells and direction registers); fills a narrow strip along left edge

### 3. digital_core (Center)

**Location:** Center of die, largest zone.
**Blocks:** Register file, sequencer FSM, BIST fabric (5 chains), event logger, SRAM block, TRNG, PUF, experiment profile controller.
**Area budget:** ~40% of user area.

**Placement rules:**
- Register file placed centrally — it connects to every other zone
- Sequencer FSM adjacent to register file (tight timing path)
- BIST fabric chains laid out in parallel east-west strips for regular routing
- Event logger and SRAM adjacent (logger writes to SRAM)
- TRNG and PUF placed on the south side of digital_core, away from host interfaces (reduced switching noise coupling)
- Experiment profile controller near the south edge, close to routing_margin zone
- Clock tree root enters from top-left (CLK_REF pad) or bottom-left (PLL output via clock_experiment)
- Maximum combinational path length: register file to sequencer to command decoder

### 4. mixed_signal (Right)

**Location:** Right edge, adjacent to right (analog) pads.
**Blocks:** DAC, ADC (SAR), comparator, analog route matrix.
**Area budget:** ~15% of user area.

**Placement rules:**
- **CRITICAL:** Analog blocks must be on VDD_A/VSS_A domain — separate from digital VDD/VSS
- Guard ring around entire mixed_signal zone (minimum 2um wide P+ guard ring to substrate)
- DAC placed closest to DAC_OUT pad (R2) — shortest analog trace
- ADC placed near ADC_REF pad (R5) and analog input (routed through AROUTE)
- Comparator placed near COMP_IN pad (R4)
- Analog route matrix placed centrally within the zone, connecting DAC output, external inputs, ADC input, and comparator input
- Digital interface signals (register read/write) cross the domain boundary through level shifters at the west edge of this zone
- No high-speed digital switching logic inside this zone
- Minimum 10um spacing between mixed_signal zone boundary and nearest digital_core standard cell row

### 5. clock_experiment (Bottom-left)

**Location:** Bottom-left corner, adjacent to bottom pads (PLL_REF at B3).
**Blocks:** PLL wrapper, ring oscillator, clock mux, frequency counter, clock divider.
**Area budget:** ~12% of user area.

**Placement rules:**
- **CRITICAL:** Placed at bottom-LEFT, maximally distant from analog zone (right edge) to minimize clock-to-analog coupling
- PLL wrapper placed closest to PLL_REF pad (B3)
- Ring oscillator placed in interior of zone (shielded by surrounding digital cells)
- Clock mux between PLL/ROSC outputs and the global clock distribution
- Frequency counter adjacent to clock mux (measures selected clock)
- Clock divider between mux output and digital_core clock tree root
- ROSC_MUX pad (R6) is on the right edge but the routing path goes south and then east along the bottom to avoid crossing through digital_core
- DBG/GP0 and DBG/GP1 pads (B4, B5) are accessible for clock observation when debug_mode is active

### 6. routing_margin (Bottom center)

**Location:** Bottom center, between clock_experiment and dangerous_zone.
**Blocks:** Experiment profile ROM, profile decoder.
**Area budget:** ~5% of user area.

**Placement rules:**
- This zone serves as both functional space (profile ROM/decoder) and routing margin
- Acts as a buffer between clock_experiment and dangerous_zone
- No hard macro placement — standard cells and routing channels only
- Profile ROM is synthesized (no hard ROM IP) — a lookup table of 15 experiment configurations
- Profile decoder fans out configuration bits to all zones via the register file
- Routing channels through this zone carry signals between bottom-left (clock) and bottom-right (dangerous), as well as vertical routes up to digital_core

### 7. dangerous_zone (Bottom-right corner)

**Location:** Bottom-right corner, maximally isolated.
**Blocks:** NVM controller (stubbed).
**Area budget:** ~5% of user area.

**Placement rules:**
- **CRITICAL:** Separate power domain (VDD_E/VSS_E) — completely independent from digital and analog domains
- Guard ring around entire zone (minimum 3um wide, tied to VSS_E)
- Power pads VDD_E (B6) and VSS_E (B7) are immediately adjacent on bottom edge
- Only digital interface: a narrow bus (address, data, command, status) crossing the domain boundary through level shifters on the west edge of this zone
- NVM controller is a protocol-exercisable stub — the FSM runs but no actual NVM element exists
- Dual-key arming required: GLOBAL_CONTROL[2] AND DANGEROUS_ARM magic — enforced in digital_core before any command reaches this zone
- If VDD_E is unpowered, the zone is completely inert; the level shifters clamp interface signals to safe values on the digital_core side

---

## Inter-Zone Signal Routing

| From | To | Signals | Path |
|------|----|---------|------|
| host_perimeter | digital_core | Register R/W bus, commands | Vertical, south through center |
| digital_core | mixed_signal | Register R/W bus (analog config) | Horizontal east, through level shifters |
| digital_core | clock_experiment | Clock config registers, clock outputs | Vertical south to bottom-left |
| digital_core | dangerous_zone | NVM command bus | South then east, through level shifters |
| digital_core | gpio_perimeter | GPIO data/direction, LED data | Horizontal west |
| clock_experiment | digital_core | Selected clock output | North through clock tree |
| mixed_signal | bottom pads | ROSC_MUX observation | South along right edge, west along bottom |
| routing_margin | digital_core | Profile configuration bits | Vertical north |

---

## Power Domain Boundaries

```
    ┌─────────────────────────────────────────────────┐
    │                                                 │
    │            VDD / VSS (Digital Core)             │
    │                                                 │
    │   ┌────────────────────────┐  ┌─────────────┐  │
    │   │                        │  │ VDD_A/VSS_A │  │
    │   │   All digital zones    │  │ mixed_signal│  │
    │   │   (host, gpio, core,   │  │ (analog)    │  │
    │   │    clock, routing)     │  │             │  │
    │   │                        │  │  [guard     │  │
    │   │                        │  │   ring]     │  │
    │   └────────────────────────┘  └─────────────┘  │
    │                                                 │
    │                          ┌───────────────────┐  │
    │                          │ VDD_E / VSS_E     │  │
    │                          │ dangerous_zone    │  │
    │                          │ [guard ring]      │  │
    │                          └───────────────────┘  │
    │                                                 │
    └─────────────────────────────────────────────────┘
```

**Domain crossing rules:**
- All signals crossing power domain boundaries must pass through level shifters
- Level shifters placed on the receiving side of the boundary
- Domain-down detection: if VDD_A or VDD_E drops, interface signals clamp to defined safe values on the digital side
- No shared clock trees across domains — each domain has its own clock buffer tree derived from the post-mux clock in digital_core

---

## Floorplan Constraints Summary

| Constraint | Value | Rationale |
|------------|-------|-----------|
| Analog guard ring width | >= 2um (P+ to substrate) | Noise isolation for mixed_signal |
| Dangerous guard ring width | >= 3um (tied to VSS_E) | Fault isolation for experimental zone |
| Digital-to-analog spacing | >= 10um | Reduce capacitive coupling |
| Clock zone to analog zone | Opposite corners (BL vs R) | Minimize clock feedthrough |
| Register file placement | Center of digital_core | Minimizes average wire length to all zones |
| Pad-to-block maximum distance | 2 metal track pitches (host) | Signal integrity for high-speed host I/O |
