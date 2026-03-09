set_property SRC_FILE_INFO {cfile:{/media/tsmc/6a3f28f3-1a75-4d55-baf2-a6aa8be84a59/kwc/vivado project/camera-vga-test-1/camera-vga-test-1.gen/sources_1/ip/clk_wiz_0/clk_wiz_0.xdc} rfile:../../../camera-vga-test-1.gen/sources_1/ip/clk_wiz_0/clk_wiz_0.xdc id:1 order:EARLY scoped_inst:inst} [current_design]
current_instance inst
set_property src_info {type:SCOPED_XDC file:1 line:54 export:INPUT save:INPUT read:READ} [current_design]
set_input_jitter [get_clocks -of_objects [get_ports clk_in1]] 0.100
