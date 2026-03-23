// ---------------------------------------------------------------------------
// reset_controller.sv — Global + software + local reset management
//
// Combines hardware RST_N pin with software reset (magic word) and
// local reset bits. Captures reset cause into BOOT_STATUS register.
// ---------------------------------------------------------------------------
module reset_controller
  import ulc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n_pin,      // external reset pin (active low)

  // Software reset from register bank
  input  logic        sw_reset_request,

  // Global control bits for local resets
  input  logic [31:0] global_control,

  // Combined reset outputs
  output logic        rst_n_global,   // combined global reset (active low)
  output logic        rst_sequencer,  // pulse: reset sequencer only
  output logic        rst_analog,     // pulse: reset DAC/ADC/comp
  output logic        rst_dangerous,  // pulse: reset + disarm dangerous

  // Boot status output
  output logic [31:0] boot_status
);

  // -----------------------------------------------------------------------
  // Global reset — OR of hardware pin and software reset
  // -----------------------------------------------------------------------
  logic sw_reset_sync;
  logic global_rst_n;

  // Software reset needs to be held for a few cycles
  logic [3:0] sw_reset_hold;

  always_ff @(posedge clk or negedge rst_n_pin) begin
    if (!rst_n_pin) begin
      sw_reset_hold <= '0;
      sw_reset_sync <= 1'b0;
    end else begin
      if (sw_reset_request)
        sw_reset_hold <= 4'hF;  // hold reset for 15 cycles
      else if (sw_reset_hold > 0)
        sw_reset_hold <= sw_reset_hold - 1;

      sw_reset_sync <= (sw_reset_hold > 0);
    end
  end

  assign global_rst_n = rst_n_pin & ~sw_reset_sync;
  assign rst_n_global = global_rst_n;

  // -----------------------------------------------------------------------
  // Local reset pulses (from self-clearing GLOBAL_CONTROL bits)
  // -----------------------------------------------------------------------
  assign rst_sequencer = global_control[CTRL_RESET_SEQUENCER];
  assign rst_analog    = global_control[CTRL_RESET_ANALOG];
  assign rst_dangerous = global_control[CTRL_RESET_DANGEROUS];

  // -----------------------------------------------------------------------
  // Boot status capture — latched at reset release
  // -----------------------------------------------------------------------
  logic        prev_rst_n;
  reset_cause_t reset_cause;

  always_ff @(posedge clk or negedge rst_n_pin) begin
    if (!rst_n_pin) begin
      prev_rst_n   <= 1'b0;
      reset_cause  <= RST_CAUSE_POR;  // default: power-on
    end else begin
      prev_rst_n <= global_rst_n;

      // Detect rising edge of global_rst_n (reset release)
      if (!prev_rst_n && global_rst_n) begin
        // Determine cause
        if (!rst_n_pin)
          reset_cause <= RST_CAUSE_PIN;  // won't actually reach here, but defensive
        else if (sw_reset_sync)
          reset_cause <= RST_CAUSE_SOFTWARE;
        // POR is the default set in async reset above
      end

      // If RST_N pin was asserted (but we're not in full reset),
      // capture pin cause for next release
      if (!rst_n_pin)
        reset_cause <= RST_CAUSE_PIN;
    end
  end

  // Boot status register layout:
  // [1:0]  reset_cause
  // [2]    debug_mode_at_boot (always 0 — debug not active at reset)
  // [3]    dangerous_armed_at_boot (always 0 — disarmed at reset)
  // [6:4]  clk_source_at_boot (always 000 = ext_ref)
  // [7]    strap_reserved (always 0 for v1)
  assign boot_status = {24'h0,
                        1'b0,           // [7] strap_reserved
                        3'b000,         // [6:4] clk_source = ext_ref
                        1'b0,           // [3] dangerous_armed = 0
                        1'b0,           // [2] debug_mode = 0
                        reset_cause};   // [1:0]

endmodule
