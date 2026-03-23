// ---------------------------------------------------------------------------
// bist_pattern_engine.sv — Serial-pattern BIST control fabric
//
// Provides shift-register / pattern-driven control of muxes, test enables,
// and route configurations. Reduces pad count by allowing compact serial
// programming of large mux fabrics.
//
// Architecture:
//   - Multiple independent chains (analog mux, clock mux, test enable, etc.)
//   - Each chain has: shift register, latch register, capture register
//   - Host writes shift data word-at-a-time, issues commands
//   - Commands: SHIFT_IN, LATCH, APPLY, CAPTURE, SHIFT_OUT, CLEAR
//   - Readback of latched and captured patterns
//   - Optional checksum for pattern integrity
//
// This is an adjunct to normal register-based control, not a replacement.
// Both register writes and BIST patterns can control the same targets;
// BIST patterns take priority when BIST_ENABLE is asserted.
// ---------------------------------------------------------------------------
module bist_pattern_engine
  import ulc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Host register interface
  input  logic        host_wr,
  input  logic [7:0]  host_addr,
  input  logic [31:0] host_wdata,
  output logic [31:0] host_rdata,

  // Global control
  input  logic        bist_enable,  // CTRL_BIST_ENABLE from global control

  // Chain outputs — active pattern applied to targets
  output logic [BIST_CHAIN_WIDTH-1:0] chain_analog_mux,
  output logic [BIST_CHAIN_WIDTH-1:0] chain_clock_mux,
  output logic [BIST_CHAIN_WIDTH-1:0] chain_test_enable,
  output logic [BIST_CHAIN_WIDTH-1:0] chain_route_config,
  output logic [BIST_CHAIN_WIDTH-1:0] chain_fault_inject,

  // Status
  output logic        patterns_loaded,    // at least one chain has been latched
  output logic        patterns_applied    // chains are being driven to targets
);

  // -----------------------------------------------------------------------
  // Per-chain storage
  // -----------------------------------------------------------------------
  logic [BIST_CHAIN_WIDTH-1:0] shift_reg   [BIST_NUM_CHAINS];
  logic [BIST_CHAIN_WIDTH-1:0] latch_reg   [BIST_NUM_CHAINS];
  logic [BIST_CHAIN_WIDTH-1:0] capture_reg [BIST_NUM_CHAINS];

  // Control registers
  bist_cmd_t                   cmd_reg;
  bist_chain_t                 chain_sel;
  logic                        apply_active;
  logic [BIST_NUM_CHAINS-1:0]  chain_latched;  // which chains have been latched

  // Shift position counter (for multi-word shifts)
  logic [4:0]                  shift_pos;  // bit position for next shift

  // Checksum
  logic [31:0]                 checksum;

  // -----------------------------------------------------------------------
  // Command execution
  // -----------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cmd_reg       <= BIST_CMD_NOP;
      chain_sel     <= CHAIN_ANALOG_MUX;
      apply_active  <= 1'b0;
      chain_latched <= '0;
      shift_pos     <= '0;
      checksum      <= '0;
      for (int i = 0; i < BIST_NUM_CHAINS; i++) begin
        shift_reg[i]   <= '0;
        latch_reg[i]   <= '0;
        capture_reg[i] <= '0;
      end
    end else begin
      cmd_reg <= BIST_CMD_NOP;  // auto-clear command

      if (host_wr) begin
        case (host_addr)
          REG_BIST_CONTROL: begin
            cmd_reg <= bist_cmd_t'(host_wdata[2:0]);

            case (bist_cmd_t'(host_wdata[2:0]))
              BIST_CMD_SHIFT_IN: begin
                // Shift data is written separately via REG_BIST_SHIFT_DATA
                // This command triggers the shift-in of the data already staged
              end

              BIST_CMD_LATCH: begin
                // Copy shift register to latch register for selected chain
                latch_reg[chain_sel] <= shift_reg[chain_sel];
                chain_latched[chain_sel] <= 1'b1;
                checksum <= checksum ^ shift_reg[chain_sel];
              end

              BIST_CMD_APPLY: begin
                // Drive latched patterns to target outputs
                apply_active <= 1'b1;
              end

              BIST_CMD_CAPTURE: begin
                // Snapshot current target state into capture register
                // (For readback of actual mux state)
                capture_reg[chain_sel] <= latch_reg[chain_sel];
              end

              BIST_CMD_SHIFT_OUT: begin
                // Prepare capture register for readback via SHIFT_DATA
                shift_reg[chain_sel] <= capture_reg[chain_sel];
                shift_pos <= '0;
              end

              BIST_CMD_CLEAR: begin
                // Clear all chains to safe defaults
                apply_active  <= 1'b0;
                chain_latched <= '0;
                checksum      <= '0;
                for (int i = 0; i < BIST_NUM_CHAINS; i++) begin
                  shift_reg[i]   <= '0;
                  latch_reg[i]   <= '0;
                  capture_reg[i] <= '0;
                end
              end

              default: ;
            endcase
          end

          REG_BIST_CHAIN_SEL: begin
            chain_sel <= bist_chain_t'(host_wdata[2:0]);
            shift_pos <= '0;
          end

          REG_BIST_SHIFT_DATA: begin
            // Load 32-bit word into shift register for selected chain
            shift_reg[chain_sel] <= host_wdata[BIST_CHAIN_WIDTH-1:0];
          end

          default: ;
        endcase
      end

      // Disable apply when BIST is disabled globally
      if (!bist_enable)
        apply_active <= 1'b0;
    end
  end

  // -----------------------------------------------------------------------
  // Read interface
  // -----------------------------------------------------------------------
  always_comb begin
    host_rdata = '0;
    case (host_addr)
      REG_BIST_CONTROL:    host_rdata = {29'd0, apply_active, patterns_loaded, patterns_applied};
      REG_BIST_CHAIN_SEL:  host_rdata = {29'd0, chain_sel};
      REG_BIST_SHIFT_DATA: host_rdata = {{(32-BIST_CHAIN_WIDTH){1'b0}}, shift_reg[chain_sel]};
      REG_BIST_LATCH_STATUS: host_rdata = {27'd0, chain_latched};
      default:             host_rdata = '0;
    endcase
  end

  // -----------------------------------------------------------------------
  // Chain outputs — drive latched patterns when applied, else zeros
  // -----------------------------------------------------------------------
  assign chain_analog_mux  = (apply_active && bist_enable) ? latch_reg[CHAIN_ANALOG_MUX]  : '0;
  assign chain_clock_mux   = (apply_active && bist_enable) ? latch_reg[CHAIN_CLOCK_MUX]   : '0;
  assign chain_test_enable = (apply_active && bist_enable) ? latch_reg[CHAIN_TEST_ENABLE]  : '0;
  assign chain_route_config= (apply_active && bist_enable) ? latch_reg[CHAIN_ROUTE_CONFIG] : '0;
  assign chain_fault_inject= (apply_active && bist_enable) ? latch_reg[CHAIN_FAULT_INJECT] : '0;

  // -----------------------------------------------------------------------
  // Status
  // -----------------------------------------------------------------------
  assign patterns_loaded  = |chain_latched;
  assign patterns_applied = apply_active && bist_enable;

endmodule
