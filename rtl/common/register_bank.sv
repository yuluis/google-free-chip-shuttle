// ---------------------------------------------------------------------------
// register_bank.sv — v2.4 banked register file
//
// 7 banks selected via BANK_SELECT register (bank 0, offset 0x04).
// 8-bit byte-addressed offsets within each bank. All registers 32 bits.
// UART host bridge writes addr (offset within current bank) + data.
//
// Read-only registers enforce read-only. Self-clearing bits auto-clear
// after one cycle. Software reset via magic word.
// ---------------------------------------------------------------------------
module register_bank
  import ulc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Host port (from UART bridge)
  input  logic        host_wr,
  input  logic        host_rd,
  input  logic [7:0]  host_addr,     // 8-bit offset within active bank
  input  logic [31:0] host_wdata,
  output logic [31:0] host_rdata,
  output logic        host_rvalid,

  // Sequencer write-back port
  input  logic        seq_wr,
  input  logic [7:0]  seq_addr,      // always targets bank 0
  input  logic [31:0] seq_wdata,

  // --- Bank 0: Global outputs ---
  output logic [3:0]  active_bank,
  output logic [31:0] global_control,
  output logic [31:0] global_status,    // written by sequencer
  output logic [7:0]  block_select,
  output logic [7:0]  command,
  output logic        cmd_strobe,       // pulsed when COMMAND is written
  output logic [31:0] timeout_cycles,
  output logic [31:0] result       [4], // written by sequencer
  output logic [7:0]  error_code,       // written by sequencer
  output logic [31:0] pass_count,       // written by sequencer
  output logic [31:0] fail_count,       // written by sequencer
  output logic [7:0]  last_block,       // written by sequencer
  output logic [4:0]  last_state,       // written by sequencer
  output logic [31:0] log_ptr,          // written by log buffer
  output logic [31:0] log_count,        // written by log buffer
  output logic [7:0]  experiment_id,
  output logic [31:0] experiment_status, // written by sequencer
  output logic [31:0] experiment_config,
  output logic [31:0] debug_control,
  output logic [31:0] spare_pad_ctrl,

  // Snapshot inputs (active state to be latched)
  input  logic [31:0] snap_live_bank_clk,
  input  logic [31:0] snap_live_route_exp,
  input  logic [31:0] snap_live_seq_err,
  input  logic [31:0] snap_live_flags,

  // Boot status input (captured by reset controller)
  input  logic [31:0] boot_status_in,

  // --- Bank 1: Clock outputs ---
  output logic [31:0] clk_mux_control,
  input  logic [31:0] clk_mux_status,
  output logic [31:0] clk_freq_select,
  output logic [31:0] clk_freq_window,
  output logic        clk_freq_trigger,
  input  logic [31:0] clk_freq_count,
  output logic [31:0] clk_div_control,
  output logic [31:0] pll_control,
  input  logic [31:0] pll_status,
  input  logic [31:0] pll_freq_count,
  output logic [31:0] pll_lock_timeout,
  output logic [31:0] rosc_control,
  output logic [31:0] dbg_clk_select,

  // --- Bank 2: Analog outputs ---
  output logic [31:0] aroute_control,
  input  logic [31:0] aroute_status,
  output logic [31:0] aroute_adc_src,
  output logic [31:0] aroute_comp_src,
  output logic [31:0] dac_control,
  output logic [31:0] dac_code,
  input  logic [31:0] dac_status,
  input  logic [31:0] dac_update_count,
  output logic [31:0] dac_alt_code,
  output logic [31:0] dac_clk_div,
  output logic [31:0] adc_control,
  input  logic [31:0] adc_result,
  input  logic [31:0] adc_min_max,
  input  logic [31:0] adc_sample_count,
  output logic [31:0] comp_control,
  input  logic [31:0] comp_status,
  output logic [31:0] comp_sweep_cfg,
  input  logic [31:0] comp_trip_result,

  // --- Bank 3: BIST outputs ---
  output logic [31:0] bist_control,
  output logic        bist_cmd_strobe,
  output logic [31:0] bist_chain_sel,
  output logic [31:0] bist_shift_data,
  input  logic [31:0] bist_latch_status,
  input  logic [31:0] bist_readback,
  input  logic [31:0] bist_apply_status,

  // --- Bank 4: Security outputs ---
  output logic [31:0] trng_control,
  input  logic [31:0] trng_status,
  input  logic [31:0] trng_bit_count,
  input  logic [31:0] trng_ones_count,
  input  logic [31:0] trng_rep_max,
  output logic [31:0] puf_control,
  input  logic [31:0] puf_status,
  input  logic [31:0] puf_resp [4],
  input  logic [31:0] puf_mismatch,

  // --- Bank 5: Log outputs ---
  output logic [31:0] log_read_index,
  input  logic [31:0] log_entry_block,
  input  logic [31:0] log_entry_t_start,
  input  logic [31:0] log_entry_t_end,
  input  logic [31:0] log_entry_r0,
  input  logic [31:0] log_entry_r1,
  input  logic [31:0] sram_bist_status,

  // --- Bank 0xA: Dangerous outputs ---
  output logic        dangerous_armed,
  output logic [31:0] nvm_address,
  output logic [31:0] nvm_write_data,
  input  logic [31:0] nvm_read_data,
  output logic [31:0] nvm_command,
  output logic        nvm_cmd_strobe,
  input  logic [31:0] nvm_status,

  // Software reset request (active one cycle)
  output logic        sw_reset_request
);

  // -----------------------------------------------------------------------
  // Bank select register
  // -----------------------------------------------------------------------
  logic [3:0] bank_sel;
  assign active_bank = bank_sel;

  // -----------------------------------------------------------------------
  // Snapshot latches
  // -----------------------------------------------------------------------
  logic [31:0] snap_bank_clk, snap_route_exp, snap_seq_err, snap_flags;
  logic        snap_capture_pulse;

  // -----------------------------------------------------------------------
  // Dangerous arm logic — requires magic word
  // -----------------------------------------------------------------------
  localparam logic [31:0] ARM_MAGIC = 32'h4152_4D21;  // 'ARM!'
  logic dangerous_arm_reg;
  assign dangerous_armed = dangerous_arm_reg;

  // -----------------------------------------------------------------------
  // Self-clearing bits
  // -----------------------------------------------------------------------
  logic cmd_strobe_reg;
  logic bist_cmd_strobe_reg;
  logic nvm_cmd_strobe_reg;
  logic clk_freq_trigger_reg;
  logic sw_reset_reg;

  assign cmd_strobe       = cmd_strobe_reg;
  assign bist_cmd_strobe  = bist_cmd_strobe_reg;
  assign nvm_cmd_strobe   = nvm_cmd_strobe_reg;
  assign clk_freq_trigger = clk_freq_trigger_reg;
  assign sw_reset_request = sw_reset_reg;

  // -----------------------------------------------------------------------
  // Write logic
  // -----------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Bank 0 defaults
      bank_sel          <= 4'h0;
      global_control    <= 32'h0;
      global_status     <= 32'h0;
      error_code        <= 8'h0;
      pass_count        <= 32'h0;
      fail_count        <= 32'h0;
      last_block        <= 8'h0;
      last_state        <= 5'h0;
      log_ptr           <= 32'h0;
      log_count         <= 32'h0;
      experiment_status <= 32'h0;
      for (int i = 0; i < 4; i++) result[i] <= 32'h0;
      block_select      <= 8'h0;
      command           <= 8'h0;
      timeout_cycles    <= 32'd1_000_000;
      experiment_id     <= 8'h0;
      experiment_config <= 32'h0;
      debug_control     <= 32'h0;
      spare_pad_ctrl    <= 32'h0;
      // Bank 1 defaults
      clk_mux_control   <= 32'h0;  // all ext_ref
      clk_freq_select   <= 32'h0;
      clk_freq_window   <= 32'd10_000;
      clk_div_control   <= 32'h0;
      pll_control        <= 32'h0;  // disabled
      pll_lock_timeout   <= 32'd500_000;
      rosc_control       <= 32'h0;  // auto-follow
      dbg_clk_select     <= 32'h0;  // disabled
      // Bank 2 defaults
      aroute_control     <= 32'h0;  // disconnected
      aroute_adc_src     <= 32'h0;
      aroute_comp_src    <= 32'h0;
      dac_control        <= 32'h0;  // disabled
      dac_code           <= 32'h0;
      dac_alt_code       <= 32'h0;
      dac_clk_div        <= 32'd10;
      adc_control        <= 32'h0;
      comp_control       <= 32'h0;
      comp_sweep_cfg     <= 32'h0;
      // Bank 3 defaults
      bist_control       <= 32'h0;
      bist_chain_sel     <= 32'h0;
      bist_shift_data    <= 32'h0;
      // Bank 4 defaults
      trng_control       <= 32'h0;
      puf_control        <= 32'h0;
      // Bank 5 defaults
      log_read_index     <= 32'h0;
      // Bank 0xA defaults
      dangerous_arm_reg  <= 1'b0;
      nvm_address        <= 32'h0;
      nvm_write_data     <= 32'h0;
      nvm_command        <= 32'h0;
      // Self-clearing
      cmd_strobe_reg        <= 1'b0;
      bist_cmd_strobe_reg   <= 1'b0;
      nvm_cmd_strobe_reg    <= 1'b0;
      clk_freq_trigger_reg  <= 1'b0;
      sw_reset_reg          <= 1'b0;
      snap_capture_pulse    <= 1'b0;
      // Snapshots
      snap_bank_clk  <= 32'h0;
      snap_route_exp <= 32'h0;
      snap_seq_err   <= 32'h0;
      snap_flags     <= 32'h0;
    end else begin
      // Auto-clear self-clearing bits every cycle
      cmd_strobe_reg       <= 1'b0;
      bist_cmd_strobe_reg  <= 1'b0;
      nvm_cmd_strobe_reg   <= 1'b0;
      clk_freq_trigger_reg <= 1'b0;
      sw_reset_reg         <= 1'b0;
      snap_capture_pulse   <= 1'b0;

      // Self-clearing control bits in GLOBAL_CONTROL
      if (global_control[CTRL_SOFTWARE_RESET])
        global_control[CTRL_SOFTWARE_RESET] <= 1'b0;
      if (global_control[CTRL_RESET_SEQUENCER])
        global_control[CTRL_RESET_SEQUENCER] <= 1'b0;
      if (global_control[CTRL_RESET_ANALOG])
        global_control[CTRL_RESET_ANALOG] <= 1'b0;
      if (global_control[CTRL_RESET_DANGEROUS])
        global_control[CTRL_RESET_DANGEROUS] <= 1'b0;
      if (global_control[CTRL_SNAP_CAPTURE]) begin
        global_control[CTRL_SNAP_CAPTURE] <= 1'b0;
        snap_capture_pulse <= 1'b1;
      end

      // Snapshot capture
      if (snap_capture_pulse) begin
        snap_bank_clk  <= snap_live_bank_clk;
        snap_route_exp <= snap_live_route_exp;
        snap_seq_err   <= snap_live_seq_err;
        snap_flags     <= snap_live_flags;
      end

      // Software reset
      if (global_control[CTRL_SOFTWARE_RESET])
        sw_reset_reg <= 1'b1;

      // ---- Host writes (bank-switched) ----
      if (host_wr) begin
        case (bank_sel)
          // ==== Bank 0: Global ====
          BANK_GLOBAL: begin
            case (host_addr)
              8'h04: bank_sel          <= host_wdata[3:0];
              8'h08: global_control    <= host_wdata;
              8'h10: block_select      <= host_wdata[7:0];
              8'h14: begin command     <= host_wdata[7:0]; cmd_strobe_reg <= 1'b1; end
              8'h18: timeout_cycles    <= host_wdata;
              8'h50: experiment_id     <= host_wdata[7:0];
              8'h58: experiment_config <= host_wdata;
              8'h5C: begin  // SOFTWARE_RESET — check magic
                if (host_wdata == 32'hDEAD)
                  sw_reset_reg <= 1'b1;
              end
              8'h70: debug_control     <= host_wdata;
              8'h74: spare_pad_ctrl    <= host_wdata;
              default: ; // read-only or unused — ignore writes
            endcase
          end

          // ==== Bank 1: Clock ====
          BANK_CLOCK: begin
            case (host_addr)
              8'h00: clk_mux_control  <= host_wdata;
              8'h08: clk_freq_trigger_reg <= 1'b1;  // write triggers measurement
              8'h0C: clk_freq_select  <= host_wdata;
              8'h10: clk_freq_window  <= host_wdata;
              8'h14: clk_div_control  <= host_wdata;
              8'h20: pll_control      <= host_wdata;
              8'h2C: pll_lock_timeout <= host_wdata;
              8'h30: rosc_control     <= host_wdata;
              8'h34: dbg_clk_select   <= host_wdata;
              default: ;
            endcase
          end

          // ==== Bank 2: Analog ====
          BANK_ANALOG: begin
            case (host_addr)
              8'h00: aroute_control   <= host_wdata;
              8'h08: aroute_adc_src   <= host_wdata;
              8'h0C: aroute_comp_src  <= host_wdata;
              8'h20: dac_control      <= host_wdata;
              8'h24: dac_code         <= host_wdata;
              8'h30: dac_alt_code     <= host_wdata;
              8'h34: dac_clk_div      <= host_wdata;
              8'h40: adc_control      <= host_wdata;
              8'h60: comp_control     <= host_wdata;
              8'h68: comp_sweep_cfg   <= host_wdata;
              default: ;
            endcase
          end

          // ==== Bank 3: BIST ====
          BANK_BIST: begin
            case (host_addr)
              8'h00: begin bist_control <= host_wdata; bist_cmd_strobe_reg <= 1'b1; end
              8'h04: bist_chain_sel   <= host_wdata;
              8'h08: bist_shift_data  <= host_wdata;
              default: ;
            endcase
          end

          // ==== Bank 4: Security ====
          BANK_SECURITY: begin
            case (host_addr)
              8'h00: trng_control     <= host_wdata;
              8'h20: puf_control      <= host_wdata;
              default: ;
            endcase
          end

          // ==== Bank 5: Log ====
          BANK_LOG: begin
            case (host_addr)
              8'h00: log_read_index   <= host_wdata;
              default: ;
            endcase
          end

          // ==== Bank 0xA: Dangerous ====
          BANK_DANGEROUS: begin
            case (host_addr)
              8'h00: dangerous_arm_reg <= (host_wdata == ARM_MAGIC);
              8'h04: nvm_address      <= host_wdata;
              8'h08: nvm_write_data   <= host_wdata;
              8'h10: begin nvm_command <= host_wdata; nvm_cmd_strobe_reg <= 1'b1; end
              default: ;
            endcase
          end

          default: ; // invalid bank — ignore
        endcase
      end

      // ---- Sequencer write-back (always bank 0) ----
      if (seq_wr) begin
        case (seq_addr)
          8'h0C: global_status    <= seq_wdata;  // GLOBAL_STATUS
          8'h1C: result[0]        <= seq_wdata;
          8'h20: result[1]        <= seq_wdata;
          8'h24: result[2]        <= seq_wdata;
          8'h28: result[3]        <= seq_wdata;
          8'h2C: error_code       <= seq_wdata[7:0];
          8'h30: pass_count       <= seq_wdata;
          8'h34: fail_count       <= seq_wdata;
          8'h38: last_block       <= seq_wdata[7:0];
          8'h3C: last_state       <= seq_wdata[4:0];
          8'h40: log_ptr          <= seq_wdata;
          8'h44: log_count        <= seq_wdata;
          8'h50: experiment_id    <= seq_wdata[7:0];
          8'h54: experiment_status <= seq_wdata;
          default: ;
        endcase
      end

      // Reset dangerous arm if dangerous zone is reset
      if (global_control[CTRL_RESET_DANGEROUS])
        dangerous_arm_reg <= 1'b0;
    end
  end

  // -----------------------------------------------------------------------
  // Read logic (combinational — active bank determines output)
  // -----------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      host_rdata  <= 32'h0;
      host_rvalid <= 1'b0;
    end else begin
      host_rvalid <= host_rd;
      if (host_rd) begin
        case (bank_sel)
          BANK_GLOBAL: begin
            case (host_addr)
              8'h00: host_rdata <= CHIP_ID_VALUE;
              8'h04: host_rdata <= {28'h0, bank_sel};
              8'h08: host_rdata <= global_control;
              8'h0C: host_rdata <= global_status;
              8'h10: host_rdata <= {24'h0, block_select};
              8'h14: host_rdata <= {24'h0, command};
              8'h18: host_rdata <= timeout_cycles;
              8'h1C: host_rdata <= result[0];
              8'h20: host_rdata <= result[1];
              8'h24: host_rdata <= result[2];
              8'h28: host_rdata <= result[3];
              8'h2C: host_rdata <= {24'h0, error_code};
              8'h30: host_rdata <= pass_count;
              8'h34: host_rdata <= fail_count;
              8'h38: host_rdata <= {24'h0, last_block};
              8'h3C: host_rdata <= {27'h0, last_state};
              8'h40: host_rdata <= log_ptr;
              8'h44: host_rdata <= log_count;
              8'h48: host_rdata <= CHIP_REV_VALUE;
              8'h50: host_rdata <= {24'h0, experiment_id};
              8'h54: host_rdata <= experiment_status;
              8'h58: host_rdata <= experiment_config;
              8'h5C: host_rdata <= 32'h0;  // SOFTWARE_RESET: write-only
              8'h60: host_rdata <= snap_bank_clk;
              8'h64: host_rdata <= snap_route_exp;
              8'h68: host_rdata <= snap_seq_err;
              8'h6C: host_rdata <= snap_flags;
              8'h70: host_rdata <= debug_control;
              8'h74: host_rdata <= spare_pad_ctrl;
              8'h78: host_rdata <= boot_status_in;
              default: host_rdata <= 32'h0;
            endcase
          end

          BANK_CLOCK: begin
            case (host_addr)
              8'h00: host_rdata <= clk_mux_control;
              8'h04: host_rdata <= clk_mux_status;
              8'h08: host_rdata <= clk_freq_count;
              8'h0C: host_rdata <= clk_freq_select;
              8'h10: host_rdata <= clk_freq_window;
              8'h14: host_rdata <= clk_div_control;
              8'h20: host_rdata <= pll_control;
              8'h24: host_rdata <= pll_status;
              8'h28: host_rdata <= pll_freq_count;
              8'h2C: host_rdata <= pll_lock_timeout;
              8'h30: host_rdata <= rosc_control;
              8'h34: host_rdata <= dbg_clk_select;
              default: host_rdata <= 32'h0;
            endcase
          end

          BANK_ANALOG: begin
            case (host_addr)
              8'h00: host_rdata <= aroute_control;
              8'h04: host_rdata <= aroute_status;
              8'h08: host_rdata <= aroute_adc_src;
              8'h0C: host_rdata <= aroute_comp_src;
              8'h20: host_rdata <= dac_control;
              8'h24: host_rdata <= dac_code;
              8'h28: host_rdata <= dac_status;
              8'h2C: host_rdata <= dac_update_count;
              8'h30: host_rdata <= dac_alt_code;
              8'h34: host_rdata <= dac_clk_div;
              8'h40: host_rdata <= adc_control;
              8'h44: host_rdata <= adc_result;
              8'h48: host_rdata <= adc_min_max;
              8'h4C: host_rdata <= adc_sample_count;
              8'h60: host_rdata <= comp_control;
              8'h64: host_rdata <= comp_status;
              8'h68: host_rdata <= comp_sweep_cfg;
              8'h6C: host_rdata <= comp_trip_result;
              default: host_rdata <= 32'h0;
            endcase
          end

          BANK_BIST: begin
            case (host_addr)
              8'h00: host_rdata <= bist_control;
              8'h04: host_rdata <= bist_chain_sel;
              8'h08: host_rdata <= bist_shift_data;
              8'h0C: host_rdata <= bist_latch_status;
              8'h10: host_rdata <= bist_readback;
              8'h14: host_rdata <= bist_apply_status;
              default: host_rdata <= 32'h0;
            endcase
          end

          BANK_SECURITY: begin
            case (host_addr)
              8'h00: host_rdata <= trng_control;
              8'h04: host_rdata <= trng_status;
              8'h08: host_rdata <= trng_bit_count;
              8'h0C: host_rdata <= trng_ones_count;
              8'h10: host_rdata <= trng_rep_max;
              8'h20: host_rdata <= puf_control;
              8'h24: host_rdata <= puf_status;
              8'h28: host_rdata <= puf_resp[0];
              8'h2C: host_rdata <= puf_resp[1];
              8'h30: host_rdata <= puf_resp[2];
              8'h34: host_rdata <= puf_resp[3];
              8'h38: host_rdata <= puf_mismatch;
              default: host_rdata <= 32'h0;
            endcase
          end

          BANK_LOG: begin
            case (host_addr)
              8'h00: host_rdata <= log_read_index;
              8'h04: host_rdata <= log_entry_block;
              8'h08: host_rdata <= log_entry_t_start;
              8'h0C: host_rdata <= log_entry_t_end;
              8'h10: host_rdata <= log_entry_r0;
              8'h14: host_rdata <= log_entry_r1;
              8'h40: host_rdata <= sram_bist_status;
              default: host_rdata <= 32'h0;
            endcase
          end

          BANK_DANGEROUS: begin
            case (host_addr)
              8'h00: host_rdata <= {31'h0, dangerous_arm_reg};
              8'h04: host_rdata <= nvm_address;
              8'h08: host_rdata <= nvm_write_data;
              8'h0C: host_rdata <= nvm_read_data;
              8'h10: host_rdata <= nvm_command;
              8'h14: host_rdata <= nvm_status;
              default: host_rdata <= 32'h0;
            endcase
          end

          default: host_rdata <= 32'h0;
        endcase
      end
    end
  end

endmodule
