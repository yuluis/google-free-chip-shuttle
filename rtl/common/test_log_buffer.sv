// Circular log buffer for test results
// Stores up to LOG_DEPTH entries in SRAM-style register array
module test_log_buffer
  import ulc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Write port (from sequencer)
  input  logic        wr_en,
  input  log_entry_t  wr_entry,

  // Read port (from host via register bank)
  input  logic [4:0]  rd_index,  // 0..LOG_DEPTH-1
  output log_entry_t  rd_entry,

  // Status
  output logic [31:0] log_ptr,   // next write position
  output logic [31:0] log_count  // total entries written (saturates at 32'hFFFF_FFFF)
);

  log_entry_t mem [0:LOG_DEPTH-1];

  logic [4:0] wr_ptr;

  assign log_ptr = {27'h0, wr_ptr};

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr    <= 5'h0;
      log_count <= 32'h0;
      for (int i = 0; i < LOG_DEPTH; i++)
        mem[i] <= '0;
    end else if (wr_en) begin
      mem[wr_ptr] <= wr_entry;
      wr_ptr      <= (wr_ptr == LOG_DEPTH - 1) ? 5'h0 : wr_ptr + 1;
      if (log_count != 32'hFFFF_FFFF)
        log_count <= log_count + 1;
    end
  end

  assign rd_entry = mem[rd_index];

endmodule
