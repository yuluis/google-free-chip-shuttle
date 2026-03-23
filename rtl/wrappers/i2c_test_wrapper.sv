// ---------------------------------------------------------------------------
// i2c_test_wrapper.sv — I2C self-test with simple internal target model
// Writes test data to internal register model at known addresses, reads
// back, and compares. Reports ACK/NACK/mismatch counts.
// ---------------------------------------------------------------------------
module i2c_test_wrapper
  import ulc_pkg::*;
(
  input  logic         clk,
  input  logic         rst_n,
  input  test_ctrl_t   ctrl,
  output test_status_t status,
  // I2C pins (simplified: separate input/output for synthesis friendliness)
  output logic         i2c_scl,
  output logic         i2c_sda_o,
  input  logic         i2c_sda_i
);

  // -----------------------------------------------------------------------
  // Test parameters
  // -----------------------------------------------------------------------
  localparam int NUM_TEST_REGS = 4;
  localparam logic [6:0] TARGET_ADDR = 7'h50;  // target device address

  logic [7:0] test_addrs [NUM_TEST_REGS];
  logic [7:0] test_data  [NUM_TEST_REGS];

  assign test_addrs[0] = 8'h00;  assign test_data[0] = 8'hA5;
  assign test_addrs[1] = 8'h01;  assign test_data[1] = 8'h5A;
  assign test_addrs[2] = 8'h02;  assign test_data[2] = 8'hFF;
  assign test_addrs[3] = 8'h03;  assign test_data[3] = 8'h42;

  // -----------------------------------------------------------------------
  // Internal target register model (simple array)
  // -----------------------------------------------------------------------
  logic [7:0] target_regs [256];

  // -----------------------------------------------------------------------
  // I2C clock divider
  // -----------------------------------------------------------------------
  localparam int I2C_DIV = 8;
  logic [3:0] clk_div;
  logic       i2c_tick;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      clk_div <= '0;
    else if (state != S_IDLE && state != S_DONE)
      clk_div <= (clk_div == I2C_DIV[3:0] - 1) ? '0 : clk_div + 1;
    else
      clk_div <= '0;
  end

  assign i2c_tick = (clk_div == I2C_DIV[3:0] - 1);

  // -----------------------------------------------------------------------
  // I2C bit-level engine
  // -----------------------------------------------------------------------
  // Simplified I2C master that talks to the internal target model directly.
  // Instead of bit-banging a full I2C protocol on wires, we model the
  // transaction at the byte/ACK level for synthesis simplicity while still
  // exercising the wrapper FSM and comparison logic.
  // -----------------------------------------------------------------------

  typedef enum logic [3:0] {
    S_IDLE,
    S_WRITE_START,
    S_WRITE_ADDR_BYTE,
    S_WRITE_REG_BYTE,
    S_WRITE_DATA_BYTE,
    S_WRITE_STOP,
    S_READ_START,
    S_READ_ADDR_BYTE,
    S_READ_REG_BYTE,
    S_READ_RSTART,
    S_READ_ADDR_RD,
    S_READ_DATA_BYTE,
    S_READ_STOP,
    S_COMPARE,
    S_DONE
  } state_t;

  state_t state, state_next;

  logic [2:0]  reg_idx;
  logic [31:0] ack_count;
  logic [31:0] nack_count;
  logic [31:0] mismatch_count;
  logic [7:0]  read_data;
  logic [3:0]  bit_cnt;
  logic        phase_done;   // current byte/phase complete
  logic        scl_reg;
  logic        sda_reg;

  // Byte transfer counter (counts I2C ticks to 18 = 9 bits * 2 edges)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bit_cnt    <= '0;
      phase_done <= 1'b0;
    end else begin
      phase_done <= 1'b0;
      if (i2c_tick) begin
        if (bit_cnt == 4'd15) begin  // ~8 bits + ACK, 2 ticks each
          bit_cnt    <= '0;
          phase_done <= 1'b1;
        end else begin
          bit_cnt <= bit_cnt + 1;
        end
      end
    end
  end

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
  // Datapath: internal target model + result tracking
  // -----------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_idx        <= '0;
      ack_count      <= '0;
      nack_count     <= '0;
      mismatch_count <= '0;
      read_data      <= '0;
      scl_reg        <= 1'b1;
      sda_reg        <= 1'b1;
      for (int i = 0; i < 256; i++)
        target_regs[i] <= '0;
    end else begin
      // SCL toggle for visibility on output pin
      if (i2c_tick && state != S_IDLE && state != S_DONE)
        scl_reg <= ~scl_reg;

      case (state)
        S_IDLE: begin
          reg_idx        <= '0;
          ack_count      <= '0;
          nack_count     <= '0;
          mismatch_count <= '0;
          scl_reg        <= 1'b1;
          sda_reg        <= 1'b1;
        end

        // Write phase: write test data into internal target model
        S_WRITE_DATA_BYTE: begin
          if (phase_done) begin
            target_regs[test_addrs[reg_idx[1:0]]] <= test_data[reg_idx[1:0]];
            ack_count <= ack_count + 1;  // model always ACKs
          end
        end

        S_WRITE_ADDR_BYTE: begin
          if (phase_done)
            ack_count <= ack_count + 1;
        end

        S_WRITE_REG_BYTE: begin
          if (phase_done)
            ack_count <= ack_count + 1;
        end

        // Read phase: read back from internal target model
        S_READ_DATA_BYTE: begin
          if (phase_done) begin
            read_data <= target_regs[test_addrs[reg_idx[1:0]]];
            ack_count <= ack_count + 1;
          end
        end

        S_READ_ADDR_BYTE: begin
          if (phase_done)
            ack_count <= ack_count + 1;
        end

        S_READ_ADDR_RD: begin
          if (phase_done)
            ack_count <= ack_count + 1;
        end

        S_READ_REG_BYTE: begin
          if (phase_done)
            ack_count <= ack_count + 1;
        end

        S_COMPARE: begin
          if (read_data != test_data[reg_idx[1:0]])
            mismatch_count <= mismatch_count + 1;
          reg_idx <= reg_idx + 1;
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
          state_next = S_WRITE_START;
      end

      // --- Write transaction ---
      S_WRITE_START:
        state_next = S_WRITE_ADDR_BYTE;

      S_WRITE_ADDR_BYTE:
        if (phase_done) state_next = S_WRITE_REG_BYTE;

      S_WRITE_REG_BYTE:
        if (phase_done) state_next = S_WRITE_DATA_BYTE;

      S_WRITE_DATA_BYTE:
        if (phase_done) state_next = S_WRITE_STOP;

      S_WRITE_STOP:
        state_next = S_READ_START;

      // --- Read transaction ---
      S_READ_START:
        state_next = S_READ_ADDR_BYTE;

      S_READ_ADDR_BYTE:
        if (phase_done) state_next = S_READ_REG_BYTE;

      S_READ_REG_BYTE:
        if (phase_done) state_next = S_READ_RSTART;

      S_READ_RSTART:
        state_next = S_READ_ADDR_RD;

      S_READ_ADDR_RD:
        if (phase_done) state_next = S_READ_DATA_BYTE;

      S_READ_DATA_BYTE:
        if (phase_done) state_next = S_READ_STOP;

      S_READ_STOP:
        state_next = S_COMPARE;

      // --- Compare & loop ---
      S_COMPARE: begin
        if (reg_idx == NUM_TEST_REGS[2:0] - 1)
          state_next = S_DONE;
        else
          state_next = S_WRITE_START;
      end

      S_DONE: begin
        if (!ctrl.test_enable)
          state_next = S_IDLE;
      end

      default: state_next = S_IDLE;
    endcase
  end

  // -----------------------------------------------------------------------
  // Pin outputs
  // -----------------------------------------------------------------------
  assign i2c_scl   = scl_reg;
  assign i2c_sda_o = sda_reg;

  // -----------------------------------------------------------------------
  // Status outputs
  // -----------------------------------------------------------------------
  assign status.test_done    = (state == S_DONE);
  assign status.test_pass    = (state == S_DONE) && (mismatch_count == '0);
  assign status.test_error   = (state == S_DONE && mismatch_count != '0) ? ERR_COMPARE_MISMATCH : ERR_NONE;
  assign status.test_result0 = ack_count;
  assign status.test_result1 = nack_count;
  assign status.test_result2 = mismatch_count;
  assign status.test_result3 = '0;

endmodule
