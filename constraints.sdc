set sdram_clk "${topmodule}clocks|pll|altpll_component|auto_generated|pll1|clk[1]"
set mem_clk   "${topmodule}clocks|pll|altpll_component|auto_generated|pll1|clk[0]"
set sys_clk   "${topmodule}clocks|pll|altpll_component|auto_generated|pll1|clk[0]"

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

set_clock_groups -asynchronous -group [get_clocks $hostclk] -group [get_clocks $sys_clk]
set_clock_groups -asynchronous -group [get_clocks $supportclk] -group [get_clocks $sys_clk]
set_clock_groups -asynchronous -group [get_clocks spiclk] -group [get_clocks $sys_clk]

# SDRAM delays
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports ${RAM_CLK}] -max 6.6 [get_ports ${RAM_IN}]
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports ${RAM_CLK}] -min 3.5 [get_ports ${RAM_IN}]

set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports ${RAM_CLK}] -max 1.5 [get_ports ${RAM_OUT}]
set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports ${RAM_CLK}] -min -0.8 [get_ports ${RAM_OUT}]

#SDRAM_CLK to internal memory clock
set_multicycle_path -from [get_clocks $sdram_clk] -to [get_clocks $mem_clk] -setup -end 2

# False paths

set_false_path -to ${VGA_OUT}
set_false_path -to ${FALSE_OUT}
set_false_path -from ${FALSE_IN}
