library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ddr3_writer is
    port (
        clk             : in std_logic;  -- MIG用户时钟(100MHz)
        reset_n         : in std_logic;
        
        -- FIFO接口
        fifo_data       : in std_logic_vector(127 downto 0);
        fifo_empty      : in std_logic;
        fifo_rd_en      : out std_logic;
        fifo_prog_full  : in std_logic;
        fifo_frame_start : in std_logic;
        fifo_frame_end  : in std_logic;
        
        -- 帧缓冲控制
        frame_addr      : in std_logic_vector(27 downto 0);  -- 当前写入帧基址
        write_enable    : in std_logic;
        write_done      : out std_logic;
        
        -- MIG AXI接口
        -- 写地址通道
        awaddr          : out std_logic_vector(27 downto 0);
        awlen           : out std_logic_vector(7 downto 0);
        awvalid         : out std_logic;
        awready         : in std_logic;
        
        -- 写数据通道
        wdata           : out std_logic_vector(127 downto 0);
        wvalid          : out std_logic;
        wready          : in std_logic;
        wlast           : out std_logic;
        
        -- 写响应通道
        bvalid          : in std_logic;
        bready          : out std_logic
    );
end entity;

architecture rtl of ddr3_writer is
    type state_type is (IDLE, WAIT_FRAME, START_BURST, WRITE_BURST, WAIT_RESP);
    signal state : state_type;
    
    -- 每帧总字节数
    constant FRAME_BYTES : integer := 640 * 480 * 4;
    constant FRAME_WORDS : integer := FRAME_BYTES / 16;  -- 128位 = 16字节
    
    -- 突发长度计算
    constant BURST_LENGTH : integer := 32;  -- 每次突发32个128位字 = 512字节
    
    signal burst_count : integer range 0 to BURST_LENGTH;
    signal word_count : integer range 0 to FRAME_WORDS;
    signal current_addr : unsigned(27 downto 0);
    
    signal fifo_rd_en_int : std_logic;
    signal write_active : std_logic;
    signal frame_in_progress : std_logic;
    
begin
    fifo_rd_en <= fifo_rd_en_int;
    
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            awvalid <= '0';
            wvalid <= '0';
            bready <= '0';
            fifo_rd_en_int <= '0';
            write_done <= '0';
            word_count <= 0;
            
        elsif rising_edge(clk) then
            -- 默认值
            awvalid <= '0';
            wvalid <= '0';
            fifo_rd_en_int <= '0';
            write_done <= '0';
            
            case state is
                when IDLE =>
                    if write_enable = '1' then
                        state <= WAIT_FRAME;
                        word_count <= 0;
                        current_addr <= unsigned(frame_addr);
                    end if;
                    
                when WAIT_FRAME =>
                    -- 适配 camera.vhd：无 frame_start 标记，检测到已有缓存数据后开始写入
                    if fifo_prog_full = '1' or fifo_empty = '0' then
                        state <= START_BURST;
                    end if;
                    
                when START_BURST =>
                    -- 发起突发写入请求
                    awaddr <= std_logic_vector(current_addr);
                    awlen <= std_logic_vector(to_unsigned(BURST_LENGTH - 1, 8));
                    awvalid <= '1';
                    burst_count <= 0;
                    
                    if awready = '1' then
                        state <= WRITE_BURST;
                    end if;
                    
                when WRITE_BURST =>
                    -- 写入突发数据
                    if fifo_empty = '0' then
                        wdata <= fifo_data;
                        wvalid <= '1';
                        
                        if wready = '1' then
                            fifo_rd_en_int <= '1';
                            
                            if burst_count = BURST_LENGTH - 1 then
                                wlast <= '1';
                                state <= WAIT_RESP;
                                burst_count <= 0;
                            else
                                burst_count <= burst_count + 1;
                            end if;
                            
                            word_count <= word_count + 1;
                        end if;
                    end if;
                    
                when WAIT_RESP =>
                    -- 等待写响应
                    bready <= '1';
                    if bvalid = '1' then
                        bready <= '0';
                        current_addr <= current_addr + (BURST_LENGTH * 16);  -- 16字节每字
                        
                        if word_count >= FRAME_WORDS then
                            -- 帧写入完成
                            state <= IDLE;
                            write_done <= '1';
                        else
                            -- 继续下一突发
                            state <= WAIT_FRAME;
                        end if;
                    end if;
            end case;
        end if;
    end process;
    
end architecture;