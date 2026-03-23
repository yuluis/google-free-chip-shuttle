// Test mux — routes sequencer control to selected block and returns status
module test_mux
  import ulc_pkg::*;
#(
  parameter int N = NUM_BLOCKS
)(
  input  logic [N-1:0]   blk_sel_oh,

  // From sequencer (broadcast)
  input  test_ctrl_t     ctrl_in,

  // Per-block control outputs
  output test_ctrl_t     ctrl_out [N],

  // Per-block status inputs
  input  test_status_t   status_in [N],

  // Muxed status to sequencer
  output test_status_t   status_out
);

  // Broadcast control to all blocks, gated by select
  always_comb begin
    for (int i = 0; i < N; i++) begin
      if (blk_sel_oh[i]) begin
        ctrl_out[i] = ctrl_in;
      end else begin
        ctrl_out[i] = '0;
      end
    end
  end

  // Mux status from selected block
  always_comb begin
    status_out = '0;
    for (int i = 0; i < N; i++) begin
      if (blk_sel_oh[i]) begin
        status_out = status_in[i];
      end
    end
  end

endmodule
