// LED/GPIO status block for bring-up visibility
// LED0: heartbeat (alive), LED1: test running, LED2: pass, LED3: fail, LED4: dangerous armed
module led_status
  import ulc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  input  logic [31:0] global_status,
  input  logic [31:0] global_control,
  input  logic [31:0] cycle_count,

  output logic [4:0]  led
);

  // Heartbeat: slow blink (~1 Hz at 50 MHz -> toggle every ~25M cycles)
  // Use bit 24 of cycle counter for ~0.67s period
  logic heartbeat;
  assign heartbeat = cycle_count[24];

  // Test running: fast blink using bit 21 (~12 Hz)
  logic running_blink;
  assign running_blink = cycle_count[21];

  logic busy, done, pass, fail, armed;
  assign busy  = global_status[STAT_BUSY];
  assign done  = global_status[STAT_DONE];
  assign pass  = global_status[STAT_PASS];
  assign fail  = global_status[STAT_FAIL];
  assign armed = global_control[CTRL_ARM_DANGEROUS];

  // LED0: heartbeat (slow blink idle, fast blink running)
  assign led[0] = busy ? running_blink : heartbeat;

  // LED1: test running (solid while busy)
  assign led[1] = busy;

  // LED2: pass (solid after done+pass, off otherwise)
  assign led[2] = done & pass;

  // LED3: fail (solid after done+fail, off otherwise)
  assign led[3] = done & fail;

  // LED4: dangerous mode armed
  assign led[4] = armed;

endmodule
