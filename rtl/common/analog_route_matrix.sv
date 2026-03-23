// ---------------------------------------------------------------------------
// analog_route_matrix.sv — Analog test/loopback switch matrix
//
// Routes analog signals between internal blocks (DAC, ADC, comparator,
// reference ladder, ring osc monitor) and external analog pins.
//
// Safe default: all routes disconnected.
// Contention prevention: only one source per destination at a time.
// Controllable via registers or BIST serial-pattern chain.
// ---------------------------------------------------------------------------
module analog_route_matrix
  import ulc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Host register interface
  input  logic        host_wr,
  input  logic [7:0]  host_addr,
  input  logic [31:0] host_wdata,
  output logic [31:0] host_rdata,

  // BIST override
  input  logic [BIST_CHAIN_WIDTH-1:0] bist_analog_chain,
  input  logic        bist_active,

  // Analog source signals (active-high enable muxing)
  // In real silicon these would be transmission-gate switches;
  // in RTL we model as select signals driving analog mux controls
  output analog_source_t adc_input_sel,
  output analog_source_t comp_pos_sel,
  output analog_source_t comp_neg_sel,
  output logic           dac_to_ext_enable,

  // Status
  output analog_route_cfg_t active_route,
  output logic              route_contention,  // flagged if invalid combo detected
  output logic              route_active        // any non-disconnected route
);

  // -----------------------------------------------------------------------
  // Configuration register
  // -----------------------------------------------------------------------
  analog_route_cfg_t cfg_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Safe default: everything disconnected
      cfg_reg.adc_source      <= ASRC_DISCONNECTED;
      cfg_reg.comp_pos_source <= ASRC_DISCONNECTED;
      cfg_reg.comp_neg_source <= ASRC_DISCONNECTED;
      cfg_reg.dac_to_ext_pin  <= 1'b0;
    end else if (host_wr) begin
      case (host_addr)
        REG_AROUTE_CONTROL: begin
          cfg_reg.adc_source      <= analog_source_t'(host_wdata[2:0]);
          cfg_reg.comp_pos_source <= analog_source_t'(host_wdata[5:3]);
          cfg_reg.comp_neg_source <= analog_source_t'(host_wdata[8:6]);
          cfg_reg.dac_to_ext_pin  <= host_wdata[12];
        end
        REG_AROUTE_ADC_SRC:  cfg_reg.adc_source      <= analog_source_t'(host_wdata[2:0]);
        REG_AROUTE_COMP_SRC: begin
          cfg_reg.comp_pos_source <= analog_source_t'(host_wdata[2:0]);
          cfg_reg.comp_neg_source <= analog_source_t'(host_wdata[5:3]);
        end
        default: ;
      endcase
    end
  end

  // -----------------------------------------------------------------------
  // BIST override — use BIST chain bits if active
  // Chain bit mapping:
  //   [2:0]   = ADC source
  //   [5:3]   = Comp+ source
  //   [8:6]   = Comp- source
  //   [12]    = DAC to ext pin
  // -----------------------------------------------------------------------
  analog_route_cfg_t effective_cfg;

  always_comb begin
    if (bist_active && |bist_analog_chain) begin
      effective_cfg.adc_source      = analog_source_t'(bist_analog_chain[2:0]);
      effective_cfg.comp_pos_source = analog_source_t'(bist_analog_chain[5:3]);
      effective_cfg.comp_neg_source = analog_source_t'(bist_analog_chain[8:6]);
      effective_cfg.dac_to_ext_pin  = bist_analog_chain[12];
    end else begin
      effective_cfg = cfg_reg;
    end
  end

  // -----------------------------------------------------------------------
  // Contention detection
  // Rule: Comp+ and Comp- should not be the same source (unless disconnected)
  // Rule: DAC driving ext pin AND being routed to ADC simultaneously is valid
  //       (DAC can fan out) but flagged as informational
  // -----------------------------------------------------------------------
  logic contention_detect;

  always_comb begin
    contention_detect = 1'b0;

    // Comp+ and Comp- same non-disconnected source = contention
    if (effective_cfg.comp_pos_source != ASRC_DISCONNECTED &&
        effective_cfg.comp_pos_source == effective_cfg.comp_neg_source)
      contention_detect = 1'b1;
  end

  // -----------------------------------------------------------------------
  // Output assignments
  // -----------------------------------------------------------------------
  assign adc_input_sel    = effective_cfg.adc_source;
  assign comp_pos_sel     = effective_cfg.comp_pos_source;
  assign comp_neg_sel     = effective_cfg.comp_neg_source;
  assign dac_to_ext_enable = effective_cfg.dac_to_ext_pin;

  assign active_route     = effective_cfg;
  assign route_contention = contention_detect;
  assign route_active     = (effective_cfg.adc_source      != ASRC_DISCONNECTED) ||
                            (effective_cfg.comp_pos_source  != ASRC_DISCONNECTED) ||
                            (effective_cfg.comp_neg_source  != ASRC_DISCONNECTED) ||
                            effective_cfg.dac_to_ext_pin;

  // -----------------------------------------------------------------------
  // Read interface
  // -----------------------------------------------------------------------
  always_comb begin
    host_rdata = '0;
    case (host_addr)
      REG_AROUTE_CONTROL: host_rdata = {19'd0,
                                        effective_cfg.dac_to_ext_pin,
                                        3'd0,
                                        effective_cfg.comp_neg_source,
                                        effective_cfg.comp_pos_source,
                                        effective_cfg.adc_source};
      REG_AROUTE_STATUS:  host_rdata = {29'd0, contention_detect, route_active, bist_active};
      REG_AROUTE_ADC_SRC: host_rdata = {29'd0, effective_cfg.adc_source};
      REG_AROUTE_COMP_SRC: host_rdata = {26'd0,
                                          effective_cfg.comp_neg_source,
                                          effective_cfg.comp_pos_source};
      default:            host_rdata = '0;
    endcase
  end

endmodule
