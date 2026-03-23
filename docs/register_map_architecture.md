# Register Map Architecture

## Address Space

16-bit byte-addressed register map. All registers are 32 bits. The address space is divided into functional groups at 256-byte boundaries so each group can hold up to 64 registers.

| Range | Group | Description |
|-------|-------|-------------|
| 0x0000–0x00FF | Global | Chip ID, revision, global reset, mode control, status |
| 0x0100–0x01FF | Test Sequencer | Block select, command, status, results, pass/fail counts |
| 0x0200–0x02FF | Clocks | Source select, divider, PLL control/status, freq counters |
| 0x0300–0x03FF | Analog Routes | Route matrix, ADC/comp source select, contention flags |
| 0x0400–0x04FF | DAC | Code, mode, alt code, clk divider, update count, status |
| 0x0500–0x05FF | ADC | Control, result, min/max capture, channel, sample count |
| 0x0600–0x06FF | Comparator | Control, threshold source, trip code, sweep config |
| 0x0700–0x07FF | BIST Engine | Chain select, shift data, latch status, commands |
| 0x0800–0x08FF | TRNG / PUF | TRNG health flags, PUF challenge/response, stability |
| 0x0900–0x09FF | Logs / SRAM | Log pointer, log count, result window, SRAM BIST |
| 0x0A00–0x0AFF | Dangerous | Arm control, NVM address/data, program command, status |

## Group 0x0000 — Global

| Offset | Name | R/W | Reset | Description |
|--------|------|-----|-------|-------------|
| 0x0000 | CHIP_ID | R | 0x554C4332 | 'ULC2' ASCII identifier |
| 0x0004 | CHIP_REV | R | 0x00000002 | Revision number |
| 0x0008 | GLOBAL_RESET | W | — | Write 0xDEAD to trigger full reset |
| 0x000C | MODE_CONTROL | RW | 0x00000000 | [0] global_enable, [1] reset_fabric, [2] arm_dangerous, [3] clear_results, [4] loop_mode, [5] pll_enable, [6] dac_enable, [7] bist_enable, [8] lab_mode |
| 0x0010 | GLOBAL_STATUS | R | 0x00000000 | [0] busy, [1] done, [2] pass, [3] fail, [4] timeout, [5] dangerous_armed, [8] pll_locked, [9] dac_active, [10] bist_loaded, [11] route_active, [12] experiment_running |
| 0x0014 | ERROR_CODE | R | 0x00 | Last error code |
| 0x0018 | CYCLE_COUNT | R | — | Free-running 32-bit cycle counter |
| 0x001C | EXPERIMENT_ID | RW | 0x00 | Active experiment profile ID |
| 0x0020 | EXPERIMENT_STATUS | R | 0x00 | Experiment execution state |

## Group 0x0100 — Test Sequencer

| Offset | Name | R/W | Reset | Description |
|--------|------|-----|-------|-------------|
| 0x0100 | TEST_SELECT | RW | 0x00 | Block ID to test |
| 0x0104 | TEST_COMMAND | W | — | Command byte (write triggers execution) |
| 0x0108 | TEST_STATUS | R | 0x00 | Sequencer state |
| 0x010C | TIMEOUT_CYCLES | RW | 0x000F4240 | Timeout threshold (default 1M) |
| 0x0110 | RESULT0 | R | — | Test result word 0 |
| 0x0114 | RESULT1 | R | — | Test result word 1 |
| 0x0118 | RESULT2 | R | — | Test result word 2 |
| 0x011C | RESULT3 | R | — | Test result word 3 |
| 0x0120 | PASS_COUNT | R | 0 | Cumulative pass count |
| 0x0124 | FAIL_COUNT | R | 0 | Cumulative fail count |
| 0x0128 | LAST_BLOCK | R | — | Last tested block ID |
| 0x012C | LAST_STATE | R | — | Last sequencer state |

## Group 0x0200 — Clocks

