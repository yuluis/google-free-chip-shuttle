// ---------------------------------------------------------------------------
// state_snapshot.sv — Latched-on-demand state capture for bring-up debugging
//
// Assembles live state from multiple subsystems into 4 snapshot words.
// When CTRL_SNAP_CAPTURE is written, all 4 words are frozen simultaneously
// for coherent multi-register readback.
// ---------------------------------------------------------------------------
module state_snapshot
  import ulc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Trigger
  input  logic        snap_capture,  // pulse from register bank

  // Live state inputs
  input  logic [3:0]  bank_sel,
  input  logic [2:0]  adc_clk_sel,
  input  logic [2:0]  dac_clk_sel,
  input  logic [2:0]  adc_source,
  input  logic [2:0]  comp_pos_source,
  input  logic [2:0]  comp_neg_source,
  input  logic [7:0]  experiment_id,
  input  logic [4:0]  seq_state,
  input  logic [7:0]  last_error,
  input  logic [7:0]  last_block,
  input  logic        pll_locked,
  input  logic        dac_active,
  input  logic        bist_applied,
  input  logic        route_active,
  input  logic        dangerous_armed,
  input  logic        debug_mode,

  // Latched snapshot outputs (to register bank)
  output logic [31:0] snap_bank_clk,
  output logic [31:0] snap_route_exp,
  output logic [31:0] snap_seq_err,
  output logic [31:0] snap_flags
);

  // Assemble live words
  wire [31:0] live_bank_clk  = {14'h0, dac_clk_sel, adc_clk_sel, 8'h0, bank_sel};
  wire [31:0] live_route_exp = {8'h0, experiment_id, 7'h0, comp_neg_source, comp_pos_source, adc_source};
  wire [31:0] live_seq_err   = {11'h0, last_block, 3'h0, last_error[4:0], 3'h0, seq_state};
  wire [31:0] live_flags     = {26'h0, debug_mode, dangerous_armed, route_active, bist_applied, dac_active, pll_locked};

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      snap_bank_clk  <= 32'h0;
      snap_route_exp <= 32'h0;
      snap_seq_err   <= 32'h0;
      snap_flags     <= 32'h0;
    end else if (snap_capture) begin
      snap_bank_clk  <= live_bank_clk;
      snap_route_exp <= live_route_exp;
      snap_seq_err   <= live_seq_err;
      snap_flags     <= live_flags;
    end
  end

endmodule
