# Analog Route Matrix

## Purpose

Connects internal analog signals between DAC, ADC, comparator, reference ladder, ring oscillator monitor, and external analog pins. Enables closed-loop experiments (e.g., DAC → ADC loopback) without external wiring.

## Supported Routes

| Source → Destination | Route |
|---------------------|-------|
| DAC → ADC input | DAC_OUT → adc_input_sel |
| DAC → Comparator+ | DAC_OUT → comp_pos_sel |
| DAC → Comparator- | DAC_OUT → comp_neg_sel |
| DAC → External pin | dac_to_ext_enable |
| External input → ADC | EXT_ANALOG_IN → adc_input_sel |
| External input → Comp+ | EXT_ANALOG_IN → comp_pos_sel |
| Reference ladder → ADC | REF_LADDER → adc_input_sel |
| Reference ladder → Comp- | REF_LADDER → comp_neg_sel |
| Ring osc monitor → ADC | RING_OSC_MON → adc_input_sel |

## Safe Defaults (Power-up / Reset)

- All routes: DISCONNECTED
- DAC to ext pin: disabled
- No contention possible

## Contention Rules

- Comp+ and Comp- cannot use the same source (flagged as ERR_ROUTE_CONTENTION)
- DAC can fan out to multiple destinations simultaneously (valid)
- Only one source per ADC input at a time (enforced by mux)

## Control

### Via Registers

| Register | Bits | Field |
|----------|------|-------|
| 0x80 AROUTE_CONTROL | [2:0] | ADC source |
| | [5:3] | Comp+ source |
| | [8:6] | Comp- source |
| | [12] | DAC to ext pin |
| 0x84 AROUTE_STATUS | [0] | BIST active |
| | [1] | Route active (any non-disconnected) |
| | [2] | Contention detected |
| 0x88 AROUTE_ADC_SRC | [2:0] | ADC source (shortcut) |
| 0x8C AROUTE_COMP_SRC | [2:0] | Comp+ source, [5:3] Comp- source |

### Via BIST Chain 0 (CHAIN_ANALOG_MUX)

Same bit mapping as AROUTE_CONTROL register. BIST takes priority when applied.

## Analog Source Encoding

| Code | Name | Signal |
|------|------|--------|
| 0 | DISCONNECTED | No connection (safe) |
| 1 | DAC_OUT | DAC output code |
| 2 | EXT_ANALOG_IN | External analog input pin |
| 3 | REF_LADDER | Internal reference/bias |
| 4 | RING_OSC_MON | Ring oscillator analog monitor |
