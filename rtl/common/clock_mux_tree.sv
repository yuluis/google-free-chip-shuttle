// ---------------------------------------------------------------------------
// clock_mux_tree.sv — Central clock source mux and measurement fabric
//
// Routes clock sources (ext ref, ring osc, divided sys, PLL, test gen) to
// destinations (ADC, DAC, BIST, digital experiment). Each destination has
// an independent source select. Includes frequency counters for any source.
//
// The chip MUST work without PLL lock — ext ref and ring osc are always
// available as fallback sources.
// ---------------------------------------------------------------------------
module clock_mux_tree
  import ulc_pkg::*;
(
  input  logic        clk,          // system clock (always present)
  input  logic        rst_n,

  // Host register interface
  input  logic        host_wr,
  input  logic [7:0]  host_addr,
  input  logic [31:0] host_wdata,
  output logic [31:0] host_rdata,

  // Clock sources
  input  logic        clk_ext_ref,  // external reference clock pad
  input  logic        clk_ring_osc, // ring oscillator output
  input  logic        clk_pll_out,  // PLL output (may be unstable)
  input  logic        pll_locked,   // PLL lock indicator

  // BIST override
  input  logic [BIST_CHAIN_WIDTH-1:0] bist_clock_chain,
  input  logic        bist_active,

  // Muxed clock outputs to destinations
  output logic        clk_adc,
  output logic        clk_dac,
  output logic        clk_bist,
  output logic        clk_experiment,

  // Status
  output logic [31:0] freq_count_result,
  output clock_mux_cfg_t active_config
);

  // -----------------------------------------------------------------------
  // Configuration registers
  // -----------------------------------------------------------------------
  clock_mux_cfg_t cfg_reg;
  logic [2:0]     freq_measure_sel;  // which source to measure
  logic [31:0]    freq_ref_window;   // measurement window in system clocks

  // Frequency measurement
  logic [31:0]    freq_cnt;
  logic [31:0]    freq_ref_cnt;
  logic [31:0]    freq_result_latched;
  logic           freq_measuring;

  // Divider for system clock (/2, /4, /8, /16)
  logic [3:0]     sys_div_cnt;
  logic           clk_div2, clk_div4, clk_div8, clk_div16;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      sys_div_cnt <= '0;
    else
      sys_div_cnt <= sys_div_cnt + 1;
  end

  assign clk_div2  = sys_div_cnt[0];
  assign clk_div4  = sys_div_cnt[1];
  assign clk_div8  = sys_div_cnt[2];
  assign clk_div16 = sys_div_cnt[3];

  // -----------------------------------------------------------------------
  // Register writes
  // -----------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cfg_reg          <= '0;  // all selects = CLKSRC_EXT_REF (safe default)
      freq_measure_sel <= '0;
      freq_ref_window  <= 32'd10000;
    end else if (host_wr) begin
      case (host_addr)
        REG_CLK_MUX_CONTROL: begin
          cfg_reg.adc_clk_sel  <= clock_source_t'(host_wdata[2:0]);
          cfg_reg.dac_clk_sel  <= clock_source_t'(host_wdata[5:3]);
          cfg_reg.bist_clk_sel <= clock_source_t'(host_wdata[8:6]);
          cfg_reg.exp_clk_sel  <= clock_source_t'(host_wdata[11:9]);
        end
        REG_CLK_FREQ_SELECT: begin
          freq_measure_sel <= host_wdata[2:0];
          freq_ref_window  <= host_wdata[31:0]; // reuse for window if nonzero
        end
        default: ;
      endcase
    end
  end

  // BIST override: if BIST is active, use BIST chain bits for clock mux
  clock_mux_cfg_t effective_cfg;
  always_comb begin
    if (bist_active && |bist_clock_chain) begin
      effective_cfg.adc_clk_sel  = clock_source_t'(bist_clock_chain[2:0]);
      effective_cfg.dac_clk_sel  = clock_source_t'(bist_clock_chain[5:3]);
      effective_cfg.bist_clk_sel = clock_source_t'(bist_clock_chain[8:6]);
      effective_cfg.exp_clk_sel  = clock_source_t'(bist_clock_chain[11:9]);
    end else begin
      effective_cfg = cfg_reg;
    end
  end

  assign active_config = effective_cfg;

  // -----------------------------------------------------------------------
  // Source mux function — safe fallback to system clock
  // PLL output only used when PLL is locked; otherwise falls back to ext ref
  // -----------------------------------------------------------------------
  function automatic logic mux_clock(clock_source_t sel);
    case (sel)
      CLKSRC_EXT_REF:  return clk_ext_ref;
      CLKSRC_RING_OSC: return clk_ring_osc;
      CLKSRC_DIV_SYS:  return clk_div4;
      CLKSRC_PLL_OUT:  return pll_locked ? clk_pll_out : clk_ext_ref; // safe fallback
      CLKSRC_TEST_GEN: return clk_div16;
      default:         return clk_ext_ref;
    endcase
  endfunction

  assign clk_adc        = mux_clock(effective_cfg.adc_clk_sel);
  assign clk_dac        = mux_clock(effective_cfg.dac_clk_sel);
  assign clk_bist       = mux_clock(effective_cfg.bist_clk_sel);
  assign clk_experiment = mux_clock(effective_cfg.exp_clk_sel);

  // -----------------------------------------------------------------------
  // Frequency counter — measures selected source against system clock
  // -----------------------------------------------------------------------
  logic meas_source;
  always_comb begin
    case (freq_measure_sel)
      3'h0: meas_source = clk_ext_ref;
      3'h1: meas_source = clk_ring_osc;
      3'h2: meas_source = clk_div4;
      3'h3: meas_source = clk_pll_out;
      3'h4: meas_source = clk_div16;
      default: meas_source = clk_ext_ref;
    endcase
  end

  // Edge detector for measured source (synchronizer + rising edge)
  logic meas_sync1, meas_sync2, meas_sync3, meas_rising;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      meas_sync1 <= 1'b0;
      meas_sync2 <= 1'b0;
      meas_sync3 <= 1'b0;
    end else begin
      meas_sync1 <= meas_source;
      meas_sync2 <= meas_sync1;
      meas_sync3 <= meas_sync2;
    end
  end
  assign meas_rising = meas_sync2 & ~meas_sync3;

  // Measurement FSM
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      freq_cnt            <= '0;
      freq_ref_cnt        <= '0;
      freq_result_latched <= '0;
      freq_measuring      <= 1'b0;
    end else begin
      if (host_wr && host_addr == REG_CLK_FREQ_COUNT) begin
        // Writing to freq count register triggers a new measurement
        freq_measuring <= 1'b1;
        freq_cnt       <= '0;
        freq_ref_cnt   <= '0;
      end else if (freq_measuring) begin
        freq_ref_cnt <= freq_ref_cnt + 1;
        if (meas_rising)
          freq_cnt <= freq_cnt + 1;
        if (freq_ref_cnt >= freq_ref_window - 1) begin
          freq_result_latched <= freq_cnt;
          freq_measuring      <= 1'b0;
        end
      end
    end
  end

  assign freq_count_result = freq_result_latched;

  // -----------------------------------------------------------------------
  // Read interface
  // -----------------------------------------------------------------------
  always_comb begin
    host_rdata = '0;
    case (host_addr)
      REG_CLK_MUX_CONTROL: host_rdata = {20'd0,
                                          effective_cfg.exp_clk_sel,
                                          effective_cfg.bist_clk_sel,
                                          effective_cfg.dac_clk_sel,
                                          effective_cfg.adc_clk_sel};
      REG_CLK_MUX_STATUS:  host_rdata = {28'd0, pll_locked, freq_measuring, bist_active, 1'b1};
      REG_CLK_FREQ_COUNT:  host_rdata = freq_result_latched;
      REG_CLK_FREQ_SELECT: host_rdata = {29'd0, freq_measure_sel};
      default:             host_rdata = '0;
    endcase
  end

endmodule
