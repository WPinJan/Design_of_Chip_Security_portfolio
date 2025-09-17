create_clock -name clk -period 10 [get_ports clk]
set_clock_uncertainty -setup 0.5 clk
set_clock_uncertainty -hold  0.2 clk

set_input_delay  4 -clock clk [all_inputs]
set_output_delay 4 -clock clk [all_outputs]
