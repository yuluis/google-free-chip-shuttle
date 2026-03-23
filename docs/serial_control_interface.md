# Serial Control Interface

## Overview

The chip is controlled through a UART serial interface mapped to a 16-bit address, 32-bit data register bank. A host PC or MCU sends read/write commands to configure tests, start experiments, and read results.

## Control Path

```
Host PC / MCU
  → UART (115200 8N1)
  → Serial Command Decoder (rtl/interfaces/uart_host_bridge.sv)
  → Register Map (16-bit address → 32-bit data)
  → Internal block controls / test fabric / measurement paths
```

## Protocol

### Frame format

| Command | TX bytes | RX bytes | Description |
|---------|----------|----------|-------------|
| Write | `W` `AH` `AL` `D3` `D2` `D1` `D0` | `A` | Write 32-bit value to 16-bit address |
| Read | `R` `AH` `AL` | `D` `D3` `D2` `D1` `D0` | Read 32-bit value from 16-bit address |
| Status | `S` | `S` `D3` `D2` `D1` `D0` | Shortcut: read GLOBAL_STATUS |
| Reset | `X` | `A` | Trigger global reset (same as writing 0xDEAD to GLOBAL_RESET) |

All multi-byte values are big-endian.

## Typical Host Automation Sequence

### Single block test
```python
write(0x0100, block_id)       # TEST_SELECT
write(0x0104, CMD_START)       # TEST_COMMAND
while read(0x0010) & 0x01:    # poll GLOBAL_STATUS.busy
    sleep(0.001)
status = read(0x0010)          # check pass/fail bits
result0 = read(0x0110)         # RESULT0
result1 = read(0x0114)         # RESULT1
```

### Experiment profile
```python
write(0x001C, EXP_DAC_ADC_LOOPBACK)   # EXPERIMENT_ID
write(0x000C, 0x161)                    # MODE_CONTROL: enable + dac_enable + lab_mode
write(0x0104, CMD_LOAD_EXPERIMENT)      # TEST_COMMAND
while read(0x0010) & 0x01:
    sleep(0.001)
# Results now in RESULT0..RESULT3
```

### DAC manual control
```python
write(0x0300, 0x001)                # ANALOG_ROUTE: ADC source = DAC
write(0x0400, 0x200)                # DAC_CODE = 512 (mid-range)
write(0x0404, 0x000)                # DAC_MODE = STATIC
write(0x000C, read(0x000C) | 0x40)  # set DAC_ENABLE in MODE_CONTROL
```

## Register Map Stability

The register map address space is designed to be stable across FPGA prototyping and shuttle versions:
- Group base addresses (0x0000, 0x0100, ...) are fixed
- New registers are appended within groups, never reordering existing offsets
- Unimplemented addresses return 0x00000000 on read and ignore writes

## SPI Secondary Path (Future)

The same register map can be accessed via SPI by adding a parallel command decoder. The register semantics are identical — only the physical transport changes. SPI support is deferred to a later revision.
