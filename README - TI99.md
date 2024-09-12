The TI99 support is still experimental and in development.

Currently the following demos work:
test1, happy_face, example, face_joystick, vgm, test2, demo, music, portrait, oscar, space_attack, viboritas, oscar_compressed, bank

The current build creates an assembly language file intended to be assembled with xas99 from the xdt99 tool suite: 
https://github.com/endlos99/xdt99

Other assemblers are unlikely to work as it makes use of some of xdt99's features.

The target is a stock TI-99/4A system with 32k memory expansion and joysticks. Both joysticks are supported with a single button. The second button is simulated on the keyboard with control for player 1 and fctn for player 2. CONT1.KEY will also return uppercase ASCII characters from the keyboard in addition to the stock 0-9, #, * for compatibility with Coleco programs. No keypad is implemented for controller 2 - only the joystick.

The program supports FCTN-= (Alt-= on PC emulation) to reset.

The program is targeted to run from a bank-switched, non-inverted cartridge ROM. A cartridge and boot header is present in every bank to ensure clean resets, and the main program is copied to the 24k RAM bank at >A000 at startup. The 8k RAM block at >2000 is used for variables and stack. (This is significantly more than most projects require.) A further 125 8k ROM banks are available for a total space of 1MB (minus the runtime and the cartridge headers). 

    cvbasic --ti994a test2.bas test2.a99

The output of the compiler is an assembly file, it can be assembled like so:

    xas99.py -b -R test2.a99 -L test2.txt

Consult the xas99 manual for details, but in short you need the -b switch to generate binary output files and -R switch to define registers for this code. The optional -L provides a listing file if the assembly was successful.

The output of xas is one or more binary object files with a .bin extension. If your program does not use bank switching, there will be a single file. However, if it does, there will be multiple files generated - three for the fixed area and one for each additional bank you used.

For instance, the above program will create "test2.bin" if not banking, or "test2_b0.bin", "test2_b1.bin", "test2_b2.bin", "test2_b3.bin" and "test2_b4.bin" if the program uses two banks above 0. (Note that because 3 banks are reserved for the fixed space, "bank 1" in your program becomes "b3" in the output files).

Run the included python program "linkticart.py" to package these files up into a padded ROM file.

    linkticart.py test2.bin test2_8.bin     << non-banked
    linkticart.py test2_b0.bin test2_8.bin  << is banked
    
linkticart will automatically detect the other files if the name ends in "0.bin". Note that in both cases it is recommended the name end with "_8.bin". While this is not mandated by emulation, it is a convention that makes it clear what the file type is. If you don't there is a possibility that the letter before the '.bin' will be recognized as another tag and cause loading issues.

You can also pass a name for the cartridge for the selection screen, up to 20 characters long (uppercase ASCII only):

    linkticart.py test2.bin test2_8.bin "TEST2"

The resulting cartridge can be used directly on Classic99 and js99er. For MAME, it is necessary to create an "RPK" image. This is a zip file containing the ROM and a 'layout.xml'. The layout.xml contents are below (update with the correct romimage filename). Pack both files into a zip and rename from .zip to .rpk and it should work in MAME.

---------
<?xml version="1.0" encoding="utf-8"?>
<romset version="1.0">
   <resources>
      <rom id="romimage" file="test2_8.bin"/>
   </resources>
   <configuration>
      <pcb type="paged378">
         <socket id="rom_socket" uses="romimage"/>
      </pcb>
   </configuration>
</romset>
---------

The programs will no longer work from disk. If you have a need for that, let me know, we can add a configuration switch, but it is much more limited.
