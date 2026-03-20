library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ddr3_reader is
    port (
        clk             : in std_logic;
        reset_n         : in std_logic;
        
        -- VGA请求接口
        vga_req         : in std_logic;  -- VGA请求下一行
        vga_line_num    : in integer range 0 to 479;
        vga_data_valid  : out std_logic;
        
        -- FIFO接口 (到VGA)
        fifo_wr_en      : out std_logic;
        fifo_data       : out std_logic_vector(31 downto 0);
        fifo_full        : in std_logic;
        
        -- 帧缓冲控制
        frame_addr      : in std_logic_vector(27 downto 0);  -- 当前读取帧基址
        read_enable     : in std_logic;
        
        -- MIG AXI接口
        araddr          : out std_logic_vector(27 downto 0);
        arlen           : out std_logic_vector(7 downto 0);
        arvalid         : out std_logic;
        arready         : in std_logic;
        
        rdata           : in std_logic_vector(127 downto 0);
        rvalid          : in std_logic;
        rready          : out std_logic;
        rlast           : in std_logic
    );
end entity;

architecture rtl of ddr3_reader is
    type state_type is (IDLE, START_READ, WAIT_DATA, SEND_TO_FIFO);
    signal state : state_type;
    
    constant BYTES_PER_LINE : integer := 640 * 4;  -- 每行2560字节
    constant WORDS_PER_LINE : integer := BYTES_PER_LINE / 16;  -- 160个128位字
    constant BURST_LENGTH : integer := 32;  -- 每次突发读取32个字
    
    signal line_addr : unsigned(27 downto 0);
    signal words_remaining : integer range 0 to WORDS_PER_LINE;
    signal current_burst_words : integer range 0 to BURST_LENGTH;
    
    signal fifo_buffer : std_logic_vector(127 downto 0);
    signal byte_sel : integer range 0 to 3;  -- 32位字选择
    
begin
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            arvalid <= '0';
            rready <= '0';
            fifo_wr_en <= '0';
            vga_data_valid <= '0';
            
        elsif rising_edge(clk) then
            -- 默认值
            arvalid <= '0';
            rready <= '0';
            fifo_wr_en <= '0';
            vga_data_valid <= '0';
            
            case state is
                when IDLE =>
                    if read_enable = '1' and vga_req = '1' then
                        -- 计算行地址
                        line_addr <= unsigned(frame_addr) + 
                                    (vga_line_num * BYTES_PER_LINE);
                        words_remaining <= WORDS_PER_LINE;
                        state <= START_READ;
                    end if;
                    
                when START_READ =>
                    -- 发起突发读取请求
                    if words_remaining > BURST_LENGTH then
                        current_burst_words <= BURST_LENGTH;
                        arlen <= std_logic_vector(to_unsigned(BURST_LENGTH - 1, 8));
                    else
                        current_burst_words <= words_remaining;
                        arlen <= std_logic_vector(to_unsigned(words_remaining - 1, 8));
                    end if;
                    araddr <= std_logic_vector(line_addr);
                    arvalid <= '1';
                    
                    if arready = '1' then
                        if words_remaining > BURST_LENGTH then
                            line_addr <= line_addr + (BURST_LENGTH * 16);
                        else
                            line_addr <= line_addr + (words_remaining * 16);
                        end if;
                        state <= WAIT_DATA;
                    end if;
                    
                when WAIT_DATA =>
                    -- 等待读数据
                    rready <= '1';
                    if rvalid = '1' then
                        fifo_buffer <= rdata;
                        byte_sel <= 0;
                        if current_burst_words > 0 then
                            current_burst_words <= current_burst_words - 1;
                        end if;
                        if words_remaining > 0 then
                            words_remaining <= words_remaining - 1;
                        end if;
                        state <= SEND_TO_FIFO;
                    end if;
                    
                when SEND_TO_FIFO =>
                    -- 将128位数据拆分为32位写入FIFO
                    if fifo_full = '0' then
                        case byte_sel is
                            when 0 => fifo_data <= fifo_buffer(31 downto 0);
                            when 1 => fifo_data <= fifo_buffer(63 downto 32);
                            when 2 => fifo_data <= fifo_buffer(95 downto 64);
                            when 3 => fifo_data <= fifo_buffer(127 downto 96);
                        end case;
                        
                        fifo_wr_en <= '1';
                        
                        if byte_sel = 3 then
                            -- 一个128位字处理完
                            if (words_remaining = 0) and (current_burst_words = 0) then
                                -- 行读取完成
                                vga_data_valid <= '1';
                                state <= IDLE;
                            elsif current_burst_words = 0 then
                                -- 发起下一突发
                                state <= START_READ;
                            else
                                -- 继续当前突发
                                state <= WAIT_DATA;
                            end if;
                        else
                            byte_sel <= byte_sel + 1;
                        end if;
                    end if;
            end case;
        end if;
    end process;
    
end architecture;