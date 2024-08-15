*
* CVBasic prologue (BASIC compiler, 9900 target)
* this is intended to be assembled by xdt99, no console ROM dependencies
*
* by Tursi
* https//harmlesslion.com
*
* based on code by
*
* by Oscar Toledo G.
* https//nanochess.org/
*
* Creation date Aug/05/2024.
* Revision date Aug/06/2024. Ported music player from Z80 CVBasic.
* Revision date Aug/07/2024. Ported Pletter decompressor from Z80 CVBasic.
*                            Added VDP delays.
* Revision date Aug/12/2024. Rewrite started for TMS9900 cpu
*

*
* Platforms supported:
* o TI-99/4A. (/4 supported if bitmap not used)
* o TI-99/4A with 32k Memory Expansion

*
* CVBasic variables in scratchpad.
*

* TODO: Concern - changing the endianess of 16-bit values from little to big,
* does anything break? Ideally not if I'm careful...

* data storage in scratchpad
    aorg >8300

* This is a block of 8 bytes that should stay together.
* TODO: check if we need these
*temp		bss 2
*temp2		bss 2
*result		bss 2
*pointer	    bss 2

read_pointer	bss 2
cursor		    bss 2
pletter_off	    bss 2  * Used by Pletter

* Joystick storage
* TODO: check if we need these - I think they are bios
*joy1_dir	    bss 2   * word
*joy2_dir	    bss 2   * word
*joy1_buttons	bss 1   * byte
*joy2_buttons	bss 1   * byte

* more joystick bytes
joy1_data	    bss 1 
joy2_data	    bss 1

key1_data	    bss 1       * byte - keyboard
key2_data	    bss 1       * byte - keyboard (not used)

frame	        bss 2       * word
lfsr		    bss 2       * word MUST BE EVEN ALIGNED

mode            bss 1
flicker         bss 1

sprite_data	    bss 4       * 2 words MUST BE EVEN ALIGNED

ntsc            bss 1
pletter_bit     bss 1

* register backup          * backup space for registers for interrupt - in scratchpad for speed
intreg_backup   bss 22     * need room for 11 regs - 22 bytes

    IF CVBASIC_MUSIC_PLAYER     * TODO: how do IFs work in xdt99?
music_playing		bss 1
music_timing		bss 1       

music_start		    bss 2       * word
music_pointer		bss 2       * word

music_note_counter	bss 1
music_instrument_1	bss 1

music_note_1		bss 1
music_counter_1	    bss 1

music_instrument_2	bss 1
music_note_2		bss 1

music_counter_2	    bss 1
music_instrument_3	bss 1

music_note_3		bss 1
music_counter_3	    bss 1

music_drum		    bss 1
music_counter_4	    bss 1

audio_freq1		    bss 2       * word
audio_freq2		    bss 2       * word
audio_freq3		    bss 2       * word

audio_vol1  		bss 1
audio_vol2	    	bss 1

audio_vol3		    bss 1
audio_vol4hw		bss 1

audio_noise 		bss 1
audio_control		bss 1

music_mode	    	bss 1
    even
    ENDIF

* While we don't mean to USE the console ROM, for interrupts we
* are forced to interface with some of it. We need these addresses
* to minimize what it does so we can maximize our use of scratchpad.
* While I'd like to use the cassette hook - requires only 10 instructions
* and only uses 6 words of scratchpad, we can't here because it
* loses the return address, meaning you can only use it if you
* know where your LIMI 2 is and interrupts are otherwise disabled. So
* we have to use the longer but more standard interrupt hook, which also
* reads VDP status for us (no choice).

intcnt              equ >8379   * interrupt counter byte, adds 1 (from GPLWS r14) every frame
statusmirror        equ >837B   * VDP status byte mirror
intwsr1             equ >83c2   * INT WS R1  - interrupt control flags - must be >8000
intwsr2             equ >83c4   * INT WS R2  - address of user interrupt routine (point to int_handler)
intwsr11            equ >83d6   * screen timeout counter - must be odd (init to 1, is inct every frame)
intwsr13            equ >83da   * INT WS R13 - used for interrupt call (word)
intwsr14            equ >83dc   * INT WS R14 - used for interrupt call (word)
intwsr15            equ >83de   * INT WS R15 - used for interrupt call (word)
gplwsr11            equ >83f6   * GPL WS R11 - return address to interrupt ROM (not used, but overwritten each int)
gplwsr12            equ >83f8   * GPL WS R12 - used for cassette test and interrupt hook test (zeroed each int)
gplwsr13            equ >83fa   * GPL WS R13 - used in my interrupt handler
gplwsr14            equ >83fc   * GPL WS R14 - flags used to detect cassette - must be >0108 (or at least >0020 clear)
gplwsr15            equ >83fe   * GPL WS R15 - base address of VDP for status read - must be >8C00

* Some hardware equates
INTWP     equ >83C0     * interrupt calling WP
GPLWP     equ >83E0     * we use this one
SOUND     equ >8400
VDPDATA   equ >8800
VDPSTATUS equ >8802
VDPWDATA  equ >8c00
VDPWADR   equ >8c02

* We'll also use GPLWS as our workspace - so we have to avoid R12-R15 (and use R11 carefully)

* Safe scratchpad RAM, assuming above setup (ints disabled by flag, screen blank disabled):
* Need to see how much BSS is using
* 8300 - 8377   ->  120 bytes
* 837C - 83C1   ->   70 bytes

* RAM we need:
* - 128 bytes for a sprite table double-buffer - no choice, needs to go in 8-bit RAM
* - TBD bytes defined above for BASIC
* - 48 bytes for interrupt ROM and workspace

* Variables are defined by equ, and can be bytes or words. Since it's originally an 8-bit
* target, we can assume mostly bytes. For now we'll just do an EA#5 target. We can consider
* a cart+32k target later if it's desired. This will limit programs to 24k + 8k of RAM data.
* if we do cart+32k then we have 8k of variables, 24k of fixed space, and unlimited paged space
* (though the compiler limits to 1MB). But I'll need to bring in my paging code and startup.

* data in low RAM
    aorg >2000

* must be even aligned - TODO: hard coded address? where does the compiler define variables?
* mirror for sprite table
sprites	    bss 128

* program in high RAM
    aorg >a000

* Utility functions

* Write register to VDP - R0 = reg in MSB, data in LSB
WRTVDP
    ori r0,>8000
    jmp SETRD

* Set VDP for write address - address in R0
SETWRT
    ori r0,>4000
* fall through

* Set VDP for read address - address in R0
SETRD
    swpb r0
    movb r0,@VDPWADR
    swpb r0
    movb r0,@VDPWADR
    b *r11

* Write byte to VDP - address in R0, data in MSB R2
* Inline address set to avoid needing to cache r11
WRTVRM
    ori r0,>4000
    swpb r0
    movb r0,@VDPWADR
    swpb r0
    movb r0,@VDPWADR
* No need to delay after setting a write address - there's no VRAM access
    movb r2,@VDPWDATA
    b *r11

* Read byte from VDP - address in R0, data returned in MSB R2
* Inline address set to avoid needing to cache r11
RDVRM
    swpb r0
    movb r0,@VDPWADR
    swpb r0
    movb r0,@VDPWADR
    nop
    movb @VDPDATA,r2
    b *r11

