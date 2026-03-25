# ULC v3.0 Floorplan

**Status:** Draft
**Die area:** 2.92 x 3.52 mm
**Process:** SKY130
**Wrapper:** Caravel digital
**Zones:** 8
**Blocks:** ~40 (including 6 tiles)

---

## Zone Map

```
    +-------------------------------------------------------------+
    |                    TOP EDGE (13 pads)                        |
    |              Host digital + spare + clk + rst                |
    +-------------------------------------------------------------+
    |                                                              |
    |   +---------------------------------------+  +------------+ |
    |   |         host_perimeter                |  |            | |
    |   |   UART controller, SPI controller,    |  |            | |
L   |   |   spare pad mux, command decoder      |  |  shared_   | |
E   |   +---------------------------------------+  |  analog    | |  R
F   |                                               |            | |  I
T   |   +---------------------------------------+  |  DAC       | |  G
    |   |                                       |  |  ADC       | |  H
E   |   |          digital_core                 |  |  Comp      | |  T
D   |   |                                       |  |  Ref       | |
G   |   |  Register bank    Sequencer           |  +------------+ |  E
E   |   |  Tile controller  BIST fabric         |                  |  D
    |   |  SRAM             Event logger        |  +-AROUTE-MUX-+ |  G
(15)|   |  TRNG             PUF                 |  |            | |  E
    |   |  Profiles         State snap          |  +------------+ |
p   |   |                                       |                  |  (7)
a   |   +---------------------------------------+  +------------+ |
d   |                                               | tile_array | |  p
s   |   +------------------+ +----------+ +------+  |            | |  a
    |   | clock_experiment | | routing_ | | dang-|  | +--+ +--+ | |  d
    |   |                  | | margin   | | erous|  | |T0| |T1| | |  s
    |   | PLL wrapper      | |          | | _zone|  | +--+ +--+ | |
    |   | Ring oscillator  | | Profile  | |      |  | +--+ +--+ | |
    |   | Clock mux        | | ROM +    | | NVM  |  | |T2| |T3| | |
    |   | Freq counter     | | decoder  | | stub |  | +--+ +--+ | |
    |   | Clock divider    | |          | | ISOL |  | +--+ +--+ | |
    |   |                  | |          | | VDD_E|  | |T4| |T5| | |
    |   +------------------+ +----------+ +------+  | +--+ +--+ | |
    |                                               +------------+ |
    +-------------------------------------------------------------+
    |                   BOTTOM EDGE (7 pads)                       |
    |            Clock + debug/GP + dangerous power                |
    +-------------------------------------------------------------+
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
**Blocks:** Register bank (8 banks, ~108 regs), sequencer FSM (20-state), tile controller (NEW), BIST fabric (6 chains), event logger, SRAM block, TRNG, PUF, experiment profile controller, state snapshot.
**Area budget:** ~35% of user area.

**Placement rules:**
- Register bank placed centrally -- it connects to every other zone
- Sequencer FSM adjacent to register bank (tight timing path)
- Tile controller placed on the east side of digital_core, adjacent to the shared_analog and tile_array zones, minimizing control signal path length to tiles
- BIST fabric chains (6 chains, including new tile chain) laid out in parallel east-west strips for regular routing
- Event logger and SRAM adjacent (logger writes to SRAM); log entries now include tile_id field
- TRNG and PUF placed on the south side of digital_core, away from host interfaces (reduced switching noise coupling)
- Experiment profile controller near the south edge, close to routing_margin zone
- State snapshot module near sequencer (captures tile state in SNAP_FLAGS)
- Clock tree root enters from top-left (CLK_REF pad) or bottom-left (PLL output via clock_experiment)
- Maximum combinational path length: register bank to sequencer to tile controller to command decoder

### 4. shared_analog (Right, upper)

**Location:** Right edge, upper portion. Adjacent to analog pads (R1-R7). Directly north of the analog route matrix expansion and tile_array.
**Blocks:** DAC (10-bit), ADC (12-bit SAR), comparator, reference ladder.
**Area budget:** ~10% of user area.
**Power domain:** VDD_A / VSS_A = **3.3V** (Caravel VDDA1/VDDA2, pads R1, R7). All analog blocks use 3.3V-tolerant devices.

**Placement rules:**
- **CRITICAL:** All blocks must be on VDD_A/VSS_A domain -- separate from digital VDD/VSS
- Guard ring around entire shared_analog zone (minimum 2um wide P+ guard ring to substrate)
- DAC placed closest to DAC_OUT pad (R2) -- shortest analog trace
- ADC placed near ADC_REF pad (R5) and analog input (routed through AROUTE)
- Comparator placed near COMP_IN pad (R4)
- Reference ladder placed between DAC and ADC for short bias distribution paths
- Digital interface signals (register read/write) cross the domain boundary through level shifters at the west edge of this zone
- No high-speed digital switching logic inside this zone
- Minimum 10um spacing between shared_analog zone boundary and nearest digital_core standard cell row
- South edge of shared_analog connects directly to the expanded analog route matrix

### 5. tile_array (Right, lower -- 2x3 grid)

**Location:** Right side, below the expanded analog route matrix. Occupies the lower portion of the former v2.4 mixed_signal zone.
**Blocks:** 6 experiment tiles (T0-T5) in a 2-column x 3-row grid.
**Area budget:** ~15% of user area.
**Power domain:** VDD_A / VSS_A = **3.3V** (shared with shared_analog, pads R1, R7). Each tile has an individual PMOS power switch between VDDA and VDD_TILE, controlled by TILE_POWER_CONTROL register.

**Tile grid layout:**

```
    +------ tile_array zone ------+
    |                             |
    |   +---------+ +---------+  |
    |   |         | |         |  |
    |   |   T0    | |   T1    |  |  Row 0 (top)
    |   |  (OTA)  | | (CMirr) |  |
    |   |         | |         |  |
    |   +---------+ +---------+  |
    |   +---------+ +---------+  |
    |   |         | |         |  |
    |   |   T2    | |   T3    |  |  Row 1 (middle)
    |   | (RingO) | | (Delay) |  |
    |   |         | |         |  |
    |   +---------+ +---------+  |
    |   +---------+ +---------+  |
    |   |         | |         |  |
    |   |   T4    | |   T5    |  |  Row 2 (bottom)
    |   | (Flash) | | (LDO)   |  |
    |   |         | |         |  |
    |   +---------+ +---------+  |
    |                             |
    +-----------------------------+
      Col 0 (left)  Col 1 (right)
