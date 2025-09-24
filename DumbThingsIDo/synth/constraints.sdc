# -------------------------------------------------------------------------- #
#
# Coffee Selector System - Timing Constraints File (SDC)
# Target Board: DE2-115
# 
# -------------------------------------------------------------------------- #

# Create base clock
create_clock -name {clk} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk}]

# Derive PLL clocks automatically
derive_pll_clocks

# Derive clock uncertainty
derive_clock_uncertainty

# Set false paths for asynchronous reset
set_false_path -from [get_ports {reset_n}]

# Set false paths from push buttons (they are synchronized internally)
set_false_path -from [get_ports {key[*]}]

# Constrain VGA outputs
set_output_delay -clock [get_clocks {pll_inst|altpll_component|auto_generated|pll1|clk[0]}] -max 0.5 [get_ports {vga_*}]
set_output_delay -clock [get_clocks {pll_inst|altpll_component|auto_generated|pll1|clk[0]}] -min -0.5 [get_ports {vga_*}]

# Constrain LCD interface (relaxed timing as it's slow)
set_output_delay -clock {clk} -max 10.0 [get_ports {lcd_*}]
set_output_delay -clock {clk} -min 0.0 [get_ports {lcd_*}]

# Constrain LED outputs (not critical)
set_false_path -to [get_ports {led[*]}]

# Set multicycle paths for slow LCD operations if needed
# The LCD controller operates much slower than system clock
set_multicycle_path -setup -to [get_ports {lcd_data[*]}] 2
set_multicycle_path -hold -to [get_ports {lcd_data[*]}] 1