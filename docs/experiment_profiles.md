# Experiment Profiles

Predefined experiment configurations that set up the entire chip for a specific measurement. Each profile defines block enables, clock sources, analog routes, DAC mode, and sample count.

## Usage

```
Host → REG_BLOCK_SELECT = profile_id
Host → REG_COMMAND = CMD_LOAD_EXPERIMENT (0x10)
```

The sequencer loads the profile and orchestrates: clock setup → PLL lock wait (if needed) → route config → block test → result collection → safe restore.

## Profile Table

| ID | Name | Blocks | Clock | Route | Risk |
|----|------|--------|-------|-------|------|
| 0x01 | DAC_ADC_LOOPBACK | DAC + ADC | ext ref | DAC→ADC | Low |
| 0x02 | DAC_COMP_SWEEP | DAC + Comp | ext ref | DAC→Comp+, Ref→Comp- | Low |
| 0x03 | ADC_EXT_INPUT | ADC | ext ref | Ext→ADC | Low |
| 0x04 | PLL_FREQ_MEASURE | PLL | ext ref | none | Medium |
| 0x05 | PLL_ADC_CLK_SWEEP | PLL + ADC + DAC | PLL→ADC | DAC→ADC | Medium |
| 0x06 | DAC_CLK_SWEEP | DAC + ADC + PLL | PLL→DAC | DAC→ADC | Medium |
| 0x07 | RINGOSC_COUNT | Ring Osc | ext ref | none | Low |
| 0x08 | TRNG_HEALTH | TRNG | ext ref | none | Low |
| 0x09 | PUF_CAPTURE | PUF | ext ref | none | Low |
| 0x0A | NVM_READONLY | NVM | ext ref | none | Low |
| 0x0B | NVM_PROGRAM | NVM | ext ref | none | **DANGEROUS** |
| 0x0C | DAC_RAMP_ADC_CAPTURE | DAC + ADC | ext ref | DAC→ADC | Low |
| 0x0D | COMP_THRESHOLD_CAL | DAC + Comp | ext ref | DAC→Comp+, Ref→Comp- | Low |
| 0x0E | CLOCK_SOURCE_COMPARE | Clk Div + Ring Osc | ext ref | none | Low |

## Learning Value

Each experiment teaches something specific about mixed-signal silicon:

- **DAC_ADC_LOOPBACK**: How well does the DAC-ADC pair track? What's the INL/DNL?
- **DAC_COMP_SWEEP**: Can the DAC precisely control the comparator trip point?
- **PLL_FREQ_MEASURE**: Does the PLL lock? At what frequency? How long to lock?
- **PLL_ADC_CLK_SWEEP**: How does ADC performance change with sample rate?
- **RINGOSC_COUNT**: What process corner did we land on?
- **TRNG_HEALTH**: Is the entropy source good enough for crypto?
- **PUF_CAPTURE**: Is the PUF stable enough for chip identity?
