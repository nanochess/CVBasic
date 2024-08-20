/*
 ** 9900 assembler output routines for CVBasic
 **
 ** by Tursi, based on cpu6502 by Oscar Toledo G.
 **
 ** Creation date: Aug/20/2024.
 */

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include "cvbasic.h"
#include "node.h"

// constant for node_get_label to give us labels with '@'
#define ADDRESS 4

// Note the Z80 version of this file does a lot of peephole and other optimizations,
// tracks register settings, and so on. This version doesn't right now. TODO.

static char cpu9900_line[MAX_LINE_SIZE];

static void cpu9900_emit_line(void);

// Final emit phase. Some peephole optimizations can be placed here
// The Z80 code maintains three lines in order to be able to do this.
void cpu9900_emit_line(void)
{
    fprintf(output, "%s", cpu9900_line);
}

// Nothing here. The Z80 code uses this to emit the three line buffers,
// but we emit the one and only buffer in emit_line.
void cpu9900_dump(void)
{
}

/*
 ** Emit a 9900 label
 */
void cpu9900_label(char *label)
{
    // the z80 version also clears its register flags
    sprintf(cpu9900_line, "%s\n", label);
    cpu9900_emit_line();
}

/*
 ** Reset accumulator register (technically a null label)
 * This is a bit tricky on the 9900 since all registers are
 * equally valid. However, it wasn't implemented for the
 * 6502 either since there's no optimizations coded yet.
 */
void cpu9900_empty(void)
{
}

/*
 ** Emit a 9900 instruction with no operand
 */
void cpu9900_noop(char *mnemonic)
{
    sprintf(cpu9900_line, "\t%s\n", mnemonic);
    cpu9900_emit_line();
}

/*
 ** Emit a 9900 instruction with a single operand
 */
void cpu9900_1op(char *mnemonic, char *operand)
{
    sprintf(cpu9900_line, "\t%s %s\n", mnemonic, operand);
    cpu9900_emit_line();
}

/*
 ** Emit a 9900 instruction with a two operands
 */
void cpu9900_2op(char *mnemonic, char *operand1, char *operand2)
{
    sprintf(cpu9900_line, "\t%s %s,%s\n", mnemonic, operand1, operand2);
    cpu9900_emit_line();
}

/*
 ** Label register usage in tree
 **
 ** This should match exactly register usage in cpu9900_node_generate.
 ** See Z80 version, mostly for register tracking
 */
void cpu9900_node_label(struct node *node)
{
    /* Nothing to do, yet */
}

/*
 ** Generate code for tree
 */
