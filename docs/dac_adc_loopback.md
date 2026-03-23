# DAC-ADC Loopback and Mixed-Signal Experiments

## DAC Block

10-bit DAC with 5 operating modes. Primarily for internal stimulation and learning — not a precision production DAC.

### Modes

| Mode | Code | Behavior |
|------|------|----------|
| STATIC | 0 | Hold programmed code |
| STAIRCASE | 1 | Increment each update tick (0 → 1023 → wrap) |
| RAMP | 2 | Triangle sweep (0 → 1023 → 0 → ...) |
| ALTERNATING | 3 | Toggle between two programmed codes |
| LUT | 4 | Cycle through 16-entry waveform table |

### Routes

| Destination | How |
|-------------|-----|
| ADC input | Set `adc_input_sel = ASRC_DAC_OUT` (analog route matrix) |
| Comparator+ | Set `comp_pos_sel = ASRC_DAC_OUT` |
| External pin | Set `dac_to_ext_enable = 1` |
| Internal monitor | Always connected |

### Registers

| Address | Name | Description |
|---------|------|-------------|
| 0x90 | DAC_CONTROL | [2:0] mode, [3] enable via CTRL_DAC_ENABLE |
| 0x94 | DAC_CODE | [9:0] static/base code |
| 0x98 | DAC_STATUS | [2:0] active mode, [3] running |
| 0x9C | DAC_UPDATE_COUNT | 32-bit update counter |

### Self-Test

Runs staircase mode, counts 64 update ticks, verifies counter advanced. Reports:
- result0: actual update count
- result1: final DAC code
- result2: total updates since enable
- result3: active mode

## Key Experiments

### EXP_DAC_ADC_LOOPBACK (0x01)
DAC staircase → analog route → ADC capture. Measures DAC-ADC transfer function. Look for:
- Linearity (INL/DNL)
- Missing codes
- Gain/offset errors
- Monotonicity

### EXP_DAC_RAMP_ADC_CAPTURE (0x0C)
DAC triangle ramp → ADC. Characterize full-swing behavior in both directions.

### EXP_DAC_COMP_SWEEP (0x02)
DAC ramp → Comparator+ with ref ladder on Comparator-. Find the exact trip point. Characterize:
- Comparator offset
- DAC accuracy at the trip point
- Hysteresis (compare up-sweep vs down-sweep trip codes)

### EXP_PLL_ADC_CLK_SWEEP (0x05)
PLL output drives ADC sample clock while DAC provides a known static input. Measure ADC noise/jitter vs sample rate.
