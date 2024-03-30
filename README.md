# CVBasic compiler v0.4.3
*(c) Copyright 2024 Óscar Toledo Gutiérrez*
*https://nanochess.org/*

BASIC language cross-compiler for the Colecovision/SG1000/MSX.

    CVBasic.c               The CVBasic compiler C language source code
    LICENSE                 Source code license

    cvbasic_prologue.asm    Prologue file needed for compiled programs.
    cvbasic_epilogue.asm    Epilogue file needed for compiled programs.

    manual.txt              English manual for CVBasic

    README.md               This file


### Usage guide

Using CVBasic to compile a Colecovision program:

    cvbasic game.bas game.asm
    gasm80 game.asm -o game.rom -l game.lst

You need to assemble the output file using Gasm80 available from [http://github.com/nanochess/gasm80](http://github.com/nanochess/gasm80)

Using CVBasic to compile a Sega SG1000 program:

    cvbasic --sg1000 game.bas game.asm

Using CVBasic to compile a MSX program:

    cvbasic --msx game.bas game.asm


### Notes

The current official version is v0.4.3.

Sega SG1000 doesn't have any keypad, so CONT1.KEY and CONT2.KEY aren't operative.

MSX controller support only handles the two joysticks and keyboard arrows (plus Space and M for buttons).

TODO:
* Implement bank-switching for Colecovision (Megacart)
* Implement bank-switching for MSX (ASCII-16)
* Implement bank-switching for Sega SG1000 (Sega Mappers, casually also 16KB)


### Acknowledgments

Thanks to the following members of Atariage for contributing valuable suggestions:

    ARTRAG
    gemintronic
    Kiwi
    pixelboy
    youki

### Supporting the developer

If you find CVBasic useful, please show your appreciation making a donation via Paypal ($9 USD suggested) to b-i+y-u+b-i (at) gmail.com

If you find a bug, please report to same email and I'll try to look into it. Because lack of time I cannot guarantee it will be corrected.
