/*
 ** 6502 assembler output routines for CVBasic
 **
 ** by Oscar Toledo G.
 **
 ** Creation date: Aug/04/2024.
 */

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include "cvbasic.h"
#include "node.h"

static char temp2[MAX_LINE_SIZE];

static char cpu6502_line[MAX_LINE_SIZE];

static void cpu6502_emit_line(void);
static int cpu6502_8bit_simple(struct node *);

void cpu6502_emit_line(void)
{
    fprintf(output, "%s", cpu6502_line);
}

void cpu6502_dump(void)
{
}

/*
 ** Emit a 6502 label
 */
void cpu6502_label(char *label)
{
    sprintf(cpu6502_line, "%s:\n", label);
    cpu6502_emit_line();
}

/*
 ** Reset accumulator register (technically a null label)
 */
void cpu6502_empty(void)
{
}

/*
 ** Emit a Z80 instruction with no operand
 */
void cpu6502_noop(char *mnemonic)
{
    sprintf(cpu6502_line, "\t%s\n", mnemonic);
    cpu6502_emit_line();
}

/*
 ** Emit a Z80 instruction with a single operand
 */
void cpu6502_1op(char *mnemonic, char *operand)
{
    sprintf(cpu6502_line, "\t%s %s\n", mnemonic, operand);
    cpu6502_emit_line();
}

/*
 ** Label register usage in tree
 **
 ** This should match exactly register usage in cpu6502_node_generate.
 */
void cpu6502_node_label(struct node *node)
{
    /* Nothing to do, yet */
}

/*
 ** Detect operations that only use A.
 */
static int cpu6502_8bit_simple(struct node *node)
{
    switch (node->type) {
        case N_LOAD8:
        case N_NUM8:
        case N_INP:
        case N_JOY1:
        case N_JOY2:
        case N_KEY1:
        case N_KEY2:
        case N_MUSIC:
        case N_NTSC:
            return 1;
        case N_NEG8:
        case N_NOT8:
            return cpu6502_8bit_simple(node->left);
        default:
            return 0;
    }
}

/*
 ** Generate code for tree
 */
