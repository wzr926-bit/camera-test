library IEEE;
library xpm;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use xpm.vcomponents.all;

entity camera_fifo_wrapper is
    port (
        -- Camera clock domain
        camera_pclk     : in std_logic;
        camera_rst_n    : in std_logic;
        camera_tdata    : in std_logic_vector(31 downto 0);
        camera_tvalid   : in std_logic;
        camera_tready   : out std_logic;
        camera_tlast    : in std_logic;
        camera_tuser    : in std_logic_vector(0 downto 0);
        
        -- MIG clock domain
        mig_clk         : in std_logic;
        mig_rst_n       : in std_logic;
        fifo_data_out   : out std_logic_vector(127 downto 0);
        fifo_rd_en      : in std_logic;
        fifo_empty      : out std_logic;
        fifo_prog_full  : out std_logic;
        fifo_frame_start : out std_logic;
        fifo_frame_end   : out std_logic
    );
end entity;

architecture rtl of camera_fifo_wrapper is
    -- Internal FIFO signals
    signal data_fifo_full : std_logic;
    signal data_fifo_almost_full : std_logic;
    signal data_fifo_dout : std_logic_vector(127 downto 0);
    signal data_fifo_empty : std_logic;
    
    -- Frame control FIFO signals
    signal frame_ctrl_fifo_dout : std_logic_vector(1 downto 0);
    signal frame_ctrl_fifo_rd_en : std_logic;
    
    -- Control signals
    signal wr_enable : std_logic;
    
begin
    -- Write side flow control
    camera_tready <= not data_fifo_full;
    wr_enable <= camera_tvalid and not data_fifo_full;

    -- Main data FIFO (32-bit to 128-bit width conversion)
    data_fifo : xpm_fifo_async
        generic map (
            WRITE_DATA_WIDTH => 32,
            READ_DATA_WIDTH => 128,
            FIFO_WRITE_DEPTH => 1024,
            USE_ADV_FEATURES => "0808"
        )
        port map (
            sleep => '0',
            wr_clk => camera_pclk,
            rst => not camera_rst_n,
            wr_en => wr_enable,
            din => camera_tdata,
            full => data_fifo_full,
            almost_full => data_fifo_almost_full,
            wr_ack => open,
            overflow => open,
            prog_full => open,
            wr_data_count => open,
            
            rd_clk => mig_clk,
            rd_en => fifo_rd_en,
            dout => data_fifo_dout,
            empty => data_fifo_empty,
            almost_empty => open,
            data_valid => open,
            underflow => open,
            prog_empty => open,
            rd_data_count => open,
            injectsbiterr => '0',
            injectdbiterr => '0',
            sbiterr => open,
            dbiterr => open,
            wr_rst_busy => open,
            rd_rst_busy => open
        );

    -- Frame control FIFO
    frame_ctrl_fifo : xpm_fifo_async
        generic map (
            WRITE_DATA_WIDTH => 2,
            READ_DATA_WIDTH => 2,
            FIFO_WRITE_DEPTH => 16
        )
        port map (
            sleep => '0',
            wr_clk => camera_pclk,
            rst => not camera_rst_n,
            wr_en => wr_enable and (camera_tuser(0) or camera_tlast),
            din => camera_tuser(0) & camera_tlast,
            full => open,
            almost_full => open,
            wr_ack => open,
            overflow => open,
            prog_full => open,
            wr_data_count => open,
            
            rd_clk => mig_clk,
            rd_en => frame_ctrl_fifo_rd_en,
            dout => frame_ctrl_fifo_dout,
            empty => open,
            almost_empty => open,
            data_valid => open,
            underflow => open,
            prog_empty => open,
            rd_data_count => open,
            injectsbiterr => '0',
            injectdbiterr => '0',
            sbiterr => open,
            dbiterr => open,
            wr_rst_busy => open,
            rd_rst_busy => open
        );

    -- Outputs
    fifo_data_out <= data_fifo_dout;
    fifo_empty <= data_fifo_empty;
    fifo_prog_full <= data_fifo_almost_full;
    
    -- Frame control output generation
    frame_ctrl_fifo_rd_en <= fifo_rd_en;
    
    process(mig_clk, mig_rst_n)
    begin
        if mig_rst_n = '0' then
            fifo_frame_start <= '0';
            fifo_frame_end <= '0';
        elsif rising_edge(mig_clk) then
            if frame_ctrl_fifo_rd_en = '1' then
                fifo_frame_start <= frame_ctrl_fifo_dout(1);
                fifo_frame_end <= frame_ctrl_fifo_dout(0);
            else
                fifo_frame_start <= '0';
                fifo_frame_end <= '0';
            end if;
        end if;
    end process;

end architecture;