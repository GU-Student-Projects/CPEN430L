#============================================================================
# SDC Timing Constraints for Coffee Machine FPGA Controller
# Target: Altera DE2-115 (Cyclone IV EP4CE115F29C7)
# Author: Gabriel DiMartino
# Date: November 2025
# Course: CPEN-430 Digital System Design Lab
#============================================================================

#============================================================================
# Clock Constraints
#============================================================================

# Create 50 MHz clock constraint
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# Set input delay for clock
set_input_delay -clock CLOCK_50 -max 3.0 [get_ports {CLOCK_50}]
set_input_delay -clock CLOCK_50 -min 1.0 [get_ports {CLOCK_50}]

#============================================================================
# Input Constraints
#============================================================================

# Push Buttons (KEYs) - Debounced in design, relaxed timing
set_input_delay -clock CLOCK_50 -max 5.0 [get_ports {KEY0 KEY1 KEY2 KEY3}]
set_input_delay -clock CLOCK_50 -min 0.0 [get_ports {KEY0 KEY1 KEY2 KEY3}]

# Switches (SWs) - Debounced in design, relaxed timing
set_input_delay -clock CLOCK_50 -max 5.0 [get_ports {SW*}]
set_input_delay -clock CLOCK_50 -min 0.0 [get_ports {SW*}]

#============================================================================
# Output Constraints
#============================================================================

# LED outputs - Slow outputs, relaxed timing (humans can't see glitches < 10ms)
set_output_delay -clock CLOCK_50 -max 10.0 [get_ports {LEDR* LEDG*}]
set_output_delay -clock CLOCK_50 -min -5.0 [get_ports {LEDR* LEDG*}]

# LCD outputs - HD44780 timing requirements
# HD44780 setup time: 60ns, hold time: 10ns, enable pulse width: 450ns
set_output_delay -clock CLOCK_50 -max 8.0 [get_ports {LCD_ON LCD_BLON LCD_EN LCD_RS LCD_RW LCD_DATA[*]}]
set_output_delay -clock CLOCK_50 -min 2.0 [get_ports {LCD_ON LCD_BLON LCD_EN LCD_RS LCD_RW LCD_DATA[*]}]

# 7-Segment display outputs - Slow outputs, relaxed timing
set_output_delay -clock CLOCK_50 -max 10.0 [get_ports {HEX*[*]}]
set_output_delay -clock CLOCK_50 -min -5.0 [get_ports {HEX*[*]}]

#============================================================================
# False Paths
#============================================================================

# Reset path is asynchronous - no timing requirements
set_false_path -from [get_ports {KEY0}] -to [all_registers]

# Push button inputs are debounced - no critical timing
set_false_path -from [get_ports {KEY1 KEY2 KEY3}] -to [all_registers]

# Switch inputs are debounced - no critical timing
set_false_path -from [get_ports {SW*}] -to [all_registers]

# LED outputs are slow - no critical timing
set_false_path -from [all_registers] -to [get_ports {LEDR* LEDG*}]

# 7-segment outputs are slow - no critical timing
set_false_path -from [all_registers] -to [get_ports {HEX*[*]}]

#============================================================================
# Multicycle Paths
#============================================================================

# LCD controller has internal timing delays - multicycle path
# LCD enable pulse is >450ns (>22 cycles at 50MHz)
set_multicycle_path -from [get_registers {*lcd_controller*}] -to [get_ports {LCD_*}] -setup 25
set_multicycle_path -from [get_registers {*lcd_controller*}] -to [get_ports {LCD_*}] -hold 24

# Temperature simulation update is every 1ms (50,000 cycles)
set_multicycle_path -from [get_registers {*water_temp_controller*heat_cycle_counter*}] -to [get_registers {*water_temp_controller*current_temp*}] -setup 50000
set_multicycle_path -from [get_registers {*water_temp_controller*heat_cycle_counter*}] -to [get_registers {*water_temp_controller*current_temp*}] -hold 49999

#============================================================================
# Clock Uncertainty
#============================================================================

# Add some clock uncertainty for clock skew and jitter
derive_clock_uncertainty

#============================================================================
# Design Rule Constraints
#============================================================================

# Set maximum fanout for high-fanout nets
# set_max_fanout 20 [current_design]

# Set maximum transition time for signals
# set_max_transition 2.0 [current_design]

# Set load for output ports (typical FPGA output load)
# set_load 10 [all_outputs]

#============================================================================
# Cut Timing Paths (for problematic paths in simulation/debug)
#============================================================================

# If you encounter timing issues during development, you can add cut paths here
# Example:
# set_false_path -from [get_registers {problematic_module|problematic_reg}] -to [get_registers {destination_reg}]

#============================================================================
# Report Settings
#============================================================================

# These will be used during compilation
# set_global_assignment -name NUM_PARALLEL_PROCESSORS ALL
# set_global_assignment -name OPTIMIZATION_TECHNIQUE SPEED
# set_global_assignment -name PHYSICAL_SYNTHESIS_EFFORT EXTRA

#============================================================================
# Notes
#============================================================================

# Timing closure tips:
# 1. If you see setup violations:
#    - Check if multicycle paths are properly defined
#    - Consider pipelining long combinational paths
#    - Review FSM state encoding (one-hot vs binary)
#
# 2. If you see hold violations:
#    - Usually handled automatically by Quartus
#    - May need to adjust hold multicycle paths
#
# 3. For better performance:
#    - Enable Physical Synthesis optimizations in Quartus
#    - Use LogicLock regions for critical modules
#    - Consider clock domain crossing (CDC) for future expansion
#
# 4. Expected timing results:
#    - All internal paths should meet 50 MHz (20ns period)
#    - Fmax should be >60 MHz for margin
#    - Setup slack should be positive (>1ns preferred)
#    - Hold slack should be positive