```

**Placement rules:**
- Each tile occupies a maximum of 200um x 150um (width x height)
- Guard ring between every adjacent tile pair: minimum 5um wide (P+ to substrate)
- Guard ring around the entire tile_array zone perimeter: minimum 5um wide
- Tiles T0/T1 (Row 0) placed closest to the analog route matrix (shortest stimulus/measurement paths)
- Tile T5 (LDO-Lite, Class D) placed in Row 2, Col 1 -- maximally distant from sensitive analog tiles T0/T1
- Timing-class tiles T2/T3 placed in Row 1, between analog core tiles (Row 0) and power tile (Row 2), with guard rings on both sides
- Each tile has a dedicated PMOS header switch (pfet_03v3, W=50u) between the VDDA power ring and VDD_TILE, with ~10pF MIM decoupling cap
- PMOS switches placed at the north edge of each tile (closest to the VDDA power ring)
- Level shifters (1.8V ↔ 3.3V) placed at the west edge of each tile row, between digital control bus and tile analog domain
- Analog I/O (STIM_A, STIM_B, OUT_MAIN, TAP1, TAP2) routes north through the analog route matrix to shared_analog resources
- Digital control bus routes west to the tile controller in digital_core
- Tile clock (clk_tile) routes from clock mux tree through digital_core east edge
- Unused tile slots (T6, T7 reserved for v3.1) would extend the grid to 2x4; physical space is reserved but unpopulated

### 6. clock_experiment (Bottom-left)

**Location:** Bottom-left corner, adjacent to bottom pads (PLL_REF at B3).
**Blocks:** PLL wrapper, ring oscillator, clock mux, frequency counter, clock divider.
**Area budget:** ~12% of user area.

**Placement rules:**
- **CRITICAL:** Placed at bottom-LEFT, maximally distant from analog zones (right edge) to minimize clock-to-analog coupling
- PLL wrapper placed closest to PLL_REF pad (B3)
- Ring oscillator placed in interior of zone (shielded by surrounding digital cells)
- Clock mux between PLL/ROSC outputs and the global clock distribution
- Frequency counter adjacent to clock mux (measures selected clock)
- Clock divider between mux output and digital_core clock tree root
- ROSC_MUX pad (R6) is on the right edge but the routing path goes south and then east along the bottom to avoid crossing through digital_core
- DBG/GP0 and DBG/GP1 pads (B4, B5) are accessible for clock observation when debug_mode is active

### 7. routing_margin (Bottom center)

**Location:** Bottom center, between clock_experiment and dangerous_zone.
**Blocks:** Experiment profile ROM, profile decoder.
**Area budget:** ~5% of user area.

**Placement rules:**
- This zone serves as both functional space (profile ROM/decoder) and routing margin
- Acts as a buffer between clock_experiment and dangerous_zone
- No hard macro placement -- standard cells and routing channels only
- Profile ROM is synthesized (no hard ROM IP) -- a lookup table of experiment configurations (extended for tile-based experiments)
- Profile decoder fans out configuration bits to all zones via the register file
- Routing channels through this zone carry signals between bottom-left (clock) and bottom-right (dangerous), as well as vertical routes up to digital_core

### 8. dangerous_zone (Bottom-right corner)

**Location:** Bottom-right corner, maximally isolated.
**Blocks:** NVM controller (stubbed).
**Area budget:** ~5% of user area.

**Placement rules:**
- **CRITICAL:** Separate power domain (VDD_E/VSS_E) -- completely independent from digital and analog domains
- Guard ring around entire zone (minimum 3um wide, tied to VSS_E)
- Power pads VDD_E (B6) and VSS_E (B7) are immediately adjacent on bottom edge
- Only digital interface: a narrow bus (address, data, command, status) crossing the domain boundary through level shifters on the west edge of this zone
- NVM controller is a protocol-exercisable stub -- the FSM runs but no actual NVM element exists
- Dual-key arming required: GLOBAL_CONTROL[2] AND DANGEROUS_ARM magic -- enforced in digital_core before any command reaches this zone
- If VDD_E is unpowered, the zone is completely inert; the level shifters clamp interface signals to safe values on the digital side

---

## Expanded Analog Route Matrix

The analog route matrix sits **between** shared_analog (north) and tile_array (south), occupying a horizontal strip on the right side of the die. It is the central switching fabric for all analog signal routing.

```
    +---shared_analog---+
    |  DAC  ADC  Comp   |
    |  Ref              |
    +--------+----------+
             |
    +========+=========+   <-- Expanded Analog Route Matrix
    | FROM:            |       (analog mux fabric)
    |  DAC_out         |
    |  ANA_IN (ext)    |
    |  Ref ladder      |
    |  Ring osc mon    |
    |  Tile[N] OUT     |
    |  Tile[N] TAP1    |
    |                  |
    | TO:              |
    |  ADC input       |
    |  Comp+, Comp-    |
    |  Tile[N] STIM_A  |
    |  Tile[N] STIM_B  |
    |  Spare IO (dig)  |
    |  DAC_OUT pad     |
    +========+=========+
             |
    +--------+----------+
    |  T0  T1           |
    |  T2  T3           |
    |  T4  T5           |
    +---tile_array------+
