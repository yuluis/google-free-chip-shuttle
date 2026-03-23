# Die Architecture Description Language

## Purpose

Standard format for all ULC design proposals and reviews. Every design update from Claude must use both the human-readable review format and the machine-readable YAML block. This enables structured, iterative review.

## Human-Readable Review Format

Every design report must contain these sections in this order:

### 1. OVERVIEW
- What changed in this revision
- Goals of the revision
- Major risks introduced or reduced

### 2. FLOORPLAN SUMMARY
- Zones and relative placement
- What is on the perimeter
- What is central
- What is isolated

### 3. PIN / PAD RING SUMMARY
- Top / bottom / left / right pad assignments
- Power / ground allocation
- Analog vs digital separation

### 4. BLOCK INVENTORY
For each block, a table row with:
- Name
- Zone
- Function (one line)
- Risk class: `straightforward` | `measurable` | `experimental`
- Pad-adjacent? yes / no
- FPGA-verifiable? yes / no
- Shuttle-only learning? yes / no

### 5. ROUTING SUMMARY
- Main buses
- Control paths
- Analog loopback paths
- Clock distribution
- Isolation boundaries

### 6. REGISTER MAP SUMMARY
- Major address groups and what they control
- New registers added in this revision

### 7. TESTABILITY SUMMARY
- How each block is controlled
- How each block is observed
- Self-test modes
- Host automation paths

### 8. OPEN QUESTIONS
- Uncertainties
- Tradeoffs needing review
- Where user input is required

### 9. CHANGE REQUESTS FOR REVIEW
- Explicit list of items for the user to approve or change

Every report must end with:
```
REVIEW QUESTIONS:
1. ...
2. ...
3. ...
```

## Machine-Readable YAML Schema

After the human-readable section, emit a YAML block:

```yaml
chip_architecture:
  revision: "rev_N"
  date: "YYYY-MM-DD"
  die:
    width_um: 2920
    height_um: 3520
    area_mm2: 10.27
    process: "SKY130"
    shuttle: "Google Open MPW / Caravel"

  zones:
    - name: "zone_id"
      label: "Human-readable label"
      role: "Description"
      risk_class: "straightforward | measurable | experimental"
      position: { x_pct: N, y_pct: N }
      size: { w_pct: N, h_pct: N }
      blocks:
        - block_id_1
        - block_id_2

  blocks:
    - id: "block_id"
      name: "Human Name"
      zone: "zone_id"
      gates: N
      risk_class: "straightforward | measurable | experimental"
      pad_adjacent: true | false
      fpga_verifiable: true | false
      shuttle_only: true | false
      pads: ["PAD_NAME", ...]
      connects_to: ["other_block_id", ...]

  pads:
    top: [{ name: "X", type: "digital|analog|power|ground|clock" }, ...]
    bottom: [...]
    left: [...]
    right: [...]

  power:
    domains:
      - name: "VDD/VSS"
        pads: ["VDD_top", "VSS_top", ...]
        serves: "Digital core"
      - name: "VDD_A/VSS_A"
        pads: ["VDD_A", "VSS_A"]
        serves: "Analog blocks"

  clocks:
    sources: ["ext_ref", "ring_osc", "pll_out", "div_sys", "test_gen"]
    destinations: ["adc_clk", "dac_clk", "bist_clk", "exp_clk"]
    default: "ext_ref"
    pll_required: false

  analog_routes:
    - source: "dac"
      destination: "adc"
      control: "ANALOG_ROUTE_SELECT"
    - source: "dac"
      destination: "comparator_pos"
      control: "ANALOG_ROUTE_SELECT"

  registers:
    total_count: N
    groups:
      - base: "0x0000"
        name: "global"
        count: N
        description: "Chip ID, reset, mode, status"

  gate_estimate:
    total: N
    capacity: 820000
    utilization_pct: N

  review_requests:
    - "Question or decision point 1"
    - "Question or decision point 2"
```

## Rules for Claude

1. **Always use both formats** — never return only prose
2. **Separate decided vs proposed vs needs-review** — use clear labels
3. **End every report with numbered REVIEW QUESTIONS**
4. **Keep the YAML schema stable** — add fields, never rename existing ones
5. **Include gate estimates** — every block must have a gate count
6. **Include risk classes** — every block and zone gets a risk assessment
