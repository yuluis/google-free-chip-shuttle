# PLL / DPLL Clock Experiments

## Important Rule

**The rest of the chip MUST operate without PLL lock.** The PLL is an experimental/learning block. All essential testing works from external reference clock, ring oscillators, or divided system clock.

## PLL Configuration

| Register | Bits | Field |
|----------|------|-------|
| CTRL_PLL_ENABLE (global control bit 5) | | Enable PLL |
| PLL mult factor | [3:0] | Multiplication (2–15) |
| PLL div factor | [3:0] | Division (1–15) |
| PLL bypass | | Pass reference through unchanged |

## Status

| Field | Source |
|-------|--------|
| PLL locked | pll_locked signal |
| PLL timeout | Lock not achieved within PLL_LOCK_TIMEOUT cycles |
| Bypass active | PLL disabled or bypass mode |
| Frequency count | Edges counted over reference window |

## Clock Mux Tree

5 sources × 4 destinations, each independently selectable:

### Sources
| Code | Source |
|------|--------|
| 0 | External reference clock (always available) |
| 1 | Ring oscillator bank |
| 2 | Divided system clock (/4) |
| 3 | PLL output (**falls back to ext ref if PLL not locked**) |
| 4 | Test-generated clock (/16) |

### Destinations
| Destination | What uses it |
|-------------|-------------|
| ADC clock | ADC conversion timing |
| DAC clock | DAC update rate |
| BIST clock | Pattern engine timing |
| Experiment clock | General-purpose |

## Safety: PLL → Clock Mux Fallback

When CLKSRC_PLL_OUT is selected but `pll_locked` is false, the clock mux automatically substitutes the external reference clock. This prevents the chip from hanging on an absent clock.

## Frequency Measurement

Any clock source can be measured:
1. Write source ID to `REG_CLK_FREQ_SELECT`
2. Write anything to `REG_CLK_FREQ_COUNT` to trigger measurement
3. Wait for measurement to complete (freq_measuring bit clears)
4. Read result from `REG_CLK_FREQ_COUNT`

Result = number of target clock edges in a reference window (default 10,000 system clocks).

## Learning Value

- How does a PLL/DPLL behave in real silicon?
- What's the actual lock time?
- How does ADC performance change with different sample clocks?
- What happens to DAC output quality at different update rates?
- How do process variations affect ring oscillator frequency vs PLL output?
