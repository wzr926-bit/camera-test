onbreak {quit -f}
onerror {quit -f}

vsim  -lib xil_defaultlib camera_vga_system_opt

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure
view signals

do {camera_vga_system.udo}

run 1000ns

quit -force
