The TI99 support is still experimental and in development.

Currently the following demos work:
test1, happy_face, example, face_joystick, vgm, test2, demo, music, portrait, oscar

The following do not work:
space_attack - unknown bug

The following require pletter compression which is not implemented:
viboritas, oscar_compressed

The following require bank switching which is not implemented:
bank

The current build creates an assembly language file intended to be assembled with xas99 from the xdt99 tool suite: 
https://github.com/endlos99/xdt99

Other assemblers are unlikely to work as it makes use of some of xdt99's ifdefs.

The target is a stock TI-99/4A system with 32k memory expansion and joysticks. Both joysticks are supported with a single button. The second button is simulated on the keyboard with control for player 1 and fctn for player 2. CONT1.KEY will also return uppercase ASCII characters from the keyboard in addition to the stock 0-9, #, * for compatibility with Coleco programs. No keypad is implemented for controller 2 - only the joystick.

The program is stored in the 24k memory expansion starting at >A000. The 8k RAM block at >2000 is used for variables and stack. (This is significantly more than most projects require.)

The output of the compiler is an assembly file, it can be assembled like so:

xas99.py -R test2.bas -L test2.txt

Consult the xas99 manual for details, but in short you need the -R switch to define registers for this code. -L provides a listing file if the assembly was successful. By default you can expect a number of warnings for "Possible branch/jump optimization". This is because xas99 detected a branch that could use the shorter jump instruction - but currently the compiler can't make that determination. Do scroll back and look for any actual errors (or check the docs to suppress this warning). 

At the end you will also see a list of "Unused constants". Do not be alarmed - this is normal:
read_pointer - unused in any program that does not use DATA statements
pletter_off  - unused until pletter is implemented
pletter_bit  - unused until pletter is implemented
key2_data    - unused cause no keyboard on controller 2

The output of xas is an uncompressed object file in Linux text format with an OBJ extension. You can load it directly in Classic99 as an E/A#3 file, and from there you can SAVE as a program image, or pack into a loader cartridge.

To do this:

- Select Cartridge->Apps->Editor/Assembler from the Classic99 menu
- Press any key to clear the title page
- Press '2' to Select Editor/Assembler
- Press '3' to Load and Run
- Enter the filename. If you stored the file in your DSK1 folder, this might be "DSK1.test2.obj".
- After the program loads, press enter to finish loading
- Enter 'START' as the run program name.

TODO:
- Find the bug crashing space_attack
- implement pletter decompression
- implement cartridge target (plan is a 24k loader cartridge with ROM support - so 24k fixed code space, 8k pages, and 8k RAM.)