```

**Route matrix constraints:**
- Only one source per destination (no bus contention)
- Explicit mux select per route (no implicit connections)
- All routes disconnected at reset
- Tile-to-tile routing supported (e.g., T0 OUT_MAIN -> T3 STIM_A)
- Status flag asserted if illegal routing detected

---

## Inter-Zone Signal Routing

| From | To | Signals | Path |
|------|----|---------|------|
| host_perimeter | digital_core | Register R/W bus, commands | Vertical, south through center |
| digital_core | shared_analog | Register R/W bus (analog config) | Horizontal east, through level shifters |
| digital_core | tile_array | Tile digital control bus (enable, reset, start, mode, param) | Horizontal east, through tile controller |
| digital_core | clock_experiment | Clock config registers, clock outputs | Vertical south to bottom-left |
| digital_core | dangerous_zone | NVM command bus | South then east, through level shifters |
| digital_core | gpio_perimeter | GPIO data/direction, LED data | Horizontal west |
| clock_experiment | digital_core | Selected clock output | North through clock tree |
| clock_experiment | tile_array | tile_clk (via clock mux tree, +1 destination) | North through digital_core, east to tiles |
| shared_analog | tile_array | Analog stimulus/measurement (DAC, ADC, Comp) | Through expanded analog route matrix (south) |
| tile_array | shared_analog | Tile analog outputs (OUT_MAIN, TAP1) | Through expanded analog route matrix (north) |
| routing_margin | digital_core | Profile configuration bits | Vertical north |
| shared_analog | right pads | DAC_OUT, ANA_IN, COMP_IN, ADC_REF, ROSC_MUX | Direct east to pads R2-R6 |

---

## Power Domain Boundaries

```
    +-----------------------------------------------------+
    |                                                     |
    |              VDD / VSS (Digital Core)               |
    |                                                     |
    |   +------------------------+  +------------------+  |
    |   |                        |  |  VDD_A / VSS_A   |  |
    |   |   All digital zones    |  |                  |  |
    |   |   (host, gpio, core,   |  |  shared_analog   |  |
    |   |    clock, routing)     |  |  analog route mx |  |
    |   |                        |  |  tile_array      |  |
    |   |                        |  |  (all 6 tiles)   |  |
    |   |                        |  |                  |  |
    |   |                        |  |  [guard ring     |  |
    |   |                        |  |   around zone]   |  |
    |   +------------------------+  +------------------+  |
    |                                                     |
    |                          +---------------------+    |
    |                          |  VDD_E / VSS_E      |    |
    |                          |  dangerous_zone     |    |
    |                          |  [guard ring]       |    |
    |                          +---------------------+    |
    |                                                     |
    +-----------------------------------------------------+
