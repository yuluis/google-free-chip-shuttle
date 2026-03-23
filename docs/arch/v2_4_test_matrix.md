# ULC v2.4 Test Matrix

**Status:** Frozen
**Testable blocks:** 15
**BIST chains:** 5
**Experiment profiles:** 15

---

## Block Test Matrix

Each of the 15 testable blocks has a self-test sequence executable via the sequencer. The sequencer selects the block (BLOCK_SELECT), issues a COMMAND, and evaluates results against pass criteria within TIMEOUT_CYCLES.

| # | Block Name | Block ID | Zone | Self-Test Description | Pass Criteria | FPGA-Verifiable? | Shuttle-Only Measurement Notes |
|---|-----------|----------|------|-----------------------|---------------|-------------------|-------------------------------|
| 1 | UART Controller | 0x01 | host_perimeter | Loopback test: TX internally routed to RX; send known pattern, verify received data matches. | All bytes received match transmitted pattern; no framing errors. | Yes | On shuttle: verify actual pad-level TX/RX with external UART adapter at target baud rate. Measure TX eye diagram. |
| 2 | SPI Controller | 0x02 | host_perimeter | Internal loopback: MOSI internally connected to MISO path; clock out test pattern, verify shift register content. | Shifted-out data matches shifted-in pattern for all test words. | Yes | On shuttle: verify with external SPI master at multiple clock rates. Check setup/hold timing on pads. |
| 3 | GPIO Bank | 0x03 | gpio_perimeter | Write output register, read back via input register (with output-enable set). For each bit: set output, verify input reads back same value. | All 8 bits read back correctly in both directions. | Yes | On shuttle: measure output drive strength (VOH, VOL) at rated current. Verify input threshold levels (VIH, VIL). |
| 4 | LED Drivers | 0x04 | gpio_perimeter | Sequentially drive each LED output HIGH, verify via internal readback register that drive state matches commanded state. | All 5 channels individually controllable; readback matches command. | Yes | On shuttle: measure LED output current drive capability. Verify PWM (if supported) waveform timing with scope. |
| 5 | Clock Mux | 0x05 | clock_experiment | Select each clock source (ext_ref, PLL, ROSC, divided), measure output via frequency counter. Verify glitch-free switching by checking counter continuity. | Frequency counter reads expected value for each source (within tolerance). No spurious zero-count readings during mux switch. | Partial | On shuttle: measure actual output frequency on DBG/GP pads with frequency counter or scope. Verify glitch-free transitions with continuous sampling. PLL and ROSC frequencies are process-dependent — FPGA can only verify mux logic. |
| 6 | Frequency Counter | 0x06 | clock_experiment | Apply known reference clock, run frequency count with known window. Verify count equals expected value. | Measured count within +/-1 of expected count for ext_ref. Repeated measurements are stable (jitter < 1 count). | Yes | On shuttle: cross-validate with external frequency counter on same clock. Verify accuracy across temperature range. |
| 7 | Clock Divider | 0x07 | clock_experiment | Configure divider ratios (1, 2, 4, 8, ...), measure output frequency via frequency counter. | Output frequency = input frequency / ratio (within +/-1 count per measurement). | Yes | On shuttle: verify divided clock waveform duty cycle with oscilloscope. |
| 8 | DAC | 0x08 | mixed_signal | Ramp DAC code from 0 to max, read back DAC_STATUS for each step. In static mode, verify status reflects commanded code. If ADC available, route DAC to ADC and verify monotonicity. | DAC_STATUS confirms each code applied. If ADC cross-check: ADC result is monotonically increasing with DAC code. | Partial | On shuttle: measure actual DAC_OUT voltage with DMM/scope at each code. Verify DNL, INL, full-scale range, settling time. FPGA verifies digital control path only. |
| 9 | ADC | 0x09 | mixed_signal | Apply known reference via ADC_REF pad. Route to ADC via AROUTE. Trigger conversion, read ADC_RESULT. Verify result is within expected range. | ADC_RESULT within +/-2 LSB of expected code for known reference. Multiple samples show low variance. | Partial | On shuttle: full ADC characterization — sweep input voltage, measure DNL, INL, ENOB. Apply known DC levels and verify. FPGA verifies FSM and digital readback only. |
| 10 | Comparator | 0x0A | mixed_signal | Configure DAC sweep mode. Route DAC to comparator via AROUTE. Sweep DAC code upward until comparator trips. Record trip code. | Comparator trips within expected code range for known threshold. Trip point repeatable across multiple sweeps. | Partial | On shuttle: apply external voltage to COMP_IN, sweep DAC, measure actual trip point with DMM. Verify hysteresis by sweeping in both directions. FPGA verifies digital trip detection logic only. |
| 11 | Analog Routing | 0x0B | mixed_signal | Configure each routing path individually. For each path: enable route, verify AROUTE_STATUS reflects connection. If DAC+ADC available, route DAC through path to ADC and verify signal passes. | All route configurations accepted. AROUTE_STATUS matches commanded state. DAC-to-ADC path (if tested) passes signal. | Partial | On shuttle: verify analog path resistance and signal attenuation with precision instruments. Check for crosstalk between routes. FPGA verifies switch control logic only. |
| 12 | BIST Fabric | 0x0C | digital_core | For each of 5 chains: shift in known pattern, apply, capture, shift out. Compare captured data against expected. | All 5 chains: shifted-out capture data matches expected response for each test pattern. No stuck-at faults detected. | Yes | On shuttle: identical to FPGA test — BIST is fully digital. May reveal manufacturing defects not present in FPGA. |
| 13 | TRNG | 0x0D | digital_core | Enable TRNG, collect N bits (N >= 1000). Check bias: ones_count should be within statistical bounds of N/2. Check repetition: rep_max should be below threshold. | ones_count within 3-sigma of N/2 (for N=1000: 469-531). rep_max < 20 for 1000-bit sample. | No | TRNG output is deterministic in FPGA (no physical entropy source). **Shuttle-only test.** On shuttle: collect large sample (100K+ bits), run NIST SP 800-22 statistical tests. Verify entropy rate. |
| 14 | PUF | 0x0E | digital_core | Issue challenge, read 128-bit response. Repeat same challenge 10 times. Measure intra-device reproducibility (Hamming distance between responses). | Intra-device Hamming distance < 5% (< 7 bits of 128) across 10 repeated challenges at same conditions. | No | PUF responses are deterministic in FPGA (no process variation). **Shuttle-only test.** On shuttle: characterize intra-device (reproducibility) and inter-device (uniqueness) Hamming distances. Test across voltage and temperature. |
| 15 | Event Logger | 0x0F | digital_core | Run a known sequence of block tests. Verify log entries: count matches number of tests run, each entry has correct block ID, start/end timestamps are monotonically increasing, result words match RESULT0/RESULT1 captured at test time. | LOG_COUNT equals number of tests executed. All entries have valid block IDs, monotonic timestamps, and correct results. | Yes | On shuttle: identical to FPGA test — logger is fully digital. Verify timestamp accuracy against known clock period. |

