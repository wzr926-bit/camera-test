library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity frame_manager is
    port (
        clk             : in std_logic;
        reset_n         : in std_logic;
        
        -- 摄像头帧同步
        cam_vsync       : in std_logic;  -- 摄像头帧同步
        
        -- VGA帧同步  
        vga_vsync       : in std_logic;  -- VGA帧同步
        
        -- 地址输出
        write_frame_addr : out std_logic_vector(27 downto 0);
        read_frame_addr  : out std_logic_vector(27 downto 0);
        
        -- 控制信号
        write_enable    : out std_logic;
        read_enable     : out std_logic;
        write_done      : in std_logic;
        
        -- 状态
        frame_ready     : out std_logic;  -- 至少一帧准备好
        frame_lost      : out std_logic   -- 帧丢失指示
    );
end entity;

architecture rtl of frame_manager is
    constant FRAME0_ADDR : std_logic_vector(27 downto 0) := x"0000000";
    constant FRAME1_ADDR : std_logic_vector(27 downto 0) := x"0130000";  -- 1.2MB偏移
    constant FRAME2_ADDR : std_logic_vector(27 downto 0) := x"0260000";  -- 2.4MB偏移
    
    type frame_state_type is (
        WAIT_FIRST_FRAME,
        WRITE_FRAME0_READ_FRAME1,
        WRITE_FRAME1_READ_FRAME2,
        WRITE_FRAME2_READ_FRAME0,
        WRITE_FRAME0_READ_FRAME2,
        WRITE_FRAME1_READ_FRAME0,
        WRITE_FRAME2_READ_FRAME1
    );
    
    signal frame_state : frame_state_type := WAIT_FIRST_FRAME;
    signal cam_vsync_prev : std_logic := '0';
    signal vga_vsync_prev : std_logic := '0';
    signal write_in_progress : std_logic := '0';
    signal frame_ready_int : std_logic := '0';
    
    signal write_addr : std_logic_vector(27 downto 0);
    signal read_addr : std_logic_vector(27 downto 0);
    
begin
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            frame_state <= WAIT_FIRST_FRAME;
            write_addr <= FRAME0_ADDR;
            read_addr <= FRAME1_ADDR;
            write_enable <= '0';
            read_enable <= '0';
            frame_ready <= '0';
            frame_ready_int <= '0';
            frame_lost <= '0';
            write_frame_addr <= FRAME0_ADDR;
            read_frame_addr <= FRAME1_ADDR;
            
        elsif rising_edge(clk) then
            cam_vsync_prev <= cam_vsync;
            vga_vsync_prev <= vga_vsync;
            
            -- 检测摄像头新帧开始
            if cam_vsync = '1' and cam_vsync_prev = '0' then
                if write_in_progress = '1' then
                    -- 上一帧还没写完，丢帧
                    frame_lost <= '1';
                else
                    write_enable <= '1';
                    write_in_progress <= '1';
                    frame_lost <= '0';
                end if;
            end if;
            
            -- 检测写入完成
            if write_done = '1' then
                write_enable <= '0';
                write_in_progress <= '0';
                frame_ready_int <= '1';
            end if;
            
            -- VGA帧同步(用于切换读取帧)
            if vga_vsync = '1' and vga_vsync_prev = '0' then
                if frame_ready_int = '1' then
                    read_enable <= '1';
                end if;
            end if;
            
            -- 状态机 - 管理双缓冲/三缓冲切换
            case frame_state is
                when WAIT_FIRST_FRAME =>
                    if write_done = '1' then
                        -- 第一帧写完，开始双缓冲模式
                        frame_state <= WRITE_FRAME0_READ_FRAME1;
                        write_addr <= FRAME0_ADDR;
                        read_addr <= FRAME1_ADDR;
                        frame_ready <= '1';
                    end if;
                    
                when WRITE_FRAME0_READ_FRAME1 =>
                    if write_done = '1' then
                        frame_state <= WRITE_FRAME1_READ_FRAME0;
                        write_addr <= FRAME1_ADDR;
                        read_addr <= FRAME0_ADDR;
                    end if;
                    
                when WRITE_FRAME1_READ_FRAME0 =>
                    if write_done = '1' then
                        frame_state <= WRITE_FRAME2_READ_FRAME1;
                        write_addr <= FRAME2_ADDR;
                        read_addr <= FRAME1_ADDR;
                    end if;
                    
                when WRITE_FRAME2_READ_FRAME1 =>
                    if write_done = '1' then
                        frame_state <= WRITE_FRAME0_READ_FRAME2;
                        write_addr <= FRAME0_ADDR;
                        read_addr <= FRAME2_ADDR;
                    end if;
                    
                when WRITE_FRAME0_READ_FRAME2 =>
                    if write_done = '1' then
                        frame_state <= WRITE_FRAME1_READ_FRAME0;
                        write_addr <= FRAME1_ADDR;
                        read_addr <= FRAME0_ADDR;
                    end if;
                    
                when WRITE_FRAME2_READ_FRAME0 =>
                    if write_done = '1' then
                        frame_state <= WRITE_FRAME0_READ_FRAME1;
                        write_addr <= FRAME0_ADDR;
                        read_addr <= FRAME1_ADDR;
                    end if;
                    
                when others =>
                    frame_state <= WAIT_FIRST_FRAME;
            end case;
            
            write_frame_addr <= write_addr;
            read_frame_addr <= read_addr;
        end if;
    end process;
    
end architecture;