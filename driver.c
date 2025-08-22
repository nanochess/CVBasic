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
#include "driver.h"
#include "cpuz80.h"
#include "cpu6502.h"
#include "cpu9900.h"

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

/*
 ** Generic range comparison (8-bit)
 */
void generic_comparison_8bit(int min, int max, char *label)
{
    char value[256];
    
    if (min == max) {
        if (target == CPU_Z80) {
            sprintf(value, "%d", min);
            cpuz80_1op("CP", value);
            cpuz80_2op("JP", "NZ", label);
        }
        if (target == CPU_6502) {
            sprintf(value, "#%d", min);
            cpu6502_1op("CMP", value);
            cpu6502_1op("BNE.L", label);
        }
        if (target == CPU_9900) {
            char internal_label[256], internal_label2[256];
            int number = next_local++;
            
            sprintf(internal_label, INTERNAL_PREFIX "%d", number);
            sprintf(internal_label2, "@%s", label);
            
            sprintf(value, "%d   ; %d*256", min * 256, min);
            cpu9900_2op("li", "r1", value);
            cpu9900_2op("cb", "r1", "r0");
            cpu9900_1op("jeq", internal_label);
            cpu9900_1op("b", internal_label2);
            cpu9900_label(internal_label);
        }
        return;
    }
    if (target == CPU_Z80) {
        sprintf(value, "%d", min);
        cpuz80_1op("CP", value);
        cpuz80_2op("JP", "C", label);
        sprintf(value, "%d", max + 1);
        cpuz80_1op("CP", value);
        cpuz80_2op("JP", "NC", label);
    }
    if (target == CPU_6502) {
        sprintf(value, "#%d", min);
        cpu6502_1op("CMP", value);
        cpu6502_1op("BCC.L", label);
        sprintf(value, "#%d", max + 1);
        cpu6502_1op("CMP", value);
        cpu6502_1op("BCS.L", label);
    }
    if (target == CPU_9900) {
        char internal_label[256], internal_label2[256], internal_label3[256];
        int number;
        
        number = next_local++;
        sprintf(internal_label, INTERNAL_PREFIX "%d", number);
        sprintf(internal_label2, "@%s", label);
        number = next_local++;
        sprintf(internal_label3, INTERNAL_PREFIX "%d", number);

        sprintf(value, "%d", min * 256);
        cpu9900_2op("ci", "r0", value);
        cpu9900_1op("jl", internal_label3);
        sprintf(value, "%d", max * 256 + 255);
        cpu9900_2op("ci", "r0", value);
        cpu9900_1op("jle", internal_label);
        cpu9900_label(internal_label3);
        cpu9900_1op("b", internal_label2);
        cpu9900_label(internal_label);
    }
}

/*
 ** Generic range comparison (16-bit)
 */
void generic_comparison_16bit(int min, int max, char *label)
{
    char value[256];
            
    if (min == max) {
        if (target == CPU_Z80) {
            sprintf(value, "%d", min);
            cpuz80_2op("LD", "DE", value);
            cpuz80_1op("OR", "A");
            cpuz80_2op("SBC", "HL", "DE");
            cpuz80_2op("ADD", "HL", "DE");
            cpuz80_2op("JP", "NZ", label);
        }
        if (target == CPU_6502) {
            sprintf(value, "#%d", min & 0xff);
            cpu6502_1op("CMP", value);
            cpu6502_1op("BNE.L", label);
            sprintf(value, "#%d", (min >> 8) & 0xff);
            cpu6502_1op("CPY", value);
            cpu6502_1op("BNE.L", label);
        }
        if (target == CPU_9900) {
            char internal_label[256], internal_label2[256];
            int number = next_local++;
            
            sprintf(internal_label, INTERNAL_PREFIX "%d", number);
            sprintf(internal_label2, "@%s", label);
            
            sprintf(value, "%d", min);
            cpu9900_2op("ci", "r0", value);
            cpu9900_1op("jeq", internal_label);
            cpu9900_1op("b", internal_label2);
            cpu9900_label(internal_label);
        }
        return;
    }
    if (target == CPU_Z80) {
        sprintf(value, "%d", min);
        cpuz80_2op("LD", "DE", value);
        cpuz80_1op("OR", "A");
        cpuz80_2op("SBC", "HL", "DE");
        cpuz80_2op("ADD", "HL", "DE");
        cpuz80_2op("JP", "C", label);
        sprintf(value, "%d", max + 1);
        cpuz80_2op("LD", "DE", value);
/*      cpuz80_1op("OR", "A"); */ /* Guaranteed */
        cpuz80_2op("SBC", "HL", "DE");
        cpuz80_2op("ADD", "HL", "DE");
        cpuz80_2op("JP", "NC", label);
    }
    if (target == CPU_6502) {
        cpu6502_noop("PHA");
        cpu6502_noop("SEC");
        sprintf(value, "#%d", min & 0xff);
        cpu6502_1op("SBC", value);
        cpu6502_noop("TYA");
        sprintf(value, "#%d", (min >> 8) & 0xff);
        cpu6502_1op("SBC", value);
        cpu6502_noop("PLA");
        cpu6502_1op("BCC.L", label);
        cpu6502_noop("PHA");
/*      cpu6502_noop("SEC"); */ /* Guaranteed */
        sprintf(value, "#%d", (max + 1) & 0xff);
        cpu6502_1op("SBC", value);
        cpu6502_noop("TYA");
        sprintf(value, "#%d", ((max + 1) >> 8) & 0xff);
        cpu6502_1op("SBC", value);
        cpu6502_noop("PLA");
        cpu6502_1op("BCS.L", label);
    }
    if (target == CPU_9900) {
        char internal_label[256], internal_label2[256], internal_label3[256];
        int number;
        
        number = next_local++;
        sprintf(internal_label, INTERNAL_PREFIX "%d", number);
        sprintf(internal_label2, "@%s", label);
        number = next_local++;
        sprintf(internal_label3, INTERNAL_PREFIX "%d", number);
        
        sprintf(value, "%d", min);
        cpu9900_2op("ci", "r0", value);
        cpu9900_1op("jl", internal_label3);
        sprintf(value, "%d", max);
        cpu9900_2op("ci", "r0", value);
        cpu9900_1op("jle", internal_label);
        cpu9900_label(internal_label3);
        cpu9900_1op("b", internal_label2);
        cpu9900_label(internal_label);
    }
}

/*
 ** Generic disable interrupt
 */
void generic_interrupt_disable(void)
{
    if (consoles[machine].int_pin == 0) {
        generic_call("nmi_off");
    } else {
        if (target == CPU_Z80)
            cpuz80_noop("DI");
        else if (target == CPU_6502)
            cpu6502_noop("SEI");
        else if (target == CPU_9900)
            cpu9900_1op("limi", "0");
    }
}

/*
 ** Generic enable interrupt
 */
void generic_interrupt_enable(void)
{
    if (consoles[machine].int_pin == 0) {
        generic_call("nmi_on");
    } else {
        if (target == CPU_Z80)
            cpuz80_noop("EI");
        else if (target == CPU_6502)
            cpu6502_noop("CLI");
        else if (target == CPU_9900)
            cpu9900_1op("limi", "2");
    }
}
