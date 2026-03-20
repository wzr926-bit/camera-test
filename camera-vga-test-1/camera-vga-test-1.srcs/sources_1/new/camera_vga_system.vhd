library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xpm;
use xpm.vcomponents.all;

entity camera_vga_system is
    port (
        -- 系统时钟
        sys_clk_200mhz  : in std_logic;
        sys_rst_n       : in std_logic;
        key             : in std_logic_vector(1 downto 1);
        
        -- 摄像头接口
        CAM_PCLK        : in std_logic;
        CAM_D           : in std_logic_vector(7 downto 0);
        CAM_VS          : in std_logic;
        CAM_RS          : in std_logic;
        CAM_SIOC        : out std_logic;
        CAM_SIOD        : out std_logic;
        CAM_RESET       : out std_logic;
        CAM_PWDN        : out std_logic;
        CAM_XCLK        : out std_logic;
        
        -- VGA接口
        VGA_HS          : out std_logic;
        VGA_VS          : out std_logic;
        VGA_R           : out std_logic_vector(3 downto 0);
        VGA_G           : out std_logic_vector(3 downto 0);
        VGA_B           : out std_logic_vector(3 downto 0);
        
        -- DDR3接口
        DDR3_addr       : out std_logic_vector(13 downto 0);
        DDR3_ba         : out std_logic_vector(2 downto 0);
        DDR3_cas_n      : out std_logic;
        DDR3_ck_n       : out std_logic_vector(0 downto 0);
        DDR3_ck_p       : out std_logic_vector(0 downto 0);
        DDR3_cke        : out std_logic_vector(0 downto 0);
        DDR3_ras_n      : out std_logic;
        DDR3_reset_n    : out std_logic;
        DDR3_we_n       : out std_logic;
        DDR3_dq         : inout std_logic_vector(31 downto 0);
        DDR3_dqs_n      : inout std_logic_vector(3 downto 0);
        DDR3_dqs_p      : inout std_logic_vector(3 downto 0);
        DDR3_odt        : out std_logic_vector(0 downto 0)
    );
end entity;

architecture structural of camera_vga_system is
    component ila_0
        port (
            clk    : in std_logic;
            probe0 : in std_logic_vector(0 downto 0);
            probe1 : in std_logic_vector(0 downto 0);
            probe2 : in std_logic_vector(0 downto 0);
            probe3 : in std_logic_vector(0 downto 0)
        );
    end component;
    
    -- 时钟和复位
    signal clk_vga         : std_logic;
    signal clk_vga_pix     : std_logic := '0';  -- 25MHz pixel clock for 640x480@60
    signal clk_cam         : std_logic;
    signal ui_clk          : std_logic;  -- MIG用户时钟(100MHz)
    signal ui_rst_n        : std_logic;
    signal mmcm_locked     : std_logic;
    signal pll_locked      : std_logic;
    signal init_calib_complete : std_logic;
    
    -- 摄像头数据流
    signal cam_tdata       : std_logic_vector(31 downto 0);
    signal cam_tvalid      : std_logic;
    signal cam_tready      : std_logic;
    signal cam_tlast       : std_logic;
    signal cam_tuser       : std_logic_vector(0 downto 0);
    
    -- FIFO接口
    signal fifo_data_out   : std_logic_vector(127 downto 0);
    signal fifo_rd_en      : std_logic;
    signal fifo_empty      : std_logic;
    signal fifo_prog_full  : std_logic;
    signal fifo_frame_start : std_logic;
    signal fifo_frame_end  : std_logic;
    
    -- 写入控制
    signal write_frame_addr : std_logic_vector(27 downto 0);
    signal write_enable     : std_logic;
    signal write_done       : std_logic;
    
    -- 读取控制
    signal read_frame_addr  : std_logic_vector(27 downto 0);
    signal read_enable      : std_logic;
    
    -- VGA请求
    signal vga_line_req     : std_logic;
    signal vga_line_num     : integer range 0 to 479;
    
    -- VGA FIFO接口
    signal vga_fifo_wr_en   : std_logic;
    signal vga_fifo_data    : std_logic_vector(31 downto 0);
    signal vga_fifo_full    : std_logic;
    signal vga_fifo_rd_en   : std_logic;
    signal vga_fifo_empty   : std_logic;
    signal vga_fifo_dout    : std_logic_vector(31 downto 0);
    
    -- 帧管理器
    signal frame_ready      : std_logic;

    -- MIG AXI写通道信号 (来自ddr3_writer)
    signal mig_awaddr       : std_logic_vector(27 downto 0);
    signal mig_awlen        : std_logic_vector(7 downto 0);
    signal mig_awvalid      : std_logic;
    signal mig_awready      : std_logic;
    signal mig_wdata        : std_logic_vector(127 downto 0);
    signal mig_wvalid       : std_logic;
    signal mig_wready       : std_logic;
    signal mig_wlast        : std_logic;
    signal mig_bvalid       : std_logic;
    signal mig_bready       : std_logic;

     -- MIG AXI读通道信号 (来自ddr3_reader)
    signal mig_araddr       : std_logic_vector(27 downto 0);  -- 您问的这个
    signal mig_arlen        : std_logic_vector(7 downto 0);
    signal mig_arvalid      : std_logic;
    signal mig_arready      : std_logic;
    signal mig_rdata        : std_logic_vector(127 downto 0);
    signal mig_rvalid       : std_logic;
    signal mig_rready       : std_logic;
    signal mig_rlast        : std_logic;
    signal mig_rresp        : std_logic_vector(1 downto 0);   -- 读响应
    
    -- vga中间信号，用作帧同步
    signal vga_vsync : std_logic;
    signal vga_clk_div_cnt : unsigned(0 downto 0) := (others => '0');
    signal key1_meta       : std_logic := '1';
    signal key1_sync       : std_logic := '1';
    signal key1_prev       : std_logic := '1';
    signal test_pattern_en : std_logic := '0';
    signal write_done_seen : std_logic := '0';
    
    signal ila_probe0      : std_logic_vector(0 downto 0);
    signal ila_probe1      : std_logic_vector(0 downto 0);
    signal ila_probe2      : std_logic_vector(0 downto 0);
    signal ila_probe3      : std_logic_vector(0 downto 0);
    
begin
    -- clk_wiz currently outputs 100MHz on clk_vga; divide by 4 -> 25MHz pixel clock
    process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            if vga_clk_div_cnt = "1" then
                vga_clk_div_cnt <= (others => '0');
                clk_vga_pix <= not clk_vga_pix;
            else
                vga_clk_div_cnt <= vga_clk_div_cnt + 1;
            end if;
        end if;
    end process;

    -- KEY[1]（低有效）按下沿切换彩条开关
    process(clk_vga_pix)
    begin
        if rising_edge(clk_vga_pix) then
            key1_meta <= key(1);
            key1_sync <= key1_meta;
            key1_prev <= key1_sync;

            if (key1_prev = '1') and (key1_sync = '0') then
                test_pattern_en <= not test_pattern_en;
            end if;
        end if;
    end process;

    -- 锁存写完成脉冲，便于屏幕调试块观察
    process(ui_clk, ui_rst_n)
    begin
        if ui_rst_n = '0' then
            write_done_seen <= '0';
        elsif rising_edge(ui_clk) then
            if write_done = '1' then
                write_done_seen <= '1';
            end if;
        end if;
    end process;

    -- 摄像头模块
    u_camera : entity work.camera
        port map (
            clk_in      => clk_cam,
            SIOC        => CAM_SIOC,
            SIOD        => CAM_SIOD,
            RESET       => CAM_RESET,
            PWDN        => CAM_PWDN,
            XCLK        => CAM_XCLK,
            CAMERA_PCLK => CAM_PCLK,
            CAMERA_D    => CAM_D,
            CAMERA_VS   => CAM_VS,
            CAMERA_RS   => CAM_RS,
            tdata_out   => cam_tdata,
            tlast_out   => cam_tlast,
            tready_in   => cam_tready,
            tuser_out   => cam_tuser,
            tvalid_out  => cam_tvalid
        );
    
    -- 写入FIFO
    u_write_fifo : entity work.camera_fifo_wrapper
        port map (
            camera_pclk    => CAM_PCLK,
            camera_rst_n   => sys_rst_n and pll_locked,
            camera_tdata   => cam_tdata,
            camera_tvalid  => cam_tvalid,
            camera_tready  => cam_tready,
            camera_tlast   => cam_tlast,
            camera_tuser   => cam_tuser,
            mig_clk        => ui_clk,
            mig_rst_n      => ui_rst_n,
            fifo_data_out  => fifo_data_out,
            fifo_rd_en     => fifo_rd_en,
            fifo_empty     => fifo_empty,
            fifo_prog_full => fifo_prog_full,
            fifo_frame_start => fifo_frame_start,
            fifo_frame_end => fifo_frame_end
        );
    
    -- DDR3写入器
    u_ddr3_writer : entity work.ddr3_writer
        port map (
            clk          => ui_clk,
            reset_n      => ui_rst_n,
            fifo_data    => fifo_data_out,
            fifo_empty   => fifo_empty,
            fifo_rd_en   => fifo_rd_en,
            fifo_prog_full => fifo_prog_full,
            fifo_frame_start => fifo_frame_start,
            fifo_frame_end => fifo_frame_end,
            frame_addr   => write_frame_addr,
            write_enable => write_enable,
            write_done   => write_done,
            awaddr       => mig_awaddr,
            awlen        => mig_awlen,
            awvalid      => mig_awvalid,
            awready      => mig_awready,
            wdata        => mig_wdata,
            wvalid       => mig_wvalid,
            wready       => mig_wready,
            wlast        => mig_wlast,
            bvalid       => mig_bvalid,
            bready       => mig_bready
        );
    
    -- 读取FIFO (VGA侧)
    u_read_fifo : entity work.xpm_fifo_async
        generic map (
            WRITE_DATA_WIDTH => 32,
            READ_DATA_WIDTH => 32,
            FIFO_WRITE_DEPTH => 1024
        )
        port map (
            wr_clk => ui_clk,
            rd_clk => clk_vga_pix,
            rst => not ui_rst_n,
            wr_en => vga_fifo_wr_en,
            din => vga_fifo_data,
            full => vga_fifo_full,
            rd_en => vga_fifo_rd_en,
            dout => vga_fifo_dout,
            empty => vga_fifo_empty
        );
    
    -- DDR3读取器
    u_ddr3_reader : entity work.ddr3_reader
        port map (
            clk          => ui_clk,
            reset_n      => ui_rst_n,
            vga_req      => vga_line_req,
            vga_line_num => vga_line_num,
            vga_data_valid => open,
            fifo_wr_en   => vga_fifo_wr_en,
            fifo_data    => vga_fifo_data,
            fifo_full    => vga_fifo_full,
            frame_addr   => read_frame_addr,
            read_enable  => read_enable,
            araddr       => mig_araddr,
            arlen        => mig_arlen,
            arvalid      => mig_arvalid,
            arready      => mig_arready,
            rdata        => mig_rdata,
            rvalid       => mig_rvalid,
            rready       => mig_rready,
            rlast        => mig_rlast
        );
    
    VGA_VS <= vga_vsync;
    
    -- 帧缓冲管理器
    u_frame_manager : entity work.frame_manager
        port map (
            clk          => ui_clk,
            reset_n      => ui_rst_n,
            cam_vsync    => CAM_VS,
            vga_vsync    => vga_vsync,
            write_frame_addr => write_frame_addr,
            read_frame_addr  => read_frame_addr,
            write_enable => write_enable,
            read_enable  => read_enable,
            write_done   => write_done,
            frame_ready  => frame_ready,
            frame_lost   => open
        );
    
    -- VGA显示模块
    u_vga : entity work.vga
        port map (
            clk_in        => clk_vga_pix,
            tdata_in      => vga_fifo_dout,
            tready_out    => vga_fifo_rd_en,
            tvalid_in     => not vga_fifo_empty,
            tlast_in      => '0',
            test_pattern_en_in => test_pattern_en,
            dbg_write_done_in  => write_done_seen,
            dbg_read_enable_in => read_enable,
            dbg_fifo_empty_in  => vga_fifo_empty,
            VGA_HS_O_out  => VGA_HS,
            VGA_VS_O_out  => vga_vsync,
            VGA_R_out     => VGA_R,
            VGA_B_out     => VGA_B,
            VGA_G_out     => VGA_G,
            line_req_out  => vga_line_req,
            line_num_out  => vga_line_num
        );
        
       u_clk_wiz : entity work.clk_wiz_0
        port map (
            clk_in1      => sys_clk_200mhz,
            clk_out1     => clk_vga,
            clk_out2     => clk_cam,
            reset        => not sys_rst_n,
            locked       => pll_locked
        );
  
 
 -- MIG IP核
     mig_inst : entity work.mig_7series_0
        port map (
            aresetn         => sys_rst_n,
            app_sr_req      => '0',
            app_ref_req     => '0',
            app_zq_req      => '0',
            app_sr_active   => open,
            app_ref_ack     => open,
            app_zq_ack      => open,
            sys_clk_i       => sys_clk_200mhz,
            sys_rst         => not sys_rst_n,
            ui_clk          => ui_clk,
            ui_clk_sync_rst => open,
            mmcm_locked     => mmcm_locked,
            init_calib_complete => init_calib_complete,
            device_temp     => open,
            
            -- DDR3物理接口
            ddr3_addr       => DDR3_addr,
            ddr3_ba         => DDR3_ba,
            ddr3_cas_n      => DDR3_cas_n,
            ddr3_ck_n       => DDR3_ck_n,
            ddr3_ck_p       => DDR3_ck_p,
            ddr3_cke        => DDR3_cke,
            ddr3_ras_n      => DDR3_ras_n,
            ddr3_reset_n    => DDR3_reset_n,
            ddr3_we_n       => DDR3_we_n,
            ddr3_dq         => DDR3_dq,
            ddr3_dqs_n      => DDR3_dqs_n,
            ddr3_dqs_p      => DDR3_dqs_p,
            ddr3_cs_n       => open,
            ddr3_dm         => open,
            ddr3_odt        => DDR3_odt,
            
            -- AXI4接口
            s_axi_awid      => (others=>'0'),
            s_axi_awaddr    => '0' & mig_awaddr,
            s_axi_awlen     => mig_awlen,
            s_axi_awsize    => "100",  -- 16字节(128位)
            s_axi_awburst   => "01",   -- INCR
            s_axi_awlock    => "0",
            s_axi_awcache   => "0011",
            s_axi_awprot    => "000",
            s_axi_awqos     => (others=>'0'),
            s_axi_awvalid   => mig_awvalid,
            s_axi_awready   => mig_awready,
            s_axi_wdata     => mig_wdata,
            s_axi_wstrb     => (others=>'1'),
            s_axi_wlast     => mig_wlast,
            s_axi_wvalid    => mig_wvalid,
            s_axi_wready    => mig_wready,
            s_axi_bid       => open,
            s_axi_bresp     => open,
            s_axi_bvalid    => mig_bvalid,
            s_axi_bready    => mig_bready,
            s_axi_arid      => (others=>'0'),
            s_axi_araddr    => '0' & mig_araddr,
            s_axi_arlen     => mig_arlen,
            s_axi_arsize    => "100",
            s_axi_arburst   => "01",
            s_axi_arlock    => "0",
            s_axi_arcache   => "0011",
            s_axi_arprot    => "000",
            s_axi_arqos     => (others=>'0'),
            s_axi_arvalid   => mig_arvalid,
            s_axi_arready   => mig_arready,
            s_axi_rid       => open,
            s_axi_rdata     => mig_rdata,
            s_axi_rresp     => open,
            s_axi_rlast     => mig_rlast,
            s_axi_rvalid    => mig_rvalid,
            s_axi_rready    => mig_rready
        );
    
    
    ui_rst_n <= mmcm_locked and init_calib_complete and pll_locked;
    
    ila_probe0(0) <= cam_tvalid;
    ila_probe1(0) <= write_done;
    ila_probe2(0) <= read_enable;
    ila_probe3(0) <= vga_fifo_empty;
    
    --ILA
    u_ila_0 : ila_0
        port map (
            clk     => ui_clk,
            probe0 => ila_probe0,
            probe1 => ila_probe1,
            probe2 => ila_probe2,
            probe3 => ila_probe3
        );
    
end architecture;