---

## FPGA Verification Summary

| Category | Count | Blocks |
|----------|-------|--------|
| Fully FPGA-verifiable | 9 | UART, SPI, GPIO, LED, Freq Counter, Clock Divider, BIST, Event Logger, (Clock Mux logic) |
| Partially FPGA-verifiable | 4 | DAC, ADC, Comparator, Analog Routing (digital control verified; analog behavior is shuttle-only) |
| Shuttle-only | 2 | TRNG, PUF (require physical entropy / process variation) |

---

## Experiment Profiles

Each experiment profile pre-configures a combination of blocks for a specific test scenario. Profiles are loaded by writing the profile number (1-15) to EXPERIMENT_ID and issuing a run command.

| Profile | Name | Blocks Exercised | Purpose |
|---------|------|-------------------|---------|
| 0 | None | — | No experiment (reset default) |
| 1 | Host Loopback | UART, SPI | Verify both host interfaces via internal loopback |
| 2 | GPIO Sweep | GPIO, LED | Walk all GPIO and LED outputs; verify readback |
| 3 | Clock Tour | Clock Mux, Freq Counter, Divider | Select each clock source, measure, divide |
| 4 | DAC Ramp | DAC, Analog Routing | Ramp DAC through full code range |
| 5 | ADC Characterize | ADC, Analog Routing | Sample ADC across input range |
| 6 | Comparator Sweep | DAC, Comparator, Analog Routing | DAC-driven comparator trip point search |
| 7 | Full Analog Loop | DAC, ADC, Comparator, Analog Routing | Route DAC to ADC and comparator; full mixed-signal path |
| 8 | BIST Full | BIST (all 5 chains) | Run all BIST chains with standard test patterns |
| 9 | Security Suite | TRNG, PUF | Collect entropy, challenge PUF, basic health checks |
| 10 | PLL Startup | PLL, Freq Counter, Clock Mux | Enable PLL, measure output frequency, verify stability |
| 11 | ROSC Characterize | Ring Oscillator, Freq Counter | Enable ROSC, measure free-running frequency |
| 12 | Stress Loop | All digital blocks | Continuous loop of all digital self-tests |
| 13 | Analog Stress | DAC, ADC, Comparator, Routing | Continuous loop of analog measurements |
| 14 | Full Chip | All 15 blocks | Sequential test of every block |
| 15 | Dangerous NVM | NVM Controller | Exercise NVM protocol (requires dual-key arming) |

---

## BIST Chain Mapping

| Chain | ID | Coverage | Description |
|-------|-----|----------|-------------|
| 0 | 0x00 | Sequencer + register file | Core control path flip-flops |
| 1 | 0x01 | BIST controller + logger | Self-test infrastructure flip-flops |
| 2 | 0x02 | Clock domain control | Clock mux, divider, PLL interface registers |
| 3 | 0x03 | Analog interface | DAC/ADC/comparator digital control flip-flops |
| 4 | 0x04 | Security + dangerous | TRNG/PUF/NVM digital control flip-flops |

---

## Test Execution Notes

### General Procedure
1. After reset, verify CHIP_ID and CHIP_REV
2. Read BOOT_STATUS to confirm clean reset
3. Set GLOBAL_CONTROL.global_enable = 1
4. Select experiment profile (EXPERIMENT_ID) or manually configure blocks
5. Issue COMMAND to start
6. Poll EXPERIMENT_STATUS or GLOBAL_STATUS for completion
7. Read RESULT0-3, PASS_COUNT, FAIL_COUNT, ERROR_CODE
8. Optionally read event log (Bank 5) for detailed per-block results

### Timeout Handling
- Default TIMEOUT_CYCLES = 1,000,000 (0x000F4240)
- At 10 MHz reference clock, this is 100ms per block test
- For analog tests (profiles 4-7, 10-11), increase timeout to accommodate settling times
- lab_mode (GLOBAL_CONTROL[8]) relaxes timeout enforcement for bench debugging

### Dangerous Zone Testing
- Profile 15 requires explicit dual-key arming before execution
- Sequencer will NOT arm the dangerous zone automatically
- Host must: (1) set GLOBAL_CONTROL[2]=1, (2) write 0x41524D21 to DANGEROUS_ARM, (3) then select profile 15
- NVM controller is a stub — test verifies protocol handling, not actual NVM operations
