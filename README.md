# Digital-System-Design-Final-Project
## Expected Behavior
In "Weakness”, you control a character that can use the directional buttons to move and the center button to fire a projectile. Enemies appear on the sides of the screen and attempt to reach the other side.
The right 7-segment display (rightmost 4 digits) displays the number of successfully eliminated enemies. The left 7-segment display (leftmost 1 digit) displays the enemy number of the enemy the character is looking at.
The character cannot fire unless exactly 1 of the switches is on (up). An enemy with a certain enemy number can only be destroyed by a projectile with that respective number  
You lose when an enemy touches you or the other wall.
## Attachments
The Nexys board will utilize buttons for moving the player, switches for enemy targeting, and a 7-segment display for outputing game information.
The DAC module will play either sound effects or music through the speaker
The VGA to HDMI converter will be used to output visuals of the player character and enemies.

## Vivado and Nexys Upload
Uploading the VHDL code to the board involved the standard process of synthesizing, implementing, and generating a bitstream for the project, which was followed by connecting the board to Vivado and programming the device.
Inputs:
Outputs:
## Starting Code
No lab code was directly started from, preferring to write the project from scratch to avoid errors. The pong lab was used to set up the vga_sync and leddec16 for the VGA display and 7-segment.
Changes:
