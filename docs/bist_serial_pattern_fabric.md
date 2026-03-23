# BIST Serial-Pattern Control Fabric

## Purpose

Compact serial control of mux selects, test enables, and route configurations. Reduces pad count and enables reproducible test setups loaded from the host.

The BIST fabric is an **adjunct** to normal registers, not a replacement. Both register writes and BIST patterns control the same targets; BIST takes priority when `CTRL_BIST_ENABLE` is set and patterns are applied.

## Architecture

```
Host → REG_BIST_SHIFT_DATA (32-bit word) → Shift Register
     → REG_BIST_CONTROL (LATCH)          → Latch Register
     → REG_BIST_CONTROL (APPLY)          → Outputs driven to targets
```

### Chains

| Chain ID | Name | Controls | Bit Width |
|----------|------|----------|-----------|
| 0 | CHAIN_ANALOG_MUX | ADC source, Comp+/- source, DAC ext pin | 32 |
| 1 | CHAIN_CLOCK_MUX | ADC/DAC/BIST/Exp clock source selects | 32 |
| 2 | CHAIN_TEST_ENABLE | Per-block test mode enables | 32 |
| 3 | CHAIN_ROUTE_CONFIG | Combined route configuration | 32 |
| 4 | CHAIN_FAULT_INJECT | Optional fault injection bits | 32 |

### Commands

| Command | Code | Action |
|---------|------|--------|
| NOP | 0 | No operation |
| SHIFT_IN | 1 | Stage shift data for selected chain |
| LATCH | 2 | Copy shift register → latch register |
| APPLY | 3 | Drive latched patterns to target outputs |
| CAPTURE | 4 | Snapshot current target state |
| SHIFT_OUT | 5 | Load capture register into shift register for readback |
| CLEAR | 6 | Clear all chains to safe defaults, disable apply |

### Registers

| Address | Name | Description |
|---------|------|-------------|
| 0x60 | BIST_CONTROL | [2:0] = command, [29] = apply_active, [30] = loaded, [31] = applied |
| 0x64 | BIST_CHAIN_SEL | [2:0] = selected chain |
| 0x68 | BIST_SHIFT_DATA | 32-bit shift data for selected chain |
| 0x6C | BIST_LATCH_STATUS | [4:0] = which chains have been latched |

### Bit Mapping for Analog Mux Chain (Chain 0)

| Bits | Field | Values |
|------|-------|--------|
| [2:0] | ADC source | 0=disconnected, 1=DAC, 2=ext, 3=ref, 4=ring_osc |
| [5:3] | Comp+ source | same |
| [8:6] | Comp- source | same |
| [12] | DAC to ext pin | 0=off, 1=on |

### Safety Rules

- CLEAR on reset — all chains zeroed
- BIST patterns **cannot** arm dangerous operations (CTRL_ARM_DANGEROUS is a separate register bit)
- APPLY is disabled when CTRL_BIST_ENABLE is cleared
- Sequencer issues BIST_CLEAR on restore-safe-state
