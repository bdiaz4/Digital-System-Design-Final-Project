LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

entity weakness is 
    port (
        clk_in : IN STD_LOGIC; -- system clock
        VGA_red : OUT STD_LOGIC_VECTOR (3 DOWNTO 0); -- VGA outputs
        VGA_green : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_blue : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_hsync : OUT STD_LOGIC;
        VGA_vsync : OUT STD_LOGIC;
        btnl : IN STD_LOGIC;
        btnr : IN STD_LOGIC;
        btnu : in std_logic; 
        btnd : in std_logic; 
        btnc : IN STD_LOGIC;
        SW : in std_logic_vector (15 downto 0); 
        SEG7_anode : OUT STD_LOGIC_VECTOR (7 DOWNTO 0); -- anodes of four 7-seg displays
        SEG7_seg : OUT STD_LOGIC_VECTOR (6 DOWNTO 0); 
        dac_MCLK : OUT STD_LOGIC; -- outputs to PMODI2L DAC
		dac_LRCK : OUT STD_LOGIC;
		dac_SCLK : OUT STD_LOGIC;
		dac_SDIN : OUT STD_LOGIC
    ); 
end weakness; 

architecture behavioral of weakness is 
    type enemy_array is array (9 downto 0) of std_logic_vector (14 downto 0); -- custom array type to contain enemies on the sides of the screen 
    -- enemies are represented by 15 bits 
    -- 14 = is the enemy on? 
    -- 13 downto 10 = "weakness" value to determine how to hit it 
    -- 9 downto 0 = enemy position 
    signal playing : std_logic := '0'; -- is the game currently playing? 
    signal char_pos : std_logic_vector (9 downto 0) := "0100100100"; -- vertical position of the player character 
    signal char_direction : std_logic := '0'; -- character facing direction (0 for left, 1 for right) 
    signal valid_weakness : std_logic; -- is the character's switch selection valid? (if only 1 switch is up) 
    constant enemy_divide : std_logic_vector := x"04444444"; -- used for dividing the character position by 60 for enemy calculations 
    signal enemy_facing_temp : std_logic_vector (41 downto 0); -- which enemy row is the character currently in? 
    signal enemy_facing : std_logic_vector (3 downto 0); -- which enemy row is the character currently in? 
    signal enemies_left : enemy_array := (others => "000000000000000"); -- stores enemies on the left side of the screen 
    signal enemies_right : enemy_array := (others => "000001100010000"); -- stores enemies on the right side of the screen 
    signal new_enemy : integer; -- stores the random state as an index for new enemy creation 
    signal score : std_logic_vector (15 downto 0); -- number of enemies successfully eliminated 
    signal random : std_logic_vector (47 downto 0); -- linear feedback shift register for pseudo-random numbers 
    signal random_next : std_logic; -- used to calculate next bit in the random LFSR 
    signal attack_flag : std_logic := '0'; -- detects if the attack button is held down, prevents holding the button down for the game 
    signal count : std_logic_vector (31 downto 0); -- clock counter 
    SIGNAL display : std_logic_vector (19 DOWNTO 0); -- value to be displayed on the 7-segment display 
    SIGNAL led_mpx : STD_LOGIC_VECTOR (2 DOWNTO 0); -- 7-seg multiplexing clock
    SIGNAL pxl_clk : STD_LOGIC := '0'; -- 25 MHz clock to VGA sync module 
    SIGNAL S_red, S_green, S_blue : STD_LOGIC_VECTOR (3 DOWNTO 0);
    SIGNAL S_vsync : STD_LOGIC;
    SIGNAL S_pixel_row, S_pixel_col : STD_LOGIC_VECTOR (10 DOWNTO 0); 
    SIGNAL dac_load_L, dac_load_R : STD_LOGIC; -- timing pulses to load DAC shift reg.
    signal audio_data : signed (15 downto 0); 
    signal audio_pitch : unsigned (13 downto 0); -- controls the audio pitch 
    signal sound_flag : std_logic := '0'; -- controls if the sound is playing 
    COMPONENT vga_sync IS
        PORT (
            pixel_clk : IN STD_LOGIC;
            red_in    : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
            green_in  : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
            blue_in   : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
            red_out   : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
            green_out : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
            blue_out  : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
            hsync : OUT STD_LOGIC;
            vsync : OUT STD_LOGIC;
            pixel_row : OUT STD_LOGIC_VECTOR (10 DOWNTO 0);
            pixel_col : OUT STD_LOGIC_VECTOR (10 DOWNTO 0)
        );
    END COMPONENT;
    COMPONENT clk_wiz_0 is
        PORT (
            clk_in1  : in std_logic;
            clk_out1 : out std_logic
        );
    END COMPONENT;
    COMPONENT leddec16 IS
        PORT (
            dig : IN STD_LOGIC_VECTOR (2 DOWNTO 0);
            data : IN STD_LOGIC_VECTOR (19 DOWNTO 0);
            anode : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
            seg : OUT STD_LOGIC_VECTOR (6 DOWNTO 0)
        );
    END COMPONENT; 
    COMPONENT dac_if IS
		PORT (
			SCLK : IN STD_LOGIC;
			L_start : IN STD_LOGIC;
			R_start : IN STD_LOGIC;
			L_data : IN signed (15 DOWNTO 0);
			R_data : IN signed (15 DOWNTO 0);
			SDATA : OUT STD_LOGIC
		);
	END COMPONENT;
	COMPONENT tone IS
		PORT (
			clk : IN STD_LOGIC;
			pitch : IN UNSIGNED (13 DOWNTO 0);
			enabled : in std_logic; 
			data : OUT SIGNED (15 DOWNTO 0)
		);
	END COMPONENT;
begin 
    led_mpx <= count(19 DOWNTO 17); -- 7-seg multiplexing clock   
    dac_MCLK <= not count(2); 
    dac_SCLK <= count(5); 
    dac_LRCK <= count(10); 
    display <= enemies_left(conv_integer(enemy_facing)) (13 downto 10) & score when char_direction = '0' else
               enemies_right(conv_integer(enemy_facing)) (13 downto 10) & score when char_direction = '1'; 
    valid_weakness <= '1' when sw = "0000000000000001" or 
                               sw = "0000000000000010" or 
                               sw = "0000000000000100" or
                               sw = "0000000000001000" or
                               sw = "0000000000010000" or
                               sw = "0000000000100000" or
                               sw = "0000000001000000" or
                               sw = "0000000010000000" or
                               sw = "0000000100000000" or
                               sw = "0000001000000000" or
                               sw = "0000010000000000" or
                               sw = "0000100000000000" or
                               sw = "0001000000000000" or
                               sw = "0010000000000000" or
                               sw = "0100000000000000" or
                               sw = "1000000000000000" 
                               else '0'; 
    enemy_facing_temp <= enemy_divide * char_pos; 
    enemy_facing <= enemy_facing_temp (35 downto 32); 
    new_enemy <= conv_integer(random (8 downto 3)) mod 10; 
    update : process (clk_in) is 
    begin 
        if rising_edge(clk_in) then 
            count <= count + 1; 
            random_next <= random(47) xor random(46) xor random(45) xor random(30) xor random(16) xor random(10); 
            random (46 downto 0) <= random (47 downto 1); 
            random(47) <= random_next; 
            IF (count(10 DOWNTO 1) >= X"00F") AND (count(10 DOWNTO 1) < X"02E") THEN
		      	dac_load_L <= '1';
		    ELSE
			    dac_load_L <= '0';
		    END IF;
		    IF (count(10 DOWNTO 1) >= X"20F") AND (count(10 DOWNTO 1) < X"22E") THEN
			   dac_load_R <= '1';
		    ELSE 
		        dac_load_R <= '0';
		    END IF;
		    if count(24 downto 0) = 0 and sound_flag = '1' then
		        sound_flag <= '0'; 
		    end if; 
            if btnc = '1' and playing = '0' then 
                playing <= '1'; 
                char_pos <= "0100100100"; 
                char_direction <= '0'; 
                score <= conv_std_logic_vector(0, 16); 
                enemies_left <= (others => "000000000000000"); 
                enemies_right <= (others => "000001100010000"); 
                random (47 downto 32) <= count (15 downto 0); 
                random (31 downto 0) <= not count; 
            end if; 
            if playing = '1' and count(19 downto 0) = 0 then 
                if attack_flag = '1' and btnc = '0' then
                    attack_flag <= '0'; 
                end if; 
                if btnd = '1' and char_pos < 600 then 
                    char_pos <= char_pos + 4; 
                elsif btnu = '1' and char_pos > 16 then 
                    char_pos <= char_pos - 4;
                end if; 
                if btnl = '1' then 
                    char_direction <= '0'; 
                elsif btnr = '1' then 
                    char_direction <= '1'; 
                end if; 
                if btnc = '1' and attack_flag = '0' then 
                    attack_flag <= '1'; 
                    if valid_weakness = '1' then 
                        if char_direction = '0' and enemies_left(conv_integer(enemy_facing)) (14) = '1' and sw(conv_integer(enemies_left(conv_integer(enemy_facing)) (13 downto 10))) = '1' then 
                            score <= score + 1; 
                            enemies_left(conv_integer(enemy_facing)) <= "000000000000000"; 
                            audio_pitch <= "00010101100000";
                            sound_flag <= '1'; 
                        end if; 
                        if char_direction = '1' and enemies_right(conv_integer(enemy_facing)) (14) = '1' and sw(conv_integer(enemies_right(conv_integer(enemy_facing)) (13 downto 10))) = '1' then  
                            score <= score + 1; 
                            enemies_right(conv_integer(enemy_facing)) <= "000001100010000"; 
                            audio_pitch <= "00010101100000";
                            sound_flag <= '1'; 
                        end if; 
                    end if; 
                end if; 
            end if; 
            if playing = '1' and count (20 downto 0) = 0 then 
                if enemies_left(0) (14) = '1' then 
                    enemies_left(0) (9 downto 0) <= enemies_left(0) (9 downto 0) + 1; 
                else 
                    enemies_left(0) (9 downto 0) <= "0000000000"; 
                end if; 
                if enemies_left(1) (14) = '1' then 
                    enemies_left(1) (9 downto 0) <= enemies_left(1) (9 downto 0) + 1; 
                else 
                    enemies_left(1) (9 downto 0) <= "0000000000"; 
                end if; 
                if enemies_left(2) (14) = '1' then 
                    enemies_left(2) (9 downto 0) <= enemies_left(2) (9 downto 0) + 1; 
                else 
                    enemies_left(2) (9 downto 0) <= "0000000000"; 
                end if; 
                if enemies_left(3) (14) = '1' then 
                    enemies_left(3) (9 downto 0) <= enemies_left(3) (9 downto 0) + 1; 
                else 
                    enemies_left(3) (9 downto 0) <= "0000000000"; 
                end if; 
                if enemies_left(4) (14) = '1' then 
                    enemies_left(4) (9 downto 0) <= enemies_left(4) (9 downto 0) + 1; 
                else 
                    enemies_left(4) (9 downto 0) <= "0000000000"; 
                end if; 
                if enemies_left(5) (14) = '1' then 
                    enemies_left(5) (9 downto 0) <= enemies_left(5) (9 downto 0) + 1; 
                else 
                    enemies_left(5) (9 downto 0) <= "0000000000"; 
                end if; 
                if enemies_left(6) (14) = '1' then 
                    enemies_left(6) (9 downto 0) <= enemies_left(6) (9 downto 0) + 1; 
                else 
                    enemies_left(6) (9 downto 0) <= "0000000000"; 
                end if; 
                if enemies_left(7) (14) = '1' then 
                    enemies_left(7) (9 downto 0) <= enemies_left(7) (9 downto 0) + 1; 
                else 
                    enemies_left(7) (9 downto 0) <= "0000000000"; 
                end if; 
                if enemies_left(8) (14) = '1' then 
                    enemies_left(8) (9 downto 0) <= enemies_left(8) (9 downto 0) + 1; 
                else 
                    enemies_left(8) (9 downto 0) <= "0000000000"; 
                end if; 
                if enemies_left(9) (14) = '1' then 
                    enemies_left(9) (9 downto 0) <= enemies_left(9) (9 downto 0) + 1; 
                else 
                    enemies_left(9) (9 downto 0) <= "0000000000"; 
                end if; 
                
                if enemies_right(0) (14) = '1' then 
                    enemies_right(0) (9 downto 0) <= enemies_right(0) (9 downto 0) - 1; 
                else 
                    enemies_right(0) (9 downto 0) <= "1100010000"; 
                end if; 
                if enemies_right(1) (14) = '1' then 
                    enemies_right(1) (9 downto 0) <= enemies_right(1) (9 downto 0) - 1; 
                else 
                    enemies_right(1) (9 downto 0) <= "1100010000"; 
                end if; 
                if enemies_right(2) (14) = '1' then 
                    enemies_right(2) (9 downto 0) <= enemies_right(2) (9 downto 0) - 1; 
                else 
                    enemies_right(2) (9 downto 0) <= "1100010000"; 
                end if; 
                if enemies_right(3) (14) = '1' then 
                    enemies_right(3) (9 downto 0) <= enemies_right(3) (9 downto 0) - 1; 
                else 
                    enemies_right(3) (9 downto 0) <= "1100010000"; 
                end if; 
                if enemies_right(4) (14) = '1' then 
                    enemies_right(4) (9 downto 0) <= enemies_right(4) (9 downto 0) - 1; 
                else 
                    enemies_right(4) (9 downto 0) <= "1100010000"; 
                end if; 
                if enemies_right(5) (14) = '1' then 
                    enemies_right(5) (9 downto 0) <= enemies_right(5) (9 downto 0) - 1; 
                else 
                    enemies_right(5) (9 downto 0) <= "1100010000"; 
                end if; 
                if enemies_right(6) (14) = '1' then 
                    enemies_right(6) (9 downto 0) <= enemies_right(6) (9 downto 0) - 1; 
                else 
                    enemies_right(6) (9 downto 0) <= "1100010000"; 
                end if; 
                if enemies_right(7) (14) = '1' then 
                    enemies_right(7) (9 downto 0) <= enemies_right(7) (9 downto 0) - 1; 
                else 
                    enemies_right(7) (9 downto 0) <= "1100010000"; 
                end if; 
                if enemies_right(8) (14) = '1' then 
                    enemies_right(8) (9 downto 0) <= enemies_right(8) (9 downto 0) - 1; 
                else 
                    enemies_right(8) (9 downto 0) <= "1100010000"; 
                end if; 
                if enemies_right(9) (14) = '1' then 
                    enemies_right(9) (9 downto 0) <= enemies_right(9) (9 downto 0) - 1; 
                else 
                    enemies_right(9) (9 downto 0) <= "1100010000"; 
                end if; 
                
                if (enemies_left(0) (14) = '1' and enemies_left(0) (9 downto 0) >= 376) or (enemies_right(0) (14) = '1' and enemies_right(0) (9 downto 0) <= 408)
                or (enemies_left(1) (14) = '1' and enemies_left(1) (9 downto 0) >= 376) or (enemies_right(1) (14) = '1' and enemies_right(1) (9 downto 0) <= 408)
                or (enemies_left(2) (14) = '1' and enemies_left(2) (9 downto 0) >= 376) or (enemies_right(2) (14) = '1' and enemies_right(2) (9 downto 0) <= 408)
                or (enemies_left(3) (14) = '1' and enemies_left(3) (9 downto 0) >= 376) or (enemies_right(3) (14) = '1' and enemies_right(3) (9 downto 0) <= 408)
                or (enemies_left(4) (14) = '1' and enemies_left(4) (9 downto 0) >= 376) or (enemies_right(4) (14) = '1' and enemies_right(4) (9 downto 0) <= 408)
                or (enemies_left(5) (14) = '1' and enemies_left(5) (9 downto 0) >= 376) or (enemies_right(5) (14) = '1' and enemies_right(5) (9 downto 0) <= 408)
                or (enemies_left(6) (14) = '1' and enemies_left(6) (9 downto 0) >= 376) or (enemies_right(6) (14) = '1' and enemies_right(6) (9 downto 0) <= 408)
                or (enemies_left(7) (14) = '1' and enemies_left(7) (9 downto 0) >= 376) or (enemies_right(7) (14) = '1' and enemies_right(7) (9 downto 0) <= 408)
                or (enemies_left(8) (14) = '1' and enemies_left(8) (9 downto 0) >= 376) or (enemies_right(8) (14) = '1' and enemies_right(8) (9 downto 0) <= 408)
                or (enemies_left(9) (14) = '1' and enemies_left(9) (9 downto 0) >= 376) or (enemies_right(9) (14) = '1' and enemies_right(9) (9 downto 0) <= 408)
                then
                    playing <= '0'; 
                    audio_pitch <= "00010000110011";
                    sound_flag <= '1'; 
                end if; 
            end if; 
            if playing = '1' and count (26 downto 0) = 0 then 
                if random (1 downto 0) = 0 then 
                    if random (2) = '0' and enemies_left(new_enemy)(14) = '0' then 
                        enemies_left(new_enemy)(14) <= '1'; 
                        enemies_left(new_enemy)(13 downto 10) <= random(12 downto 9); 
                        enemies_left(new_enemy)(9 downto 0) <= "0000000000"; 
                    elsif random (2) = '1' and enemies_right(new_enemy)(14) = '0' then
                        enemies_right(new_enemy)(14) <= '1'; 
                        enemies_right(new_enemy)(13 downto 10) <= random(12 downto 9); 
                        enemies_right(new_enemy)(9 downto 0) <= "1100010000"; 
                    end if; 
                end if; 
            end if; 
        end if; 
    end process; 
    draw : process (S_pixel_row, S_pixel_col, char_pos, char_direction, enemies_left, enemies_right)
    begin 
        if playing = '1' then 
            if S_pixel_col >= 392 and S_pixel_col <= 408 and S_pixel_row <= char_pos and S_pixel_row >= (char_pos - 16) then
                if (char_direction = '0' and 400 - S_pixel_col <= char_pos - S_pixel_row and 400 - S_pixel_col <= S_pixel_row - char_pos + 16) 
                or (char_direction = '1' and S_pixel_col - 400 <= char_pos - S_pixel_row and S_pixel_col - 400 <= S_pixel_row - char_pos + 16) then
                    S_red <= "1111"; 
                    S_green <= "1010"; 
                    S_blue <= "0000"; 
                else 
                    S_red <= "0000"; 
                    S_green <= "1111"; 
                    S_blue <= "1111"; 
                end if; 
            else 
                S_red <= "0000"; 
                S_green <= "1111"; 
                S_blue <= "1111"; 
            end if; 
            if (enemies_left(0)(14) = '1' and S_pixel_col >= enemies_left(0)(9 downto 0) and S_pixel_col <= enemies_left(0)(9 downto 0) + 16 and S_pixel_row >= (0 * 60) + 14 and S_pixel_row <= (1 * 60) - 14) 
            or (enemies_right(0)(14) = '1' and S_pixel_col >= enemies_right(0)(9 downto 0) and S_pixel_col <= enemies_right(0)(9 downto 0) + 16 and S_pixel_row >= (0 * 60) + 14 and S_pixel_row <= (1 * 60) - 14) 
            or (enemies_left(1)(14) = '1' and S_pixel_col >= enemies_left(1)(9 downto 0) and S_pixel_col <= enemies_left(1)(9 downto 0) + 16 and S_pixel_row >= (1 * 60) + 14 and S_pixel_row <= (2 * 60) - 14)
            or (enemies_right(1)(14) = '1' and S_pixel_col >= enemies_right(1)(9 downto 0) and S_pixel_col <= enemies_right(1)(9 downto 0) + 16 and S_pixel_row >= (1 * 60) + 14 and S_pixel_row <= (2 * 60) - 14)
            or (enemies_left(2)(14) = '1' and S_pixel_col >= enemies_left(2)(9 downto 0) and S_pixel_col <= enemies_left(2)(9 downto 0) + 16 and S_pixel_row >= (2 * 60) + 14 and S_pixel_row <= (3 * 60) - 14)
            or (enemies_right(2)(14) = '1' and S_pixel_col >= enemies_right(2)(9 downto 0) and S_pixel_col <= enemies_right(2)(9 downto 0) + 16 and S_pixel_row >= (2 * 60) + 14 and S_pixel_row <= (3 * 60) - 14)
            or (enemies_left(3)(14) = '1' and S_pixel_col >= enemies_left(3)(9 downto 0) and S_pixel_col <= enemies_left(3)(9 downto 0) + 16 and S_pixel_row >= (3 * 60) + 14 and S_pixel_row <= (4 * 60) - 14)
            or (enemies_right(3)(14) = '1' and S_pixel_col >= enemies_right(3)(9 downto 0) and S_pixel_col <= enemies_right(3)(9 downto 0) + 16 and S_pixel_row >= (3 * 60) + 14 and S_pixel_row <= (4 * 60) - 14)
            or (enemies_left(4)(14) = '1' and S_pixel_col >= enemies_left(4)(9 downto 0) and S_pixel_col <= enemies_left(4)(9 downto 0) + 16 and S_pixel_row >= (4 * 60) + 14 and S_pixel_row <= (5 * 60) - 14)
            or (enemies_right(4)(14) = '1' and S_pixel_col >= enemies_right(4)(9 downto 0) and S_pixel_col <= enemies_right(4)(9 downto 0) + 16 and S_pixel_row >= (4 * 60) + 14 and S_pixel_row <= (5 * 60) - 14)
            or (enemies_left(5)(14) = '1' and S_pixel_col >= enemies_left(5)(9 downto 0) and S_pixel_col <= enemies_left(5)(9 downto 0) + 16 and S_pixel_row >= (5 * 60) + 14 and S_pixel_row <= (6 * 60) - 14)
            or (enemies_right(5)(14) = '1' and S_pixel_col >= enemies_right(5)(9 downto 0) and S_pixel_col <= enemies_right(5)(9 downto 0) + 16 and S_pixel_row >= (5 * 60) + 14 and S_pixel_row <= (6 * 60) - 14)
            or (enemies_left(6)(14) = '1' and S_pixel_col >= enemies_left(6)(9 downto 0) and S_pixel_col <= enemies_left(6)(9 downto 0) + 16 and S_pixel_row >= (6 * 60) + 14 and S_pixel_row <= (7 * 60) - 14)
            or (enemies_right(6)(14) = '1' and S_pixel_col >= enemies_right(6)(9 downto 0) and S_pixel_col <= enemies_right(6)(9 downto 0) + 16 and S_pixel_row >= (6 * 60) + 14 and S_pixel_row <= (7 * 60) - 14)
            or (enemies_left(7)(14) = '1' and S_pixel_col >= enemies_left(7)(9 downto 0) and S_pixel_col <= enemies_left(7)(9 downto 0) + 16 and S_pixel_row >= (7 * 60) + 14 and S_pixel_row <= (8 * 60) - 14)
            or (enemies_right(7)(14) = '1' and S_pixel_col >= enemies_right(7)(9 downto 0) and S_pixel_col <= enemies_right(7)(9 downto 0) + 16 and S_pixel_row >= (7 * 60) + 14 and S_pixel_row <= (8 * 60) - 14)
            or (enemies_left(8)(14) = '1' and S_pixel_col >= enemies_left(8)(9 downto 0) and S_pixel_col <= enemies_left(8)(9 downto 0) + 16 and S_pixel_row >= (8 * 60) + 14 and S_pixel_row <= (9 * 60) - 14)
            or (enemies_right(8)(14) = '1' and S_pixel_col >= enemies_right(8)(9 downto 0) and S_pixel_col <= enemies_right(8)(9 downto 0) + 16 and S_pixel_row >= (8 * 60) + 14 and S_pixel_row <= (9 * 60) - 14)
            or (enemies_left(9)(14) = '1' and S_pixel_col >= enemies_left(9)(9 downto 0) and S_pixel_col <= enemies_left(9)(9 downto 0) + 16 and S_pixel_row >= (9 * 60) + 14 and S_pixel_row <= (10 * 60) - 14)
            or (enemies_right(9)(14) = '1' and S_pixel_col >= enemies_right(9)(9 downto 0) and S_pixel_col <= enemies_right(9)(9 downto 0) + 16 and S_pixel_row >= (9 * 60) + 14 and S_pixel_row <= (10 * 60) - 14)
            then 
                S_red <= "1111"; 
                S_green <= "0000"; 
                S_blue <= "0000"; 
            end if; 
        else 
            S_red <= "1110"; 
            S_green <= "0000"; 
            S_blue <= "1000"; 
        end if; 
    end process; 
    vga_driver : vga_sync
    PORT MAP(--instantiate vga_sync component
        pixel_clk => pxl_clk, 
        red_in => S_red, 
        green_in => S_green, 
        blue_in => S_blue, 
        red_out => VGA_red, 
        green_out => VGA_green, 
        blue_out => VGA_blue, 
        pixel_row => S_pixel_row, 
        pixel_col => S_pixel_col, 
        hsync => VGA_hsync, 
        vsync => S_vsync
    );
    VGA_vsync <= S_vsync; --connect output vsync
    led : leddec16
    PORT MAP(
      dig => led_mpx, data => display, 
      anode => SEG7_anode, seg => SEG7_seg
    );
    clk_wiz_0_inst : clk_wiz_0
    port map (
      clk_in1 => clk_in,
      clk_out1 => pxl_clk
    );
    dac : dac_if
	PORT MAP(
		SCLK => count(5), -- instantiate parallel to serial DAC interface
		L_start => dac_load_L, 
		R_start => dac_load_R, 
		L_data => audio_data, 
		R_data => audio_data, 
		SDATA => dac_SDIN 
	);
	sound : tone
	PORT MAP(
		clk => count(10), -- instance a tone module
		pitch => audio_pitch, -- use pitch to modulate tone
		enabled => sound_flag,
		data => audio_data
	);
end behavioral; 