* Fill VRAM - address in R0, byte in R2, count in R3
* TODO: Original: address in pointer, byte in temp, count in temp2 (ZP)
* Inline address set to avoid needing to cache r11
FILVRM
    ori r0,>4000
    swpb r0
    movb r0,@VDPWADR
    swpb r0
    movb r0,@VDPWADR
* No need to delay after setting a write address - there's no VRAM access
.1
    movb r2,@VDPWDATA
    dec r3
    jne .1
    b *r11

* Load VRAM - address in R0, CPU data at R2, count in R3
* TODO: Original: address in pointer, CPU address at temp, count in temp2
* Inline address set to avoid needing to cache r11
LDIRVM
    ori r0,>4000
    swpb r0
    movb r0,@VDPWADR
    swpb r0
    movb r0,@VDPWADR
* No need to delay after setting a write address - there's no VRAM access
.1
    movb *r2+,@VDPWDATA
    dec r3
    jne .1
    b *r11

* Define a pattern three times with 2k offsets - used for bitmap color and pattern tables
* Load VRAM 3 times with offset - address in R0, CPU data at R2, count in R3
* TODO: Original: address in pointer, CPU address at temp, count in temp2
LDIRVM3
    mov r11,r4      * save return address
    mov r2,r5       * save CPU address
    mov r3,r7       * save count
    bl @LDIRVM
    ai r0,>0800     * the OR'd mask doesn't matter
    mov r5,r2       * restore CPU
    mov r7,r3       * restore count
    bl @LDIRVM
    ai r0,>0800     * the OR'd mask doesn't matter
    mov r5,r2
    mov r7,r3
    mov r4,r11      * for tail recursion
    b @LDIRVM

* Disable screen by setting VDP register 1 to >a2
DISSCR
    limi 0
    li r0,>a281
DISSCR2
    swpb r0
    movb r0,@VDPWADR
    swpb r0
    movb r0,@VDPWADR
    limi 2
    b *r11

* enable screen by setting VDP register 1 to >E2
ENASCR
    limi 0
    li r0,>e281
    jmp DISSCR2

* copy a set of blocks of data to VDP, offset by 32 bytes each
* address in R0, CPU data at R2, count per row in R3, number rows in R4, CPU stride in R5 (VDP stride fixed at 32)
* original: address in pointer, CPU address at temp, count in temp2, stride in YYXX
CPYBLK
    limi 0
    mov r11,r7      * save return
    mov r0,r8       * save vdp address
    mov r2,r9       * save cpu address
    mov r3,r10      * save count per row
    jmp .2          * skip over the restore step
.1
    mov r8,r0       * get vdp address
    mov r9,r2       * get cpu address
    mov r10,r3      * get count
.2
    bl @LDRIVM      * copy one row
    a r5,r9         * add stride to CPU address
    ai r8,32        * add 32 to VDP
    dec r4          * count down rows
    jne .1          * loop till done
    limi 2
    b *r7           * back to caller

* clear screen and reset cursor to >1800
cls
    mov r11,r4      * save return
    li r0,>1800     * SIT address
    mov r0,@cursor  * save cursor
    li r2,>2000     * byte to write
    li r3,768       * number of bytes
    limi 0          * ints off
    bl @FILVRM      * write them
    limi 2          * ints back on
    b *r4           * back to caller

* copy a string to screen at cursor - address enforced
* CPU address in R2, length in R3
print_string
    mov r11,r4      * save return
    mov @cursor,r0  * get cursor pos
    andi r0,>07ff   * enforce position - pretty large range though? 80 column support maybe?
    ai r0,>1800     * add is safer than OR, and we have that option
    a r3,@cursor    * add the count to cursor (might as well do it now!)
    limi 0
    bl @LDIRVM      * do the write
    limi 2
    b *r4           * back to caller

* emit a 16-bit number as decimal with leading zero masking at cursor
* R0 - number to print
* original number in YYAA?
print_number
    mov r11,r4          * save return address
    limi 0              * interrupts off so we can hold the VDP address
    mov r0,r3           * save value off
    mov @cursor,r0      * get cursor
    andi r0,>07ff       * enforce position - pretty large range though? 80 column support maybe?
    ai r0,>1800         * add is safer than OR, and we have that option
    bl @SETWRT          * set write address
    clr r5              * leading zero flag

print_number5
    clr r2              * make r2/r3 a 32-bit value
    li r1,10000         * divisor
    div r1,r2           * yields quotient(r2), remainder(r3)
    mov r2,r2           * check for zero
    jeq print_number4   * skip ahead if so
    li r5,>0030         * ascii 48 to OR in so we can make a single test instead of 2
    soc r5,r2           * OR in the ASCII
    swpb r2             * get value into MSB
    movb r2,@VDPWDATA   * write it
    inc @cursor         * track it

print_number4
    clr r2              * make r2/r3 a 32-bit value
    li r1,1000          * divisor
    div r1,r2           * yields quotient(r2), remainder(r3)
    soc r5,r2           * OR in the leading flags
    jeq print_number3   * if result was 0 and leading flags are zero, skip
    li r5,>0030         * ascii 48 to OR in so we can make a single test instead of 2
    soc r5,r2           * we have to OR again, but it's a net wash compared to an extra test and jump
    swpb r2             * get value into MSB
    movb r2,@VDPWDATA   * write it
    inc @cursor         * track it

print_number3
    clr r2              * make r2/r3 a 32-bit value
    li r1,100           * divisor
    div r1,r2           * yields quotient(r2), remainder(r3)
    soc r5,r2           * OR in the leading flags
    jeq print_number2   * if result was 0 and leading flags are zero, skip
    li r5,>0030         * ascii 48 to OR in so we can make a single test instead of 2
    soc r5,r2           * we have to OR again, but it's a net wash compared to an extra test and jump
    swpb r2             * get value into MSB
    movb r2,@VDPWDATA   * write it
    inc @cursor         * track it

print_number2
    clr r2              * make r2/r3 a 32-bit value
    li r1,10            * divisor
    div r1,r2           * yields quotient(r2), remainder(r3)
    soc r5,r2           * OR in the leading flags
    jeq print_number1   * if result was 0 and leading flags are zero, skip
    li r5,>0030         * ascii 48 to OR in so we can make a single test instead of 2
    soc r5,r2           * we have to OR again, but it's a net wash compared to an extra test and jump
    swpb r2             * get value into MSB
    movb r2,@VDPWDATA   * write it
    inc @cursor         * track it

print_number1
    ori r3,>0030        * we know we always print this one
    swpb r3             * get value into MSB
    movb r3,@VDPWDATA   * write it
    inc @cursor         * track it

    limi 2              * ints on
    b *r4               * back to caller

* Load sprite definitions: Sprite char number in R0, CPU data in R2, count of sprites in R3
* Original: pointer = sprite char number, temp = CPU address, a = number sprites
* Note: sprites are all expected to be double-size 16x16, 32 bytes each, so sprite char 1 is character 4
* Sprite pattern table at >3800? TODO
define_sprite
    mov r11,r4          * save return
    sla r0,5            * char number times 32
    ai r0,>3800         * add VDP base
    sla r3,5            * count times 32
    limi 0              * ints off
    bl @LDIRVM          * do the copy
    limi 2              * ints on
    b *r4               * back to caller

