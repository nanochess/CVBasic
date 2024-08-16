# CVBasic compiler v0.6.0
*(c) Copyright 2024 Óscar Toledo Gutiérrez*
*https://nanochess.org/*

CVBasic is a BASIC language cross-compiler with a syntax alike to QBasic originally written for the Colecovision video game console.

The CVBasic compiler can create programs up to 1 MB using the BANK statements (using 16K bank switching). 

Later it was extended to support the following platforms:

* Sega SG-1000 (supporting bank switching with Sega mapper)
* MSX 1 (supporting bank switching with ASCII16 mapper)
* Spectravideo SVI-318 / 328.
* Sord M5.
* Memotech MTX.
* Vtech Creativision (Dick Smith's Wizzard / Laser 2001).
* Tatung Einstein.
* Casio PV2000.
* Hanimex/Soundic Pencil II.

One of the advantages of using CVBasic is that all the programs can be compiled for all the platforms with mostly no modifications at all. Although the compiler started supporting only Z80, now this includes the 6502 based Creativision. This way it achieves a truly portable BASIC across the common theme: the video processor Texas Instruments TMS9128/9129.

The following files compose the compiler:

    CVBasic.c                   The CVBasic compiler C language source code.
    cpu6502.h                   6502 code headers.
    cpu6502.c                   6502 code generation.
    cpuz80.h                    Z80 code headers.
    cpuz80.c                    Z80 code generation.
    driver.h                    Driver headers.
    driver.c                    Driver for both processors.
    node.h                      Tree node headers.
    node.c                      Tree node creation and optimization.
    LICENSE.txt                 Source code license

    cvbasic_prologue.asm        Prologue file needed for compiled programs.
    cvbasic_epilogue.asm        Epilogue file needed for compiled programs.

    manual.txt                  English manual for CVBasic

    README.md                   This file
    
    examples/bank.bas           Bank-switching example.
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
    examples/vgm.bas            VGM audio player.
    examples/viboritas.bas      Game example.


### Usage guide

Using CVBasic to compile a Colecovision program:

    cvbasic game.bas game.asm
    gasm80 game.asm -o game.rom -l game.lst

You need to assemble the output file using Gasm80 available from [http://github.com/nanochess/gasm80](http://github.com/nanochess/gasm80) (this assembler serves for all the platforms, including Creativision based on 6502 CPU)

Using CVBasic to compile a Sega SG1000 program:

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

Using CVBasic to compile a Hanimex/Soundic Pencil II program (almost exactly like a Colecovision, but with 2K of RAM and different cartridge header):

    cvbasic --pencil game.bas game.asm
    gasm80 game.asm -o game.rom
    
Using CVBasic to compile a Tatung Einstein program:
    
    cvbasic --einstein game.bas game.asm
    gasm80 game.asm -o game.com
    
Using CVBasic to compile a Casio PV-2000 program:
    
    cvbasic --pv2000 game.bas game.asm
    gasm80 game.asm -o game.rom
    
### Notes

The current official version is v0.6.0.

All platforms have been tested in emulation.

* Colecovision and MSX have been tested in real hardware by myself.
* Sega SG1000 tested in real hardware by aotta.
* Spectravideo SVI-318/328 tested in real hardware by Tony Cruise.
* Creativision / Dick Smith's Wizzard tested in real hardware by Scouter3d.

MSX controller support only handles the two joysticks and keyboard arrows (plus Space and M for buttons).

The Sega SG1000 doesn't have any keypad, so CONT1.KEY and CONT2.KEY aren't operative, but the support includes compatibility with Sega SC3000 computer, and the keyboard can be used as first controller (code contributed by SiRioKD)

The Spectravideo SVI-328 only has one button in the joystick. The keyboard can be used for the second button (letter M) and to have keypad.

The Sord M5 can only use binaries up to 16 kb, and the keyboard can be used for the first controller.

The Casio PV-2000 can only use binaries up to 16 kb.

Currently Memotech, Tatung Einstein, Casio PV-2000, and Creativision doesn't handle CONT1.KEY and CONT2.KEY.

Many people is developing games using CVBasic, feel free to check some of these examples at the [AtariAge Colecovision Programming forum](https://forums.atariage.com/forum/55-colecovision-programming/)


### Supporting the developer

If you find CVBasic useful, please show your appreciation making a donation via Paypal ($9 USD suggested) to b-i+y-u+b-i (at) gmail.com

If you find a bug, please report it to the same email address, and I'll try to look into it. Because lack of time I cannot guarantee it will be corrected.

You can also get my book **Programming Games for Colecovision** including an introductory course to game programming with CVBasic and full examples with source code: Game of Ball, Monkey Moon, Space Raider, Bouncy Cube, and Dungeon Warrior.

The foreword is written by the legendary David R. Megarry, programmer of Zaxxon™ for Colecovision, and creator of the Dungeon!™ Board game.

All the games in the book will compile for **all** the platforms.

* [Programming Games for Colecovision, paperback, 250 pages](https://www.lulu.com/shop/oscar-toledo-gutierrez/programming-games-for-colecovision/paperback/product-95qvzj8.html?page=1&pageSize=4)
* [Programming Games for Colecovision, hardcover, 250 pages](https://www.lulu.com/shop/oscar-toledo-gutierrez/programming-games-for-colecovision/hardcover/product-84nm767.html?page=1&pageSize=4)
* [Programming Games for Colecovision, PDF ebook, 250 pages](https://nanochess.org/store.html)


### Acknowledgments

Thanks to the following members of Atariage for contributing valuable suggestions: abeker, aotta, ARTRAG, atari2600land, carlsson, CrazyBoss, drfloyd, gemintronic, Jess Ragan, Kamshaft, Kiwi, pixelboy, SiRioKD, Tarzilla, Tony Cruise, wavemotion, and youki.
