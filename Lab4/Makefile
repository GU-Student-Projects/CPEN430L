# Makefile for Firebird Taillight Controller

# Verilog compiler
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Source files
SOURCES = src/firebird.v src/taillight.v src/counter.v src/debouncer.v src/sync.v
TESTBENCH = sim/firebird_tb.v
TOP_MODULE = firebird_tb

# Output files
EXECUTABLE = firebird_sim.vvp
WAVEFORM = firebird_tb.vcd

# Compilation flags
FLAGS = -g2001

# Default target
all: compile

# Compile with normal speed
compile:
	$(IVERILOG) $(FLAGS) -o $(EXECUTABLE) $(TESTBENCH) $(SOURCES)

# Run simulation
run: compile
	$(VVP) $(EXECUTABLE)

# View waveform
wave: $(WAVEFORM)
	$(GTKWAVE) $(WAVEFORM) &

# Clean generated files
clean:
	rm -f $(EXECUTABLE) $(WAVEFORM) quartus_sim.vvp

# Syntax check only
check:
	$(IVERILOG) $(FLAGS) -tnull $(SOURCES)

# Help
help:
	@echo "Firebird Taillight Controller Makefile"
	@echo "======================================"
	@echo "Targets:"
	@echo "  make compile         - Compile with normal timing"
	@echo "  make compile_fast    - Compile with SIMULATION flag (fast debouncer)"
	@echo "  make run             - Run simulation (normal speed)"
	@echo "  make run_fast        - Run simulation (fast speed with SIMULATION flag)"
	@echo "  make quartus_run     - Run Quartus testbench with SIMULATION flag"
	@echo "  make wave            - View waveforms in GTKWave"
	@echo "  make check           - Syntax check only"
	@echo "  make clean           - Remove generated files"
	@echo "  make help            - Show this help message"
	@echo ""
	@echo "The SIMULATION flag enables:"
	@echo "  - 10-bit debouncer (1024 cycles) instead of 19-bit (524k cycles)"
	@echo "  - Makes simulation ~500x faster"

.PHONY: all compile compile_fast run run_fast wave clean check help