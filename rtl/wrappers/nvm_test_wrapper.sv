// NVM / OTP self-test wrapper (DANGEROUS block)
// This wrapper will refuse to operate unless the dangerous_armed input
// is asserted — immediately failing with ERR_UNSAFE_DENIED otherwise.
// When armed: reads the pre-value at a test address, programs a known
// pattern, reads back the post-value, and reports all three.
module nvm_test_wrapper
  import ulc_pkg::*;
#(
  parameter int ADDR_BITS       = 8,
  parameter int DATA_BITS       = 32,
  parameter int PROGRAM_TIMEOUT = 100_000,
  parameter logic [ADDR_BITS-1:0] TEST_ADDR    = '0,
  parameter logic [DATA_BITS-1:0] TEST_PATTERN = 32'hA5A5_5A5A
)(
  input  logic                  clk,
  input  logic                  rst_n,
  input  test_ctrl_t            ctrl,
  output test_status_t          status,
  // Safety interlock
  input  logic                  dangerous_armed,
  // Block-specific NVM ports
  output logic [ADDR_BITS-1:0]  nvm_addr,
  output logic [DATA_BITS-1:0]  nvm_wdata,
  input  logic [DATA_BITS-1:0]  nvm_rdata,
  output logic                  nvm_we,
  output logic                  nvm_re,
  output logic                  nvm_program,
  input  logic                  nvm_busy
);

  // -------------------------------------------------------------------
  // Operation codes (recorded in RESULT0)
  // -------------------------------------------------------------------
  localparam logic [31:0] OP_BLOCKED    = 32'h0000_0000;
  localparam logic [31:0] OP_PRE_READ   = 32'h0000_0001;
  localparam logic [31:0] OP_WRITE      = 32'h0000_0002;
  localparam logic [31:0] OP_PROGRAM    = 32'h0000_0003;
  localparam logic [31:0] OP_POST_READ  = 32'h0000_0004;
  localparam logic [31:0] OP_COMPLETE   = 32'h0000_00FF;

  // -------------------------------------------------------------------
  // FSM states
  // -------------------------------------------------------------------
  typedef enum logic [3:0] {
    S_IDLE,
    S_ARM_CHECK,
    S_PRE_READ_START,
    S_PRE_READ_WAIT,
    S_WRITE,
    S_PROGRAM_START,
    S_PROGRAM_WAIT,
    S_POST_READ_START,
    S_POST_READ_WAIT,
    S_VERIFY,
    S_DONE
  } state_t;

  state_t  state;

  // Latched data
  logic [31:0] pre_value;
  logic [31:0] post_value;
  logic [31:0] op_code;

  // Timeout counter
  logic [31:0] wait_cnt;

  // Pass / error tracking
  logic        pass_r;
  logic [7:0]  error_r;

  // Program summary: bit0 = pre_read_ok, bit1 = write_ok,
  //                  bit2 = program_ok, bit3 = post_read_ok,
  //                  bit4 = verify_match
  logic [31:0] summary;

  // Start edge
  logic        start_d;
  wire         start_pulse = ctrl.test_start & ~start_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= ctrl.test_start;
  end

  // -------------------------------------------------------------------
  // Main FSM
  // -------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      pre_value  <= '0;
      post_value <= '0;
      op_code    <= OP_BLOCKED;
      wait_cnt   <= '0;
      pass_r     <= 1'b0;
      error_r    <= ERR_NONE;
      summary    <= '0;
    end else begin
      case (state)
        // ----------------------------------------------------------
        S_IDLE: begin
          if (ctrl.test_enable && ctrl.test_mode && start_pulse) begin
            state      <= S_ARM_CHECK;
            pre_value  <= '0;
            post_value <= '0;
            op_code    <= OP_BLOCKED;
            pass_r     <= 1'b0;
            error_r    <= ERR_NONE;
            summary    <= '0;
          end
        end

        // ----------------------------------------------------------
        S_ARM_CHECK: begin
          if (!dangerous_armed) begin
            // Safety interlock — refuse to proceed
            error_r <= ERR_UNSAFE_DENIED;
            op_code <= OP_BLOCKED;
            state   <= S_DONE;
          end else begin
            state   <= S_PRE_READ_START;
            op_code <= OP_PRE_READ;
          end
        end

        // ----------------------------------------------------------
        S_PRE_READ_START: begin
          // Assert read enable for one cycle
          wait_cnt <= '0;
          state    <= S_PRE_READ_WAIT;
        end

        // ----------------------------------------------------------
        S_PRE_READ_WAIT: begin
          wait_cnt <= wait_cnt + 32'd1;

          if (!nvm_busy) begin
            pre_value      <= 32'(nvm_rdata);
            summary[0]     <= 1'b1;  // pre_read_ok
            state          <= S_WRITE;
            op_code        <= OP_WRITE;
          end else if (wait_cnt >= PROGRAM_TIMEOUT[31:0] - 32'd1) begin
            error_r <= ERR_TIMEOUT;
            op_code <= OP_PRE_READ;
            state   <= S_DONE;
          end
        end

        // ----------------------------------------------------------
        S_WRITE: begin
          // Assert write enable for one cycle (loads write buffer)
          summary[1] <= 1'b1;  // write_ok
          op_code    <= OP_PROGRAM;
          state      <= S_PROGRAM_START;
        end

        // ----------------------------------------------------------
        S_PROGRAM_START: begin
          // Pulse program signal
          wait_cnt <= '0;
          state    <= S_PROGRAM_WAIT;
        end

        // ----------------------------------------------------------
        S_PROGRAM_WAIT: begin
          wait_cnt <= wait_cnt + 32'd1;

          if (!nvm_busy) begin
            summary[2] <= 1'b1;  // program_ok
            op_code    <= OP_POST_READ;
            wait_cnt   <= '0;
            state      <= S_POST_READ_START;
          end else if (wait_cnt >= PROGRAM_TIMEOUT[31:0] - 32'd1) begin
            error_r <= ERR_TIMEOUT;
            op_code <= OP_PROGRAM;
            state   <= S_DONE;
          end
        end

        // ----------------------------------------------------------
        S_POST_READ_START: begin
          // Assert read enable for one cycle
          wait_cnt <= '0;
          state    <= S_POST_READ_WAIT;
        end

        // ----------------------------------------------------------
        S_POST_READ_WAIT: begin
          wait_cnt <= wait_cnt + 32'd1;

          if (!nvm_busy) begin
            post_value <= 32'(nvm_rdata);
            summary[3] <= 1'b1;  // post_read_ok
            state      <= S_VERIFY;
          end else if (wait_cnt >= PROGRAM_TIMEOUT[31:0] - 32'd1) begin
            error_r <= ERR_TIMEOUT;
            op_code <= OP_POST_READ;
            state   <= S_DONE;
          end
        end

        // ----------------------------------------------------------
        S_VERIFY: begin
          op_code <= OP_COMPLETE;

          if (post_value == 32'(TEST_PATTERN)) begin
            summary[4] <= 1'b1;  // verify_match
            pass_r     <= 1'b1;
          end else begin
            error_r <= ERR_COMPARE_MISMATCH;
          end

          state <= S_DONE;
        end

        // ----------------------------------------------------------
        S_DONE: begin
          if (!ctrl.test_enable)
            state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  // -------------------------------------------------------------------
  // NVM port drivers
  // -------------------------------------------------------------------
  assign nvm_addr    = TEST_ADDR;
  assign nvm_wdata   = DATA_BITS'(TEST_PATTERN);
  assign nvm_re      = (state == S_PRE_READ_START) || (state == S_POST_READ_START);
  assign nvm_we      = (state == S_WRITE);
  assign nvm_program = (state == S_PROGRAM_START);

  // -------------------------------------------------------------------
  // Status outputs
  // -------------------------------------------------------------------
  assign status.test_done    = (state == S_DONE);
  assign status.test_pass    = (state == S_DONE) & pass_r;
  assign status.test_error   = (state == S_DONE) ? error_r : ERR_NONE;
  assign status.test_result0 = op_code;
  assign status.test_result1 = pre_value;
  assign status.test_result2 = post_value;
  assign status.test_result3 = summary;

endmodule