```

**Power domain assignment:**

| Domain | Rails | Voltage | Zones | Pad Locations |
|--------|-------|---------|-------|---------------|
| Digital | VDD / VSS | **1.8V** | host_perimeter, gpio_perimeter, digital_core, clock_experiment, routing_margin | T1, T12, T13, L1, L15, B1, B2 |
| Analog | VDD_A / VSS_A | **3.3V** | shared_analog, analog route matrix, tile_array (per-tile gated) | R1 (VDD_A), R7 (VSS_A) |
| Dangerous | VDD_E / VSS_E | 1.8V | dangerous_zone | B6 (VDD_E), B7 (VSS_E) |

**Domain crossing rules:**
- All signals crossing power domain boundaries must pass through level shifters
- Level shifters placed on the receiving side of the boundary
- Domain-down detection: if VDD_A or VDD_E drops, interface signals clamp to defined safe values on the digital side
- No shared clock trees across domains -- each domain has its own clock buffer tree derived from the post-mux clock in digital_core
- Tile digital control signals cross VDD (1.8V) → VDD_A (3.3V) boundary at the east edge of digital_core (level shifters in shared_analog/tile_array zone)
- Level shifters must handle 1.8V → 3.3V (control signals to tiles) and 3.3V → 1.8V (status signals from tiles)
- PMOS power switches per tile add a VDD_A → VDD_TILE boundary within the tile_array zone, controlled by 3.3V-level-shifted register bits

---

## Physical Constraints Summary

| Constraint | Value | Rationale |
|------------|-------|-----------|
| Shared analog guard ring width | >= 2um (P+ to substrate) | Noise isolation for DAC/ADC/Comp |
| Tile-to-tile guard ring width | >= 5um (P+ to substrate) | Substrate noise isolation between tile DUTs |
| Tile array perimeter guard ring | >= 5um (P+ to substrate) | Isolate tile array from digital zones |
| Dangerous guard ring width | >= 3um (tied to VSS_E) | Fault isolation for experimental zone |
| Digital-to-analog spacing | >= 10um | Reduce capacitive coupling |
| Clock zone to analog zone | Opposite corners (BL vs R) | Minimize clock feedthrough |
| Register bank placement | Center of digital_core | Minimizes average wire length to all zones |
| Pad-to-block maximum distance | 2 metal track pitches (host) | Signal integrity for high-speed host I/O |
| Tile-to-shared-analog distance | <= 200um | Minimize analog routing parasitics |
| Maximum tile area | 200um x 150um | Fit 6 tiles in 2x3 grid on right side |
| Analog routing metal layers | M3 / M4 preferred | Avoid M1/M2 digital congestion |
| Digital control routing metal | M1 / M2 | Standard digital routing |
| Power tap per tile | Dedicated VDD_A/VSS_A connection | Avoid IR drop between tiles |

---

## Tile Placement Rules

### Grid Geometry

- **Grid:** 2 columns x 3 rows = 6 tile slots
- **Tile cell size:** 200um (W) x 150um (H) maximum per tile
- **Inter-tile guard ring:** 5um minimum on all four sides of each tile
- **Effective tile pitch:** 210um (H) x 160um (V) including guard rings

### Tile Assignment

| Slot | Row | Col | Class | DUT | Notes |
|------|-----|-----|-------|-----|-------|
| T0 | 0 | 0 | A (Analog Core) | 5-Transistor OTA | Closest to route matrix |
| T1 | 0 | 1 | A (Analog Core) | Current Mirror Bank | Closest to route matrix |
| T2 | 1 | 0 | B (Timing) | Current-Starved Ring Osc | Guard rings isolate from Row 0/2 |
| T3 | 1 | 1 | B (Timing) | Programmable Delay Line | Guard rings isolate from Row 0/2 |
| T4 | 2 | 0 | C (Mixed-Signal) | Flash ADC (3-bit) | Bottom row |
| T5 | 2 | 1 | D (Power) | LDO-Lite | Max distance from sensitive tiles |

### Guard Ring Layout

```
    +===================================================+
    | 5um perimeter guard ring                          |
    |                                                   |
    |   +-------+  5um  +-------+                      |
    |   |  T0   |  gap  |  T1   |                      |
    |   | 200x  |       | 200x  |                      |
    |   | 150um |       | 150um |                      |
    |   +-------+       +-------+                      |
    |       5um gap between rows                       |
    |   +-------+  5um  +-------+                      |
    |   |  T2   |  gap  |  T3   |                      |
    |   | 200x  |       | 200x  |                      |
    |   | 150um |       | 150um |                      |
    |   +-------+       +-------+                      |
    |       5um gap between rows                       |
    |   +-------+  5um  +-------+                      |
    |   |  T4   |  gap  |  T5   |                      |
    |   | 200x  |       | 200x  |                      |
    |   | 150um |       | 150um |                      |
    |   +-------+       +-------+                      |
    |                                                   |
    | 5um perimeter guard ring                          |
    +===================================================+
```

### Isolation Rules

- Every guard ring is P+ tied to VSS_A substrate
- Class D tile (T5, LDO-Lite) gets a reinforced guard ring: 8um minimum on all sides
- Timing-class tiles (T2, T3) are placed in the middle row as a buffer between sensitive analog core tiles (Row 0) and the power tile (Row 2)
- Each tile's isolation switches (transmission gates) are physically inside the guard ring perimeter, controlled by `tile_enable`
- Disabled tiles present Hi-Z on all analog outputs and pull inputs to VSS_A via weak keepers

### Expansion Path

Row 3 (T6, T7) is reserved for v3.1. The tile_array zone includes physical space for a fourth row. Bank 6 register offsets 0x30-0x3F are pre-allocated. No infrastructure changes needed if populated.