| Offset | Name | R/W | Reset | Description |
|--------|------|-----|-------|-------------|
| 0x0200 | CLK_SOURCE_SELECT | RW | 0x000 | [2:0] ADC clk, [5:3] DAC clk, [8:6] BIST clk, [11:9] EXP clk |
| 0x0204 | CLK_DIVIDER_SELECT | RW | 0x00 | Global divider setting |
| 0x0208 | PLL_ENABLE | RW | 0x00 | [0] enable, [1] bypass, [7:4] mult, [11:8] div |
| 0x020C | PLL_STATUS | R | 0x00 | [0] locked, [1] timeout, [2] bypass_active |
| 0x0210 | PLL_FREQ_COUNT | R | — | Measured PLL output frequency |
| 0x0214 | PLL_LOCK_TIMEOUT | RW | 0x0007A120 | Lock timeout cycles (500K) |
| 0x0218 | FREQ_MEAS_SELECT | RW | 0x00 | [2:0] source to measure |
| 0x021C | FREQ_MEAS_RESULT | R/W | — | Write to trigger, read for result |
| 0x0220 | FREQ_MEAS_WINDOW | RW | 0x00002710 | Reference window (10K default) |

## Group 0x0300 — Analog Routes

| Offset | Name | R/W | Reset | Description |
|--------|------|-----|-------|-------------|
| 0x0300 | ANALOG_ROUTE_SELECT | RW | 0x000 | [2:0] ADC src, [5:3] comp+ src, [8:6] comp- src, [12] DAC→ext |
| 0x0304 | ANALOG_ROUTE_STATUS | R | 0x00 | [0] bist_active, [1] route_active, [2] contention |
| 0x0308 | ADC_INPUT_SOURCE | RW | 0x00 | [2:0] ADC source select shortcut |
| 0x030C | COMP_INPUT_SOURCE | RW | 0x00 | [2:0] comp+ source, [5:3] comp- source |

## Group 0x0400 — DAC

| Offset | Name | R/W | Reset | Description |
|--------|------|-----|-------|-------------|
| 0x0400 | DAC_CODE | RW | 0x000 | [9:0] static / base output code |
| 0x0404 | DAC_MODE | RW | 0x00 | [2:0] mode (static/staircase/ramp/alt/lut) |
| 0x0408 | DAC_ALT_CODE | RW | 0x000 | [9:0] alternating second code |
| 0x040C | DAC_CLK_DIVIDER | RW | 0x0A | [7:0] update rate divider |
| 0x0410 | DAC_STATUS | R | 0x00 | [0] running, [2:0] active mode |
| 0x0414 | DAC_UPDATE_COUNT | R | 0 | 32-bit update counter |

## Group 0x0500 — ADC

| Offset | Name | R/W | Reset | Description |
|--------|------|-----|-------|-------------|
| 0x0500 | ADC_CONTROL | RW | 0x00 | [0] start, [3:1] channel |
| 0x0504 | ADC_RESULT | R | — | [11:0] last conversion result |
| 0x0508 | ADC_MIN_CAPTURE | R | 0xFFF | Minimum observed code |
| 0x050C | ADC_MAX_CAPTURE | R | 0x000 | Maximum observed code |
| 0x0510 | ADC_SAMPLE_COUNT | R | 0 | Number of conversions completed |

## Group 0x0600 — Comparator

| Offset | Name | R/W | Reset | Description |
|--------|------|-----|-------|-------------|
| 0x0600 | COMP_CONTROL | RW | 0x00 | [7:0] threshold code |
| 0x0604 | COMP_STATUS | R | 0x00 | [0] comp_out, [31:16] toggle count |
| 0x0608 | COMP_SWEEP_CONFIG | RW | 0x00 | [7:0] sweep start, [15:8] sweep end, [19:16] num_sweeps |
| 0x060C | COMP_TRIP_RESULT | R | — | [7:0] avg trip code, [15:8] trip count |

## Group 0x0700 — BIST Engine

| Offset | Name | R/W | Reset | Description |
|--------|------|-----|-------|-------------|
| 0x0700 | BIST_COMMAND | W | — | [2:0] command (nop/shift/latch/apply/capture/shiftout/clear) |
| 0x0704 | BIST_CHAIN_SELECT | RW | 0x00 | [2:0] active chain ID |
| 0x0708 | BIST_SHIFT_DATA_IN | RW | 0x00 | 32-bit shift data for selected chain |
| 0x070C | BIST_SHIFT_DATA_OUT | R | 0x00 | 32-bit readback from selected chain |
| 0x0710 | BIST_LATCH_STATUS | R | 0x00 | [4:0] which chains are latched |
| 0x0714 | BIST_APPLY_STATUS | R | 0x00 | [0] patterns applied |