void cpu9900_node_generate(struct node *node, int decision)
{
    // Maybe in the future we can pass an arg to tell cpu9900_node_generate which 
    // reg to generate for instead of always r0? That would make better code...

    struct node *explore;
    
    switch (node->type) {
        case N_USR:     /* Assembly language function with result */
            if (node->left != NULL)
                cpu9900_node_generate(node->left, 0);
            cpu9900_1op("bl", "@JSR");
            cpu9900_1op("data", node->label->name);
            break;
        case N_ADDR:    /* Get address of variable into r0 */
            node_get_label(node, 0);
            cpu9900_2op("li", "r0", temp);
            break;
        case N_NEG8:    /* Negate 8-bit value in r0 */
        case N_NEG16:   /* Negate 16-bit value */
            cpu9900_node_generate(node->left, 0);
            cpu9900_1op("neg","r0");
            break;
        case N_NOT8:    /* Complement 8-bit value */
        case N_NOT16:   /* Complement 16-bit value */
            cpu9900_node_generate(node->left, 0);
            cpu9900_1op("inv","r0");
            break;
        case N_ABS16:   /* Get absolute 16-bit value */
            cpu9900_node_generate(node->left, 0);
            cpu9900_1op("abs","r0");
            break;
        case N_SGN16:   /* Get sign of 16-bit value */
            cpu9900_node_generate(node->left, 0);
            cpu9900_1op("bl","@JSR");
            cpu9900_1op("data", "_sgn16");
            break;
        case N_POS:     /* Get screen cursor position in r0 (AAYY) */
            cpu9900_2op("mov","@cursor","r0");
            break;
        case N_EXTEND8S:    /* Extend 8-bit signed value to 16-bit */
            cpu9900_node_generate(node->left, 0);
            cpu9900_2op("sra","r0","8");
            break;
        case N_EXTEND8: /* Extend 8-bit value to 16-bit */
            cpu9900_node_generate(node->left, 0);
            cpu9900_2op("srl","r0","8");
            break;
        case N_REDUCE16:    /* Reduce 16-bit value to 8-bit */
            cpu9900_node_generate(node->left, 0);
            cpu9900_2op("sla","r0","8");
            break;
        case N_READ8:   /* Read 8-bit value from read_pointer */
            cpu9900_2op("mov","@read_pointer","r1");
            cpu9900_2op("movb","*r1","r0");
            cpu9900_1op("inc","@read_pointer");
            break;
        case N_READ16:  /* Read 16-bit value - warning, will not work as expected unaligned! */
            cpu9900_2op("mov","@read_pointer","r1");
            cpu9900_2op("mov","*r1","r0");
            cpu9900_1op("inct","@read_pointer");
            break;
        case N_LOAD8:   /* Load 8-bit value from address */
            strcpy(temp, "@");
            strcat(temp, LABEL_PREFIX);
            strcat(temp, node->label->name);
            cpu9900_2op("movb", temp, "r0");
            break;
        case N_LOAD16:  /* Load 16-bit value from address */
            strcpy(temp, "@");
            strcat(temp, LABEL_PREFIX);
            strcat(temp, node->label->name);
            cpu9900_2op("mov", temp, "r0");
            break;
        case N_NUM8:    /* Load 8-bit constant */
            sprintf(temp, "%d", (node->value)*256);
            cpu9900_2op("li", "r0", temp);
            break;
        case N_NUM16:   /* Load 16-bit constant */
            sprintf(temp, "%d", node->value);
            cpu9900_2op("li", "r0", temp);
            break;
        case N_PEEK8:   /* Load 8-bit content */
            if (node->left->type == N_ADDR) {   /* Optimize address */
                node_get_label(node->left, ADDRESS);
                cpu9900_2op("movb", temp, "r0");
                break;
            }
            if ((node->left->type == N_PLUS16 || node->left->type == N_MINUS16)
                && node->left->left->type == N_ADDR
                && node->left->right->type == N_NUM16) {    /* Optimize address plus constant */
                char *p;
                
                node_get_label(node->left->left, ADDRESS);        // address
                p = temp;
                while (*p)
                    p++;
                if (node->left->type == N_PLUS16)
                    *p++ = '+';
                else
                    *p++ = '-';
                sprintf(p, "%d", node->left->right->value); // constant
                cpu9900_2op("movb", temp, "r0");
                break;
            }
            // so presumably here we are reading from something loaded into r0
            cpu9900_node_generate(node->left, 0);
            cpu9900_2op("movb","*r0","r0");
            break;
        case N_PEEK16:  /* Load 16-bit content - must be aligned! */
            if (node->left->type == N_ADDR) {   /* Optimize address */
                node_get_label(node->left, ADDRESS);
                cpu9900_2op("mov", temp, "r0");
                break;
            }
            if ((node->left->type == N_PLUS16 || node->left->type == N_MINUS16)
                && node->left->left->type == N_ADDR
                && node->left->right->type == N_NUM16) {    /* Optimize address plus constant */
                char *p;
                
                node_get_label(node->left->left, ADDRESS);
                p = temp;
                while (*p)
                    p++;
                if (node->left->type == N_PLUS16)
                    *p++ = '+';
                else
                    *p++ = '-';
                sprintf(p, "%d", node->left->right->value);
                cpu9900_2op("mov", temp, "r0");
                break;
            }
            cpu9900_node_generate(node->left, 0);
            cpu9900_2op("mov", "*r0", "r0");
            break;
        case N_VPEEK:   /* Read VRAM */
            cpu9900_node_generate(node->left, 0);
            cpu9900_1op("limi", "0");
            cpu9900_1op("bl", "@jsr");
            cpu9900_1op("data", "RDVRM");
            cpu9900_1op("limi", "2");
            break;
        case N_INP:     /* Read port */
            cpu9900_1op("clr", "r0");   /* Do nothing */
            break;
        case N_JOY1:    /* Read joystick 1 */
            cpu9900_2op("movb", "@joy1_data", "r0");
            break;
        case N_JOY2:    /* Read joystick 2 */
            cpu9900_2op("movb", "@joy2_data", "r0");
            break;
        case N_KEY1:    /* Read keypad 1 */
            cpu9900_2op("movb", "@key1_data", "r0");
            break;
        case N_KEY2:    /* Read keypad 2 */
            cpu9900_2op("movb", "@key2_data", "r0");
            break;
        case N_RANDOM:  /* Read pseudorandom generator */
            cpu9900_1op("bl", "@jsr");
            cpu9900_1op("data", "random");
            break;
        case N_FRAME:   /* Read current frame number */
            cpu9900_2op("mov", "@frame", "r0");
            break;
        case N_MUSIC:   /* Read music playing status */
            cpu9900_2op("movb", "@music_playing", "r0");
            break;
        case N_NTSC:    /* Read NTSC flag */
            cpu9900_2op("movb", "@ntsc", "r0");
            break;
        case N_OR8:     /* 8-bit OR */
        case N_XOR8:    /* 8-bit XOR */
        case N_AND8:    /* 8-bit AND */
        case N_EQUAL8:  /* 8-bit = */
        case N_NOTEQUAL8:   /* 8-bit <> */
        case N_LESS8:   /* 8-bit < */
        case N_LESSEQUAL8:  /* 8-bit <= */
        case N_GREATER8:    /* 8-bit > */
        case N_GREATEREQUAL8:   /* 8-bit >= */
        case N_PLUS8:   /* 8-bit + */
        case N_MINUS8:  /* 8-bit - */
        case N_MUL8:    /* 8-bit * */
        case N_DIV8:    /* 8-bit / */
            if (node->type == N_MUL8 && node->right->type == N_NUM8 && is_power_of_two(node->right->value)) {
                int c,cnt;
                
                // power of 2 multiply
                cpu9900_node_generate(node->left, 0);
                c = node->right->value;
                cnt = 0;
                while (c > 1) {
                    ++cnt;
                    c /= 2;
                }
                // not sure if treating full 16 bit here is okay? we'll see... should be!
                if (cnt >= 16) {
                    cpu9900_1op("clr","r0");
                } else {
                    sprintf(temp, "%d", cnt);
                    cpu9900_2op("sla","r0",temp);
                }
                break;
            }
            if (node->type == N_DIV8 && node->right->type == N_NUM8 && is_power_of_two(node->right->value)) {
                int c, cnt;
                
                // power of 2 divide
                cpu9900_node_generate(node->left, 0);
                c = node->right->value;
                cnt = 0;
                while (c > 1) {
                    ++cnt;
                    c /= 2;
                }
                if (cnt >= 16) {
                    cpu9900_1op("clr","r0");
                } else {
                    sprintf(temp, "%d", cnt);
                    cpu9900_2op("srl","r0",temp);
                }
                break;
            }
            if (node->type == N_LESSEQUAL8 || node->type == N_GREATER8) {
                if (node->left->type == N_NUM8) {
                    cpu9900_noop("* Unclear code - N_LESSEQUAL8 || N_GREATER8 left=N_NUM8");
                    cpu9900_node_generate(node->right, 0);
                    sprintf(temp,"%d",(node->left->value&0xff)*256);
                    cpu9900_2op("li","r1",temp);
                    strcpy(temp, "r1");
                } else {
                    cpu9900_noop("* Unclear code - N_LESSEQUAL8 || N_GREATER8 left!=N_NUM8");
                    // Is there a reason right needs to go first? Can't we swap them?
                    cpu9900_node_generate(node->right, 0);
                    cpu9900_2op("mov","r0","r2");
                    cpu9900_node_generate(node->left, 0);
                    cpu9900_2op("mov","r0","r1");
                    cpu9900_2op("mov","r2","r0");
                    strcpy(temp, "r1");
                }
            } else if (node->right->type == N_NUM8) {
                int c;
                cpu9900_noop("* Unclear code - node->right->type == N_NUM8");
                c = node->right->value & 0xff;
                cpu9900_node_generate(node->left, 0);
                sprintf(temp, "%d", c);
            } else {
                cpu9900_noop("* Unclear code - node->right->type != N_NUM8");
                // again, why this order?
                cpu9900_node_generate(node->left, 0);
                cpu9900_2op("mov","r0","r2");
                cpu9900_node_generate(node->right, 0);
                cpu9900_2op("mov","r0","r1");
                cpu9900_2op("mov","r2","r0");
                strcpy(temp, "r1");
            }
            
*************************************            
            
            if (node->type == N_OR8) {
                cpu9900_1op("ORA", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BNE", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_XOR8) {
                cpu9900_1op("EOR", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BNE", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_AND8) {
                cpu9900_1op("AND", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BNE", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_EQUAL8) {
                cpu9900_1op("CMP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BEQ", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BEQ", temp);
                    cpu9900_1op("LDA", "#0");
                    cpu9900_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu9900_label(temp);
                    cpu9900_1op("LDA", "#255");
                    cpu9900_empty();
                }
            } else if (node->type == N_NOTEQUAL8) {
                cpu9900_1op("CMP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BNE", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BNE", temp);
                    cpu9900_1op("LDA", "#0");
                    cpu9900_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu9900_label(temp);
                    cpu9900_1op("LDA", "#255");
                    cpu9900_empty();
                }
            } else if (node->type == N_LESS8) {
                cpu9900_1op("CMP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BCC", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BCC", temp);
                    cpu9900_1op("LDA", "#0");
                    cpu9900_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu9900_label(temp);
                    cpu9900_1op("LDA", "#255");
                    cpu9900_empty();
                }
            } else if (node->type == N_LESSEQUAL8) {
                cpu9900_1op("CMP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BCS", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BCS", temp);
                    cpu9900_1op("LDA", "#0");
                    cpu9900_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu9900_label(temp);
                    cpu9900_1op("LDA", "#255");
                    cpu9900_empty();
                }
            } else if (node->type == N_GREATER8) {
                cpu9900_1op("CMP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BCC", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BCC", temp);
                    cpu9900_1op("LDA", "#0");
                    cpu9900_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu9900_label(temp);
                    cpu9900_1op("LDA", "#255");
                    cpu9900_empty();
                }
            } else if (node->type == N_GREATEREQUAL8) {
                cpu9900_1op("CMP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BCS", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BCS", temp);
                    cpu9900_1op("LDA", "#0");
                    cpu9900_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu9900_label(temp);
                    cpu9900_1op("LDA", "#255");
                    cpu9900_empty();
                }
            } else if (node->type == N_PLUS8) {
                cpu9900_noop("CLC");
                cpu9900_1op("ADC", temp);
            } else if (node->type == N_MINUS8) {
                cpu9900_noop("SEC");
                cpu9900_1op("SBC", temp);
            }
            break;
        case N_ASSIGN8: /* 8-bit assignment */
            if (node->right->type == N_ADDR) {
                cpu9900_node_generate(node->left, 0);
                node_get_label(node->right, 0);
                cpu9900_1op("STA", temp);
                break;
            }
            if ((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16) {
                char *p;
                
                cpu9900_node_generate(node->left, 0);
                node_get_label(node->right->left, 0);
                p = temp;
                while (*p)
                    p++;
                if (node->right->type == N_PLUS16)
                    *p++ = '+';
                else
                    *p++ = '-';
                sprintf(p, "%d", node->right->right->value);
                cpu9900_1op("STA", temp);
                break;
            }
            cpu9900_node_generate(node->left, 0);
            cpu9900_noop("PHA");
            cpu9900_node_generate(node->right, 0);
            cpu9900_1op("STA", "temp");
            cpu9900_1op("STY", "temp+1");
            cpu9900_noop("PLA");
            cpu9900_1op("LDY", "#0");
            cpu9900_1op("STA", "(temp),Y");
            break;
        case N_ASSIGN16:    /* 16-bit assignment */
            if (node->right->type == N_ADDR) {
                cpu9900_node_generate(node->left, 0);
                node_get_label(node->right, 0);
                cpu9900_1op("STA", temp);
                strcat(temp, "+1");
                cpu9900_1op("STY", temp);
                break;
            }
            if ((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16) {
                char *p;
                
                cpu9900_node_generate(node->left, 0);
                node_get_label(node->right->left, 0);
                p = temp;
                while (*p)
                    p++;
                if (node->right->type == N_PLUS16)
                    *p++ = '+';
                else
                    *p++ = '-';
                sprintf(p, "%d", node->right->right->value);
                cpu9900_1op("STA", temp);
                strcat(temp, "+1");
                cpu9900_1op("STY", temp);
                break;
            }
            cpu9900_node_generate(node->left, 0);
            cpu9900_noop("PHA");
            cpu9900_noop("TYA");
            cpu9900_noop("PHA");
            cpu9900_node_generate(node->right, 0);
            cpu9900_1op("STA", "temp");
            cpu9900_1op("STY", "temp+1");
            cpu9900_noop("PLA");
            cpu9900_1op("LDY", "#1");
            cpu9900_1op("STA", "(temp),Y");
            cpu9900_noop("PLA");
            cpu9900_noop("DEY");
            cpu9900_1op("STA", "(temp),Y");
            break;
        default:    /* Every other node, all remaining are 16-bit operations */
            /* Optimization of address plus/minus constant */
            if (node->type == N_PLUS16 || node->type == N_MINUS16) {
                if (node->left->type == N_ADDR) {
                    if (node->right->type == N_NUM16) {
                        char *p;
                        
                        node_get_label(node->left, 2);
                        if (node->type == N_PLUS16)
                            strcat(temp, "+");
                        else
                            strcat(temp, "-");
                        p = temp;
                        while (*p)
                            p++;
                        sprintf(p, "%d", node->right->value);
                        cpu9900_1op("LDA", temp);
                        node_get_label(node->left, 3);
                        if (node->type == N_PLUS16)
                            strcat(temp, "+");
                        else
                            strcat(temp, "-");
                        p = temp;
                        while (*p)
                            p++;
                        sprintf(p, "%d)>>8", node->right->value);
                        cpu9900_1op("LDY", temp);
                        break;
                    }
                }
            }
            if (node->type == N_PLUS16) {
                if (node->left->type == N_ADDR) {
                    cpu9900_node_generate(node->right, 0);
                    node_get_label(node->left, 2);
                    cpu9900_noop("CLC");
                    cpu9900_1op("ADC", temp);
                    cpu9900_noop("PHA");
                    cpu9900_noop("TYA");
                    strcat(temp, ">>8");
                    cpu9900_1op("ADC", temp);
                    cpu9900_noop("TAY");
                    cpu9900_noop("PLA");
                    break;
                }
                if (node->left->type == N_NUM16 || node->right->type == N_NUM16) {
                    int c;
                    
                    if (node->left->type == N_NUM16)
                        explore = node->left;
                    else
                        explore = node->right;
                    if (node->left != explore)
                        cpu9900_node_generate(node->left, 0);
                    else
                        cpu9900_node_generate(node->right, 0);
                    c = explore->value;
                    sprintf(temp, "#%d", c & 0xff);
                    cpu9900_noop("CLC");
                    cpu9900_1op("ADC", temp);
                    cpu9900_noop("PHA");
                    cpu9900_noop("TYA");
                    sprintf(temp, "#%d", c >> 8);
                    cpu9900_1op("ADC", temp);
                    cpu9900_noop("TAY");
                    cpu9900_noop("PLA");
                    break;
                }
            }
            if (node->type == N_MINUS16) {
                if (node->right->type == N_NUM16)
                    explore = node->right;
                else
                    explore = NULL;
                if (explore != NULL) {
                    int c = explore->value;
                    
                    cpu9900_node_generate(node->left, 0);
                    sprintf(temp, "#%d", c & 0xff);
                    cpu9900_noop("SEC");
                    cpu9900_1op("SBC", temp);
                    cpu9900_noop("PHA");
                    cpu9900_noop("TYA");
                    sprintf(temp, "#%d", c >> 8);
                    cpu9900_1op("SBC", temp);
                    cpu9900_noop("TAY");
                    cpu9900_noop("PLA");
                    break;
                }
            }
            if (node->type == N_OR16 || node->type == N_AND16 || node->type == N_XOR16) {
                if (node->right->type == N_NUM16)
                    explore = node->right;
                else
                    explore = NULL;
                if (explore != NULL) {
                    int value = explore->value;
                    int byte;
                    char *mnemonic;
                    
                    if (node->type == N_OR16) {
                        mnemonic = "ORA";
                    } else if (node->type == N_AND16) {
                        mnemonic = "AND";
                    } else /*if (node->type == N_XOR16)*/ {
                        mnemonic = "EOR";
                    }
                    if (node->left != explore)
                        cpu9900_node_generate(node->left, 0);
                    else
                        cpu9900_node_generate(node->right, 0);
                    byte = value & 0xff;
                    if ((node->type == N_OR16 || node->type == N_XOR16) && byte == 0x00) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0xff) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0x00) {
                        cpu9900_1op("LDA", "#0");
                    } else if (node->type == N_OR16 && byte == 0xff) {
                        cpu9900_1op("LDA", "#255");
                    } else {
                        sprintf(temp, "#%d", byte);
                        cpu9900_1op(mnemonic, temp);
                    }
                    byte = (value >> 8) & 0xff;
                    if ((node->type == N_OR16 || node->type == N_XOR16) && byte == 0x00) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0xff) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0x00) {
                        cpu9900_1op("LDY", "#0");
                    } else if (node->type == N_OR16 && byte == 0xff) {
                        cpu9900_1op("LDY", "#255");
                    } else {
                        cpu9900_noop("PHA");
                        cpu9900_noop("TYA");
                        sprintf(temp, "#%d", byte);
                        cpu9900_1op(mnemonic, temp);
                        cpu9900_noop("TAY");
                        cpu9900_noop("PLA");
                    }
                    break;
                }
            }
            if (node->type == N_MUL16) {
                if (node->left->type == N_NUM16)
                    explore = node->left;
                else if (node->right->type == N_NUM16)
                    explore = node->right;
                else
                    explore = NULL;
                if (explore != NULL && (explore->value == 0 || explore->value == 1 || is_power_of_two(explore->value))) {
                    int c = explore->value;
                    
                    if (c == 0) {
                        cpu9900_1op("LDA", "#0");
                        cpu9900_noop("TAY");
                    } else {
                        if (node->left != explore)
                            node = node->left;
                        else
                            node = node->right;
                        if (c >= 256) {
                            if (node->type == N_EXTEND8 || node->type == N_EXTEND8S) {
                                cpu9900_node_generate(node->left, 0);
                                cpu9900_noop("TAY");
                                cpu9900_1op("LDA", "#0");
                            } else {
                                cpu9900_node_generate(node, 0);
                                cpu9900_noop("TAY");
                                cpu9900_1op("LDA", "#0");
                            }
                            c /= 256;
                        } else {
                            cpu9900_node_generate(node, 0);
                        }
                        cpu9900_1op("STY", "temp");
                        while (c > 1) {
                            cpu9900_1op("ASL", "A");
                            cpu9900_1op("ROL", "temp");
                            c /= 2;
                        }
                        cpu9900_1op("LDY", "temp");
                    }
                    break;
                }
            }
            if (node->type == N_DIV16) {
                if (node->right->type == N_NUM16 && (node->right->value == 2 || node->right->value == 4 || node->right->value == 8)) {
                    int c;
                    
                    cpu9900_node_generate(node->left, 0);
                    c = node->right->value;
                    cpu9900_1op("STY", "temp");
                    do {
                        cpu9900_1op("LSR", "temp");
                        cpu9900_1op("ROR", "A");
                        c /= 2;
                    } while (c > 1) ;
                    cpu9900_1op("LDY", "temp");
                    break;
                }
            }
            if (node->type == N_LESSEQUAL16 || node->type == N_GREATER16) {
                cpu9900_node_generate(node->right, 0);
                cpu9900_noop("PHA");
                cpu9900_noop("TYA");
                cpu9900_noop("PHA");
                cpu9900_node_generate(node->left, 0);
                cpu9900_1op("STA", "temp");
                cpu9900_1op("STY", "temp+1");
            } else {
                cpu9900_node_generate(node->left, 0);
                cpu9900_noop("PHA");
                cpu9900_noop("TYA");
                cpu9900_noop("PHA");
                cpu9900_node_generate(node->right, 0);
                cpu9900_1op("STA", "temp");
                cpu9900_1op("STY", "temp+1");
            }
            if (node->type == N_OR16) {
                cpu9900_noop("PLA");
                cpu9900_1op("ORA", "temp+1");
                cpu9900_noop("TAY");
                cpu9900_noop("PLA");
                cpu9900_1op("ORA", "temp");
                if (decision) {
                    optimized = 1;
                    cpu9900_1op("STY", "temp");
                    cpu9900_1op("ORA", "temp");
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BNE", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_XOR16) {
                cpu9900_noop("PLA");
                cpu9900_1op("EOR", "temp+1");
                cpu9900_noop("TAY");
                cpu9900_noop("PLA");
                cpu9900_1op("EOR", "temp");
                if (decision) {
                    optimized = 1;
                    cpu9900_1op("STY", "temp");
                    cpu9900_1op("ORA", "temp");
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BNE", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_AND16) {
                cpu9900_noop("PLA");
                cpu9900_1op("AND", "temp+1");
                cpu9900_noop("TAY");
                cpu9900_noop("PLA");
                cpu9900_1op("AND", "temp");
                if (decision) {
                    optimized = 1;
                    cpu9900_1op("STY", "temp");
                    cpu9900_1op("ORA", "temp");
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BNE", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_EQUAL16) {
                cpu9900_noop("PLA");
                cpu9900_noop("TAY");
                cpu9900_noop("PLA");
                cpu9900_noop("SEC");
                cpu9900_1op("SBC", "temp");
                cpu9900_1op("STA", "temp");
                cpu9900_noop("TYA");
                cpu9900_1op("SBC", "temp+1");
                cpu9900_1op("ORA", "temp");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BEQ", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BEQ", temp);
                    cpu9900_1op("LDA", "#0");
                    cpu9900_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu9900_label(temp);
                    cpu9900_1op("LDA", "#255");
                    cpu9900_empty();
                }
            } else if (node->type == N_NOTEQUAL16) {
                cpu9900_noop("PLA");
                cpu9900_noop("TAY");
                cpu9900_noop("PLA");
                cpu9900_noop("SEC");
                cpu9900_1op("SBC", "temp");
                cpu9900_1op("STA", "temp");
                cpu9900_noop("TYA");
                cpu9900_1op("SBC", "temp+1");
                cpu9900_1op("ORA", "temp");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BNE", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BNE", temp);
                    cpu9900_1op("LDA", "#0");
                    cpu9900_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu9900_label(temp);
                    cpu9900_1op("LDA", "#255");
                    cpu9900_empty();
                }
            } else if (node->type == N_LESS16 || node->type == N_GREATER16) {
                cpu9900_noop("PLA");
                cpu9900_noop("TAY");
                cpu9900_noop("PLA");
                cpu9900_noop("SEC");
                cpu9900_1op("SBC", "temp");
                cpu9900_noop("TYA");
                cpu9900_1op("SBC", "temp+1");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BCC", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BCC", temp);
                    cpu9900_1op("LDA", "#0");
                    cpu9900_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu9900_label(temp);
                    cpu9900_1op("LDA", "#255");
                    cpu9900_empty();
                }
            } else if (node->type == N_LESSEQUAL16 || node->type == N_GREATEREQUAL16) {
                cpu9900_noop("PLA");
                cpu9900_noop("TAY");
                cpu9900_noop("PLA");
                cpu9900_noop("SEC");
                cpu9900_1op("SBC", "temp");
                cpu9900_noop("TYA");
                cpu9900_1op("SBC", "temp+1");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BCS", temp + 100);
                    cpu9900_1op("JMP", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("BCS", temp);
                    cpu9900_1op("LDA", "#0");
                    cpu9900_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu9900_label(temp);
                    cpu9900_1op("LDA", "#255");
                    cpu9900_empty();
                }
            } else if (node->type == N_PLUS16) {
                cpu9900_noop("PLA");
                cpu9900_noop("TAY");
                cpu9900_noop("PLA");
                cpu9900_noop("CLC");
                cpu9900_1op("ADC", "temp");
                cpu9900_noop("TAX");
                cpu9900_noop("TYA");
                cpu9900_1op("ADC", "temp+1");
                cpu9900_noop("TAY");
                cpu9900_noop("TXA");
            } else if (node->type == N_MINUS16) {
                cpu9900_noop("PLA");
                cpu9900_noop("TAY");
                cpu9900_noop("PLA");
                cpu9900_noop("SEC");
                cpu9900_1op("SBC", "temp");
                cpu9900_noop("TAX");
                cpu9900_noop("TYA");
                cpu9900_1op("SBC", "temp+1");
                cpu9900_noop("TAY");
                cpu9900_noop("TXA");
            } else if (node->type == N_MUL16) {
                cpu9900_1op("JSR", "_mul16");
            } else if (node->type == N_DIV16) {
                cpu9900_1op("JSR", "_div16");
            } else if (node->type == N_MOD16) {
                cpu9900_1op("JSR", "_mod16");
            } else if (node->type == N_DIV16S) {
                cpu9900_1op("JSR", "_div16s");
            } else if (node->type == N_MOD16S) {
                cpu9900_1op("JSR", "_mod16s");
            }
            break;
    }
}
