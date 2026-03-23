# Universal Learning Chip — Simulation Makefile
# Requires: Icarus Verilog (iverilog) or compatible SystemVerilog simulator

IVERILOG  ?= iverilog
VVP       ?= vvp
SV_FLAGS  = -g2012 -Wall

# Source files
PKG       = rtl/common/ulc_pkg.sv
COMMON    = $(wildcard rtl/common/*.sv)
WRAPPERS  = $(wildcard rtl/wrappers/*.sv)
IFACES    = $(wildcard rtl/interfaces/*.sv)
TOP       = rtl/top/ulc_top.sv
ALL_RTL   = $(PKG) $(filter-out $(PKG),$(COMMON)) $(WRAPPERS) $(IFACES) $(TOP)

# Testbenches
TB_DIR    = tb

.PHONY: all clean sim_regbank sim_sequencer sim_top help

all: sim_regbank sim_sequencer sim_top

help:
	@echo "Targets:"
	@echo "  sim_regbank    — Run register bank unit test"
	@echo "  sim_sequencer  — Run sequencer unit test"
	@echo "  sim_top        — Run full-chip integration test"
	@echo "  all            — Run all tests"
	@echo "  clean          — Remove build artifacts"

# Register bank unit test
sim_regbank: build/tb_register_bank.vvp
	$(VVP) $<

build/tb_register_bank.vvp: $(PKG) rtl/common/test_register_bank.sv $(TB_DIR)/tb_register_bank.sv | build
	$(IVERILOG) $(SV_FLAGS) -o $@ $^

# Sequencer unit test
sim_sequencer: build/tb_test_sequencer.vvp
	$(VVP) $<

build/tb_test_sequencer.vvp: $(PKG) rtl/common/test_sequencer.sv $(TB_DIR)/tb_test_sequencer.sv | build
	$(IVERILOG) $(SV_FLAGS) -o $@ $^

# Full-chip integration test
sim_top: build/tb_ulc_top.vvp
	$(VVP) $<

build/tb_ulc_top.vvp: $(ALL_RTL) $(TB_DIR)/tb_ulc_top.sv | build
	$(IVERILOG) $(SV_FLAGS) -o $@ $^

build:
	mkdir -p build

clean:
	rm -rf build