* Load character definitions: Char number in R0, CPU data in R2, count in R3
* Original: pointer = char number, temp = CPU address, a = number chars
* Note this loads the pattern three times if in bitmap mode (MODE&0x04)
* Pattern table at >0000
define_char
    mov r11,r8          * save return
    sla r0,3            * char number times 8 (VDP base is 0, so already there)
    sla r3,3            * count times 8
    mov @mode,r5        * get mode flags
    andi r5,>0004
    jne .1              * not in bitmap mode, do a single copy

    limi 0              * ints off
    bl @LDIRVM3         * do the triple copy
    limi 2              * ints on
    b *r8               * back to caller

.1
    limi 0              * ints off
    bl @LDIRVM          * do the single copy
    limi 2              * ints on
    b *r8               * back to caller

* Load bitmap color definitions: Char number in R0, CPU data in R2, count in R3
* Original: pointer = char number, temp = CPU address, a = number chars
* Note: always does the triple copy. Color table at >2000
define_color
    mov r11,r8          * save return
    sla r0,3            * char number times 8
    ai r0,>2000         * add base address
    sla r3,3            * count times 8
    limi 0              * ints off
    bl @LDIRVM3         * do the triple copy
    limi 2              * ints on
    b *r8               * back to caller

* Update sprite entry - copy sprite_data (4 bytes) to sprite table mirror at sprites
* R0 = sprite number
* Original: A = sprite number
update_sprite
    sla r0,2            * x4 for address
    ai r0,sprites       * sprite mirror address
    li r2,sprite_data   * single sprite data
    mov *r2+,*r0+       * move two bytes (must be aligned)
    mov *r2,*r0         * move second two bytes
    b *r11

* ABS R0 - this is a single opcode, see if we can inline it - TODO (YYAA?)
*_abs16

* NEG R0 - this is a single opcode, see if we can inline it - TODO (YYAA?)
*_neg16

* SGN R0 - return 1, -1 or 0 as 16 bit
_sgn16
    mov r0,r0       * check for zero
    jeq .1          * if yes, we're done
    andi r0,>8000   * check for negative
    jeq .2          * was not
    seto r0         * was negative, make it -1
    b *r11          * back to caller
.2
    inc r0          * we know it was zero, and we want 1
.1
    b *r11          * back to caller

* Read 16 bits from read_pointer into r0, see if we can inline it - TODO (YYAA)
* Used to call read8 twice, but I don't know where that is
*_read16

* Read 8 bits from R0 into R0 - see if we can inline it - TODO (YYAA)
*_peek8

* Read 8 bits from R0 into R0 - see if we can inline it - TODO (YYAA -> YYAA)
*_peek16

* 16 bit multiply = temp2*temp - see if we can inline it - TODO (stack*stack -> YYAA)  
*_mul16

* 16-bit signed modulo. R3 % R0 = R0 - 9900 doesn't do signed divide
* original was stack%stack=YYAA
* Remainder is negative if the dividend was negative
_mod16s
    clr r2          * make dividend 32-bit
    mov r0,r0       * check divisor for zero
    jne .1          * continue if not

    clr r0          * result is zero
    b *r11          * return

.1
    abs r0          * make sure divisor is positive
    mov r3,r3       * check sign of dividend
    jgt .2          * go do the faster positive version

    abs r3          * was negative, make it positive
    div r0,r2       * do the division => r2=quotient, r3=remainder
    neg r3          * make remainder negative
    mov r3,r0       * into r0
    b *r11

.2
    div r0,r2       * do the division => r2=quotient, r3=remainder
    mov r3,r0       * into r0
    b *r11

* 16-bit signed modulo. R3 % R0 = R0 - 9900 doesn't do signed divide
* original was stack/stack=YYAA
* Remainder is negative if the signs differ
_div16s
    mov r0,r0       * check divisor for zero
    jne .1          * continue if not

    clr r0          * result is zero (maybe should be max_int?)
    b *r11          * return

.1
    mov r0,r4       * make working copies
    mov r3,r5
    andi r4,>8000   * mask out sign bit
    andi r5,>8000
    abs r0
    abs r3          * might as well make them positive now that we have copies
    clr r2          * make dividend 32-bit
    div r0,r2       * do the divide => r2=quotient, r3=remainder
    c r4,r5         * compare the original sign bits
    jeq .2          * skip ahead to positive version

    neg r2          * negate the result
.2
    mov r2,r0       * move to return
    b *r11

* unsigned 16-bit div - see if we can do this inline (TODO)
* original was stack/stack=YYAA
*_div16

* unsigned 16-bit mod - see if we can do this inline (TODO)
* original was stack%stack=YYAA
*_mod16

* Random number generator - return in R0
* Original output into YYAA
* TODO: Not 100% sure I ported this one right... probably could be simpler with 16-bit manips...
random
    mov @lfsr,r0        * fetch current state
    jne .0
    li r0,>7811         * reset value if zero
    mov r0,@lfsr
.0
    movb @lfsr+1,r0
    movb @mywp,@mywp+1  * trick, copy msb to lsb (so the 16-bit rotate works)
    mov r0,r3           * we use this again
    src r0,2            * circular rotate twice (rotates directly like z80)
    xor @lfsr+1,r0      * because of 16 bit addressing, only the LSB is correct
    movb @mywp+1,@mywp  * fix up - copy LSB to MSB
    mov r0,r2           * save it (temp)
    src r3,1            * rotate the second read once
    xor r3,r2           * xor into the temp copy
    movb @lfsr,r0       * get the lsb
    sla r0,2            * just a straight shift
    xor r2,r0           * xor the temp copy in (both bytes of r2 were valid)
    andi r0,>8000       * mask out just the msb
    mov @lfsr,r2        * get word for shifting
    srl r2,1            * shift once
    socb r0,r2          * merge in the msb we just generated
    mov r2,@lfsr        * write it back
    mov r2,r0           * for return
    b *r11


* Set SN Frequency: R0=freqency code, R2=channel command (MSB)
* Original: A=least significant byte  X=channel command  Y=most significant byte
sn76489_freq
    mov r0,r3
    andi r3,>000f
    swpb r3
    socb r3,r2
    movb r2,@SOUND  * cmd and least significant nibble
    srl r0,4
    andi r0,>003f
    swpb r0
    movb r0,@SOUND  * most significant byte
    b *r11

* Set SN volume: R0=volume (MSB, inverse of attenuation), R2=channel command (MSB)
* Original: A=volume (inverse of attenuation), X=channel command
sn76489_vol
    inv r0
    andi r0,>0f00
    socb r2,r0
    movb r0,@SOUND
    b *r11

* Set noise type: R0=Noise type (MSB)
* original: A=noise command
sn76489_control
    andi r0,>0f00
    ori r0,>e000
    movb r0,@SOUND
    b *r11

