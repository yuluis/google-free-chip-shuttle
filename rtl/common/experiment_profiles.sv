// ---------------------------------------------------------------------------
// experiment_profiles.sv — Predefined experiment configurations
//
// Each profile defines: block enables, clock sources, analog routes,
// DAC mode, sample count, and safety requirements. The sequencer loads
// a profile by ID and configures all subsystems before running.
//
// This creates a structured "lab mode" rather than ad hoc testing.
// ---------------------------------------------------------------------------
module experiment_profiles
  import ulc_pkg::*;
(
  input  experiment_id_t      profile_id,
  output experiment_profile_t profile
);

  always_comb begin
    // Default: everything off / safe
    profile = '0;
    profile.exp_id = profile_id;

    case (profile_id)
      // -----------------------------------------------------------------
      // DAC -> ADC closed-loop characterization
      // DAC runs staircase, ADC captures codes, compare linearity
      // -----------------------------------------------------------------
      EXP_DAC_ADC_LOOPBACK: begin
        profile.block_enables    = (1 << BLK_DAC) | (1 << BLK_ADC);
        profile.adc_clk          = CLKSRC_EXT_REF;
        profile.dac_clk          = CLKSRC_EXT_REF;
        profile.adc_source       = ASRC_DAC_OUT;
        profile.comp_pos         = ASRC_DISCONNECTED;
        profile.comp_neg         = ASRC_DISCONNECTED;
        profile.dac_mode         = DAC_MODE_STAIRCASE;
        profile.sample_count     = 16'd1024;
        profile.requires_pll     = 1'b0;
        profile.requires_dangerous = 1'b0;
      end

      // -----------------------------------------------------------------
      // DAC -> Comparator threshold sweep
      // DAC ramps, comparator detects crossing against ref ladder
      // -----------------------------------------------------------------
      EXP_DAC_COMP_SWEEP: begin
        profile.block_enables    = (1 << BLK_DAC) | (1 << BLK_COMPARATOR);
        profile.adc_clk          = CLKSRC_EXT_REF;
        profile.dac_clk          = CLKSRC_EXT_REF;
        profile.adc_source       = ASRC_DISCONNECTED;
        profile.comp_pos         = ASRC_DAC_OUT;
        profile.comp_neg         = ASRC_REF_LADDER;
        profile.dac_mode         = DAC_MODE_RAMP;
        profile.sample_count     = 16'd2048;
        profile.requires_pll     = 1'b0;
        profile.requires_dangerous = 1'b0;
      end

      // -----------------------------------------------------------------
      // ADC with external analog input
      // -----------------------------------------------------------------
      EXP_ADC_EXT_INPUT: begin
        profile.block_enables    = (1 << BLK_ADC);
        profile.adc_clk          = CLKSRC_EXT_REF;
        profile.dac_clk          = CLKSRC_EXT_REF;
        profile.adc_source       = ASRC_EXT_ANALOG_IN;
        profile.comp_pos         = ASRC_DISCONNECTED;
        profile.comp_neg         = ASRC_DISCONNECTED;
        profile.dac_mode         = DAC_MODE_STATIC;
        profile.sample_count     = 16'd256;
        profile.requires_pll     = 1'b0;
        profile.requires_dangerous = 1'b0;
      end

      // -----------------------------------------------------------------
      // PLL frequency measurement only
      // -----------------------------------------------------------------
      EXP_PLL_FREQ_MEASURE: begin
        profile.block_enables    = (1 << BLK_PLL);
        profile.adc_clk          = CLKSRC_EXT_REF;
        profile.dac_clk          = CLKSRC_EXT_REF;
        profile.adc_source       = ASRC_DISCONNECTED;
        profile.comp_pos         = ASRC_DISCONNECTED;
        profile.comp_neg         = ASRC_DISCONNECTED;
        profile.dac_mode         = DAC_MODE_STATIC;
        profile.sample_count     = 16'd10000;
        profile.requires_pll     = 1'b1;
        profile.requires_dangerous = 1'b0;
      end

      // -----------------------------------------------------------------
      // PLL -> ADC clock sweep (vary sample rate, measure noise)
      // -----------------------------------------------------------------
      EXP_PLL_ADC_CLK_SWEEP: begin
        profile.block_enables    = (1 << BLK_PLL) | (1 << BLK_ADC) | (1 << BLK_DAC);
        profile.adc_clk          = CLKSRC_PLL_OUT;
        profile.dac_clk          = CLKSRC_EXT_REF;
        profile.adc_source       = ASRC_DAC_OUT;
        profile.comp_pos         = ASRC_DISCONNECTED;
        profile.comp_neg         = ASRC_DISCONNECTED;
        profile.dac_mode         = DAC_MODE_STATIC;
        profile.sample_count     = 16'd512;
        profile.requires_pll     = 1'b1;
        profile.requires_dangerous = 1'b0;
      end

      // -----------------------------------------------------------------
      // DAC update clock sweep (vary DAC rate using PLL)
      // -----------------------------------------------------------------
      EXP_DAC_CLK_SWEEP: begin
        profile.block_enables    = (1 << BLK_DAC) | (1 << BLK_ADC) | (1 << BLK_PLL);
        profile.adc_clk          = CLKSRC_EXT_REF;
        profile.dac_clk          = CLKSRC_PLL_OUT;
        profile.adc_source       = ASRC_DAC_OUT;
        profile.comp_pos         = ASRC_DISCONNECTED;
        profile.comp_neg         = ASRC_DISCONNECTED;
        profile.dac_mode         = DAC_MODE_STAIRCASE;
        profile.sample_count     = 16'd1024;
        profile.requires_pll     = 1'b1;
        profile.requires_dangerous = 1'b0;
      end

      // -----------------------------------------------------------------
      // Ring oscillator frequency count
      // -----------------------------------------------------------------
      EXP_RINGOSC_COUNT: begin
        profile.block_enables    = (1 << BLK_RING_OSC);
        profile.adc_clk          = CLKSRC_EXT_REF;
        profile.dac_clk          = CLKSRC_EXT_REF;
        profile.adc_source       = ASRC_DISCONNECTED;
        profile.comp_pos         = ASRC_DISCONNECTED;
        profile.comp_neg         = ASRC_DISCONNECTED;
        profile.dac_mode         = DAC_MODE_STATIC;
        profile.sample_count     = 16'd1024;
        profile.requires_pll     = 1'b0;
        profile.requires_dangerous = 1'b0;
      end

      // -----------------------------------------------------------------
      // TRNG health screening
      // -----------------------------------------------------------------
      EXP_TRNG_HEALTH: begin
        profile.block_enables    = (1 << BLK_TRNG);
        profile.adc_clk          = CLKSRC_EXT_REF;
        profile.dac_clk          = CLKSRC_EXT_REF;
        profile.adc_source       = ASRC_DISCONNECTED;
        profile.comp_pos         = ASRC_DISCONNECTED;
        profile.comp_neg         = ASRC_DISCONNECTED;
        profile.dac_mode         = DAC_MODE_STATIC;
        profile.sample_count     = 16'd1024;
        profile.requires_pll     = 1'b0;
        profile.requires_dangerous = 1'b0;
      end

      // -----------------------------------------------------------------
      // PUF stability capture
      // -----------------------------------------------------------------
      EXP_PUF_CAPTURE: begin
        profile.block_enables    = (1 << BLK_PUF);
        profile.adc_clk          = CLKSRC_EXT_REF;
        profile.dac_clk          = CLKSRC_EXT_REF;
        profile.adc_source       = ASRC_DISCONNECTED;
        profile.comp_pos         = ASRC_DISCONNECTED;
        profile.comp_neg         = ASRC_DISCONNECTED;
        profile.dac_mode         = DAC_MODE_STATIC;
        profile.sample_count     = 16'd8;
        profile.requires_pll     = 1'b0;
        profile.requires_dangerous = 1'b0;
      end

      // -----------------------------------------------------------------
      // NVM read-only (non-destructive)
      // -----------------------------------------------------------------
      EXP_NVM_READONLY: begin
        profile.block_enables    = (1 << BLK_NVM);
        profile.adc_clk          = CLKSRC_EXT_REF;
        profile.dac_clk          = CLKSRC_EXT_REF;
        profile.adc_source       = ASRC_DISCONNECTED;
        profile.comp_pos         = ASRC_DISCONNECTED;
        profile.comp_neg         = ASRC_DISCONNECTED;
        profile.dac_mode         = DAC_MODE_STATIC;
        profile.sample_count     = 16'd1;
        profile.requires_pll     = 1'b0;
        profile.requires_dangerous = 1'b0;
      end

      // -----------------------------------------------------------------
      // NVM program (DANGEROUS — requires arming)
      // -----------------------------------------------------------------
      EXP_NVM_PROGRAM: begin
        profile.block_enables    = (1 << BLK_NVM);
        profile.adc_clk          = CLKSRC_EXT_REF;
        profile.dac_clk          = CLKSRC_EXT_REF;
        profile.adc_source       = ASRC_DISCONNECTED;
        profile.comp_pos         = ASRC_DISCONNECTED;
        profile.comp_neg         = ASRC_DISCONNECTED;
        profile.dac_mode         = DAC_MODE_STATIC;
        profile.sample_count     = 16'd1;
        profile.requires_pll     = 1'b0;
        profile.requires_dangerous = 1'b1;
      end

      // -----------------------------------------------------------------
      // DAC ramp with ADC capture (linearity sweep)
      // -----------------------------------------------------------------
      EXP_DAC_RAMP_ADC_CAPTURE: begin
        profile.block_enables    = (1 << BLK_DAC) | (1 << BLK_ADC);
        profile.adc_clk          = CLKSRC_EXT_REF;
        profile.dac_clk          = CLKSRC_EXT_REF;
        profile.adc_source       = ASRC_DAC_OUT;
        profile.comp_pos         = ASRC_DISCONNECTED;
        profile.comp_neg         = ASRC_DISCONNECTED;
        profile.dac_mode         = DAC_MODE_RAMP;
        profile.sample_count     = 16'd2048;
        profile.requires_pll     = 1'b0;
        profile.requires_dangerous = 1'b0;
      end

      // -----------------------------------------------------------------
      // Comparator threshold calibration using DAC
      // -----------------------------------------------------------------
      EXP_COMP_THRESHOLD_CAL: begin
        profile.block_enables    = (1 << BLK_DAC) | (1 << BLK_COMPARATOR);
        profile.adc_clk          = CLKSRC_EXT_REF;
        profile.dac_clk          = CLKSRC_EXT_REF;
        profile.adc_source       = ASRC_DISCONNECTED;
        profile.comp_pos         = ASRC_DAC_OUT;
        profile.comp_neg         = ASRC_REF_LADDER;
        profile.dac_mode         = DAC_MODE_STAIRCASE;
        profile.sample_count     = 16'd1024;
        profile.requires_pll     = 1'b0;
        profile.requires_dangerous = 1'b0;
      end

      // -----------------------------------------------------------------
      // Clock source comparison (measure all sources)
      // -----------------------------------------------------------------
      EXP_CLOCK_SOURCE_COMPARE: begin
        profile.block_enables    = (1 << BLK_CLK_DIV) | (1 << BLK_RING_OSC);
        profile.adc_clk          = CLKSRC_EXT_REF;
        profile.dac_clk          = CLKSRC_EXT_REF;
        profile.adc_source       = ASRC_DISCONNECTED;
        profile.comp_pos         = ASRC_DISCONNECTED;
        profile.comp_neg         = ASRC_DISCONNECTED;
        profile.dac_mode         = DAC_MODE_STATIC;
        profile.sample_count     = 16'd10000;
        profile.requires_pll     = 1'b0;
        profile.requires_dangerous = 1'b0;
      end

      default: begin
        profile = '0;
        profile.exp_id = EXP_NONE;
      end
    endcase
  end

endmodule
