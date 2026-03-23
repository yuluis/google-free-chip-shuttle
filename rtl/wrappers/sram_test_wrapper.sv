// ---------------------------------------------------------------------------
// sram_test_wrapper.sv — SRAM built-in self-test (BIST)
// Runs four data patterns across all addresses: write-all then read-all.
// ---------------------------------------------------------------------------
module sram_test_wrapper
  import ulc_pkg::*;
#(
  parameter int ADDR_WIDTH = 10,
  parameter int DATA_WIDTH = 32
)(
  input  logic                  clk,
  input  logic                  rst_n,
  input  test_ctrl_t            ctrl,
  output test_status_t          status,
  // SRAM interface
  output logic [ADDR_WIDTH-1:0] sram_addr,
  output logic [DATA_WIDTH-1:0] sram_wdata,
  input  logic [DATA_WIDTH-1:0] sram_rdata,
  output logic                  sram_we,
  output logic                  sram_en
);

  // -----------------------------------------------------------------------
  // Test patterns
  // -----------------------------------------------------------------------
  localparam int NUM_PATTERNS = 4;
  logic [DATA_WIDTH-1:0] patterns [NUM_PATTERNS];
  assign patterns[0] = {DATA_WIDTH{1'b0}};          // all-zeros
  assign patterns[1] = {DATA_WIDTH{1'b1}};          // all-ones
  assign patterns[2] = 32'hAAAAAAAA;                 // checkerboard
  assign patterns[3] = 32'h55555555;                 // inverse checkerboard

  localparam logic [ADDR_WIDTH-1:0] MAX_ADDR = {ADDR_WIDTH{1'b1}};

  // -----------------------------------------------------------------------
  // FSM
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE,
    S_WRITE,
    S_READ,
    S_CHECK,
    S_DONE
  } state_t;

  state_t state, state_next;

  logic [ADDR_WIDTH-1:0] addr_cnt;
  logic [1:0]            pat_idx;
  logic [31:0]           fail_addr;
  logic [31:0]           fail_expected;
  logic [31:0]           fail_actual;
  logic [31:0]           patterns_done;
  logic                  failed;
  logic                  read_valid;   // rdata valid one cycle after read

  // -----------------------------------------------------------------------
  // State register
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
      addr_cnt       <= '0;
      pat_idx        <= '0;
      fail_addr      <= '0;
      fail_expected  <= '0;
      fail_actual    <= '0;
      patterns_done  <= '0;
      failed         <= 1'b0;
      read_valid     <= 1'b0;
    end else begin
      read_valid <= 1'b0;

      case (state)
        S_IDLE: begin
          addr_cnt      <= '0;
          pat_idx       <= '0;
          fail_addr     <= '0;
          fail_expected <= '0;
          fail_actual   <= '0;
          patterns_done <= '0;
          failed        <= 1'b0;
        end

        S_WRITE: begin
          if (addr_cnt == MAX_ADDR) begin
            addr_cnt <= '0;
          end else begin
            addr_cnt <= addr_cnt + 1;
          end
        end

        S_READ: begin
          read_valid <= 1'b1;
          if (addr_cnt == MAX_ADDR) begin
            addr_cnt <= '0;
          end else begin
            addr_cnt <= addr_cnt + 1;
          end
        end

        S_CHECK: begin
          // Check comes one cycle after the last read address
          // The comparison is done in the CHECK state using read_valid
          // Actually we pipeline: read_valid triggers comparison in READ
        end

        default: ;
      endcase
    end
  end

  // -----------------------------------------------------------------------
  // Read comparison (pipelined — check previous cycle's read)
  // -----------------------------------------------------------------------
  logic [ADDR_WIDTH-1:0] check_addr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      check_addr <= '0;
    end else if (state == S_READ) begin
      check_addr <= addr_cnt;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // reset handled above
    end else if (read_valid && (state == S_READ || state == S_CHECK)) begin
      if (sram_rdata != patterns[pat_idx]) begin
        if (!failed) begin
          fail_addr     <= {{(32-ADDR_WIDTH){1'b0}}, check_addr};
          fail_expected <= patterns[pat_idx];
          fail_actual   <= sram_rdata;
        end
        failed <= 1'b1;
      end
    end
  end

  // Track patterns completed
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // handled above
    end else if (state == S_CHECK) begin
      patterns_done <= {30'd0, pat_idx} + 32'd1;
      if (pat_idx < NUM_PATTERNS[1:0] - 1)
        pat_idx <= pat_idx + 1;
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
        if (addr_cnt == MAX_ADDR)
          state_next = S_READ;
      end

      S_READ: begin
        if (addr_cnt == MAX_ADDR)
          state_next = S_CHECK;
      end

      S_CHECK: begin
        // One-cycle state to absorb last read comparison
        if (pat_idx < NUM_PATTERNS[1:0] - 1)
          state_next = S_WRITE;
        else
          state_next = S_DONE;
      end

      S_DONE: begin
        if (!ctrl.test_enable)
          state_next = S_IDLE;
      end

      default: state_next = S_IDLE;
    endcase
  end

  // -----------------------------------------------------------------------
  // SRAM port drives
  // -----------------------------------------------------------------------
  assign sram_en    = (state == S_WRITE) || (state == S_READ);
  assign sram_we    = (state == S_WRITE);
  assign sram_addr  = addr_cnt;
  assign sram_wdata = patterns[pat_idx];

  // -----------------------------------------------------------------------
  // Output assignments
  // -----------------------------------------------------------------------
  assign status.test_done    = (state == S_DONE);
  assign status.test_pass    = (state == S_DONE) && !failed;
  assign status.test_error   = (state == S_DONE && failed) ? ERR_COMPARE_MISMATCH : ERR_NONE;
  assign status.test_result0 = fail_addr;
  assign status.test_result1 = fail_expected;
  assign status.test_result2 = fail_actual;
  assign status.test_result3 = patterns_done;

endmodule
