# ULC Block Test Matrix

## Matrix

| Block Name  | Block ID | SAFE_AUTO | LAB_EXTENDED | DANGEROUS_ARMED | Automatic Method | Expected Outputs (RESULT0-3) | Host Deep Analysis |
|-------------|----------|-----------|--------------|-----------------|------------------|------------------------------|--------------------|
| REGBANK     | 0x00     | Yes       | Yes          | No              | Walking-1/0 write-readback across all register addresses | R0=tested_count, R1=mismatch_count, R2=first_fail_addr, R3=first_fail_data | No |
| SRAM        | 0x01     | Yes       | Yes          | Yes (stress)    | March-C + checkerboard write/read/verify | R0=words_tested, R1=words_passed, R2=first_fail_addr, R3=first_fail_data | No |
| UART        | 0x02     | Yes       | Yes          | No              | Internal loopback: TX known patterns, compare RX | R0=bytes_sent, R1=bytes_matched, R2=baud_measured, R3=0 | No |
| SPI         | 0x03     | Yes       | Yes          | No              | Internal loopback: master TX→slave RX, verify byte patterns | R0=bytes_sent, R1=bytes_matched, R2=clock_div_used, R3=0 | No |
| I2C         | 0x04     | Yes       | Yes          | No              | Internal loopback: master write→slave ACK→master read→compare | R0=transactions, R1=ack_count, R2=nack_count, R3=data_mismatches | No |
| GPIO        | 0x05     | Yes       | Yes          | Yes (stress)    | Output→input loopback via test mux; all pins, both polarities | R0=pins_tested, R1=pins_passed, R2=stuck_high_mask, R3=stuck_low_mask | No |
| RING_OSC    | 0x06     | Yes       | Yes          | No              | Start oscillators, count edges over N reference cycles | R0=min_freq (safe: nonzero check / ext: Hz), R1=max_freq, R2=mean_freq, R3=osc_count | Yes (extended) |
| CLK_DIV     | 0x07     | Yes       | Yes          | No              | Switch divider ratios, verify output frequency via counter | R0=ratio_tested, R1=ratio_passed, R2=jitter_pk_pk (ext only), R3=0 | No |
| TRNG        | 0x08     | Yes       | Yes          | No              | Collect N bits; safe: stuck-at check; extended: monobit + runs | R0=bits_collected, R1=ones_count, R2=runs_stat (ext), R3=0 | Yes (extended) |
| PUF         | 0x09     | Yes       | Yes          | No              | Challenge-response; safe: non-trivial check; extended: multi-enroll HD | R0=hd_intra (ext) or response_word (safe), R1=response_word, R2=enrollments, R3=0 | Yes (extended) |
| COMPARATOR  | 0x0A     | Yes       | Yes          | No              | Apply known reference, verify output polarity; extended: sweep for trip point | R0=trip_code (ext) or polarity (safe), R1=ref_applied, R2=0, R3=0 | Yes (extended) |
| ADC         | 0x0B     | Yes       | Yes          | No              | Convert known reference; safe: coarse window; extended: full ramp INL/DNL | R0=inl_max (ext) or code (safe), R1=dnl_max (ext), R2=offset, R3=gain_error | Yes (extended) |
| NVM         | 0x0C     | Yes (read)| Yes (read)   | **Yes (write)** | Safe/ext: read-verify existing contents; dangerous: program + verify | R0=words_read, R1=words_matched, R2=first_fail_addr, R3=programmed_count (dangerous) | No |

## Block Test Details

### REGBANK (0x00)
Writes walking-1 and walking-0 patterns to every writable register, reads back, compares. Tests address decoding and data path integrity. No side effects.

### SRAM (0x01)
Runs March-C algorithm (write 0, read 0/write 1, read 1/write 0, read 0) across full address range. Checkerboard pattern as secondary pass. Extended mode adds retention test (write, wait, re-read). Dangerous mode adds marginal-timing stress writes.

### UART (0x02)
Configures internal loopback mode. Transmits a sequence of known bytes, captures received bytes, compares. Tests baud rate generator, TX shift register, RX shift register, and frame detection.

### SPI (0x03)
Connects internal master to internal slave via test mux. Transmits byte patterns in modes 0-3 (CPOL/CPHA), verifies slave received correct data. Tests clock generation, MOSI/MISO paths, and chip-select timing.

### I2C (0x04)
Internal master sends write transactions to internal slave, then reads back. Verifies ACK generation, clock stretching, and data integrity. Tests both 7-bit addressing and data phases.

### GPIO (0x05)
Routes each GPIO output back to input via on-chip test mux. Drives each pin high and low, reads back, compares. Reports stuck-at faults per pin. Dangerous mode toggles all pins at max frequency for stress.

### RING_OSC (0x06)
Enables each ring oscillator, counts edges over a fixed reference window. Safe mode verifies non-zero count (oscillator alive). Extended mode measures actual frequency in Hz per stage, reports min/max/mean. Host analysis can detect process corner from frequency spread.

### CLK_DIV (0x07)
Programs each supported divider ratio, measures output frequency via internal counter against reference. Verifies all ratios produce correct frequency within tolerance. Extended mode adds jitter measurement over longer window.

### TRNG (0x08)
Collects entropy bits from noise source. Safe mode: 64 bits, verifies not all-0 or all-1 (not stuck). Extended mode: 1024+ bits, runs NIST SP 800-22 monobit and runs tests on-chip, reports statistics. Host deep analysis can run full test suite on collected bitstream.

### PUF (0x09)
Issues challenge, reads response. Safe mode: verifies response is non-trivial (not 0x00 or 0xFF). Extended mode: multiple enrollments of same challenge, computes intra-chip Hamming distance (should be low). Host analysis evaluates uniqueness and reliability.

### COMPARATOR (0x0A)
Applies reference voltage to positive input via internal DAC, known voltage to negative input. Safe mode: verifies output matches expected polarity. Extended mode: sweeps DAC code to find exact trip point. Host analysis characterizes offset and hysteresis.

### ADC (0x0B)
Connects ADC input to internal reference. Safe mode: single conversion, verifies code within coarse window (e.g., +/-10% of expected). Extended mode: ramp test across full input range, computes INL and DNL per code, offset, and gain error. Host analysis can plot transfer function.

### NVM (0x0C)
Safe and extended modes: read existing NVM/OTP contents, compare against expected values (factory defaults or previously programmed). Reports word count and mismatches. **Dangerous mode only:** programs OTP bits with specified test pattern, then reads back to verify. This is **irreversible** — OTP bits cannot be erased. Requires full arming sequence.

## Notes

- "Host Deep Analysis" = the on-chip test provides raw data, but meaningful characterization requires host-side statistical processing (e.g., TRNG entropy estimation, ADC INL/DNL plotting, PUF reliability metrics).
- All blocks report pass/fail autonomously via the wrapper interface. Host deep analysis is optional and additive.
- Block-specific error codes (0x08+) are documented in each block's RTL wrapper header.