* Set up vdp generic settings - R0 should be preloaded with a register in MSB, data in LSB
* R2 should contain the color table entry (in MSB), R3 the bitmap table (in MSB). Rest is
* hard coded. WARNING: Disables interrupts but does not re-enable them.
vdp_generic_mode
    mov r11,r4      * save return
    limi 0          * ints off

    bl @WRTVDP      * caller must set up this one
    li r0,>01a2     * VDP mode, screen off
    bl @WRTVDP
    li r0,>0206     * >1800 pattern table
    bl @WRTVDP
    li r0,>0003     * for color table
    socb r2,r0
    swpb r0
    bl @WRTVDP
    li r0,>0004     * for pattern table
    socb r3,r0
    swpb r0
    bl @WRTVDP
    li r0,>0536     * >1b00 for sprite attribute table
    bl @WRTVDP
    li r0,>0607     * >3800 for sprite pattern table
    bl @WRTVDP
    li r0,>0701     * default screen color
    bl @WRTVDP
    b *r4

* set up VDP mode 0
mode_0
    mov r11,r8      * careful - we call vdp_generic_mode and LDIRVM3
    li r0,>0400     * bit we want to clear
    szcb r0,@mode

    li r2,>ff00	    * $2000 for color table.
    li r3,>0300	    * $0000 for bitmaps
    li r0,>0002     * r0 setting
    bl @vdp_generic_mode    * interrupts are now off

    li r0,>0100     * target in VDP memory
    li r2,font_bitmaps  * CPU memory source
    li r3,>0300     * number of bytes
    bl @LDIRVM3
    
    limi 2
    limi 0

    li r0,>2000
    li r2,>f000
    li r3,>1800     * fill color table with white on transparent
    bl @FILVRM

    limi 2
    bl @cls
    mov r8,r11      * restore return address, and fall through to vdp_generic_sprites

* Initialize sprite table
vdp_generic_sprites
    mov r11,r8      * save return address
    li r0,>1b00     * sprite attribute table in VDP
    li r2,>d100     * off screen, and otherwise unimportant
    li r3,128       * number of bytes

    limi 0
    bl @FILVRM

    li r0,sprites
    li r2,>d1d1     * write 2 bytes at a time
    li r3,128
.1
    mov r2,*r0+     * initialize CPU mirror
    dect r3
    jne .1

    li r0,>01e2     * screen on
    bl @WRTVDP

    limi 2
    b *r8

* set up VDP mode 1
mode_1
    mov r11,r8      * careful - we call vdp_generic_mode and LDIRVM3
    li r0,>0400     * bit we want to clear
    szcb r0,@mode

    li r2,>ff00	    * $2000 for color table.
    li r3,>0300	    * $0000 for bitmaps
    li r0,>0002     * r0 setting
    bl @vdp_generic_mode    * interrupts are now off

    li r0,>0000
    li r2,>0000
    li r3,>1800
    bl @FILVRM      * clear pattern table

    limi 2

    li r0,>2000
    li r2,>f000
    li r3,>1800

    limi 0
    bl @FILVRM      * init color table
    limi r2

    li r0,>5800     * >1800 with the write bit set

.1
    limi 0          * write the screen image table, but pause every 32 bytes for interrupts

    swpb r0
    movb r0,@VDPWADR
    swpb r0
    movb r0,@VDPWADR

    li r2,32
    mov r0,r3
    swpb r3         * address LSB, no need to mask it, we don't do any compares

.2
    movb r3,@VDPWDATA
    ai r3,>0100
    dec r2
    jne .2

    limi 2
    ai r0,32
    ci r0,>1b00
    jl .1

    mov r8,r11      * restore return address
    b @vdp_generic_sprites

* Set up VDP mode 2
mode_2
    mov r11,r8      * careful - we call vdp_generic_mode and LDIRVM3
    li r0,>0400     * bit we want to clear
    szcb r0,@mode

    li r2,>8000	    * $2000 for color table.
    li r3,>0000	    * $0000 for bitmaps
    li r0,>0000     * r0 setting
    bl @vdp_generic_mode    * interrupts are now off

    li r0,>0100
    li r2,font_bitmaps
    li r3,>0300
    bl @LDIRVM      * load character set

    limi 2
    limi 0

    li r0,>2000
    li r2,>f000
    li r3,>0020
    bl @FILVRM      * init color table

    limi 2
    bl @cls         * clear screen
    mov r8,r11      * restore return
    b @vdp_generic_sprites

* this is where interrupts happen every frame
* Unlike a normal TI application, this one runs with interrupts ON,
* so all operations need to be sure to protect VDP address with LIMI 0,
* as well as any operations that might need to manipulate data managed
* by this interrupt. We enter via the normal user hook, so WP is already
* GPLWS, interrupts are off, and the VDP is already reset and status 
* stashed on statusmirror (>837b). Our return address to the ROM is in
* r11, but we are NOT going to use it so that we don't need to reserve
* r8 for whatever nonsense it does. That means we need to load intws
* and RTWP ourselves at the end. Since the compiler may inject user
* code, we need to save all our free registers anyway, so we should feel
* free to use what we will. (The normal TI approach would be a separate
* workspace, but we'd have to save the regs anyway since there are some
* functions that assume the WP address.) We can freely use R11,R12,R13
* for temporary data, though R11 will not carry across the user block.
int_handler
* first copy the sprite table
    li r11,>005b        * >1b00 with the write bit added, and byte flipped
    movb r11,@VDPWADR   * SAL address
    swpb r11
    movb r11,@VDPWADR   * going to copy the sprite table to VDP

    movb @mode,r11
    andi r11,>0400      * if bit >04 (inhibit flicker) is cleared, jump ahead to rotate
    jeq .4

    clr r11             * else we're going to just write it straight across
    li r12,128
    li r13,sprites
.7
    movb *r13+,@VDPWDATA
    dec r12
    jne .7
    jmp .5

.4
    movb @flicker,r11   * here we write it rotated every frame, and backwards for no reason
    ai r11,>0400
    andi r11,>7f00
    movb r11,@flicker
    swpb r11            * make count
    li r12,31           * count

.6
    ai r11,sprites        * this is still faster than separate incs
    movb *r11+,@VDPWDATA  * copy one sprite
    movb *r11+,@VDPWDATA  * no delay needed    
    movb *r11+,@VDPWDATA    
    movb *r11,@VDPWDATA   * small optimization, since we have an add coming anyway
    ai r11,25-sprites     * remove address and add the rest of the increment - the total increment is 28
    andi r11,>007F        * clamp it in range (basically write the list backwards?)
    dec r12
    jne .6

* next read the joysticks - output needs to be 21xxLDRU - 1 and 2 are button and button2 respectively
* We don't have a button 2. We also need to read the keyboard and fill in key1_data. key2_data we
* will leave unused. Note key1_data expects Coleco-style 0-9,10-*,11-#,15=not pressed, but we can throw
* everything else as ASCII. We could do a split keyboard for 2 players, but I guess we'll leave it for now.
.5
 * joy1
    li r12,>0024    * CRU base of select output
    li r13,>0600    * joystick 1 column
    ldcr r13,3      * select it
    src 12,7        * delay
    li r12,>0006    * CRU base of return read
    stcr r13,8      * read 8 bits (we could get away with fewer, but be consistent)
    bl @convert_joystick
    movb r12,@joy1_data