## Group 0x0800 — TRNG / PUF

| Offset | Name | R/W | Reset | Description |
|--------|------|-----|-------|-------------|
| 0x0800 | TRNG_CONTROL | RW | 0x00 | [0] start collection |
| 0x0804 | TRNG_STATUS | R | 0x00 | [0] rep_fail, [1] prop_fail, [2] stuck |
| 0x0808 | TRNG_BIT_COUNT | R | 0 | Bits collected |
| 0x080C | TRNG_ONES_COUNT | R | 0 | Ones counted |
| 0x0810 | TRNG_REP_MAX | R | 0 | Max consecutive identical bits |
| 0x0820 | PUF_CONTROL | RW | 0x00 | [0] start challenge |
| 0x0824 | PUF_STATUS | R | 0x00 | [0] valid, [7:0] stability score |
| 0x0828 | PUF_RESPONSE_0 | R | — | Response bits [31:0] |
| 0x082C | PUF_RESPONSE_1 | R | — | Response bits [63:32] |
| 0x0830 | PUF_RESPONSE_2 | R | — | Response bits [95:64] |
| 0x0834 | PUF_RESPONSE_3 | R | — | Response bits [127:96] |
| 0x0838 | PUF_MISMATCH | R | 0 | Total Hamming distance |

## Group 0x0900 — Logs / SRAM

| Offset | Name | R/W | Reset | Description |
|--------|------|-----|-------|-------------|
| 0x0900 | LOG_PTR | R | 0 | Current write pointer (circular) |
| 0x0904 | LOG_COUNT | R | 0 | Total entries written |
| 0x0908 | LOG_READ_INDEX | RW | 0 | Index for reading log entries |
| 0x090C | LOG_ENTRY_BLOCK | R | — | Log entry: block_id + error_code |
| 0x0910 | LOG_ENTRY_TIME_START | R | — | Log entry: cycle_start |
| 0x0914 | LOG_ENTRY_TIME_END | R | — | Log entry: cycle_end |
| 0x0918 | LOG_ENTRY_RESULT0 | R | — | Log entry: result0 |
| 0x091C | LOG_ENTRY_RESULT1 | R | — | Log entry: result1 |
| 0x0940 | SRAM_BIST_STATUS | R | 0x00 | [0] pass, [1] fail, [31:16] fail addr |

## Group 0x0A00 — Dangerous Zone

| Offset | Name | R/W | Reset | Description |
|--------|------|-----|-------|-------------|
| 0x0A00 | DANGEROUS_ARM | RW | 0x00 | Write 0x4152_4D21 ('ARM!') to arm. Read: [0] armed |
| 0x0A04 | NVM_ADDRESS | RW | 0x00 | [7:0] NVM test address |
| 0x0A08 | NVM_WRITE_DATA | RW | 0x00 | 32-bit write data |
| 0x0A0C | NVM_READ_DATA | R | — | 32-bit read data |
| 0x0A10 | NVM_COMMAND | W | — | [0] read, [1] write, [2] program |
| 0x0A14 | NVM_STATUS | R | 0x00 | [0] busy, [1] done, [2] error |

## Serial Protocol

### UART Frame Format (115200 8N1)

**Write register:**
```
TX: 'W' addr_hi addr_lo data[3] data[2] data[1] data[0]
RX: 'A'  (ACK)
```

**Read register:**
```
TX: 'R' addr_hi addr_lo
RX: 'D' data[3] data[2] data[1] data[0]
```

**Status poll:**
```
TX: 'S'
RX: 'S' status[3] status[2] status[1] status[0]   (returns GLOBAL_STATUS)
```

Address is 16-bit big-endian. Data is 32-bit big-endian.

### Safety

- Reset clears all registers to documented defaults
- DANGEROUS_ARM requires magic word 0x41524D21 ('ARM!') — any other write disarms
- GLOBAL_RESET requires magic word 0xDEAD
- MODE_CONTROL bit operations are idempotent
