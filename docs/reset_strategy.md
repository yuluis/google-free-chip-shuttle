# Reset Strategy

## Global Reset Pin

One active-low global reset pin (`RST_N`) on the top edge of the pad ring.

### Reset Behavior

When `RST_N` is asserted (low) or `GLOBAL_RESET` register receives magic word `0xDEAD`:

| Subsystem | Reset Action |
|-----------|-------------|
| Test sequencer | Returns to SEQ_IDLE, all control outputs deasserted |
| Register bank | All RW registers return to documented reset values |
| BIST pattern engine | All chains cleared, apply disabled |
| Clock mux tree | All destinations select CLKSRC_EXT_REF (source 0) |
| Analog route matrix | All routes set to ASRC_DISCONNECTED, DAC-to-ext disabled |
| DAC | Disabled, code = 0, mode = STATIC, update counter = 0 |
| ADC | Idle, no conversion in progress |
| Comparator | Threshold code = 0 |
| PLL | Disabled or bypass mode, lock counter reset |
| GPIO | All outputs = 0, all output enables = 0 |
| LED | All off |
| Log buffer | Pointers reset to 0 (entries preserved until overwritten) |
| SRAM | Data preserved (not cleared — use SRAM BIST to test) |
| Pass/fail counters | Reset to 0 |
| Cycle counter | Reset to 0 |
| Dangerous zone | **Disarmed** — DANGEROUS_ARM cleared |
| NVM | All commands deasserted, address/data cleared |
| Experiment | Profile cleared to EXP_NONE |

### Reset Sources

| Source | Trigger | Scope |
|--------|---------|-------|
| `RST_N` pin | Active-low external pin | Full chip reset |
| `GLOBAL_RESET` register | Write 0xDEAD to 0x0008 | Full chip reset (same effect) |
| `MODE_CONTROL[1]` (reset_fabric) | Set bit 1 | Test fabric only (sequencer, counters, BIST — preserves register values) |
| `CMD_RESTORE_SAFE` command | Write 0x1F to TEST_COMMAND | Soft restore: routes disconnected, clocks to ext ref, BIST cleared, experiment cleared. Does NOT reset registers or counters. |

### Reset Priority

```
RST_N pin (highest)  →  GLOBAL_RESET register  →  reset_fabric bit  →  CMD_RESTORE_SAFE (lowest)
```

### Power-On Reset

On power-up, all flip-flops initialize to their reset values (synthesis attribute or async reset). The `RST_N` pin should be held low during power-up ramp and released after supply is stable.

Recommended: add a simple power-on-reset (POR) detector that holds internal reset for ~100 clock cycles after VDD rises above threshold.

### Safety Invariant

**After any reset event, the chip must be in a state where no block is active, no analog route is connected, no dangerous operation is armed, and the only clock source is the external reference.**

This is verified by checking `GLOBAL_STATUS == 0x00000000` after reset.
