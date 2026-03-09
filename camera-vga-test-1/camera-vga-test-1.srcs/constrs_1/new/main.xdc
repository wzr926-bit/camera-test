## Clock signal  → 接 Project1_top 的 CLOCK_50

set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports sys_clk_200mhz]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports sys_clk_200mhz]

## sys_resetn → 接到 KEY(0) 作为按键复位（低有效）
set_property -dict {PACKAGE_PIN T6 IOSTANDARD LVCMOS15} [get_ports {sys_rst_n}]


## VGA RGB

##位数问题
set_property -dict {PACKAGE_PIN W21 IOSTANDARD LVCMOS33} [get_ports {VGA_R[0]}]
set_property -dict {PACKAGE_PIN N13 IOSTANDARD LVCMOS33} [get_ports {VGA_R[1]}]
set_property -dict {PACKAGE_PIN P19 IOSTANDARD LVCMOS33} [get_ports {VGA_R[2]}]
set_property -dict {PACKAGE_PIN T21 IOSTANDARD LVCMOS33} [get_ports {VGA_R[3]}]

##位数问题
set_property -dict {PACKAGE_PIN T20 IOSTANDARD LVCMOS33} [get_ports {VGA_B[0]}]
set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVCMOS33} [get_ports {VGA_B[1]}]
set_property -dict {PACKAGE_PIN U21 IOSTANDARD LVCMOS33} [get_ports {VGA_B[2]}]
set_property -dict {PACKAGE_PIN V22 IOSTANDARD LVCMOS33} [get_ports {VGA_B[3]}]

##位数问题
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {VGA_G[0]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {VGA_G[1]}]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {VGA_G[2]}]
set_property -dict {PACKAGE_PIN AA18 IOSTANDARD LVCMOS33} [get_ports {VGA_G[3]}]

set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports VGA_HS]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports VGA_VS]

## Camera interface  → 映射到 OV7670_xxx 端口

set_property -dict {PACKAGE_PIN W22  IOSTANDARD LVCMOS33} [get_ports CAM_SIOC]  ;# CAMERA_SCL
set_property -dict {PACKAGE_PIN V17  IOSTANDARD LVCMOS33} [get_ports CAM_SIOD]  ;# CAMERA_SDR (SDA)

set_property -dict {PACKAGE_PIN AA21 IOSTANDARD LVCMOS33} [get_ports CAM_VS] 
set_property -dict {PACKAGE_PIN AA19 IOSTANDARD LVCMOS33} [get_ports CAM_RS];# CAMERA_hs
set_property -dict {PACKAGE_PIN Y22  IOSTANDARD LVCMOS33} [get_ports CAM_PCLK]  ;# CAMERA_PCLK
set_property -dict {PACKAGE_PIN V18  IOSTANDARD LVCMOS33} [get_ports CAM_XCLK]  ;# CAMERA_MCLK

set_property -dict {PACKAGE_PIN AB22 IOSTANDARD LVCMOS33} [get_ports {CAM_D[7]}]
set_property -dict {PACKAGE_PIN W20  IOSTANDARD LVCMOS33} [get_ports {CAM_D[6]}]
set_property -dict {PACKAGE_PIN AA20 IOSTANDARD LVCMOS33} [get_ports {CAM_D[5]}]
set_property -dict {PACKAGE_PIN AB20 IOSTANDARD LVCMOS33} [get_ports {CAM_D[4]}]
set_property -dict {PACKAGE_PIN Y21  IOSTANDARD LVCMOS33} [get_ports {CAM_D[3]}]
set_property -dict {PACKAGE_PIN V19  IOSTANDARD LVCMOS33} [get_ports {CAM_D[2]}]
set_property -dict {PACKAGE_PIN AB21 IOSTANDARD LVCMOS33} [get_ports {CAM_D[1]}]
set_property -dict {PACKAGE_PIN Y19  IOSTANDARD LVCMOS33} [get_ports {CAM_D[0]}]

set_property -dict {PACKAGE_PIN U20 IOSTANDARD LVCMOS33} [get_ports CAM_RESET] ;# CAMERA_RESET
set_property -dict {PACKAGE_PIN V20 IOSTANDARD LVCMOS33} [get_ports CAM_PWDN]  ;# CAMERA_PWDN


