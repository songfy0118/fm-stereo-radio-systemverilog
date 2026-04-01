set CLK_PERIOD_NS 10.000
create_clock -name clk -period $CLK_PERIOD_NS [get_ports clk]
set_clock_uncertainty 0.200 [get_clocks clk]
set_false_path -from [get_ports rst]
