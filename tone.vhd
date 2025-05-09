LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Generates a 16-bit signed triangle wave sequence at a sampling rate determined
-- by input clk and with a frequency of (clk*pitch)/65,536
ENTITY tone IS
	PORT (
		clk : IN STD_LOGIC; -- 48.8 kHz audio sampling clock
		pitch : IN unsigned (13 DOWNTO 0); -- frequency (in units of 0.745 Hz)
		enabled : in std_logic; -- if the sound is playing 
	    data : OUT SIGNED (15 DOWNTO 0)); -- signed triangle wave out
END tone;

ARCHITECTURE Behavioral OF tone IS
	SIGNAL count : unsigned (15 DOWNTO 0); -- represents current phase of waveform
	SIGNAL quad : std_logic_vector (1 DOWNTO 0); -- current quadrant of phase
BEGIN
	-- This process adds "pitch" to the current phase every sampling period. Generates
	-- an unsigned 16-bit sawtooth waveform. Frequency is determined by pitch. For
	-- example when pitch=1, then frequency will be 0.745 Hz. When pitch=16,384, frequency
	-- will be 12.2 kHz.
	cnt_pr : PROCESS
	BEGIN
		WAIT UNTIL rising_edge(clk);
		count <= count + pitch;
	END PROCESS;
	quad <= std_logic_vector (count (15 DOWNTO 14)) when enabled = '1' else "00"; -- splits count range into 4 phases
	WITH quad SELECT
	data <= to_signed(32767, 16) WHEN "00", -- 1st quadrant
	        to_signed(0, 16) WHEN "01", -- 2nd quadrant
	        to_signed(-32767, 16) WHEN "10", -- 3rd quadrant
	        to_signed(0, 16) WHEN OTHERS; -- 4th quadrant
END Behavioral;
