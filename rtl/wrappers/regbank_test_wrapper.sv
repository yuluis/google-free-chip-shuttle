// ---------------------------------------------------------------------------
// regbank_test_wrapper.sv — Register bank read/write sanity test
// Writes known patterns to internal test registers, reads back, compares.
// ---------------------------------------------------------------------------
module regbank_test_wrapper
  import ulc_pkg::*;
(
  input  logic         clk,
  input  logic         rst_n,
  input  test_ctrl_t   ctrl,
  output test_status_t status
);

  // -----------------------------------------------------------------------
  // Internal test register file (4 x 32-bit)
  // -----------------------------------------------------------------------
  localparam int NUM_REGS    = 4;
  localparam int NUM_PATTERNS = 4;

  logic [31:0] test_regs [NUM_REGS];

  logic [31:0] patterns [NUM_PATTERNS];
  assign patterns[0] = 32'hA5A5A5A5;
  assign patterns[1] = 32'h5A5A5A5A;
  assign patterns[2] = 32'h00000000;
  assign patterns[3] = 32'hFFFFFFFF;

  // -----------------------------------------------------------------------
  // FSM
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE,
    S_WRITE,
    S_READ_CHECK,
    S_DONE
  } state_t;

  state_t state, state_next;

  logic [1:0] pat_idx;      // current pattern index (0..3)
  logic [1:0] reg_idx;      // current register index (0..3)
  logic       writing;      // 1 = write phase, 0 = read phase
  logic       all_pass;
  logic [31:0] first_expected;
  logic [31:0] first_observed;

  // -----------------------------------------------------------------------
  // FSM register
  // -----------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= S_IDLE;
    else
      state <= state_next;
  end

  // -----------------------------------------------------------------------
  // Datapath
  // -----------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pat_idx        <= '0;
      reg_idx        <= '0;
      writing        <= 1'b1;
      all_pass       <= 1'b1;
      first_expected <= '0;
      first_observed <= '0;
      for (int i = 0; i < NUM_REGS; i++)
        test_regs[i] <= '0;
    end else begin
      case (state)
        S_IDLE: begin
          pat_idx        <= '0;
          reg_idx        <= '0;
          writing        <= 1'b1;
          all_pass       <= 1'b1;
          first_expected <= '0;
          first_observed <= '0;
        end

        S_WRITE: begin
          // Write the current pattern to the current register
          test_regs[reg_idx] <= patterns[pat_idx];
          if (reg_idx == NUM_REGS[1:0] - 1) begin
            reg_idx <= '0;
            writing <= 1'b0;  // switch to read phase
          end else begin
            reg_idx <= reg_idx + 1;
          end
        end

        S_READ_CHECK: begin
          // Compare readback
          if (test_regs[reg_idx] != patterns[pat_idx]) begin
            if (all_pass) begin
              first_expected <= patterns[pat_idx];
              first_observed <= test_regs[reg_idx];
            end
            all_pass <= 1'b0;
          end

          if (reg_idx == NUM_REGS[1:0] - 1) begin
            reg_idx <= '0;
            if (pat_idx == NUM_PATTERNS[1:0] - 1) begin
              // All patterns done — go to DONE
              pat_idx <= pat_idx; // hold
            end else begin
              pat_idx <= pat_idx + 1;
              writing <= 1'b1;  // next pattern: start writing again
            end
          end else begin
            reg_idx <= reg_idx + 1;
          end
        end

        default: ;
      endcase
    end
  end

  // -----------------------------------------------------------------------
  // Next-state logic
  // -----------------------------------------------------------------------
  always_comb begin
    state_next = state;
    case (state)
      S_IDLE: begin
        if (ctrl.test_enable && ctrl.test_mode && ctrl.test_start)
          state_next = S_WRITE;
      end

      S_WRITE: begin
        if (reg_idx == NUM_REGS[1:0] - 1)
          state_next = S_READ_CHECK;
      end

      S_READ_CHECK: begin
        if (reg_idx == NUM_REGS[1:0] - 1) begin
          if (pat_idx == NUM_PATTERNS[1:0] - 1)
            state_next = S_DONE;
          else
            state_next = S_WRITE;
        end
      end

      S_DONE: begin
        // Stay in DONE until de-asserted
        if (!ctrl.test_enable)
          state_next = S_IDLE;
      end

      default: state_next = S_IDLE;
    endcase
  end

  // -----------------------------------------------------------------------
  // Output assignments
  // -----------------------------------------------------------------------
  assign status.test_done    = (state == S_DONE);
  assign status.test_pass    = (state == S_DONE) && all_pass;
  assign status.test_error   = (state == S_DONE && !all_pass) ? ERR_COMPARE_MISMATCH : ERR_NONE;
  assign status.test_result0 = first_expected;
  assign status.test_result1 = first_observed;
  assign status.test_result2 = '0;
  assign status.test_result3 = '0;

endmodule
