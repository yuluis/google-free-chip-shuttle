// PUF stability self-test wrapper
// Captures the PUF response NUM_REPEATS times for the same challenge,
// compares each repeat against the first (reference) capture, and
// reports the total Hamming-distance mismatch count plus a stability
// score (0-100 percentage).
module puf_test_wrapper
  import ulc_pkg::*;
#(
  parameter int PUF_WIDTH   = 128,
  parameter int NUM_REPEATS = 8
)(
  input  logic                  clk,
  input  logic                  rst_n,
  input  test_ctrl_t            ctrl,
  output test_status_t          status,
  // Block-specific ports
  output logic [PUF_WIDTH-1:0]  puf_challenge,
  input  logic [PUF_WIDTH-1:0]  puf_response,
  input  logic                  puf_valid
);

  // -------------------------------------------------------------------
  // FSM states
  // -------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE,
    S_CHALLENGE,
    S_WAIT_RESP,
    S_COMPARE,
    S_DONE
  } state_t;

  state_t  state;

  // Repeat counter
  logic [$clog2(NUM_REPEATS):0] repeat_idx;

  // Reference response (first capture)
  logic [PUF_WIDTH-1:0]  ref_response;
  logic [PUF_WIDTH-1:0]  current_response;

  // Accumulated mismatch bit count
  logic [31:0]           total_mismatch;

  // CRC-32 of reference response (compact fingerprint for RESULT0)
  logic [31:0]           ref_crc;

  // Timeout
  logic [31:0]           wait_cnt;
  localparam int         WAIT_TIMEOUT = 10_000;

  // Start edge
  logic                  start_d;
  wire                   start_pulse = ctrl.test_start & ~start_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= ctrl.test_start;
  end

  // -------------------------------------------------------------------
  // Hamming distance calculator (combinational)
  // -------------------------------------------------------------------
  logic [PUF_WIDTH-1:0] diff_bits;
  logic [31:0]          hamming_dist;

  assign diff_bits = ref_response ^ current_response;

  // Population count — sum all differing bits
  always_comb begin
    hamming_dist = '0;
    for (int i = 0; i < PUF_WIDTH; i++)
      hamming_dist = hamming_dist + {31'd0, diff_bits[i]};
  end

  // -------------------------------------------------------------------
  // Simple CRC-32 of reference response (XOR-fold into 32 bits)
  // -------------------------------------------------------------------
  always_comb begin
    ref_crc = '0;
    for (int i = 0; i < PUF_WIDTH; i += 32) begin
      if (i + 32 <= PUF_WIDTH)
        ref_crc = ref_crc ^ ref_response[i +: 32];
      else
        ref_crc = ref_crc ^ {{(32 - (PUF_WIDTH - i)){1'b0}}, ref_response[PUF_WIDTH-1:i]};
    end
  end

  // -------------------------------------------------------------------
  // Stability score: 100 - (total_mismatch * 100) / (PUF_WIDTH * (NUM_REPEATS-1))
  // -------------------------------------------------------------------
  logic [31:0] stability_score;
  localparam int MAX_MISMATCH_BITS = PUF_WIDTH * (NUM_REPEATS - 1);

  always_comb begin
    if (MAX_MISMATCH_BITS == 0)
      stability_score = 32'd100;
    else if (total_mismatch >= MAX_MISMATCH_BITS[31:0])
      stability_score = 32'd0;
    else
      stability_score = 32'd100 - (total_mismatch * 32'd100) / MAX_MISMATCH_BITS[31:0];
  end

  // -------------------------------------------------------------------
  // Fixed challenge pattern (all-ones; simple but exercises all SRAM cells)
  // -------------------------------------------------------------------
  assign puf_challenge = {PUF_WIDTH{1'b1}};

  // -------------------------------------------------------------------
  // Main FSM
  // -------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= S_IDLE;
      repeat_idx       <= '0;
      ref_response     <= '0;
      current_response <= '0;
      total_mismatch   <= '0;
      wait_cnt         <= '0;
    end else begin
      case (state)
        // ----------------------------------------------------------
        S_IDLE: begin
          if (ctrl.test_enable && ctrl.test_mode && start_pulse) begin
            state          <= S_CHALLENGE;
            repeat_idx     <= '0;
            total_mismatch <= '0;
            ref_response   <= '0;
          end
        end

        // ----------------------------------------------------------
        S_CHALLENGE: begin
          // Issue challenge (active for one cycle), then wait
          wait_cnt <= '0;
          state    <= S_WAIT_RESP;
        end

        // ----------------------------------------------------------
        S_WAIT_RESP: begin
          wait_cnt <= wait_cnt + 32'd1;

          if (puf_valid) begin
            current_response <= puf_response;
            state            <= S_COMPARE;
          end else if (wait_cnt >= WAIT_TIMEOUT[31:0] - 32'd1) begin
            // Timeout — no PUF response
            state <= S_DONE;
          end
        end

        // ----------------------------------------------------------
        S_COMPARE: begin
          if (repeat_idx == '0) begin
            // First capture: store as reference
            ref_response <= current_response;
          end else begin
            // Subsequent captures: accumulate Hamming distance
            total_mismatch <= total_mismatch + hamming_dist;
          end

          if (repeat_idx == NUM_REPEATS[$clog2(NUM_REPEATS):0] - 1) begin
            state <= S_DONE;
          end else begin
            repeat_idx <= repeat_idx + 1;
            state      <= S_CHALLENGE;
          end
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
  // Pass/fail determination
  // -------------------------------------------------------------------
  wire timed_out = (state == S_DONE) && (wait_cnt >= WAIT_TIMEOUT[31:0] - 32'd1) && (repeat_idx < NUM_REPEATS[$clog2(NUM_REPEATS):0] - 1);
  wire pass      = (state == S_DONE) && !timed_out && (stability_score >= 32'd90);

  wire [7:0] err_code = timed_out                ? ERR_TIMEOUT :
                         (stability_score < 32'd90) ? ERR_RANGE_VIOLATION :
                         ERR_NONE;

  // -------------------------------------------------------------------
  // Status outputs
  // -------------------------------------------------------------------
  assign status.test_done    = (state == S_DONE);
  assign status.test_pass    = pass;
  assign status.test_error   = (state == S_DONE) ? err_code : ERR_NONE;
  assign status.test_result0 = ref_crc;
  assign status.test_result1 = total_mismatch;
  assign status.test_result2 = stability_score;
  assign status.test_result3 = '0;

endmodule
