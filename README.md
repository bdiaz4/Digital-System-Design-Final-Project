# Digital System Design Final Project: "Weakness" 
---
## Expected Behavior
In this custom video game titled "Weakness”, the player controls a triangular character that can use the directional buttons to move up and down and aim left or right (indicated by the direction the triangle is pointing), and the center button to eliminate an enemy or start the game if it is not currently running (indicated by the red screen). 
- Enemies appear on the sides of the screen in rows and attempt to reach the player in the center.
- The right 7-segment display (rightmost 4 digits) displays the number of successfully eliminated enemies. The left 7-segment display (leftmost 1 digit) displays the weakness number of the enemy the character is looking at.
- The character cannot eliminate an enemy unless exactly 1 of the switches is on (up). An enemy with a certain enemy number can only be destroyed by pressing the center button with that respective number switch on. 
- You lose when an enemy reaches the center of the screen, where the player is located, and the screen will turn red again. 
- A square-wave sound is played through the DAC module every time an enemy is eliminated. A lower-pitch sound is played when the game ends due to an enemy reaching the center of the screen. 

![](20250508_153933.jpg)
---
## Attachments
- The Pmod I2S2 DAC module will play square-wave sound effects when the player successfully kills an enemy or when an enemy reaches the player when the game is over.
  - The module should be connected to Pmod port JA in the middle of the right side of the Nexys A7 board. 
- The female VGA connector will be connected to a display via a male VGA cable or the VGA to HDMI converter and will be used to output visuals of the player character and enemies.
  - Note: if the display supports audio, it is recommended to connect the DAC module output directly to the display's audio input, as the included DAC speaker is very quiet even at its maxiumu theoretical volume. 

---
## Vivado and Nexys Upload Instructions 
1. Create a new RTL project called *weakness* in Vivado
2. Download and import all `.vhd` source files from the GitHub page as source files to the project.
3. Download and import `weakness.xdc` as a constraints file to the project.
4. Choose Nexys A7-100T as the board utilized in the project. (Click 'Finish' afterwards) 
5. Run Synthesis
6. Run Implementation
7. Generate Bitstream
8. Open Hardware Manager, click Auto Connect, and Program Device followed by the device.
9. Ensure that all attachments and supplementary hardware, including the external display/speakers are on and functioning, and that they are properly connected to the device in accordance with the Attachments section.
10. The game should enter its initial state by displaying a red screen. 
![board](20250508_154102.jpg)
---
### Inputs:
- All 5 Onboard Buttons
- All 16 Onboard Switches
- Onboard 100MHz Clock 
### Outputs:
- 7-Segment Display
  - Shows the Weakness value and the current score
- VGA Connector
  - Shows the game state, character and all enabled enemies
- DAC Module (Pmod Port JA)
  - Plays a square-wave tone when an enemy is eliminated and a lower-pitched tone when the player is eliminated and the game ends 
---
## Starting Code/Changes: 
No specific lab code was a direct "starting point," as we initially began writing the primary project file from scratch to avoid unnecessary overhead in development. However, the project is loosely based around some files (particularly drivers) from Labs 3 and 5 (bouncing ball and siren) as these provided the basic starter code necessary to generate signals to control the VGA display and the DAC. The `leddec16` file was also modified to serve as a driver for the specific data to be rendered on the 7-segment displays. The Pong lab was used to set up the `vga_sync`, `leddec16`, `clk_wiz_0`, and `clk_wiz_0_clk_wiz` for the VGA and 7-segment display. 
- `vga_sync.vhd` is a general-purpose driver providing rendering capabilities for the board's built-in VGA output.
  - Notably, this file was not directly modified, as this would compromise its functionality, but the way in which it is utilized was different from previous labs, as all 4 bits of each color (RGB) were utilized within the input in `weakness.vhd` for a more diverse palette (and to make the character orange)
- `clk_wiz_0.vhd` and `clk_wiz_0_clk_wiz.vhd` are used unmodified to provide the 25MHz clock required by the VGA driver to function, creating a signal called `pxl_clk`for this purpose.
- `leddec16.vhd` was modified to have a 20-bit (5-digit) input signal, and the last 3 digits of the left display were disabled, with the 5 digits of the input being mapped to the 5 remaining digits.
  - The purpose of this change was to allow the input signal to contain a concatenation of the weakness value (leftmost digit) and the score (right 4 digits) with a separation between them. 
Files from lab 5 `tone` and `dac_if` were reused to provide simple square-wave based sound effects.
- Notably, automated pitch modulation was unnecessary, so `wail.vhd` was omitted, and the data from `tone.vhd` was directly mapped through to the `dac_if.vhd` file.
  - The `index` signal was removed entirely, as there was no need to generate any ramp-like waveforms.
  - A new input `enabled` was added to force the waveform to take on a singular value (thus not making a wave) when this signal was '0'. 
- `dac_if.vhd` was unmodified, but notably, its inputs in `weakness.vhd` had to be modified to function with a 100MHz clock as opposed to a 50MHz clock, so the `count` values were offset by 1. 
Finally, the constraints file `weakness.xdc` was built from prior documentation of the Nexys board with inputs added and taken away based on what was required for the inputs and outputs. 

## Development Process:
Leddec16- anodes 4, 5, and 6 were removed so the weakness value would be separated from the 4-digit score.
![display](20250508_153923.jpg)\
tone- The modified square wave was chosen to output sound effects and the pitch was changed based on player or enemy death.
weakness.xdc- All 4 VGA color bits are defined when controlling the VGA to have access to more vivid colors.
