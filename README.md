# CVBasic compiler v0.7.1
*(c) Copyright 2024 Óscar Toledo Gutiérrez*
*https://nanochess.org/*

CVBasic is a BASIC language cross-compiler with a syntax alike to QBasic originally written for the Colecovision video game console.

The CVBasic compiler can create programs up to 1 MB using the BANK statements (using 16K bank switching on most platforms, 8k on TI-99/4A). 

Later it was extended to support the following platforms:

* Sega SG-1000 / SC-3000  (supporting bank switching with Sega mapper)
* MSX 1 (supporting bank switching with ASCII16 mapper)
* Texas Instruments TI-99/4A (courtesy of @tursilion, supporting bank switching)
* Spectravideo SVI-318 / 328.
* Sord M5.
* Memotech MTX.
* Vtech Creativision (Dick Smith's Wizzard / Laser 2001).
* Tatung Einstein.
* Casio PV2000.
* Hanimex/Soundic Pencil II.
* NABU PC.

One of the advantages of using CVBasic is that all the programs can be compiled for all the platforms with mostly no modifications at all. Although the compiler started supporting only Z80, now this includes the 6502 based Creativision, and TMS9900 based TI-99/4A. This way it achieves a truly portable BASIC across the common theme: the video processor Texas Instruments TMS9128/9129.

The following files compose the compiler:

    cvbasic.h                   The CVBasic compiler global definitions.
    cvbasic.c                   The CVBasic compiler C language source code.
    cpu6502.h                   6502 code headers.
    cpu6502.c                   6502 code generation.
    cpu9900.h                   TMS9900 code headers.
    cpu9900.c                   TMS9900 code generation.
    cpuz80.h                    Z80 code headers.
    cpuz80.c                    Z80 code generation.
    driver.h                    Driver headers.
    driver.c                    Driver for all processors.
    node.h                      Tree node headers.
    node.c                      Tree node creation and optimization.
    LICENSE.txt                 Source code license

    cvbasic_prologue.asm        Prologue file needed for compiled programs.
    cvbasic_epilogue.asm        Epilogue file needed for compiled programs.
    cvbasic_6502_prologue.asm   Prologue file needed for 6502 compiled programs.
    cvbasic_6502_epilogue.asm   Epilogue file needed for 6502 compiled programs.
    cvbasic_9900_prologue.asm   Prologue file needed for TMS9900 compiled programs.
    cvbasic_9900_epilogue.asm   Epilogue file needed for TMS9900 compiled programs.

    manual.txt                  English manual for CVBasic

    README.md                   This file
    
    examples/bank.bas           Bank-switching example.
    examples/brinquitos.bas     Jumping game.
    examples/controller.bas     Controller test.
    examples/demo.bas           Demo of graphics.
    examples/face_joystick.bas  Moving face with joystick.
    examples/happy_face.bas     Bouncing face.
    examples/music.bas          Music example.
    examples/oscar_compressed.bas  High-resolution graphics example compressed with Pletter.
    examples/oscar.bas          High-resolution graphics example.
    examples/portrait.bas       Data used by demo.bas
    examples/space_attack.bas   Game example.
    examples/test1.bas          Moving stars.
    examples/test2.bas          Arithmetic test.
    examples/test3.bas          Shows usage of SELECT CASE / END CASE
    examples/varptr.bas         VARPTR example for redefining graphics.
    examples/vgm.bas            VGM audio player.
    examples/viboritas.bas      Game example.
    examples/vramcopy.bas       VRAM copy example.


### Usage guide

Using CVBasic to compile a Colecovision program:

    cvbasic game.bas game.asm
    gasm80 game.asm -o game.rom -l game.lst

You need to assemble the output file using Gasm80 available from [http://github.com/nanochess/gasm80](http://github.com/nanochess/gasm80) (this assembler serves for all the platforms, including Creativision based on 6502 CPU)

Using CVBasic to compile a Sega SG1000/SC3000 program:

    cvbasic --sg1000 game.bas game.asm
    gasm80 game.asm -o game.rom

Using CVBasic to compile a MSX program for 8K RAM (wider compatibility) and 16K RAM:

    cvbasic --msx game.bas game.asm
    gasm80 game.asm -o game.rom

    cvbasic --msx -ram16 game.bas game.asm
    gasm80 game.asm -o game.rom

Using CVBasic to compile a Colecovision Super Game Module program:

    cvbasic --sgm game.bas game.asm
    gasm80 game.asm -o game.rom

Using CVBasic to compile a Spectravideo SVI-318/328 program:

    cvbasic --svi game.bas game.asm
    gasm80 game.asm -o game.rom

Using CVBasic to compile a Sord M5 program:

    cvbasic --sord game.bas game.asm
    gasm80 game.asm -o game.rom

Using CVBasic to compile a Memotech MTX program:

    cvbasic --memotech game.bas game.asm
    gasm80 game.asm -o game.run
    
    cvbasic --memotech -cpm game.bas game.asm
    gasm80 game.asm -o game.com

Using CVBasic to compile a VTech Creativision (Dick Smith's Wizzard / Vtech Laser 2001) program:

    cvbasic --creativision game.bas game.asm
    gasm80 game.asm -o game.rom
    
You can use the -rom16 option to generate a 16K ROM instead of a 32K ROM, and it is provided utility/switch.c to switch the two 8K banks in a 16K ROM and run it with MAME, as MAME doesn't yet support 32K ROM. For 32K ROM you can use the Creativision emulator.

Using CVBasic to compile a Hanimex/Soundic Pencil II program (almost exactly like a Colecovision, but with 2K of RAM and different cartridge header):

    cvbasic --pencil game.bas game.asm
    gasm80 game.asm -o game.rom
    
Using CVBasic to compile a Tatung Einstein program:
    
    cvbasic --einstein game.bas game.asm
    gasm80 game.asm -o game.com
    
Using CVBasic to compile a Casio PV-2000 program:
    
    cvbasic --pv2000 game.bas game.asm
    gasm80 game.asm -o game.rom
    
Using CVBasic to compile a Texas Instruments TI-99/4A program:

    cvbasic --ti994a game.bas game.a99
    xas99.py -b -R game.a99
    linkticart.py game.bin game_8.bin "CARTNAME"
    
You require Python3 and the utilities from the xdt99 tool suite: [https://github.com/endlos99/xdt99](https://github.com/endlos99/xdt99)
    
The target is a stock TI-99/4A system with 32k memory expansion and joysticks. The cartridge binary can be used directly with the online emulator [js99er.net](js99er.net) or Classic99, and can be packed into an RPK for MAME (see README - TI99.md).

Using CVBasic to compile a NABU PC program:

    cvbasic --nabu game.bas game.asm
    gasm80 game.asm -o 000001.nabu
    zip game.npz 000001.nabu

    cvbasic --nabu -cpm game.bas game.asm
    gasm80 game.asm -o game.com

The .npz file is directlty usable by [MAME NABU port](https://github.com/ontheslab/nabu-mame-builds/releases) (put it in the nabu directory). The 000001.nabu name is important or it doesn't work. I've used the script _boot-built-in-adapter-local.sh_

I don't have tested the COM files for NABU CP/M yet.

### Notes

The current official version is v0.7.0.

All platforms have been tested in emulation.

* Colecovision and MSX have been tested in real hardware by myself.
* Sega SG1000/SC3000 tested in real hardware by aotta.
* Spectravideo SVI-318/328 tested in real hardware by Tony Cruise.
* Creativision / Dick Smith's Wizzard tested in real hardware by Scouter3d.
* NABU tested in real hardware by Sektor.

Untested:

* DEFINE VRAM READ is only tested for Colecovision/MSX, please test in your real hardware to check that the timing is right.

MSX controller support only handles the two joysticks and keyboard arrows (plus Space and M for buttons). The keys 0-9, Backspace and Return emulate the Colecovision keypad (CONT1.KEY only).

The Sega SG1000 doesn't have any keypad, so CONT1.KEY and CONT2.KEY aren't operative, but the support includes compatibility with Sega SC3000 computer, and the keyboard can be used as first controller (code contributed by SiRioKD) and for CONT1.KEY using the keys 0-9, Delete and CR.

The Spectravideo SVI-328 only has one button in the joystick. The keyboard can be used for the second button (letter M) and to have keypad (CONT1.KEY only) using the keys 0-9, Backspace and Return.

The Sord M5 can only use binaries up to 16 kb, both joysticks are handled as controllers, and the keyboard emulate the Colecovision keypad (CONT1.KEY only) using the keys 0-9, Backslash/Del and Return.

The Tatung Einstein can only use binaries up to 32 kb, keyboard is handled as controller 1 (joystick not used), and it can also emulate the Colecovision keypad (CONT1.KEY only) using the keys 0-9, Del/Ins and Enter.

The Casio PV-2000 can only use binaries up to 16 kb, the keyboard and joystick are controller 1, and it can emulate the Colecovision keypad (CONT1.KEY only) using the keys 0-9, Home/Cls and Return.

The Creativision can only use binaries up to 32 kb, the joysticks are controller 1 and controller 2, and it can emulate the Coleocovision keypad (CONT1.KEY only) using the keys 0-9, Left and RETN.

The TI-99/4A can only generate non-banked binaries up to 24 kb. When banking, the fixed space is 24k and pages are 8k. Both joysticks are supported with a single button. The second button is simulated on the keyboard with control for player 1 and fctn for player 2. CONT1.KEY will also return uppercase ASCII characters from the keyboard in addition to the stock 0-9, #, * for compatibility with Coleco programs. No keypad is implemented for controller 2 - only the joystick. The program supports FCTN-= (Alt-= on PC emulation) to reset.

The NABU PC can only use binaries up to 32 kb, joysticks can be used for both controllers, keyboard arrows are handled as controller 1, and it can also emulate the Colecovision keypad (CONT1.KEY only) using the keys 0-9, Del and Enter.

Many people is developing games using CVBasic, feel free to check some of these examples at the [AtariAge Colecovision Programming forum](https://forums.atariage.com/forum/55-colecovision-programming/)


### People using CVBasic

There are some very good examples of games developed with CVBasic.

* Beachhead by Eric Damain. Demo screenshots [https://forums.atariage.com/topic/373822-beach-head-dev-log-cvbasic/](https://forums.atariage.com/topic/373822-beach-head-dev-log-cvbasic/)

* Camelot Knights by nanochess. Available from [https://forums.atariage.com/topic/363252-camelot-knights-game/](https://forums.atariage.com/topic/363252-camelot-knights-game/)

* Colecovania demo by Skywaffle. Video at [https://www.youtube.com/watch?v=ixlAEZ0GSis&ab_channel=MatthewKiehl]((https://www.youtube.com/watch?v=ixlAEZ0GSis&ab_channel=MatthewKiehl)

* Donkey.BAS by Claus Bækkel. Available for purchase from [https://forums.atariage.com/topic/366153-donkeybas-game-coded-in-cvbasic-0500/](https://forums.atariage.com/topic/366153-donkeybas-game-coded-in-cvbasic-0500/)

* Manhole by Eric Damain. Available from [https://electric-dreams.itch.io/manhole-for-colecovision](https://electric-dreams.itch.io/manhole-for-colecovision)

* Monkey Moon by nanochess, example from the book **Programming Games for Colecovision**. Available from [https://forums.atariage.com/topic/365456-the-mystery-of-monkey-moon/#findComment-5478249](https://forums.atariage.com/topic/365456-the-mystery-of-monkey-moon/#findComment-5478249)

* Rogue-like Wip by Skywaffle. Available from [https://forums.atariage.com/topic/372717-colecovision-rogue-like-wip/](https://forums.atariage.com/topic/372717-colecovision-rogue-like-wip/)

* Unnamed game by OriginalJohn. Demo screenshot [https://forums.atariage.com/topic/365456-the-mystery-of-monkey-moon/#findComment-5471429](https://forums.atariage.com/topic/365456-the-mystery-of-monkey-moon/#findComment-5471429)

* Whack'em Smack'em Byron by Jess Ragan. Available from [https://forums.atariage.com/topic/364885-whack-em-smack-em-byron-dev-log/page/3/#findComment-5483961](https://forums.atariage.com/topic/364885-whack-em-smack-em-byron-dev-log/page/3/#findComment-5483961)

### Supporting the developer

If you find CVBasic useful, please show your appreciation making a donation via Paypal ($9 USD suggested) to b-i+y-u+b-i (at) gmail.com

If you find a bug, please report it to the same email address, and I'll try to look into it. Because lack of time I cannot guarantee it will be corrected.

You can also get my book **Programming Games for Colecovision** including an introductory course to game programming with CVBasic and full examples with source code: Game of Ball, Monkey Moon, Space Raider, Bouncy Cube, and Dungeon Warrior.

The foreword is written by the legendary David R. Megarry, programmer of Zaxxon™ for Colecovision, and creator of the Dungeon!™ Board game.

All the games in the book will compile for **all** the platforms (exception of Dungeon Warrior for Casio PV2000 because the small 16KB ROM size)

* [Programming Games for Colecovision, paperback, 250 pages](https://www.lulu.com/shop/oscar-toledo-gutierrez/programming-games-for-colecovision/paperback/product-95qvzj8.html?page=1&pageSize=4)
* [Programming Games for Colecovision, hardcover, 250 pages](https://www.lulu.com/shop/oscar-toledo-gutierrez/programming-games-for-colecovision/hardcover/product-84nm767.html?page=1&pageSize=4)
* [Programming Games for Colecovision, PDF ebook, 250 pages](https://nanochess.org/store.html)


### Acknowledgments

Thanks to the following members of Atariage for contributing valuable suggestions: abeker, aotta, ARTRAG, atari2600land, carlsson, chalkyw64, CrazyBoss, drfloyd, gemintronic, Jess Ragan, Kamshaft, Kiwi, pixelboy, SiRioKD, Tarzilla, Tony Cruise, tursilion, visrealm, wavemotion, and youki.
