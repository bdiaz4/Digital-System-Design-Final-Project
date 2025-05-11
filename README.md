# Digital-System-Design-Final-Project
## Expected Behavior
In "Weakness”, you control a triangular character that can use the directional buttons to move up and down and aim left or right (indicated by the direction the triangle is pointing), and the center button to eliminate an enemy or start the game if it is not currently running. Enemies appear on the sides of the screen and attempt to reach the player in the center.
The right 7-segment display (rightmost 4 digits) displays the number of successfully eliminated enemies. The left 7-segment display (leftmost 1 digit) displays the weakness number of the enemy the character is looking at.
The character cannot fire unless exactly 1 of the switches is on (up). An enemy with a certain enemy number can only be destroyed by a projectile with that respective number. 
You lose when an enemy reaches the center of the screen, where the player is located.

![](20250508_153933.jpg)
## Attachments
The Nexys board will utilize buttons for moving the player, switches for enemy targeting, and a 7-segment display for outputing game information.
The DAC module will play sound effects when the player successfully kills an enemy or when an enemy reaches the player when the game is over.\
The VGA to HDMI converter will be used to output visuals of the player character and enemies.

## Vivado and Nexys Upload
Uploading the VHDL code to the board involved the standard process of synthesizing, implementing, and generating a bitstream for the project, which was followed by connecting the board to Vivado and programming the device.\
![board](20250508_154102.jpg)
### Inputs:
Linear Shift Register RNG, Onboard buttons, switches
### Outputs:
Enemy placement/direction, player movement and direction, valid_weakness flag
## Starting Code
No lab code was directly started from, preferring to write the project from scratch to avoid errors. However, many vhd files were used for general setup of displays and peripherals. The Pong lab was used to set up the vga_sync, leddec16, clk_wiz_0, and clk_wiz_0_clk_wiz for the VGA and 7-segment display. Files from lab 5 tone and dac_if were reused to provide simple sound effects. Finally, the constraint file was built from prior documentation of the Nexys board with inputs added and taken away based on what was required.\
### Changes:
Leddec16- anodes 4, 5, and 6 were removed so the weakness value would be separated from the 4-digit score.
![display](20250508_153923.jpg)\
tone- The modified square wave was chosen to output sound effects and the pitch was changed based on player or enemy death.\
weakness.xdc- All 4 VGA color bits are defined to have access to more vivid colors.