* joy2
    li r12,>0024    * CRU base of select output
    li r13,>0700    * joystick 2 column
    ldcr r13,3      * select it
    src 12,7        * delay
    li r12,>0006    * CRU base of return read
    stcr r13,8      * read 8 bits (we could get away with fewer, but be consistent)
    bl @convert_joystick
    movb r12,@joy2_data

* key1 - this is a very simple read with no modifiers, it just gives access to the letters and numbers
    clr r11         * column
.key1
    li r12,>0024    * CRU base of select output
    ldcr r11,3      * select column
    src r12,7       * delay
    li r12,>0006    * CRU base of return read
    stcr r13,8      * get the bits
    li r12,7        * bit search
.key2
    cocb @masktable(r12),r13    * bit set?
    jeq .key3       * continue
    srl r11,5
    a r12,r11       * calculate table offset
    movb @keyboard_table(r11),@key1_data    * might be a dead key, but that's okay
    
    mov r12,r12     * if column 0, check for QUIT before we go
    jne .key4
    li r11,>1100    * zero pattern for FCTN-=
    czcb r11,r13    * were both pressed?
    jne .key4
    clr @intwsr2    * clear user interrupt hook
    blwp @>0000     * soft reset

.key3
    dec r12
    jgt .key1
    jeq .key1       * we don't have a jump if not negative
.key4

* gone as far as I can with the 3 reserved registers, it's time to save the main regs off
* not sure if I can do this IF, if I can I can save a lot of code when there's no user int
* and no music player...

    if CVBASIC_MUSIC_PLAYER || .inttestlabel1 != .inttestlabel2
* backup R0-R10 (11 regs)
    li r12,intreg_backup
    mov r0,*r12+
    mov r1,*r12+
    mov r2,*r12+
    mov r3,*r12+
    mov r4,*r12+
    mov r5,*r12+
    mov r6,*r12+
    mov r7,*r12+
    mov r8,*r12+
    mov r9,*r12+
    mov r10,*r12
    * TODO: If we needed temp,temp2,result and pointer, backup the 8 bytes here too
    endif

    if CVBASIC_MUSIC_PLAYER
    movb @music_mode,r0
    jeq .10
    bl @music_hardware
