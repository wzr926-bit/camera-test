#!/bin/sh

# 
# Vivado(TM)
# runme.sh: a Vivado-generated Runs Script for UNIX
# Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
# Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
# 

if [ -z "$PATH" ]; then
  PATH=/media/tsmc/6a3f28f3-1a75-4d55-baf2-a6aa8be84a59/tools/Xilinx2025/2025.1/Vitis/bin:/media/tsmc/6a3f28f3-1a75-4d55-baf2-a6aa8be84a59/tools/Xilinx2025/2025.1/Vivado/ids_lite/ISE/bin/lin64:/media/tsmc/6a3f28f3-1a75-4d55-baf2-a6aa8be84a59/tools/Xilinx2025/2025.1/Vivado/bin
else
  PATH=/media/tsmc/6a3f28f3-1a75-4d55-baf2-a6aa8be84a59/tools/Xilinx2025/2025.1/Vitis/bin:/media/tsmc/6a3f28f3-1a75-4d55-baf2-a6aa8be84a59/tools/Xilinx2025/2025.1/Vivado/ids_lite/ISE/bin/lin64:/media/tsmc/6a3f28f3-1a75-4d55-baf2-a6aa8be84a59/tools/Xilinx2025/2025.1/Vivado/bin:$PATH
fi
export PATH

if [ -z "$LD_LIBRARY_PATH" ]; then
  LD_LIBRARY_PATH=
else
  LD_LIBRARY_PATH=:$LD_LIBRARY_PATH
fi
export LD_LIBRARY_PATH

HD_PWD='/media/tsmc/6a3f28f3-1a75-4d55-baf2-a6aa8be84a59/kwc/vivado project/camera-vga-test-1/camera-vga-test-1.runs/impl_1'
cd "$HD_PWD"

HD_LOG=runme.log
/bin/touch $HD_LOG

ISEStep="./ISEWrap.sh"
EAStep()
{
     $ISEStep $HD_LOG "$@" >> $HD_LOG 2>&1
     if [ $? -ne 0 ]
     then
         exit
     fi
}

# pre-commands:
/bin/touch .write_bitstream.begin.rst
EAStep vivado -log camera_vga_system.vdi -applog -m64 -product Vivado -messageDb vivado.pb -mode batch -source camera_vga_system.tcl -notrace


