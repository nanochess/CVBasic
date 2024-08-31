/*
 ** Driver for backend
 **
 ** by Oscar Toledo G.
 **
 ** Creation date: Aug/04/2024.
 */

#include <stdio.h>
#include <string.h>
#include "cvbasic.h"
#include "node.h"
#include "cpuz80.h"
#include "cpu6502.h"
#include "cpu9900.h"

static char driver_temp[MAX_LINE_SIZE];

/*
 ** Dump peephole optimization
 */
void generic_dump(void)
{
    if (target == CPU_Z80)
        cpuz80_dump();
}

/*
 ** 8-bit test
 */
void generic_test_8(void)
{
    if (target == CPU_6502)
        cpu6502_1op("CMP", "#0");
    if (target == CPU_9900)
        cpu9900_2op("movb", "r0", "r0");
    if (target == CPU_Z80)
        cpuz80_1op("OR", "A");
}

/*
 ** 16-bit test
 */
void generic_test_16(void)
{
    if (target == CPU_6502) {
        cpu6502_1op("STY", "temp");
        cpu6502_1op("ORA", "temp");
    }
    if (target == CPU_9900) {
        cpu9900_2op("mov", "r0", "r0");
    }
    if (target == CPU_Z80) {
        cpuz80_2op("LD", "A", "H");
        cpuz80_1op("OR", "L");
    }
}

/*
 ** Label
 */
void generic_label(char *label)
{
    if (target == CPU_6502)
        cpu6502_label(label);
    if (target == CPU_9900)
        cpu9900_label(label);
    if (target == CPU_Z80)
        cpuz80_label(label);
}

/*
 ** Call
 */
void generic_call(char *label)
{
    if (target == CPU_6502)
        cpu6502_1op("JSR", label);
    if (target == CPU_9900) {
        cpu9900_1op("bl", "@jsr");
        cpu9900_1op("data", label);
    }
    if (target == CPU_Z80)
        cpuz80_1op("CALL", label);
}

/*
 ** Return
 */
void generic_return(void)
{
    if (target == CPU_6502)
        cpu6502_noop("RTS");
    if (target == CPU_9900) {
        /* we don't presume r11 was preserved - it probably wasn't! */
        cpu9900_2op("mov", "*r10+", "r0");
        cpu9900_1op("b", "*r0");
    }
    if (target == CPU_Z80)
        cpuz80_noop("RET");
}

/*
 ** Jump
 */
void generic_jump(char *label)
{
    if (target == CPU_6502)
        cpu6502_1op("JMP", label);
    if (target == CPU_9900) {
        char temp[256];
        
        sprintf(temp, "@%s", label);
        cpu9900_1op("b", temp);
    }
    if (target == CPU_Z80)
        cpuz80_1op("JP", label);
}

/*
 ** Jump if zero
 */
void generic_jump_zero(char *label)
{
    if (target == CPU_6502)
        cpu6502_1op("BEQ.L", label);
    if (target == CPU_9900) {
        char internal_label[256], internal_label2[256];
        int number = next_local++;

        sprintf(internal_label, INTERNAL_PREFIX "%d", number);
        sprintf(internal_label2, "@%s", label);

        cpu9900_1op("jne", internal_label);
        cpu9900_1op("b", internal_label2);
        cpu9900_label(internal_label);
    }
    if (target == CPU_Z80)
        cpuz80_2op("JP", "Z", label);
}