.10
    endif

    inc @frame
    li r0,3
    a r0,@lfsr  * Make LFSR more random (TODO: Difference - will increment into MSB, original didn't)

    if CVBASIC_MUSIC_PLAYER
    movb @music_mode,r0
    jeq .9
    bl @music_generate
.9
    endif

* These labels test if any code was injected. If we aren't using the music player
* and we don't inject any code, then don't bother with the register save/restore
.inttestlabel1
    *CVBASIC MARK DON'T CHANGE
.inttestlabel2

    if CVBASIC_MUSIC_PLAYER || .inttestlabel1 != .inttestlabel2
* restore R0-R10 (11 regs)
    li r12,intreg_backup
    mov *r12+,r0
    mov *r12+,r1
    mov *r12+,r2
    mov *r12+,r3
    mov *r12+,r4
    mov *r12+,r5
    mov *r12+,r6
    mov *r12+,r7
    mov *r12+,r8
    mov *r12+,r9
    mov *r12+,r10
    * TODO: If we needed temp,temp2,result and pointer, restore the 8 bytes here too
    endif

* get back the interrupt workspace and return
    lwpi INTWS
    RTWP

* given a joystick read in r13, return bits in r12
* The final output is 8 bits:
* 21xxLDRU - 1 and 2 are button and button2 respectively
* NOTE: if called by the compiler, this won't act as expected
convert_joystick
    clr r12
    czcb @joystick_table,r13
    jne .j1
    ori r12,>08
.j1
    czcb @joystick_table+1,r13
    jne .j2
    ori r12,>04
.j2
    czcb @joystick_table+2,r13
    jne .j3
    ori r12,>02
.j3
    czcb @joystick_table+3,r13
    jne .j4
    ori r12,>01
.j4
    czcb @joystick_table+4,r13
    jne .j5
    ori r12,>40
.j5
    b *r11

joystick_table
    byte >02,>08,>04,>10,>01    * LDRU1

* By columns, then rows. 8 Rows per column. No shift states - converted to the Coleco returns
* for numbers, , and . become * and #
keyboard_table
    byte 61,32,13,15,15,15,15,15    * '=',' ',enter,n/a,fctn,shift,ctrl,n/a
    byte 11,76,79,9,2,83,87,88      * '.','L','O','9','2','S','W','X'
    byte 10,75,73,8,3,68,69,67      * ',','K','I','8','3','D','E','C'
    byte 77,74,85,7,4,70,82,86      * 'M','J','U','7','4','F','R','V'
    byte 78,72,89,6,5,71,84,66      * 'N','H','Y','6','5','G','T','B'
    byte 47,59,80,0,1,65,81,90      * '/',';','P','0','1','A','Q','Z'

masktable
    byte >01,>02,>04,>08,>10,>20,>40,>80

* wait for frame to increment
wait
    mov @frame,r0
.1
    c r0,@frame
    jeq .1
    b *r11

********************************************************

music_init
    LDA #$9f
    JSR BIOS_WRITE_PSG	
    LDA #$bf
    JSR BIOS_WRITE_PSG	
    LDA #$df
    JSR BIOS_WRITE_PSG	
    LDA #$ff
    JSR BIOS_WRITE_PSG
    if CVBASIC_MUSIC_PLAYER
    else	
    RTS
    endif

    if CVBASIC_MUSIC_PLAYER
    LDA #$ff
    STA audio_vol4hw
    LDA #$00
    STA audio_control
    LDA #music_silence
    LDY #music_silence>>8
    *
    * Play music.
    * YA = Pointer to music.
    *
music_play
    SEI
    STA music_pointer
    STY music_pointer+1
    LDY #0
    STY music_note_counter
    LDA (music_pointer),Y
    STA music_timing
    INY
    STY music_playing
    INC music_pointer
    BNE $+4
    INC music_pointer+1
    LDA music_pointer
    LDY music_pointer+1
    STA music_start
    STY music_start+1
    CLI
    RTS

    *
    * Generates music
    *
music_generate
    LDA #0
    STA audio_vol1
    STA audio_vol2
    STA audio_vol3
    LDA #$FF
    STA audio_vol4hw
    LDA music_note_counter
    BEQ .1
    JMP .2
.1
    LDY #0
    LDA (music_pointer),Y
    CMP #$fe	* End of music?
    BNE .3		* No, jump.
    LDA #0		* Keep at same place.
    STA music_playing
    RTS

.3	CMP #$fd	* Repeat music?
    BNE .4
    LDA music_start
    LDY music_start+1
    STA music_pointer
    STY music_pointer+1
    JMP .1

.4	LDA music_timing
    AND #$3f	* Restart note time.
    STA music_note_counter

    LDA (music_pointer),Y
    CMP #$3F	* Sustain?
    BEQ .5
    AND #$C0
    STA music_instrument_1
    LDA (music_pointer),Y
    AND #$3F
    ASL A
    STA music_note_1
    LDA #0
    STA music_counter_1
.5
    INY
    LDA (music_pointer),Y
    CMP #$3F	* Sustain?
    BEQ .6
    AND #$C0
    STA music_instrument_2
    LDA (music_pointer),Y
    AND #$3F
    ASL A
    STA music_note_2
    LDA #0
    STA music_counter_2
.6
    INY
    LDA (music_pointer),Y
    CMP #$3F	* Sustain?
    BEQ .7
    AND #$C0
    STA music_instrument_3
    LDA (music_pointer),Y
    AND #$3F
    ASL A
    STA music_note_3
    LDA #0
    STA music_counter_3
.7
    INY
    LDA (music_pointer),Y
    STA music_drum
    LDA #0	
    STA music_counter_4
    LDA music_pointer
    CLC
    ADC #4
    STA music_pointer
    LDA music_pointer+1
    ADC #0
    STA music_pointer+1
.2
    LDY music_note_1
    BEQ .8
    LDA music_instrument_1
    LDX music_counter_1
    JSR music_note2freq
    STA audio_freq1
    STY audio_freq1+1
    STX audio_vol1
.8
    LDY music_note_2
    BEQ .9
    LDA music_instrument_2
    LDX music_counter_2
    JSR music_note2freq
    STA audio_freq2
    STY audio_freq2+1
    STX audio_vol2
.9
    LDY music_note_3
    BEQ .10
    LDA music_instrument_3
    LDX music_counter_3
    JSR music_note2freq
    STA audio_freq3
    STY audio_freq3+1
    STX audio_vol3
.10
    LDA music_drum
    BEQ .11
    CMP #1		* 1 - Long drum.
    BNE .12
    LDA music_counter_4
    CMP #3
    BCS .11
.15
    LDA #$ec
    STA audio_noise
    LDA #$f5
    STA audio_vol4hw
    JMP .11

.12	CMP #2		* 2 - Short drum.
    BNE .14
    LDA music_counter_4
    CMP #0
    BNE .11
    LDA #$ed
    STA audio_noise
    LDA #$F5
    STA audio_vol4hw
    JMP .11

.14	*CMP #3		* 3 - Roll.
    *BNE
    LDA music_counter_4
    CMP #2
    BCC .15
    ASL A
    SEC
    SBC music_timing
    BCC .11
    CMP #4
    BCC .15
.11
    LDX music_counter_1
    INX
    CPX #$18
    BNE $+4
    LDX #$10
    STX music_counter_1

    LDX music_counter_2
    INX
    CPX #$18
    BNE $+4
    LDX #$10
    STX music_counter_2

    LDX music_counter_3
    INX
    CPX #$18
    BNE $+4
    LDX #$10
    STX music_counter_3

    INC music_counter_4
    DEC music_note_counter
    RTS

music_flute
    LDA music_notes_table,Y
    CLC
    ADC .2,X
    PHA
    LDA music_notes_table+1,Y
    ADC #0
    TAY
    LDA .1,X
    TAX
    PLA
    RTS

.1
        db 10,12,13,13,12,12,12,12
        db 11,11,11,11,10,10,10,10
        db 11,11,11,11,10,10,10,10

.2
    db 0,0,0,0,0,1,1,1
    db 0,1,1,1,0,1,1,1
    db 0,1,1,1,0,1,1,1

    *
    * Converts note to frequency.
    * Input
    *   A = Instrument.
    *   Y = Note (1-62)
    *   X = Instrument counter.
    * Output
    *   YA = Frequency.
    *   X = Volume.
    *
music_note2freq
    CMP #$40
    BCC music_piano
    BEQ music_clarinet
    CMP #$80
    BEQ music_flute
    *
    * Bass instrument
    * 
music_bass
    LDA music_notes_table,Y
    ASL A
    PHA
    LDA music_notes_table+1,Y
    ROL A
    TAY
    LDA .1,X
    TAX
    PLA
    RTS

.1
    db 13,13,12,12,11,11,10,10
    db 9,9,8,8,7,7,6,6
    db 5,5,4,4,3,3,2,2

music_piano
    LDA music_notes_table,Y
    PHA
    LDA music_notes_table+1,Y
    TAY
    LDA .1,X
    TAX
    PLA
    RTS

.1	db 12,11,11,10,10,9,9,8
    db 8,7,7,6,6,5,5,4
    db 4,4,5,5,4,4,3,3

music_clarinet
    LDA music_notes_table,Y
    CLC
    ADC .2,X
    PHA
    LDA .2,X
    BMI .3
    LDA #$00
    DB $2C
.3	LDA #$ff
    ADC music_notes_table+1,Y
    LSR A
    TAY
    LDA .1,X
    TAX
    PLA
    ROR A
    RTS

.1
        db 13,14,14,13,13,12,12,12
        db 11,11,11,11,12,12,12,12
        db 11,11,11,11,12,12,12,12

.2
    db 0,0,0,0,-1,-2,-1,0
    db 1,2,1,0,-1,-2,-1,0
    db 1,2,1,0,-1,-2,-1,0

    *
    * Musical notes table.
    *
music_notes_table
    * Silence - 0
    dw 0
    * Values for 2.00 mhz.
    * 2nd octave - Index 1
    dw 956,902,851,804,758,716,676,638,602,568,536,506
    * 3rd octave - Index 13
    dw 478,451,426,402,379,358,338,319,301,284,268,253
    * 4th octave - Index 25
    dw 239,225,213,201,190,179,169,159,150,142,134,127
    * 5th octave - Index 37
    dw 119,113,106,100,95,89,84,80,75,71,67,63
    * 6th octave - Index 49
    dw 60,56,53,50,47,45,42,40,38,36,34,32
    * 7th octave - Index 61
    dw 30,28,27

music_hardware
    LDA music_mode
    CMP #4		* PLAY SIMPLE?
    BCC .7		* Yes, jump.
    LDA audio_vol2
    BNE .7
    LDA audio_vol3
    BEQ .7
    STA audio_vol2
    LDA #0
    STA audio_vol3
    LDA audio_freq3
    LDY audio_freq3+1
    STA audio_freq2
    STY audio_freq2+1
.7
    LDA audio_freq1+1
    CMP #$04
    LDA #$9F
    BCS .1
    LDA audio_freq1
    AND #$0F
    ORA #$80
    JSR BIOS_WRITE_PSG
    LDA audio_freq1+1
    ASL audio_freq1
    ROL A
    ASL audio_freq1
    ROL A
    ASL audio_freq1
    ROL A
    ASL audio_freq1
    ROL A
    JSR BIOS_WRITE_PSG
    LDX audio_vol1
    LDA ay2sn,X
    ORA #$90
.1	JSR BIOS_WRITE_PSG

    LDA audio_freq2+1
    CMP #$04
    LDA #$BF
    BCS .2
    LDA audio_freq2
    AND #$0F
    ORA #$A0
    JSR BIOS_WRITE_PSG
    LDA audio_freq2+1
    ASL audio_freq2
    ROL A
    ASL audio_freq2
    ROL A
    ASL audio_freq2
    ROL A
    ASL audio_freq2
    ROL A
    JSR BIOS_WRITE_PSG
    LDX audio_vol2
    LDA ay2sn,X
    ORA #$b0
.2	JSR BIOS_WRITE_PSG

    LDA music_mode
    CMP #4		* PLAY SIMPLE?
    BCC .6		* Yes, jump.

    LDA audio_freq3+1
    CMP #$04
    LDA #$DF
    BCS .3
    LDA audio_freq3
    AND #$0F
    ORA #$C0
    JSR BIOS_WRITE_PSG
    LDA audio_freq3+1
    ASL audio_freq3
    ROL A
    ASL audio_freq3
    ROL A
    ASL audio_freq3
    ROL A
    ASL audio_freq3
    ROL A
    JSR BIOS_WRITE_PSG
    LDX audio_vol3
    LDA ay2sn,X
    ORA #$D0
.3	JSR BIOS_WRITE_PSG

.6	LDA music_mode
    LSR A		* NO DRUMS?
    BCC .8
    LDA audio_vol4hw
    CMP #$ff
    BEQ .4
    LDA audio_noise
    CMP audio_control
    BEQ .4
    STA audio_control
    JSR BIOS_WRITE_PSG
.4	LDA audio_vol4hw
    JSR BIOS_WRITE_PSG
.8
    RTS

        *
        * Converts AY-3-8910 volume to SN76489
        *
ay2sn
        db $0f,$0f,$0f,$0e,$0e,$0e,$0d,$0b,$0a,$08,$07,$05,$04,$03,$01,$00

music_silence
    db 8
    db 0,0,0,0
    db -2
    endif

    if CVBASIC_COMPRESSION
define_char_unpack
    lda pointer
    asl a
    rol pointer+1
    asl a
    rol pointer+1
    asl a
    rol pointer+1
    sta pointer
    lda mode
    and #$04
    beq unpack3
    bne unpack

define_color_unpack
    lda #4
    sta pointer+1
    lda pointer
    asl a
    rol pointer+1
    asl a
    rol pointer+1
    asl a
    rol pointer+1
    sta pointer
unpack3
    jsr .1
    jsr .1
.1	lda pointer
    pha
    lda pointer+1
    pha
    lda temp
    pha
    lda temp+1
    pha
    jsr unpack
    pla
    sta temp+1
    pla
    sta temp
    pla
    clc
    adc #8
    sta pointer+1
    pla
    sta pointer
    rts

        *
        * Pletter-0.5c decompressor (XL2S Entertainment & Team Bomba)
        * Ported from Z80 original
    * temp = Pointer to source data
    * pointer = Pointer to target VRAM
    * temp2
    * temp2+1
    * result
    * result+1
    * pletter_off
    * pletter_off+1
    *
unpack
    * Initialization
    ldy #0
    sty temp2
    lda (temp),y
    inc temp
    bne $+4
    inc temp+1
    asl a
    rol temp2
    adc #1
    asl a
    rol temp2
    asl a
    sta pletter_bit
    rol temp2
    rol temp2
    lda #.modes
    adc temp2
    sta temp2
    lda #.modes>>8
    adc #0
    sta temp2+1
    lda (temp2),y
    tax
    iny
    lda (temp2),y
    stx temp2	* IX (temp2)
    sta temp2+1
    lda pletter_bit
.literal
    sta pletter_bit
    ldy #0
    lda (temp),y
    inc temp
    bne $+4
    inc temp+1
    tax
    lda pointer
    ldy pointer+1
    sei
    jsr WRTVRM
    cli
    inc pointer
    bne $+4
    inc pointer+1
    lda pletter_bit
.loop
    asl a
    bne $+5
    jsr .getbit
    bcc .literal

    * Compressed data
    ldx #1
    stx result
    dex
    stx result+1
.getlen
    asl a
    bne $+5
    jsr .getbit
    bcc .lenok
.lus	asl a
    bne $+5
    jsr .getbit
    rol result
    rol result+1
    bcc $+3
    rts
    asl a
    bne $+5
    jsr .getbit
    bcc .lenok
    asl a
    bne $+5
    jsr .getbit
    rol result
    rol result+1
    bcc $+3
    rts
    asl a
    bne $+5
    jsr .getbit
    bcs .lus
.lenok
    inc result
    bne $+4
    inc result+1
    sta pletter_bit
    ldy #0
    sty pletter_off+1
    lda (temp),y
    inc temp
    bne $+4
    inc temp+1
    sta pletter_off
    lda pletter_off
    bpl .offsok
    lda pletter_bit
    jmp (temp2)
    
.mode6
    asl a
    bne $+5
    jsr .getbit
    rol pletter_off+1
.mode5
    asl a
    bne $+5
    jsr .getbit
    rol pletter_off+1
.mode4
    asl a
    bne $+5
    jsr .getbit
    rol pletter_off+1
.mode3
    asl a
    bne $+5
    jsr .getbit
    rol pletter_off+1
.mode2
    asl a
    bne $+5
    jsr .getbit
    rol pletter_off+1
    asl a
    bne $+5
    jsr .getbit
    sta pletter_bit
    bcc .offsok
    inc pletter_off+1
    lda pletter_off
    and #$7f
    sta pletter_off
.offsok
    inc pletter_off
    bne $+4
    inc pletter_off+1

    lda result
    beq $+4
    inc result+1

    lda pointer
    sec
    sbc pletter_off
    sta pletter_off
    lda pointer+1
    sbc pletter_off+1
    sta pletter_off+1
.loop2
    sei
    lda pletter_off
    ldy pletter_off+1
    jsr RDVRM
    tax
    lda pointer
    ldy pointer+1
    jsr WRTVRM
    cli
    inc pletter_off
    bne $+4
    inc pletter_off+1
    inc pointer
    bne $+4
    inc pointer+1
    dec result
    bne .loop2
    dec result+1
    bne .loop2

    lda pletter_bit
    jmp .loop

.getbit
    ldy #0
    lda (temp),y
    inc temp
    bne $+4
    inc temp+1
    rol a
    rts

.modes
    dw .offsok
    dw .mode2
    dw .mode3
    dw .mode4
    dw .mode5
    dw .mode6
    endif

    * Required for Creativision because it doesn't provide an ASCII charset.
    *
        * My personal font for TMS9928.
        *
        * Patterned after the TMS9928 programming manual 6x8 letters
        * with better lowercase letters, also I made a proper
        * AT sign.
        *
font_bitmaps
        db $00,$00,$00,$00,$00,$00,$00,$00      * $20 space
        db $20,$20,$20,$20,$20,$00,$20,$00      * $21 !
        db $50,$50,$50,$00,$00,$00,$00,$00      * $22 "
        db $50,$50,$f8,$50,$f8,$50,$50,$00      * $23 #
        db $20,$78,$a0,$70,$28,$f0,$20,$00      * $24 $
        db $c0,$c8,$10,$20,$40,$98,$18,$00      * $25 %
        db $40,$a0,$40,$a0,$a8,$90,$68,$00      * $26 &
        db $60,$20,$40,$00,$00,$00,$00,$00      * $27 '
        db $10,$20,$40,$40,$40,$20,$10,$00      * $28 (
        db $40,$20,$10,$10,$10,$20,$40,$00      * $29 )
        db $00,$a8,$70,$20,$70,$a8,$00,$00      * $2a *
        db $00,$20,$20,$f8,$20,$20,$00,$00      * $2b +
        db $00,$00,$00,$00,$00,$60,$20,$40      * $2c ,
        db $00,$00,$00,$fc,$00,$00,$00,$00      * $2d -
        db $00,$00,$00,$00,$00,$00,$60,$00      * $2e .
        db $00,$08,$10,$20,$40,$80,$00,$00      * $2f /
        db $70,$88,$98,$a8,$c8,$88,$70,$00      * $30 0
        db $20,$60,$20,$20,$20,$20,$f8,$00      * $31 1
        db $70,$88,$08,$10,$60,$80,$f8,$00      * $32 2
        db $70,$88,$08,$30,$08,$88,$70,$00      * $33 3
        db $30,$50,$90,$90,$f8,$10,$10,$00      * $34 4
        db $f8,$80,$f0,$08,$08,$08,$f0,$00      * $35 5
        db $30,$40,$80,$f0,$88,$88,$70,$00      * $36 6
        db $f8,$08,$10,$20,$20,$20,$20,$00      * $37 7
        db $70,$88,$88,$70,$88,$88,$70,$00      * $38 8
        db $70,$88,$88,$78,$08,$10,$60,$00      * $39 9
        db $00,$00,$00,$60,$00,$60,$00,$00      * $3a 
        db $00,$00,$00,$60,$00,$60,$20,$40      * $3b *
        db $10,$20,$40,$80,$40,$20,$10,$00      * $3c <
        db $00,$00,$f8,$00,$f8,$00,$00,$00      * $3d =
        db $08,$04,$02,$01,$02,$04,$08,$00      * $3e >
        db $70,$88,$08,$10,$20,$00,$20,$00      * $3f ?
        db $70,$88,$98,$a8,$98,$80,$70,$00      * $40 @
        db $20,$50,$88,$88,$f8,$88,$88,$00      * $41 A
        db $f0,$88,$88,$f0,$88,$88,$f0,$00      * $42 B
        db $70,$88,$80,$80,$80,$88,$70,$00      * $43 C
        db $f0,$88,$88,$88,$88,$88,$f0,$00      * $44 D
        db $f8,$80,$80,$f0,$80,$80,$f8,$00      * $45 E
        db $f8,$80,$80,$f0,$80,$80,$80,$00      * $46 F
        db $70,$88,$80,$b8,$88,$88,$70,$00      * $47 G
        db $88,$88,$88,$f8,$88,$88,$88,$00      * $48 H
        db $70,$20,$20,$20,$20,$20,$70,$00      * $49 I
        db $08,$08,$08,$08,$88,$88,$70,$00      * $4A J
        db $88,$90,$a0,$c0,$a0,$90,$88,$00      * $4B K
        db $80,$80,$80,$80,$80,$80,$f8,$00      * $4C L
        db $88,$d8,$a8,$a8,$88,$88,$88,$00      * $4D M
        db $88,$c8,$c8,$a8,$98,$98,$88,$00      * $4E N
        db $70,$88,$88,$88,$88,$88,$70,$00      * $4F O
        db $f0,$88,$88,$f0,$80,$80,$80,$00      * $50 P
        db $70,$88,$88,$88,$88,$a8,$90,$68      * $51 Q
        db $f0,$88,$88,$f0,$a0,$90,$88,$00      * $52 R
        db $70,$88,$80,$70,$08,$88,$70,$00      * $53 S
        db $f8,$20,$20,$20,$20,$20,$20,$00      * $54 T
        db $88,$88,$88,$88,$88,$88,$70,$00      * $55 U
        db $88,$88,$88,$88,$50,$50,$20,$00      * $56 V
        db $88,$88,$88,$a8,$a8,$d8,$88,$00      * $57 W
        db $88,$88,$50,$20,$50,$88,$88,$00      * $58 X
        db $88,$88,$88,$70,$20,$20,$20,$00      * $59 Y
        db $f8,$08,$10,$20,$40,$80,$f8,$00      * $5A Z
        db $78,$60,$60,$60,$60,$60,$78,$00      * $5B [
        db $00,$80,$40,$20,$10,$08,$00,$00      * $5C \
        db $F0,$30,$30,$30,$30,$30,$F0,$00      * $5D ]
        db $20,$50,$88,$00,$00,$00,$00,$00      * $5E 
        db $00,$00,$00,$00,$00,$00,$f8,$00      * $5F _
        db $40,$20,$10,$00,$00,$00,$00,$00      * $60 
        db $00,$00,$68,$98,$88,$98,$68,$00      * $61 a
        db $80,$80,$f0,$88,$88,$88,$f0,$00      * $62 b
        db $00,$00,$78,$80,$80,$80,$78,$00      * $63 c
        db $08,$08,$68,$98,$88,$98,$68,$00      * $64 d
        db $00,$00,$70,$88,$f8,$80,$70,$00      * $65 e
        db $30,$48,$40,$e0,$40,$40,$40,$00      * $66 f
        db $00,$00,$78,$88,$88,$78,$08,$70      * $67 g
        db $80,$80,$f0,$88,$88,$88,$88,$00      * $68 h
        db $20,$00,$60,$20,$20,$20,$70,$00      * $69 i
        db $08,$00,$18,$08,$88,$88,$70,$00      * $6a j
        db $80,$80,$88,$90,$e0,$90,$88,$00      * $6b k
        db $60,$20,$20,$20,$20,$20,$70,$00      * $6c l
        db $00,$00,$d0,$a8,$a8,$a8,$a8,$00      * $6d m
        db $00,$00,$b0,$c8,$88,$88,$88,$00      * $6e n
        db $00,$00,$70,$88,$88,$88,$70,$00      * $6f o
        db $00,$00,$f0,$88,$88,$88,$f0,$80      * $70 p
        db $00,$00,$78,$88,$88,$88,$78,$08      * $71 q
        db $00,$00,$b8,$c0,$80,$80,$80,$00      * $72 r
        db $00,$00,$78,$80,$70,$08,$f0,$00      * $73 s
        db $20,$20,$f8,$20,$20,$20,$20,$00      * $74 t
        db $00,$00,$88,$88,$88,$98,$68,$00      * $75 u
        db $00,$00,$88,$88,$88,$50,$20,$00      * $76 v
        db $00,$00,$88,$a8,$a8,$a8,$50,$00      * $77 w
        db $00,$00,$88,$50,$20,$50,$88,$00      * $78 x
        db $00,$00,$88,$88,$98,$68,$08,$70      * $79 y
        db $00,$00,$f8,$10,$20,$40,$f8,$00      * $7a z
        db $18,$20,$20,$40,$20,$20,$18,$00      * $7b {
        db $20,$20,$20,$20,$20,$20,$20,$00      * $7c |
        db $c0,$20,$20,$10,$20,$20,$c0,$00      * $7d } 
        db $00,$00,$40,$a8,$10,$00,$00,$00      * $7e
        db $70,$70,$20,$f8,$20,$70,$50,$00      * $7f

START
    SEI
    CLD
    LDX #STACK
    TXS
    LDA $2001
    LDA #$82
    LDX #$01
    JSR WRTVDP
    LDA $2001
    LDA #$82
    LDX #$01
    JSR WRTVDP

    JSR music_init

    JSR mode_0

    LDA #$00
    STA joy1_data
    STA joy2_data
    LDA #$0F
    STA key1_data
    STA key2_data

