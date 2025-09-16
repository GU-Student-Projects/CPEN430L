# constraints.sdc - Synopsys Design Constraints for firebird project
# Defines timing constraints for the DE2-115 board

# Create the base clock
create_clock -name {CLOCK_50} -period 20.000 -waveform {0.000 10.000} [get_ports {CLOCK_50}]

# Derive PLL clocks (if any PLLs are used)
derive_pll_clocks

# Derive clock uncertainty
derive_clock_uncertainty

# Set input delays for switches (these are asynchronous, so we set relaxed constraints)
set_input_delay -clock CLOCK_50 -max 5.0 [get_ports {SW[*]}]
set_input_delay -clock CLOCK_50 -min 0.0 [get_ports {SW[*]}]

# Set input delays for KEY buttons
set_input_delay -clock CLOCK_50 -max 5.0 [get_ports {KEY[*]}]
set_input_delay -clock CLOCK_50 -min 0.0 [get_ports {KEY[*]}]

# Set output delays for LEDs
set_output_delay -clock CLOCK_50 -max 5.0 [get_ports {LEDG[*]}]
set_output_delay -clock CLOCK_50 -min 0.0 [get_ports {LEDG[*]}]

# Set false paths for asynchronous reset
set_false_path -from [get_ports {KEY[3]}] -to [all_registers]

# Set multicycle paths for the debouncer circuits (they can be slower)
# The debouncer has internal counters that don't need to meet single-cycle timing
set_multicycle_path -setup 2 -from [get_registers {*debounce*|counter[*]}] -to [get_registers {*debounce*|sw_out}]
set_multicycle_path -hold 1 -from [get_registers {*debounce*|counter[*]}] -to [get_registers {*debounce*|sw_out}]