void cpu6502_node_generate(struct node *node, int decision)
{
    struct node *explore;
    int stack;
    int c;
    char *p;
    
    switch (node->type) {
        case N_USR:     /* Assembly language function with result */
            if (node->left != NULL)
                cpu6502_node_generate(node->left, 0);
            cpu6502_1op("JSR", node->label->name);
            break;
        case N_ADDR:    /* Get address of variable */
            node_get_label(node, 2);
            cpu6502_1op("LDA", temp);
            strcat(temp, ">>8");
            cpu6502_1op("LDY", temp);
            break;
        case N_NEG8:    /* Negate 8-bit value */
            cpu6502_node_generate(node->left, 0);
            cpu6502_1op("EOR", "#255");
            cpu6502_noop("CLC");
            cpu6502_1op("ADC", "#1");
            break;
        case N_NOT8:    /* Complement 8-bit value */
            cpu6502_node_generate(node->left, 0);
            cpu6502_1op("EOR", "#255");
            break;
        case N_NEG16:   /* Negate 16-bit value */
            cpu6502_node_generate(node->left, 0);
            cpu6502_1op("EOR", "#255");
            cpu6502_noop("CLC");
            cpu6502_1op("ADC", "#1");
            cpu6502_noop("PHA");
            cpu6502_noop("TYA");
            cpu6502_1op("EOR", "#255");
            cpu6502_1op("ADC", "#0");
            cpu6502_noop("TAY");
            cpu6502_noop("PLA");
            break;
        case N_NOT16:   /* Complement 16-bit value */
            cpu6502_node_generate(node->left, 0);
            cpu6502_1op("EOR", "#255");
            cpu6502_noop("PHA");
            cpu6502_noop("TYA");
            cpu6502_1op("EOR", "#255");
            cpu6502_noop("TAY");
            cpu6502_noop("PLA");
            break;
        case N_ABS16:   /* Get absolute 16-bit value */
            cpu6502_node_generate(node->left, 0);
            cpu6502_1op("JSR", "_abs16");
            break;
        case N_SGN16:   /* Get sign of 16-bit value */
            cpu6502_node_generate(node->left, 0);
            cpu6502_1op("JSR", "_sgn16");
            break;
        case N_POS:     /* Get screen cursor position */
            cpu6502_1op("LDA", "cursor");
            cpu6502_1op("LDY", "cursor+1");
            break;
        case N_EXTEND8S:    /* Extend 8-bit signed value to 16-bit */
            cpu6502_node_generate(node->left, 0);
            sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
            cpu6502_noop("PHA");
            cpu6502_1op("AND", "#128");
            cpu6502_1op("BPL", temp);
            cpu6502_1op("LDA", "#255");
            cpu6502_label(temp);
            cpu6502_noop("TAY");
            cpu6502_noop("PLA");
            break;
        case N_EXTEND8: /* Extend 8-bit value to 16-bit */
            cpu6502_node_generate(node->left, 0);
            cpu6502_1op("LDY", "#0");
            break;
        case N_REDUCE16:    /* Reduce 16-bit value to 8-bit */
            cpu6502_node_generate(node->left, 0);
            break;
        case N_READ8:   /* Read 8-bit value */
            cpu6502_1op("JSR", "_read8");
            break;
        case N_READ16:  /* Read 16-bit value */
            cpu6502_1op("JSR", "_read16");
            break;
        case N_LOAD8:   /* Load 8-bit value from address */
            strcpy(temp, LABEL_PREFIX);
            strcat(temp, node->label->name);
            cpu6502_1op("LDA", temp);
            break;
        case N_LOAD16:  /* Load 16-bit value from address */
            strcpy(temp, LABEL_PREFIX);
            strcat(temp, node->label->name);
            cpu6502_1op("LDA", temp);
            strcat(temp, "+1");
            cpu6502_1op("LDY", temp);
            break;
        case N_NUM8:    /* Load 8-bit constant */
            sprintf(temp, "#%d", node->value);
            cpu6502_1op("LDA", temp);
            break;
        case N_NUM16:   /* Load 16-bit constant */
            sprintf(temp, "#%d", node->value & 0xff);
            cpu6502_1op("LDA", temp);
            sprintf(temp, "#%d", node->value >> 8);
            cpu6502_1op("LDY", temp);
            break;
        case N_PEEK8:   /* Load 8-bit content */
            if (node->left->type == N_ADDR) {   /* Optimize address */
                node_get_label(node->left, 0);
                cpu6502_1op("LDA", temp);
                break;
            }
            if ((node->left->type == N_PLUS16 || node->left->type == N_MINUS16)
                && node->left->left->type == N_ADDR
                && node->left->right->type == N_NUM16) {    /* Optimize address plus constant */
                node_get_label(node->left->left, 0);
                p = temp;
                while (*p)
                    p++;
                if (node->left->type == N_PLUS16)
                    *p++ = '+';
                else
                    *p++ = '-';
                sprintf(p, "%d", node->left->right->value);
                cpu6502_1op("LDA", temp);
                break;
            }
            cpu6502_node_generate(node->left, 0);
            cpu6502_1op("JSR", "_peek8");
            break;
        case N_PEEK16:  /* Load 16-bit content */
            if (node->left->type == N_ADDR) {   /* Optimize address */
                node_get_label(node->left, 0);
                cpu6502_1op("LDA", temp);
                strcat(temp, "+1");
                cpu6502_1op("LDY", temp);
                break;
            }
            if ((node->left->type == N_PLUS16 || node->left->type == N_MINUS16)
                && node->left->left->type == N_ADDR
                && node->left->right->type == N_NUM16) {    /* Optimize address plus constant */
                node_get_label(node->left->left, 0);
                p = temp;
                while (*p)
                    p++;
                if (node->left->type == N_PLUS16)
                    *p++ = '+';
                else
                    *p++ = '-';
                sprintf(p, "%d", node->left->right->value);
                cpu6502_1op("LDA", temp);
                strcat(temp, "+1");
                cpu6502_1op("LDY", temp);
                break;
            }
            cpu6502_node_generate(node->left, 0);
            cpu6502_1op("JSR", "_peek16");
            break;
        case N_VPEEK:   /* Read VRAM */
            cpu6502_node_generate(node->left, 0);
            cpu6502_noop("SEI");
            cpu6502_1op("JSR", "RDVRM");
            cpu6502_noop("CLI");
            break;
        case N_INP:     /* Read port */
            cpu6502_1op("LDA", "#0");   /* Do nothing */
            break;
        case N_JOY1:    /* Read joystick 1 */
            cpu6502_1op("LDA", "joy1_data");
            break;
        case N_JOY2:    /* Read joystick 2 */
            cpu6502_1op("LDA", "joy2_data");
            break;
        case N_KEY1:    /* Read keypad 1 */
            cpu6502_1op("LDA", "key1_data");
            break;
        case N_KEY2:    /* Read keypad 2 */
            cpu6502_1op("LDA", "key2_data");
            break;
        case N_RANDOM:  /* Read pseudorandom generator */
            cpu6502_1op("JSR", "random");
            break;
        case N_FRAME:   /* Read current frame number */
            cpu6502_1op("LDA", "frame");
            cpu6502_1op("LDY", "frame+1");
            break;
        case N_MUSIC:   /* Read music playing status */
            cpu6502_1op("LDA", "music_playing");
            break;
        case N_NTSC:    /* Read NTSC flag */
            cpu6502_1op("LDA", "ntsc");
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
                cpu6502_node_generate(node->left, 0);
                c = node->right->value;
                while (c > 1) {
                    cpu6502_1op("ASL", "A");
                    c /= 2;
                }
                break;
            }
            if (node->type == N_DIV8 && node->right->type == N_NUM8 && is_power_of_two(node->right->value)) {
                cpu6502_node_generate(node->left, 0);
                c = node->right->value;
                while (c > 1) {
                    cpu6502_1op("LSR", "A");
                    c /= 2;
                }
                break;
            }
            if (node->type == N_LESSEQUAL8 || node->type == N_GREATER8) {
                if (node->left->type == N_NUM8) {
                    cpu6502_node_generate(node->right, 0);
                    sprintf(temp, "#%d", node->left->value & 0xff);
                } else if (node->left->type == N_LOAD8) {
                    cpu6502_node_generate(node->right, 0);
                    node_get_label(node->left, 0);
                } else {
                    cpu6502_node_generate(node->right, 0);
                    cpu6502_noop("PHA");
                    cpu6502_node_generate(node->left, 0);
                    cpu6502_1op("STA", "temp");
                    cpu6502_noop("PLA");
                    strcpy(temp, "temp");
                }
            } else if (node->right->type == N_LOAD8) {
                cpu6502_node_generate(node->left, 0);
                node_get_label(node->right, 0);
            } else if (node->right->type == N_NUM8) {
                c = node->right->value & 0xff;
                cpu6502_node_generate(node->left, 0);
                sprintf(temp, "#%d", c);
            } else {
                cpu6502_node_generate(node->left, 0);
                cpu6502_noop("PHA");
                cpu6502_node_generate(node->right, 0);
                cpu6502_1op("STA", "temp");
                cpu6502_noop("PLA");
                strcpy(temp, "temp");
            }
            if (node->type == N_OR8) {
                cpu6502_1op("ORA", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BNE", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                }
            } else if (node->type == N_XOR8) {
                cpu6502_1op("EOR", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BNE", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                }
            } else if (node->type == N_AND8) {
                cpu6502_1op("AND", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BNE", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                }
            } else if (node->type == N_EQUAL8) {
                cpu6502_1op("CMP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BEQ", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BEQ", temp);
                    cpu6502_1op("LDA", "#0");
                    cpu6502_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu6502_label(temp);
                    cpu6502_1op("LDA", "#255");
                    cpu6502_empty();
                }
            } else if (node->type == N_NOTEQUAL8) {
                cpu6502_1op("CMP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BNE", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BNE", temp);
                    cpu6502_1op("LDA", "#0");
                    cpu6502_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu6502_label(temp);
                    cpu6502_1op("LDA", "#255");
                    cpu6502_empty();
                }
            } else if (node->type == N_LESS8) {
                cpu6502_1op("CMP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BCC", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BCC", temp);
                    cpu6502_1op("LDA", "#0");
                    cpu6502_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu6502_label(temp);
                    cpu6502_1op("LDA", "#255");
                    cpu6502_empty();
                }
            } else if (node->type == N_LESSEQUAL8) {
                cpu6502_1op("CMP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BCS", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BCS", temp);
                    cpu6502_1op("LDA", "#0");
                    cpu6502_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu6502_label(temp);
                    cpu6502_1op("LDA", "#255");
                    cpu6502_empty();
                }
            } else if (node->type == N_GREATER8) {
                cpu6502_1op("CMP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BCC", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BCC", temp);
                    cpu6502_1op("LDA", "#0");
                    cpu6502_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu6502_label(temp);
                    cpu6502_1op("LDA", "#255");
                    cpu6502_empty();
                }
            } else if (node->type == N_GREATEREQUAL8) {
                cpu6502_1op("CMP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BCS", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BCS", temp);
                    cpu6502_1op("LDA", "#0");
                    cpu6502_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu6502_label(temp);
                    cpu6502_1op("LDA", "#255");
                    cpu6502_empty();
                }
            } else if (node->type == N_PLUS8) {
                cpu6502_noop("CLC");
                cpu6502_1op("ADC", temp);
            } else if (node->type == N_MINUS8) {
                cpu6502_noop("SEC");
                cpu6502_1op("SBC", temp);
            }
            break;
        case N_ASSIGN8: /* 8-bit assignment */
            if ((node->left->type == N_PLUS8 || node->left->type == N_MINUS8 || node->left->type == N_OR8 || node->left->type == N_AND8 || node->left->type == N_XOR8)
                && (node->left->right->type == N_NUM8 || node->left->right->type == N_LOAD8)
                && node_same_address(node->left->left, node->right)) {
                if (node->right->type == N_ADDR) {
                    node_get_label(node->right, 0);
                    strcpy(temp2, temp);
                    c = 0;
                } else if (((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16)) {
                    node_get_label(node->right->left, 0);
                    p = temp;
                    while (*p)
                        p++;
                    if (node->right->type == N_PLUS16)
                        *p++ = '+';
                    else
                        *p++ = '-';
                    sprintf(p, "%d", node->right->right->value);
                    strcpy(temp2, temp);
                    c = 0;
                } else {
                    if (node->right->type == N_PLUS16 && node->right->left->type == N_ADDR && node->right->right->type == N_EXTEND8 && node->right->right->left->type == N_LOAD8) {
                        node_get_label(node->right->right->left, 0);
                        strcpy(temp2, temp);
                        node_get_label(node->right->left, 2);
                        cpu6502_1op("LDA", temp);
                        cpu6502_noop("CLC");
                        cpu6502_1op("ADC", temp2);
                        cpu6502_1op("STA", "temp");
                        strcat(temp, ">>8");
                        cpu6502_1op("LDA", temp);
                        cpu6502_1op("ADC", "#0");
                        cpu6502_1op("STA", "temp+1");
                    } else {
                        cpu6502_node_generate(node->right, 0);
                        cpu6502_1op("STA", "temp");
                        cpu6502_1op("STY", "temp+1");
                    }
                    c = 1;
                    cpu6502_1op("LDY", "#0");
                    strcpy(temp2, "(temp),Y");
                }
                if (c == 0 && (node->left->type == N_PLUS8 || node->left->type == N_MINUS8) && node->left->right->type == N_NUM8 && node->left->right->value < 4) {
                    c = node->left->right->value;
                    do {
                        if (node->left->type == N_PLUS8)
                            cpu6502_1op("INC", temp2);
                        else
                            cpu6502_1op("DEC", temp2);
                    } while (--c) ;
                } else {
                    cpu6502_1op("LDA", temp2);
                    if (node->left->right->type == N_NUM8)
                        sprintf(temp, "#%d", node->left->right->value);
                    else if (node->left->right->type == N_LOAD8)
                        node_get_label(node->left->right, 0);
                    if (node->left->type == N_PLUS8) {
                        cpu6502_noop("CLC");
                        cpu6502_1op("ADC", temp);
                    } else if (node->left->type == N_MINUS8) {
                        cpu6502_noop("SEC");
                        cpu6502_1op("SBC", temp);
                    } else if (node->left->type == N_OR8) {
                        cpu6502_1op("ORA", temp);
                    } else if (node->left->type == N_AND8) {
                        cpu6502_1op("AND", temp);
                    } else if (node->left->type == N_XOR8) {
                        cpu6502_1op("EOR", temp);
                    }
                    cpu6502_1op("STA", temp2);
                }
                break;
            }
            
            if (node->right->type == N_ADDR
            || ((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16)) {
                cpu6502_node_generate(node->left, 0);
                if (node->right->type == N_ADDR) {
                    node_get_label(node->right, 0);
                } else {
                    node_get_label(node->right->left, 0);
                    p = temp;
                    while (*p)
                        p++;
                    if (node->right->type == N_PLUS16)
                        *p++ = '+';
                    else
                        *p++ = '-';
                    sprintf(p, "%d", node->right->right->value);
                }
                cpu6502_1op("STA", temp);
                break;
                
            }
            if (cpu6502_8bit_simple(node->left)) {
                cpu6502_node_generate(node->right, 0);
                cpu6502_1op("STA", "temp");
                cpu6502_1op("STY", "temp+1");
                cpu6502_node_generate(node->left, 0);
                cpu6502_1op("LDY", "#0");
                cpu6502_1op("STA", "(temp),Y");
            } else {
                cpu6502_node_generate(node->left, 0);
                cpu6502_noop("PHA");
                cpu6502_node_generate(node->right, 0);
                cpu6502_1op("STA", "temp");
                cpu6502_1op("STY", "temp+1");
                cpu6502_noop("PLA");
                cpu6502_1op("LDY", "#0");
                cpu6502_1op("STA", "(temp),Y");
            }
            break;
        case N_ASSIGN16:    /* 16-bit assignment */
            if (node->right->type == N_ADDR) {
                c = 1;
            } else if (((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16)) {
                c = 1;
            } else {
                c = 0;
            }
            if (node->left->type == N_PLUS16
                && node->left->right->type == N_NUM16
                && ((c && node->left->right->value == 1) || !c)
                && node_same_address(node->left->left, node->right)) {
                if (node->right->type == N_ADDR) {
                    node_get_label(node->right, 0);
                    c = 0;
                } else if (((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16)) {
                    node_get_label(node->right->left, 0);
                    p = temp;
                    while (*p)
                        p++;
                    if (node->right->type == N_PLUS16)
                        *p++ = '+';
                    else
                        *p++ = '-';
                    sprintf(p, "%d", node->right->right->value);
                    c = 0;
                } else {
                    cpu6502_node_generate(node->right, 0);
                    cpu6502_1op("STA", "temp");
                    cpu6502_1op("STY", "temp+1");
                    cpu6502_1op("LDY", "#0");
                    sprintf(temp, "#%d", node->left->right->value & 0xff);
                    sprintf(temp2, "#%d", node->left->right->value >> 8);
                    c = 1;
                }
                if (c == 1) {
                    cpu6502_noop("CLC");
                    cpu6502_1op("LDA", "(temp),Y");
                    cpu6502_1op("ADC", temp);
                    cpu6502_1op("STA", "(temp),Y");
                    cpu6502_noop("INY");
                    cpu6502_1op("LDA", "(temp),Y");
                    cpu6502_1op("ADC", temp2);
                    cpu6502_1op("STA", "(temp),Y");
                } else {
                    cpu6502_1op("INC", temp);
                    sprintf(temp2, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BNE", temp2);
                    if (c == 1)
                        cpu6502_noop("INY");
                    else
                        strcat(temp, "+1");
                    cpu6502_1op("INC", temp);
                    cpu6502_label(temp2);
                }
                break;
            }

            if (node->right->type == N_ADDR
             || ((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16)) {
                cpu6502_node_generate(node->left, 0);
                if (node->right->type == N_ADDR) {
                    node_get_label(node->right, 0);
                } else {
                    node_get_label(node->right->left, 0);
                    p = temp;
                    while (*p)
                        p++;
                    if (node->right->type == N_PLUS16)
                        *p++ = '+';
                    else
                        *p++ = '-';
                    sprintf(p, "%d", node->right->right->value);
                }
                cpu6502_1op("STA", temp);
                strcat(temp, "+1");
                cpu6502_1op("STY", temp);
                break;
            }
            if (node->left->type == N_NUM16 || node->left->type == N_LOAD16) {
                cpu6502_node_generate(node->right, 0);
                cpu6502_1op("STA", "temp");
                cpu6502_1op("STY", "temp+1");
                cpu6502_node_generate(node->left, 0);
                cpu6502_noop("TAX");
                cpu6502_noop("TYA");
                cpu6502_1op("LDY", "#1");
                cpu6502_1op("STA", "(temp),Y");
                cpu6502_noop("TXA");
                cpu6502_noop("DEY");
                cpu6502_1op("STA", "(temp),Y");
            } else {
                cpu6502_node_generate(node->left, 0);
                cpu6502_noop("PHA");
                cpu6502_noop("TYA");
                cpu6502_noop("PHA");
                cpu6502_node_generate(node->right, 0);
                cpu6502_1op("STA", "temp");
                cpu6502_1op("STY", "temp+1");
                cpu6502_noop("PLA");
                cpu6502_1op("LDY", "#1");
                cpu6502_1op("STA", "(temp),Y");
                cpu6502_noop("PLA");
                cpu6502_noop("DEY");
                cpu6502_1op("STA", "(temp),Y");
            }
            break;
        default:    /* Every other node, all remaining are 16-bit operations */
            /* Optimization of address plus/minus constant */
            if (node->type == N_PLUS16 || node->type == N_MINUS16) {
                if (node->left->type == N_ADDR) {
                    if (node->right->type == N_NUM16) {
                        node_get_label(node->left, 2);
                        if (node->type == N_PLUS16)
                            strcat(temp, "+");
                        else
                            strcat(temp, "-");
                        p = temp;
                        while (*p)
                            p++;
                        sprintf(p, "%d", node->right->value);
                        cpu6502_1op("LDA", temp);
                        node_get_label(node->left, 3);
                        if (node->type == N_PLUS16)
                            strcat(temp, "+");
                        else
                            strcat(temp, "-");
                        p = temp;
                        while (*p)
                            p++;
                        sprintf(p, "%d)>>8", node->right->value);
                        cpu6502_1op("LDY", temp);
                        break;
                    } else if (node->right->type == N_EXTEND8 && node->right->left->type == N_LOAD8) {
                        node_get_label(node->left, 2);
                        cpu6502_1op("LDA", temp);
                        cpu6502_noop("CLC");
                        node_get_label(node->right->left, 0);
                        cpu6502_1op("ADC", temp);
                        cpu6502_noop("TAX");
                        node_get_label(node->left, 2);
                        strcat(temp, ">>8");
                        cpu6502_1op("LDA", temp);
                        cpu6502_1op("ADC", "#0");
                        cpu6502_noop("TAY");
                        cpu6502_noop("TXA");
                        break;
                    }
                }
            }
            if (node->type == N_PLUS16) {
                if (node->left->type == N_ADDR) {
                    cpu6502_node_generate(node->right, 0);
                    node_get_label(node->left, 2);
                    cpu6502_noop("CLC");
                    cpu6502_1op("ADC", temp);
                    cpu6502_noop("TAX");
                    cpu6502_noop("TYA");
                    strcat(temp, ">>8");
                    cpu6502_1op("ADC", temp);
                    cpu6502_noop("TAY");
                    cpu6502_noop("TXA");
                    break;
                }
                if (node->left->type == N_NUM16 || node->right->type == N_NUM16) {
                    if (node->left->type == N_NUM16)
                        explore = node->left;
                    else
                        explore = node->right;
                    if (node->left != explore)
                        cpu6502_node_generate(node->left, 0);
                    else
                        cpu6502_node_generate(node->right, 0);
                    c = explore->value;
                    if ((c & 0xff) == 0 && (c & 0xff00) < 0x0800) {
                        c = c / 256;
                        while (c--)
                            cpu6502_noop("INY");
                        break;
                    }
                    sprintf(temp, "#%d", c & 0xff);
                    cpu6502_noop("CLC");
                    if ((c & 0xff) != 0)
                        cpu6502_1op("ADC", temp);
                    cpu6502_noop("TAX");
                    cpu6502_noop("TYA");
                    sprintf(temp, "#%d", c >> 8);
                    cpu6502_1op("ADC", temp);
                    cpu6502_noop("TAY");
                    cpu6502_noop("TXA");
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
                    
                    cpu6502_node_generate(node->left, 0);
                    if ((c & 0xff) == 0 && (c & 0xff00) < 0x0800) {
                        c = c / 256;
                        while (c--)
                            cpu6502_noop("DEY");
                        break;
                    }
                    sprintf(temp, "#%d", c & 0xff);
                    cpu6502_noop("SEC");
                    if ((c & 0xff) != 0)
                        cpu6502_1op("SBC", temp);
                    cpu6502_noop("TAX");
                    cpu6502_noop("TYA");
                    sprintf(temp, "#%d", c >> 8);
                    cpu6502_1op("SBC", temp);
                    cpu6502_noop("TAY");
                    cpu6502_noop("TXA");
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
                        cpu6502_node_generate(node->left, 0);
                    else
                        cpu6502_node_generate(node->right, 0);
                    byte = value & 0xff;
                    if ((node->type == N_OR16 || node->type == N_XOR16) && byte == 0x00) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0xff) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0x00) {
                        cpu6502_1op("LDA", "#0");
                    } else if (node->type == N_OR16 && byte == 0xff) {
                        cpu6502_1op("LDA", "#255");
                    } else {
                        sprintf(temp, "#%d", byte);
                        cpu6502_1op(mnemonic, temp);
                    }
                    byte = (value >> 8) & 0xff;
                    if ((node->type == N_OR16 || node->type == N_XOR16) && byte == 0x00) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0xff) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0x00) {
                        cpu6502_1op("LDY", "#0");
                    } else if (node->type == N_OR16 && byte == 0xff) {
                        cpu6502_1op("LDY", "#255");
                    } else {
                        cpu6502_noop("TAX");
                        cpu6502_noop("TYA");
                        sprintf(temp, "#%d", byte);
                        cpu6502_1op(mnemonic, temp);
                        cpu6502_noop("TAY");
                        cpu6502_noop("TXA");
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
                    c = explore->value;
                    if (c == 0) {
                        cpu6502_1op("LDA", "#0");
                        cpu6502_noop("TAY");
                    } else {
                        if (node->left != explore)
                            node = node->left;
                        else
                            node = node->right;
                        if (c >= 256) {
                            if (node->type == N_EXTEND8 || node->type == N_EXTEND8S) {
                                cpu6502_node_generate(node->left, 0);
                                cpu6502_noop("TAY");
                                cpu6502_1op("LDA", "#0");
                            } else {
                                cpu6502_node_generate(node, 0);
                                cpu6502_noop("TAY");
                                cpu6502_1op("LDA", "#0");
                            }
                            c /= 256;
                        } else {
                            cpu6502_node_generate(node, 0);
                        }
                        cpu6502_1op("STY", "temp");
                        while (c > 1) {
                            cpu6502_1op("ASL", "A");
                            cpu6502_1op("ROL", "temp");
                            c /= 2;
                        }
                        cpu6502_1op("LDY", "temp");
                    }
                    break;
                }
            }
            if (node->type == N_DIV16) {
                if (node->right->type == N_NUM16 && (node->right->value == 2 || node->right->value == 4 || node->right->value == 8)) {
                    cpu6502_node_generate(node->left, 0);
                    c = node->right->value;
                    cpu6502_1op("STY", "temp");
                    do {
                        cpu6502_1op("LSR", "temp");
                        cpu6502_1op("ROR", "A");
                        c /= 2;
                    } while (c > 1) ;
                    cpu6502_1op("LDY", "temp");
                    break;
                }
            }
            if (node->type == N_LESSEQUAL16 || node->type == N_GREATER16) {
                if (node->left->type == N_NUM16) {
                    cpu6502_node_generate(node->right, 0);
                    sprintf(temp, "#%d", node->left->value & 0xff);
                    sprintf(temp2, "#%d", (node->left->value >> 8) & 0xff);
                    stack = 0;
                } else if (node->left->type == N_LOAD16) {
                    cpu6502_node_generate(node->right, 0);
                    node_get_label(node->left, 0);
                    strcpy(temp2, temp);
                    strcat(temp2, "+1");
                    stack = 0;
                } else if (node->left->type == N_EXTEND8 && node->left->left->type == N_LOAD8) {
                    cpu6502_node_generate(node->right, 0);
                    node_get_label(node->left->left, 0);
                    strcpy(temp2, "#0");
                    stack = 0;
                } else {
                    cpu6502_node_generate(node->right, 0);
                    cpu6502_noop("PHA");
                    cpu6502_noop("TYA");
                    cpu6502_noop("PHA");
                    cpu6502_node_generate(node->left, 0);
                    cpu6502_1op("STA", "temp");
                    cpu6502_1op("STY", "temp+1");
                    stack = 1;
                }
            } else {
                if (node->right->type == N_NUM16) {
                    cpu6502_node_generate(node->left, 0);
                    sprintf(temp, "#%d", node->right->value & 0xff);
                    sprintf(temp2, "#%d", (node->right->value >> 8) & 0xff);
                    stack = 0;
                } else if (node->right->type == N_LOAD16) {
                    cpu6502_node_generate(node->left, 0);
                    node_get_label(node->right, 0);
                    strcpy(temp2, temp);
                    strcat(temp2, "+1");
                    stack = 0;
                } else if (node->right->type == N_EXTEND8 && node->right->left->type == N_LOAD8) {
                    cpu6502_node_generate(node->left, 0);
                    node_get_label(node->right->left, 0);
                    strcpy(temp2, "#0");
                    stack = 0;
                } else {
                    cpu6502_node_generate(node->left, 0);
                    cpu6502_noop("PHA");
                    cpu6502_noop("TYA");
                    cpu6502_noop("PHA");
                    cpu6502_node_generate(node->right, 0);
                    cpu6502_1op("STA", "temp");
                    cpu6502_1op("STY", "temp+1");
                    stack = 1;
                }
            }
            if (node->type == N_OR16) {
                if (stack) {
                    cpu6502_noop("PLA");
                    cpu6502_1op("ORA", "temp+1");
                    cpu6502_noop("TAY");
                    cpu6502_noop("PLA");
                    cpu6502_1op("ORA", "temp");
                } else {
                    cpu6502_1op("ORA", temp);
                    cpu6502_noop("TAX");
                    cpu6502_noop("TYA");
                    cpu6502_1op("ORA", temp2);
                    cpu6502_noop("TAY");
                    cpu6502_noop("TXA");
                }
                if (decision) {
                    optimized = 1;
                    cpu6502_1op("STY", "temp");
                    cpu6502_1op("ORA", "temp");
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BNE", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                }
            } else if (node->type == N_XOR16) {
                if (stack) {
                    cpu6502_noop("PLA");
                    cpu6502_1op("EOR", "temp+1");
                    cpu6502_noop("TAY");
                    cpu6502_noop("PLA");
                    cpu6502_1op("EOR", "temp");
                } else {
                    cpu6502_1op("EOR", temp);
                    cpu6502_noop("TAX");
                    cpu6502_noop("TYA");
                    cpu6502_1op("EOR", temp2);
                    cpu6502_noop("TAY");
                    cpu6502_noop("TXA");
                }
                if (decision) {
                    optimized = 1;
                    cpu6502_1op("STY", "temp");
                    cpu6502_1op("ORA", "temp");
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BNE", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                }
            } else if (node->type == N_AND16) {
                if (stack) {
                    cpu6502_noop("PLA");
                    cpu6502_1op("AND", "temp+1");
                    cpu6502_noop("TAY");
                    cpu6502_noop("PLA");
                    cpu6502_1op("AND", "temp");
                } else {
                    cpu6502_1op("AND", temp);
                    cpu6502_noop("TAX");
                    cpu6502_noop("TYA");
                    cpu6502_1op("AND", temp2);
                    cpu6502_noop("TAY");
                    cpu6502_noop("TXA");
                }
                if (decision) {
                    optimized = 1;
                    cpu6502_1op("STY", "temp");
                    cpu6502_1op("ORA", "temp");
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BNE", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                }
            } else if (node->type == N_EQUAL16) {
                if (stack) {
                    cpu6502_noop("PLA");
                    cpu6502_noop("TAY");
                    cpu6502_noop("PLA");
                    cpu6502_noop("SEC");
                    cpu6502_1op("SBC", "temp");
                    cpu6502_1op("STA", "temp");
                    cpu6502_noop("TYA");
                    cpu6502_1op("SBC", "temp+1");
                    cpu6502_1op("ORA", "temp");
                } else if (strcmp(temp, "#0") == 0 && strcmp(temp2, "#0") == 0) {
                    cpu6502_1op("STY", "temp");
                    cpu6502_1op("ORA", "temp");
                } else {
                    cpu6502_noop("SEC");
                    if (strcmp(temp, "#0") != 0)
                        cpu6502_1op("SBC", temp);
                    cpu6502_1op("STA", "temp");
                    cpu6502_noop("TYA");
                    cpu6502_1op("SBC", temp2);
                    cpu6502_1op("ORA", "temp");
                }
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BEQ", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BEQ", temp);
                    cpu6502_1op("LDA", "#0");
                    cpu6502_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu6502_label(temp);
                    cpu6502_1op("LDA", "#255");
                    cpu6502_empty();
                }
            } else if (node->type == N_NOTEQUAL16) {
                if (stack) {
                    cpu6502_noop("PLA");
                    cpu6502_noop("TAY");
                    cpu6502_noop("PLA");
                    cpu6502_noop("SEC");
                    cpu6502_1op("SBC", "temp");
                    cpu6502_1op("STA", "temp");
                    cpu6502_noop("TYA");
                    cpu6502_1op("SBC", "temp+1");
                    cpu6502_1op("ORA", "temp");
                } else if (strcmp(temp, "#0") == 0 && strcmp(temp2, "#0") == 0) {
                    cpu6502_1op("STY", "temp");
                    cpu6502_1op("ORA", "temp");
                } else {
                    cpu6502_noop("SEC");
                    if (strcmp(temp, "#0") != 0)
                        cpu6502_1op("SBC", temp);
                    cpu6502_1op("STA", "temp");
                    cpu6502_noop("TYA");
                    cpu6502_1op("SBC", temp2);
                    cpu6502_1op("ORA", "temp");
                }
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BNE", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BNE", temp);
                    cpu6502_1op("LDA", "#0");
                    cpu6502_1op("DB", "$2c");   /* BIT instruction to jump two bytes */
                    cpu6502_label(temp);
                    cpu6502_1op("LDA", "#255");
                    cpu6502_empty();
                }
            } else if (node->type == N_LESS16 || node->type == N_GREATER16) {
                if (stack) {
                    cpu6502_noop("PLA");
                    cpu6502_noop("TAY");
                    cpu6502_noop("PLA");
                    cpu6502_noop("SEC");
                    cpu6502_1op("SBC", "temp");
                    cpu6502_noop("TYA");
                    cpu6502_1op("SBC", "temp+1");
                } else {
                    cpu6502_noop("SEC");
                    cpu6502_1op("SBC", temp);
                    cpu6502_noop("TYA");
                    cpu6502_1op("SBC", temp2);
                }
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BCC", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                } else {
                    cpu6502_1op("LDA", "#255");
                    cpu6502_1op("ADC", "#0");   
                }
            } else if (node->type == N_LESSEQUAL16 || node->type == N_GREATEREQUAL16) {
                if (stack) {
                    cpu6502_noop("PLA");
                    cpu6502_noop("TAY");
                    cpu6502_noop("PLA");
                    cpu6502_noop("SEC");
                    cpu6502_1op("SBC", "temp");
                    cpu6502_noop("TYA");
                    cpu6502_1op("SBC", "temp+1");
                } else {
                    cpu6502_noop("SEC");
                    cpu6502_1op("SBC", temp);
                    cpu6502_noop("TYA");
                    cpu6502_1op("SBC", temp2);
                }
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu6502_1op("BCS", temp + 100);
                    cpu6502_1op("JMP", temp);
                    cpu6502_label(temp + 100);
                } else {
                    cpu6502_1op("LDA", "#255");
                    cpu6502_1op("ADC", "#0");
                    cpu6502_1op("EOR", "#255");
                }
            } else if (node->type == N_PLUS16) {
                if (stack) {
                    cpu6502_noop("PLA");
                    cpu6502_noop("TAY");
                    cpu6502_noop("PLA");
                    cpu6502_noop("CLC");
                    cpu6502_1op("ADC", "temp");
                    cpu6502_noop("TAX");
                    cpu6502_noop("TYA");
                    cpu6502_1op("ADC", "temp+1");
                    cpu6502_noop("TAY");
                    cpu6502_noop("TXA");
                } else {
                    cpu6502_noop("CLC");
                    cpu6502_1op("ADC", temp);
                    cpu6502_noop("TAX");
                    cpu6502_noop("TYA");
                    cpu6502_1op("ADC", temp2);
                    cpu6502_noop("TAY");
                    cpu6502_noop("TXA");
                }
            } else if (node->type == N_MINUS16) {
                if (stack) {
                    cpu6502_noop("PLA");
                    cpu6502_noop("TAY");
                    cpu6502_noop("PLA");
                    cpu6502_noop("SEC");
                    cpu6502_1op("SBC", "temp");
                    cpu6502_noop("TAX");
                    cpu6502_noop("TYA");
                    cpu6502_1op("SBC", "temp+1");
                    cpu6502_noop("TAY");
                    cpu6502_noop("TXA");
                } else {
                    cpu6502_noop("SEC");
                    cpu6502_1op("SBC", temp);
                    cpu6502_noop("TAX");
                    cpu6502_noop("TYA");
                    cpu6502_1op("SBC", temp2);
                    cpu6502_noop("TAY");
                    cpu6502_noop("TXA");
                }
            } else {
                if (!stack) {
                    cpu6502_noop("PHA");
                    cpu6502_noop("TYA");
                    cpu6502_noop("PHA");
                    cpu6502_1op("LDA", temp);
                    cpu6502_1op("LDY", temp2);
                    cpu6502_1op("STA", "temp");
                    cpu6502_1op("STY", "temp+1");
                }
                if (node->type == N_MUL16) {
                    cpu6502_1op("JSR", "_mul16");
                } else if (node->type == N_DIV16) {
                    cpu6502_1op("JSR", "_div16");
                } else if (node->type == N_MOD16) {
                    cpu6502_1op("JSR", "_mod16");
                } else if (node->type == N_DIV16S) {
                    cpu6502_1op("JSR", "_div16s");
                } else if (node->type == N_MOD16S) {
                    cpu6502_1op("JSR", "_mod16s");
                }
            }
            break;
    }
}
