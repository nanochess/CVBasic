/*
 ** Z80 assembler output routines for CVBasic
 **
 ** by Oscar Toledo G.
 **
 ** Creation date: Jul/31/2024. Separated from CVBasic.c
 */

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include "cvbasic.h"
#include "node.h"

static char z80_line[MAX_LINE_SIZE];

static char z80_line_1[MAX_LINE_SIZE];
static char z80_line_2[MAX_LINE_SIZE];
static char z80_line_3[MAX_LINE_SIZE];

static char z80_a_content[MAX_LINE_SIZE];
static char z80_hl_content[MAX_LINE_SIZE];
static int z80_flag_z_valid;

static void z80_emit_line(void);

void z80_emit_line(void)
{
    int c;
    int d;
    
    /*
     ** Optimize the following cases:
     **     JP Z,cv1
     **     JP somewhere
     ** cv1:
     **
     **     JP Z,cv1
     **     CALL somewhere
     ** cv1:
     */
    if (memcmp(z80_line_2, "\tJP NZ," INTERNAL_PREFIX, 9) == 0 && isdigit(z80_line_2[9]) &&
        (memcmp(z80_line_3, "\tJP ", 4) == 0 || memcmp(z80_line_3, "\tCALL ", 6) == 0) &&
        memcmp(z80_line, INTERNAL_PREFIX, 2) == 0 && isdigit(z80_line[2]) &&
        atoi(z80_line_2 + 9) == atoi(z80_line + 2)) {
        if (z80_line_3[1] == 'J') {
            strcpy(z80_line_2, "\tJP Z,");
            strcat(z80_line_2, z80_line_3 + 4);
        } else {
            strcpy(z80_line_2, "\tCALL Z,");
            strcat(z80_line_2, z80_line_3 + 6);
        }
        z80_line_3[0] = '\0';
        z80_line[0] = '\0';
    }
    
    /*
     ** Optimize the following case:
     **     CALL cv1
     **     RET
     */
    if (memcmp(z80_line_3, "\tCALL " INTERNAL_PREFIX, 8) == 0 && memcmp(z80_line, "\tRET\n", 5) == 0) {
        strcpy(z80_line, "\tJP ");
        strcat(z80_line, z80_line_3 + 6);
        z80_line_3[0] = '\0';
    }
    if (z80_line_1[0])
        fprintf(output, "%s", z80_line_1);
    strcpy(z80_line_1, z80_line_2);
    strcpy(z80_line_2, z80_line_3);
    strcpy(z80_line_3, z80_line);
}

void cpuz80_dump(void)
{
    if (z80_line_1[0])
        fprintf(output, "%s", z80_line_1);
    if (z80_line_2[0])
        fprintf(output, "%s", z80_line_2);
    if (z80_line_3[0])
        fprintf(output, "%s", z80_line_3);
    z80_line_1[0] = '\0';
    z80_line_2[0] = '\0';
    z80_line_3[0] = '\0';
}

/*
 ** Emit a Z80 label
 */
void cpuz80_label(char *label)
{
    sprintf(z80_line, "%s:\n", label);
    z80_emit_line();
    z80_a_content[0] = '\0';
    z80_hl_content[0] = '\0';
    z80_flag_z_valid = 0;
}

/*
 ** Reset A register (technically a null label)
 */
void cpuz80_empty(void)
{
    z80_a_content[0] = '\0';
    z80_flag_z_valid = 0;
}

/*
 ** Emit a Z80 instruction with no operand
 */
void cpuz80_noop(char *mnemonic)
{
    sprintf(z80_line, "\t%s\n", mnemonic);
    z80_emit_line();
    z80_a_content[0] = '\0';
    if (strcmp(mnemonic, "NEG") != 0 && strcmp(mnemonic, "CPL") != 0)
        z80_hl_content[0] = '\0';
    if (strcmp(mnemonic, "NEG") == 0)
        z80_flag_z_valid = 1;
    else
        z80_flag_z_valid = 0;
}

/*
 ** Emit a Z80 instruction with a single operand
 */
void cpuz80_1op(char *mnemonic, char *operand)
{
    /*
     ** Optimize zero in register A
     */
    if (strcmp(mnemonic, "SUB") == 0) {
        if (strcmp(operand, "A") == 0) {
            if (strcmp(z80_a_content, "0") == 0)
                return;
        }
    }
    
    /*
     ** Important note: AND A is used for the sole purpose of
     ** make sure A is zero.
     **
     ** It is used OR A for clearing the carry flag for SBC HL,DE
     */
    if (strcmp(mnemonic, "AND") == 0) {
        if (strcmp(operand, "A") == 0) {
            if (z80_flag_z_valid)
                return;
        }
    }

    sprintf(z80_line, "\t%s %s\n", mnemonic, operand);
    z80_emit_line();
    
    if (strcmp(mnemonic, "PUSH") == 0) {
        /* No affected registers */
    } else if (strcmp(mnemonic, "CP") == 0) {
        /* No affected registers */
        z80_flag_z_valid = 0;
    } else if (strcmp(mnemonic, "POP") == 0) {
        if (strcmp(operand, "AF") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 0;
        } else if (strcmp(operand, "HL") == 0) {
            z80_hl_content[0] = '\0';
        }
    } else if (strcmp(mnemonic, "CALL") == 0 ||
               strcmp(mnemonic, "JP") == 0) {
        z80_a_content[0] = '\0';
        z80_hl_content[0] = '\0';
        z80_flag_z_valid = 0;
    } else if (strcmp(mnemonic, "SUB") == 0) {
        if (strcmp(operand, "A") == 0)
            strcpy(z80_a_content, "0");
        else
            z80_a_content[0] = '\0';
        z80_flag_z_valid = 1;
    } else if (strcmp(mnemonic, "OR") == 0 ||
               strcmp(mnemonic, "XOR") == 0 ||
               strcmp(mnemonic, "AND") == 0) {
        z80_a_content[0] = '\0';
        z80_flag_z_valid = 1;
    } else if (strcmp(mnemonic, "SRL") == 0) {
        if (strcmp(operand, "H") == 0)
            z80_hl_content[0] = '\0';
        else if (strcmp(operand, "A") == 0)
            z80_flag_z_valid = 1;
    } else if (strcmp(mnemonic, "RR") == 0) {
        if (strcmp(operand, "L") == 0)
            z80_hl_content[0] = '\0';
        z80_flag_z_valid = 0;
    } else if (strcmp(mnemonic, "INC") == 0) {
        if (strcmp(operand, "H") == 0 ||
            strcmp(operand, "L") == 0 ||
            strcmp(operand, "HL") == 0) {
            z80_hl_content[0] = '\0';
            z80_flag_z_valid = 0;
        } else if (strcmp(operand, "A") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 1;
        } else if (strcmp(operand, "(HL)") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 0;
        }
    } else if (strcmp(mnemonic, "DEC") == 0) {
        if (strcmp(operand, "H") == 0 ||
            strcmp(operand, "L") == 0 ||
            strcmp(operand, "HL") == 0) {
            z80_hl_content[0] = '\0';
            z80_flag_z_valid = 0;
        } else if (strcmp(operand, "A") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 1;
        } else if (strcmp(operand, "(HL)") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 0;
        }
    } else if (strcmp(mnemonic, "DW") == 0 || strcmp(mnemonic, "ORG") == 0 || strcmp(mnemonic, "FORG") == 0) {
        /* Nothing to do */
    } else {
        fprintf(stderr, "cpuz80_1op: not found mnemonic %s\n", mnemonic);
    }
}

/*
 ** Emit a Z80 instruction with two operands
 */
void cpuz80_2op(char *mnemonic, char *operand1, char *operand2)
{
    int special;
    
    /*
     ** Optimize constant expressions (both constants and access to memory variables)
     */
    special = 0;
    if (strcmp(mnemonic, "LD") == 0) {
        if (strcmp(operand1, "A") == 0) {
            if (strcmp(operand2, z80_a_content) == 0)
                return;
            if (strcmp(operand2, z80_hl_content) == 0) {
                operand2 = "L";
            /* Reading from memory address, and HL already has the address */
            } else if (operand2[0] == '(' && operand2[strlen(operand2) - 1] == ')' && memcmp(&operand2[1], z80_hl_content, strlen(operand2) - 2) == 0) {
                /* Generate subexpression info and mark as previously processed */
                z80_flag_z_valid = 0;
                strcpy(z80_a_content, operand2);
                special = 1;    /* Mark as processed */
                operand2 = "(HL)";
            }
        } else if (strcmp(operand1, "HL") == 0) {
            if (strcmp(operand2, z80_hl_content) == 0)
                return;
        } else if (strcmp(operand2, "A") == 0) {
            /* Writing to memory address, and HL already has the address */
            if (operand1[0] == '(' && operand1[strlen(operand1) - 1] == ')' && memcmp(&operand1[1], z80_hl_content, strlen(operand1) - 2) == 0) {
                /* Generate subexpression info and mark as previously processed */
                strcpy(z80_a_content, operand1);
                special = 1;    /* Mark as processed */
                operand1 = "(HL)";
            }
        }
    }
    
    sprintf(z80_line, "\t%s %s,%s\n", mnemonic, operand1, operand2);
    z80_emit_line();

    if (strcmp(mnemonic, "JP") == 0 ||
        strcmp(mnemonic, "JR") == 0 ||
        strcmp(mnemonic, "OUT") == 0 ||
        strcmp(mnemonic, "RES") == 0 ||
        strcmp(mnemonic, "SET") == 0) {
        /* No affected registers or flags */
    } else if (strcmp(mnemonic, "EX") == 0) {
        z80_hl_content[0] = '\0';
    } else if (strcmp(mnemonic, "IN") == 0) {
        z80_a_content[0] = '\0';
        z80_flag_z_valid = 0;
    } else if (strcmp(mnemonic, "ADD") == 0 || strcmp(mnemonic, "ADC") == 0 || strcmp(mnemonic, "SBC") == 0) {
        if (strcmp(operand1, "A") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 1;
        } else {
            z80_hl_content[0] = '\0';
            z80_flag_z_valid = 0;
        }
    } else if (strcmp(mnemonic, "LD") == 0) {
        if (special != 0)
            return;
        if (strcmp(operand1, "A") == 0)  /* Read value into accumulator */
            z80_flag_z_valid = 0;       /* Z status isn't valid */
        if (strcmp(operand1, "L") == 0 || strcmp(operand1, "H") == 0)
            z80_hl_content[0] = '\0';
        if (strcmp(operand1, "HL") == 0)
            strcpy(z80_hl_content, operand2);
        else if (strcmp(operand2, "HL") == 0)
            strcpy(z80_hl_content, operand1);
        if (strcmp(operand1, "A") == 0 && strcmp(operand2, "(HL)") == 0) {
            z80_a_content[0] = '\0';
        } else if (strcmp(operand1, "(HL)") == 0 && strcmp(operand2, "A") == 0) {
            /* A keeps its value */
        } else if (strcmp(operand1, "A") == 0) {
            if (isdigit(operand2[0]) || operand2[0] == '(')
                strcpy(z80_a_content, operand2);
            else
                z80_a_content[0] = '\0';
        } else if (strcmp(operand2, "A") == 0 && operand1[0] == '(') {
            strcpy(z80_a_content, operand1);
        }
    } else {
        fprintf(stderr, "z80_2op: not found mnemonic %s\n", mnemonic);
    }
}

/*
 ** Label register usage in tree
 **
 ** This should match exactly register usage in cpuz80_node_generate.
 */
void cpuz80_node_label(struct node *node)
{
    struct node *explore;
    int c;
    
    switch (node->type) {
        case N_USR:     /* Assembly language function with result */
            if (node->left != NULL)
                cpuz80_node_label(node->left);
            node->regs = REG_ALL;
            break;
        case N_ADDR:    /* Get address of variable */
        case N_POS:     /* Get screen cursor position */
        case N_LOAD16:  /* Load 16-bit value from address */
        case N_NUM16:   /* Load 16-bit constant */
        case N_FRAME:   /* Read current frame number */
            node->regs = REG_HL;
            break;
        case N_NEG8:    /* Negate 8-bit value */
        case N_NOT8:    /* Complement 8-bit value */
            cpuz80_node_label(node->left);
            node->regs = node->left->regs;
            break;
        case N_NEG16:   /* Negate 16-bit value */
        case N_NOT16:   /* Complement 16-bit value */
        case N_ABS16:   /* Get absolute 16-bit value */
        case N_SGN16:   /* Get sign of 16-bit value */
            cpuz80_node_label(node->left);
            node->regs = node->left->regs | REG_AF;
            break;
        case N_EXTEND8S:    /* Extend 8-bit signed value to 16-bit */
            cpuz80_node_label(node->left);
            node->regs = node->left->regs | REG_HL;
            break;
        case N_EXTEND8: /* Extend 8-bit value to 16-bit */
            if (node->left->type == N_LOAD8) {  /* Reading 8-bit variable */
                node->left->type = N_LOAD16;
                cpuz80_node_label(node->left);
                node->left->type = N_LOAD8;
                node->regs = node->left->regs;
                break;
            }
            if (node->left->type == N_PEEK8) {    /* If reading 8-bit memory */
                if (node->left->left->type == N_ADDR
                    || ((node->left->left->type == N_PLUS16 || node->left->left->type == N_MINUS16) && node->left->left->left->type == N_ADDR && node->left->left->right->type == N_NUM16)) {   /* Is it variable? */
                    node->left->type = N_PEEK16;
                    cpuz80_node_label(node->left);
                    node->left->type = N_PEEK8;
                    node->regs = node->left->regs;
                    break;
                } else {    /* Optimize to avoid LD A,(HL) / LD L,A */
                    cpuz80_node_label(node->left->left);
                    node->regs = node->left->left->regs;
                    break;
                }
            }
            cpuz80_node_label(node->left);
            node->regs = node->left->regs | REG_HL;
            break;
        case N_REDUCE16:    /* Reduce 16-bit value to 8-bit */
            cpuz80_node_label(node->left);
            node->regs = node->left->regs | REG_A;
            break;
        case N_READ8:   /* Read 8-bit value */
            node->regs = REG_A | REG_HL;
            break;
        case N_READ16:  /* Read 16-bit value */
            node->regs = REG_A | REG_DE | REG_HL;
            break;
        case N_LOAD8:   /* Load 8-bit value from address */
        case N_JOY1:    /* Read joystick 1 */
        case N_JOY2:    /* Read joystick 2 */
        case N_KEY1:    /* Read keypad 1 */
        case N_KEY2:    /* Read keypad 2 */
        case N_MUSIC:   /* Read music playing status */
        case N_NTSC:    /* Read NTSC flag */
            node->regs = REG_A;
            break;
        case N_NUM8:    /* Load 8-bit constant */
            if (node->value == 0) {
                node->regs = REG_AF;
            } else {
                node->regs = REG_A;
            }
            break;
        case N_PEEK8:   /* Load 8-bit content */
            if (node->left->type == N_ADDR) {   /* Optimize address */
                node->regs = REG_A;
                break;
            }
            if ((node->left->type == N_PLUS16 || node->left->type == N_MINUS16)
                && node->left->left->type == N_ADDR
                && node->left->right->type == N_NUM16) {    /* Optimize address plus constant */
                node->regs = REG_A;
                break;
            }
            cpuz80_node_label(node->left);
            node->regs = node->left->regs | REG_A;
            break;
        case N_PEEK16:  /* Load 16-bit content */
            if (node->left->type == N_ADDR) {   /* Optimize address */
                node->regs = REG_HL;
                break;
            }
            if ((node->left->type == N_PLUS16 || node->left->type == N_MINUS16)
                && node->left->left->type == N_ADDR
                && node->left->right->type == N_NUM16) {    /* Optimize address plus constant */
                node->regs = REG_HL;
                break;
            }
            cpuz80_node_label(node->left);
            node->regs = node->left->regs | REG_AF;
            break;
        case N_VPEEK:   /* Read VRAM */
            cpuz80_node_label(node->left);
            node->regs = node->left->regs | REG_AF;
            break;
        case N_INP:     /* Read port */
            cpuz80_node_label(node->left);
            node->regs = node->left->regs | REG_C | REG_AF;
            break;
        case N_RANDOM:  /* Read pseudorandom generator */
            node->regs = REG_ALL;
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
            if (node->type == N_OR8 && node->left->type == N_JOY1 && node->right->type == N_JOY2) {
                node->regs = REG_HL | REG_AF;
                break;
            }
            if (node->type == N_AND8 && node->left->type == N_KEY1 && node->right->type == N_KEY2) {
                node->regs = REG_HL | REG_AF;
                break;
            }
            if (node->type == N_MUL8 && node->right->type == N_NUM8 && is_power_of_two(node->right->value)) {
                cpuz80_node_label(node->left);
                node->regs = node->left->regs;
                c = node->right->value;
                if (c > 1)
                    node->regs |= REG_F;
                break;
            }
            if (node->type == N_DIV8 && node->right->type == N_NUM8 && is_power_of_two(node->right->value)) {
                cpuz80_node_label(node->left);
                node->regs = node->left->regs;
                c = node->right->value;
                if (c > 1)
                    node->regs |= REG_F;
                break;
            }
            if (node->type == N_LESSEQUAL8 || node->type == N_GREATER8) {
                if (node->left->type == N_NUM8) {
                    cpuz80_node_label(node->right);
                    node->regs = node->right->regs;
                } else {
                    cpuz80_node_label(node->left);
                    cpuz80_node_label(node->right);
                    if (node->right->regs == REG_A) {
                        node->regs = REG_A | REG_B;
                    } else {
                        node->regs = node->left->regs | node->right->regs | REG_BC;
                    }
                }
            } else if (node->right->type == N_NUM8) {
                c = node->right->value & 0xff;
                cpuz80_node_label(node->left);
                node->regs = node->left->regs;
            } else {
                cpuz80_node_label(node->right);
                cpuz80_node_label(node->left);
                if (node->left->regs == REG_A) {
                    node->regs = REG_A | REG_B;
                } else {
                    node->regs = node->left->regs | node->right->regs | REG_BC;
                }
            }
            break;
        case N_ASSIGN8: /* 8-bit assignment */
            if ((node->left->type == N_PLUS8 || node->left->type == N_MINUS8 || node->left->type == N_OR8 || node->left->type == N_AND8 || node->left->type == N_XOR8)
                && (node->left->right->type == N_NUM8 || node->left->right->type == N_LOAD8)
                && node_same_address(node->left->left, node->right)) {
                if (node->right->type == N_ADDR) {
                    node->regs = REG_HL | REG_AF;
                } else if (((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16)) {
                    node->regs = REG_HL | REG_AF;
                } else {
                    cpuz80_node_label(node->right);
                    node->regs = node->right->regs | REG_AF;
                }
                break;
            }
            if (node->right->type == N_ADDR) {
                cpuz80_node_label(node->left);
                node->regs = node->left->regs;
                break;
            }
            if ((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16) {
                cpuz80_node_label(node->left);
                node->regs = node->left->regs;
                break;
            }
            cpuz80_node_label(node->right);
            cpuz80_node_label(node->left);
            if (node->left->type == N_NUM8) {
                node->regs = node->right->regs;
            } else {
                node->regs = node->left->regs | node->right->regs;
            }
            break;
        case N_ASSIGN16:    /* 16-bit assignment */
            if (node->right->type == N_ADDR) {
                cpuz80_node_label(node->left);
                node->regs = node->left->regs;
                break;
            }
            if ((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16) {
                cpuz80_node_label(node->left);
                node->regs = node->left->regs;
                break;
            }
            cpuz80_node_label(node->right);
            cpuz80_node_label(node->left);
            node->regs = node->right->regs | node->left->regs | REG_DE | REG_A;
            break;
        default:    /* Every other node, all remaining are 16-bit operations */
            if (node->type == N_PLUS16 || node->type == N_MINUS16) {
                if (node->left->type == N_ADDR) {
                    if (node->right->type == N_NUM16) {
                        node->regs = REG_HL;
                        break;
                    }
                }
            }
            if (node->type == N_PLUS16) {
                if (node->left->type == N_ADDR) {
                    cpuz80_node_label(node->right);
                    node->regs = node->right->regs | REG_DE;
                    break;
                }
                if (node->left->type == N_NUM16 || node->right->type == N_NUM16) {
                    if (node->left->type == N_NUM16)
                        explore = node->left;
                    else
                        explore = node->right;
                    c = explore->value;
                    if (c == 0 || c == 1 || c == 2 || c == 3 || c == 0xffff || c == 0xfffe || c == 0xfffd || c == 0xfc00 || c == 0xfd00 || c == 0xfe00 || c == 0xff00 || c == 0x0100 || c == 0x0200 || c == 0x0300 || c == 0x0400) {
                        if (node->left != explore) {
                            cpuz80_node_label(node->left);
                            node->regs = node->left->regs;
                        } else {
                            cpuz80_node_label(node->right);
                            node->regs = node->right->regs;
                        }
                        break;
                    }
                }
            }
            if (node->type == N_MINUS16) {
                if (node->right->type == N_ADDR) {
                    cpuz80_node_label(node->left);
                    node->regs = node->left->regs | REG_DE | REG_F;
                    break;
                }
                if (node->right->type == N_NUM16)
                    explore = node->right;
                else
                    explore = NULL;
                if (explore != NULL && (explore->value == 0 || explore->value == 1 || explore->value == 2 || explore->value == 3)) {
                    cpuz80_node_label(node->left);
                    node->regs = node->left->regs;
                    break;
                }
                if (explore != NULL && (explore->value == 0xffff || explore->value == 0xfffe || explore->value == 0xfffd)) {
                    cpuz80_node_label(node->left);
                    node->regs = node->left->regs;
                    break;
                }
                if (explore != NULL) {
                    cpuz80_node_label(node->left);
                    node->regs = node->left->regs | REG_DE | REG_F;
                    break;
                }
            }
            if (node->type == N_OR16 || node->type == N_AND16 || node->type == N_XOR16) {
                if (node->right->type == N_NUM16) {
                    cpuz80_node_label(node->left);
                    node->regs = node->left->regs | REG_AF;
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
                    cpuz80_node_label(node->left);
                    cpuz80_node_label(node->right);
                    if (c == 0) {
                        node->regs = REG_HL;
                    } else {
                        node->regs = node->left->regs | node->right->regs;
                    }
                    break;
                }
            }
            if (node->type == N_DIV16) {
                if (node->right->type == N_NUM16 && (node->right->value == 2 || node->right->value == 4 || node->right->value == 8)) {
                    cpuz80_node_label(node->left);
                    node->regs = node->left->regs;
                    break;
                }
            }
            if (node->type == N_LESSEQUAL16 || node->type == N_GREATER16) {
                if (node->left->type == N_NUM16) {
                    cpuz80_node_label(node->right);
                    node->regs = node->right->regs | REG_DE;
                } else if (node->left->type == N_LOAD16) {
                    cpuz80_node_label(node->right);
                    node->regs = node->right->regs | REG_DE;
                } else {
                    cpuz80_node_label(node->left);
                    cpuz80_node_label(node->right);
                    node->regs = node->left->regs | node->right->regs | REG_DE;
                }
            } else if ((node->type == N_EQUAL16 || node->type == N_NOTEQUAL16) && node->right->type == N_NUM16 && (node->right->value == 65535 || node->right->value == 0 || node->right->value == 1)) {
                cpuz80_node_label(node->left);
                node->regs = node->left->regs | REG_AF;
                break;
            } else {
                cpuz80_node_label(node->right);
                cpuz80_node_label(node->left);
                node->regs = node->left->regs | node->right->regs | REG_DE;
            }
            if (node->type == N_OR16 || node->type == N_XOR16 || node->type == N_AND16 || node->type == N_EQUAL16 || node->type == N_NOTEQUAL16 || node->type == N_LESS16 || node->type == N_LESSEQUAL16 || node->type == N_GREATER16 || node->type == N_GREATEREQUAL16) {
                node->regs |= REG_AF;
            } else if (node->type == N_PLUS16 || node->type == N_MINUS16) {
                node->regs |= REG_F;
            } else if (node->type == N_MUL16 || node->type == N_DIV16 || node->type == N_MOD16 || node->type == N_DIV16S || node->type == N_MOD16S) {
                node->regs |= REG_ALL;
            }
            break;
    }
}

/*
 ** Generate code for tree
 */
void cpuz80_node_generate(struct node *node, int decision)
{
    struct node *explore;
    int c;
    char *p;
    
    switch (node->type) {
        case N_USR:     /* Assembly language function with result */
            if (node->left != NULL)
                cpuz80_node_generate(node->left, 0);
            cpuz80_1op("CALL", node->label->name);
            break;
        case N_ADDR:    /* Get address of variable */
            node_get_label(node, 0);
            cpuz80_2op("LD", "HL", temp);
            break;
        case N_NEG8:    /* Negate 8-bit value */
            cpuz80_node_generate(node->left, 0);
            cpuz80_noop("NEG");
            break;
        case N_NOT8:    /* Complement 8-bit value */
            cpuz80_node_generate(node->left, 0);
            cpuz80_noop("CPL");
            break;
        case N_NEG16:   /* Negate 16-bit value */
            cpuz80_node_generate(node->left, 0);
            cpuz80_2op("LD", "A", "H");
            cpuz80_noop("CPL");
            cpuz80_2op("LD", "H", "A");
            cpuz80_2op("LD", "A", "L");
            cpuz80_noop("CPL");
            cpuz80_2op("LD", "L", "A");
            cpuz80_1op("INC", "HL");
            break;
        case N_NOT16:   /* Complement 16-bit value */
            cpuz80_node_generate(node->left, 0);
            cpuz80_2op("LD", "A", "H");
            cpuz80_noop("CPL");
            cpuz80_2op("LD", "H", "A");
            cpuz80_2op("LD", "A", "L");
            cpuz80_noop("CPL");
            cpuz80_2op("LD", "L", "A");
            break;
        case N_ABS16:   /* Get absolute 16-bit value */
            cpuz80_node_generate(node->left, 0);
            cpuz80_1op("CALL", "_abs16");
            break;
        case N_SGN16:   /* Get sign of 16-bit value */
            cpuz80_node_generate(node->left, 0);
            cpuz80_1op("CALL", "_sgn16");
            break;
        case N_POS:     /* Get screen cursor position */
            cpuz80_2op("LD", "HL", "(cursor)");
            break;
        case N_EXTEND8S:    /* Extend 8-bit signed value to 16-bit */
            cpuz80_node_generate(node->left, 0);
            cpuz80_2op("LD", "L", "A");
            cpuz80_noop("RLA");
            cpuz80_2op("SBC", "A", "A");
            cpuz80_2op("LD", "H", "A");
            break;
        case N_EXTEND8: /* Extend 8-bit value to 16-bit */
            if (node->left->type == N_LOAD8) {  /* Reading 8-bit variable */
                node->left->type = N_LOAD16;
                cpuz80_node_generate(node->left, 0);
                node->left->type = N_LOAD8;
                cpuz80_2op("LD", "H", "0");
                break;
            }
            if (node->left->type == N_PEEK8) {    /* If reading 8-bit memory */
                if (node->left->left->type == N_ADDR
                    || ((node->left->left->type == N_PLUS16 || node->left->left->type == N_MINUS16) && node->left->left->left->type == N_ADDR && node->left->left->right->type == N_NUM16)) {   /* Is it variable? */
                    node->left->type = N_PEEK16;
                    cpuz80_node_generate(node->left, 0);
                    node->left->type = N_PEEK8;
                    cpuz80_2op("LD", "H", "0");
                    break;
                } else {    /* Optimize to avoid LD A,(HL) / LD L,A */
                    cpuz80_node_generate(node->left->left, 0);
                    cpuz80_2op("LD", "L", "(HL)");
                    cpuz80_2op("LD", "H", "0");
                    break;
                }
            }
            cpuz80_node_generate(node->left, 0);
            cpuz80_2op("LD", "L", "A");
            cpuz80_2op("LD", "H", "0");
            break;
        case N_REDUCE16:    /* Reduce 16-bit value to 8-bit */
            cpuz80_node_generate(node->left, 0);
            cpuz80_2op("LD", "A", "L");
            break;
        case N_READ8:   /* Read 8-bit value */
            cpuz80_2op("LD", "HL", "(read_pointer)");
            cpuz80_2op("LD", "A", "(HL)");
            cpuz80_1op("INC", "HL");
            cpuz80_2op("LD", "(read_pointer)", "HL");
            break;
        case N_READ16:  /* Read 16-bit value */
            cpuz80_2op("LD", "HL", "(read_pointer)");
            cpuz80_2op("LD", "E", "(HL)");
            cpuz80_1op("INC", "HL");
            cpuz80_2op("LD", "D", "(HL)");
            cpuz80_1op("INC", "HL");
            cpuz80_2op("LD", "(read_pointer)", "HL");
            cpuz80_2op("EX", "DE", "HL");
            break;
        case N_LOAD8:   /* Load 8-bit value from address */
            strcpy(temp, "(" LABEL_PREFIX);
            strcat(temp, node->label->name);
            strcat(temp, ")");
            cpuz80_2op("LD", "A", temp);
            break;
        case N_LOAD16:  /* Load 16-bit value from address */
            strcpy(temp, "(" LABEL_PREFIX);
            strcat(temp, node->label->name);
            strcat(temp, ")");
            cpuz80_2op("LD", "HL", temp);
            break;
        case N_NUM8:    /* Load 8-bit constant */
            if (node->value == 0) {
                cpuz80_1op("SUB", "A");
            } else {
                sprintf(temp, "%d", node->value);
                cpuz80_2op("LD", "A", temp);
            }
            break;
        case N_NUM16:   /* Load 16-bit constant */
            sprintf(temp, "%d", node->value);
            cpuz80_2op("LD", "HL", temp);
            break;
        case N_PEEK8:   /* Load 8-bit content */
            if (node->left->type == N_ADDR) {   /* Optimize address */
                node_get_label(node->left, 1);
                cpuz80_2op("LD", "A", temp);
                break;
            }
            if ((node->left->type == N_PLUS16 || node->left->type == N_MINUS16)
                && node->left->left->type == N_ADDR
                && node->left->right->type == N_NUM16) {    /* Optimize address plus constant */
                node_get_label(node->left->left, 1);
                p = temp;
                while (*p)
                    p++;
                p--;    /* Eat right parenthesis */
                if (node->left->type == N_PLUS16)
                    *p++ = '+';
                else
                    *p++ = '-';
                sprintf(p, "%d)", node->left->right->value);
                cpuz80_2op("LD", "A", temp);
                break;
            }
            cpuz80_node_generate(node->left, 0);
            cpuz80_2op("LD", "A", "(HL)");
            break;
        case N_PEEK16:  /* Load 16-bit content */
            if (node->left->type == N_ADDR) {   /* Optimize address */
                node_get_label(node->left, 1);
                cpuz80_2op("LD", "HL", temp);
                break;
            }
            if ((node->left->type == N_PLUS16 || node->left->type == N_MINUS16)
                && node->left->left->type == N_ADDR
                && node->left->right->type == N_NUM16) {    /* Optimize address plus constant */
                node_get_label(node->left->left, 1);
                p = temp;
                while (*p)
                    p++;
                p--;    /* Eat right parenthesis */
                if (node->left->type == N_PLUS16)
                    *p++ = '+';
                else
                    *p++ = '-';
                sprintf(p, "%d)", node->left->right->value);
                cpuz80_2op("LD", "HL", temp);
                break;
            }
            cpuz80_node_generate(node->left, 0);
            cpuz80_2op("LD", "A", "(HL)");
            cpuz80_1op("INC", "HL");
            cpuz80_2op("LD", "H", "(HL)");
            cpuz80_2op("LD", "L", "A");
            break;
        case N_VPEEK:   /* Read VRAM */
            cpuz80_node_generate(node->left, 0);
            cpuz80_1op("CALL", "nmi_off");
            cpuz80_1op("CALL", "RDVRM");
            cpuz80_1op("CALL", "nmi_on");
            break;
        case N_INP:     /* Read port */
            cpuz80_node_generate(node->left, 0);
            cpuz80_2op("LD", "C", "L");
            cpuz80_2op("IN", "A", "(C)");
            break;
        case N_JOY1:    /* Read joystick 1 */
            cpuz80_2op("LD", "A", "(joy1_data)");
            break;
        case N_JOY2:    /* Read joystick 2 */
            cpuz80_2op("LD", "A", "(joy2_data)");
            break;
        case N_KEY1:    /* Read keypad 1 */
            cpuz80_2op("LD", "A", "(key1_data)");
            break;
        case N_KEY2:    /* Read keypad 2 */
            cpuz80_2op("LD", "A", "(key2_data)");
            break;
        case N_RANDOM:  /* Read pseudorandom generator */
            cpuz80_1op("CALL", "random");
            break;
        case N_FRAME:   /* Read current frame number */
            cpuz80_2op("LD", "HL", "(frame)");
            break;
        case N_MUSIC:   /* Read music playing status */
            cpuz80_2op("LD", "A", "(music_playing)");
            break;
        case N_NTSC:    /* Read NTSC flag */
            cpuz80_2op("LD", "A", "(ntsc)");
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
            if (node->type == N_OR8 && node->left->type == N_JOY1 && node->right->type == N_JOY2) {
                cpuz80_2op("LD", "HL", "(joy1_data)");
                cpuz80_2op("LD", "A", "H");
                cpuz80_1op("OR", "L");
                break;
            }
            if (node->type == N_AND8 && node->left->type == N_KEY1 && node->right->type == N_KEY2) {
                cpuz80_2op("LD", "HL", "(key1_data)");
                cpuz80_2op("LD", "A", "H");
                cpuz80_1op("AND", "L");
                break;
            }
            if (node->type == N_MUL8 && node->right->type == N_NUM8 && is_power_of_two(node->right->value)) {
                cpuz80_node_generate(node->left, 0);
                c = node->right->value;
                while (c > 1) {
                    cpuz80_2op("ADD", "A", "A");
                    c /= 2;
                }
                break;
            }
            if (node->type == N_DIV8 && node->right->type == N_NUM8 && is_power_of_two(node->right->value)) {
                cpuz80_node_generate(node->left, 0);
                c = node->right->value;
                if (c == 2) {
                    cpuz80_1op("SRL", "A");
                } else if (c == 4) {
                    cpuz80_1op("SRL", "A");
                    cpuz80_1op("SRL", "A");
                } else if (c == 8) {
                    cpuz80_noop("RRCA");
                    cpuz80_noop("RRCA");
                    cpuz80_noop("RRCA");
                    cpuz80_1op("AND", "31");
                } else if (c == 16) {
                    cpuz80_noop("RRCA");
                    cpuz80_noop("RRCA");
                    cpuz80_noop("RRCA");
                    cpuz80_noop("RRCA");
                    cpuz80_1op("AND", "15");
                } else if (c == 32) {
                    cpuz80_noop("RLCA");
                    cpuz80_noop("RLCA");
                    cpuz80_noop("RLCA");
                    cpuz80_1op("AND", "7");
                } else if (c == 64) {
                    cpuz80_noop("RLCA");
                    cpuz80_noop("RLCA");
                    cpuz80_1op("AND", "3");
                } else if (c == 128) {
                    cpuz80_noop("RLCA");
                    cpuz80_1op("AND", "1");
                }
                break;
            }
            if (node->type == N_LESSEQUAL8 || node->type == N_GREATER8) {
                if (node->left->type == N_NUM8) {
                    cpuz80_node_generate(node->right, 0);
                    sprintf(temp, "%d", node->left->value & 0xff);
                } else {
                    cpuz80_node_generate(node->left, 0);
                    if ((node->right->regs & REG_B) == 0) {
                        cpuz80_2op("LD", "B", "A");
                        cpuz80_node_generate(node->right, 0);
                    } else {
                        cpuz80_1op("PUSH", "AF");
                        cpuz80_node_generate(node->right, 0);
                        cpuz80_1op("POP", "BC");
                    }
                    strcpy(temp, "B");
                }
            } else if (node->right->type == N_NUM8) {
                c = node->right->value & 0xff;
                cpuz80_node_generate(node->left, 0);
                if ((node->type == N_PLUS8 && c == 1) || (node->type == N_MINUS8 && c == 255)) {
                    cpuz80_1op("INC", "A");
                    break;
                }
                if ((node->type == N_PLUS8 && c == 255) || (node->type == N_MINUS8 && c == 1)) {
                    cpuz80_1op("DEC", "A");
                    break;
                }
                sprintf(temp, "%d", c);
            } else {
                if ((node->left->regs & REG_B) == 0) {
                    cpuz80_node_generate(node->right, 0);
                    cpuz80_2op("LD", "B", "A");
                    cpuz80_node_generate(node->left, 0);
                } else if (is_commutative(node->type) && (node->right->regs & REG_B) == 0) {
                    cpuz80_node_generate(node->left, 0);
                    cpuz80_2op("LD", "B", "A");
                    cpuz80_node_generate(node->right, 0);
                } else {
                    cpuz80_node_generate(node->right, 0);
                    cpuz80_1op("PUSH", "AF");
                    cpuz80_node_generate(node->left, 0);
                    cpuz80_1op("POP", "BC");
                }
                strcpy(temp, "B");
            }
            if (node->type == N_OR8) {
                cpuz80_1op("OR", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "Z", temp);
                }
            } else if (node->type == N_XOR8) {
                cpuz80_1op("XOR", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "Z", temp);
                }
            } else if (node->type == N_AND8) {
                cpuz80_1op("AND", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "Z", temp);
                }
            } else if (node->type == N_EQUAL8) {
                if (strcmp(temp, "0") == 0)
                    cpuz80_1op("AND", "A");
                else
                    cpuz80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "NZ", temp);
                } else {
                    cpuz80_2op("LD", "A", "0");
                    cpuz80_2op("JR", "NZ", "$+3");
                    cpuz80_1op("DEC", "A");
                    cpuz80_empty();
                }
            } else if (node->type == N_NOTEQUAL8) {
                if (strcmp(temp, "0") == 0)
                    cpuz80_1op("AND", "A");
                else
                    cpuz80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "Z", temp);
                } else {
                    cpuz80_2op("LD", "A", "0");
                    cpuz80_2op("JR", "Z", "$+3");
                    cpuz80_1op("DEC", "A");
                    cpuz80_empty();
                }
            } else if (node->type == N_LESS8 || node->type == N_GREATER8) {
                if (strcmp(temp, "0") == 0)
                    cpuz80_1op("AND", "A");
                else
                    cpuz80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "NC", temp);
                } else {
                    cpuz80_2op("LD", "A", "0");
                    cpuz80_2op("SBC", "A", "A");
                }
            } else if (node->type == N_LESSEQUAL8 || node->type == N_GREATEREQUAL8) {
                if (strcmp(temp, "0") == 0)
                    cpuz80_1op("AND", "A");
                else
                    cpuz80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "C", temp);
                } else {
                    cpuz80_2op("LD", "A", "255");
                    cpuz80_2op("ADC", "A", "0");
                }
            } else if (node->type == N_PLUS8) {
                cpuz80_2op("ADD", "A", temp);
            } else if (node->type == N_MINUS8) {
                cpuz80_1op("SUB", temp);
            }
            break;
        case N_ASSIGN8: /* 8-bit assignment */
            if ((node->left->type == N_PLUS8 || node->left->type == N_MINUS8 || node->left->type == N_OR8 || node->left->type == N_AND8 || node->left->type == N_XOR8)
                && (node->left->right->type == N_NUM8 || node->left->right->type == N_LOAD8)
                && node_same_address(node->left->left, node->right)) {
                if (node->right->type == N_ADDR) {
                    node_get_label(node->right, 0);
                    cpuz80_2op("LD", "HL", temp);
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
                    cpuz80_2op("LD", "HL", temp);
                } else {
                    cpuz80_node_generate(node->right, 0);
                }
                if ((node->left->type == N_PLUS8 || node->left->type == N_MINUS8) && node->left->right->type == N_NUM8 && node->left->right->value < 4) {
                    c = node->left->right->value;
                    do {
                        if (node->left->type == N_PLUS8)
                            cpuz80_1op("INC", "(HL)");
                        else
                            cpuz80_1op("DEC", "(HL)");
                    } while (--c) ;
                } else {
                    if (node->left->right->type == N_NUM8) {
                        if (node->left->type == N_MINUS8)
                            sprintf(temp, "%d", (0 - node->left->right->value) & 0xff);
                        else
                            sprintf(temp, "%d", node->left->right->value);
                        cpuz80_2op("LD", "A", temp);
                    } else if (node->left->right->type == N_LOAD8) {
                        node_get_label(node->left->right, 1);
                        cpuz80_2op("LD", "A", temp);
                        if (node->left->type == N_MINUS8)
                            cpuz80_noop("NEG");
                    }
                    if (node->left->type == N_PLUS8) {
                        cpuz80_2op("ADD", "A", "(HL)");
                    } else if (node->left->type == N_MINUS8) {
                        cpuz80_2op("ADD", "A", "(HL)");
                    } else if (node->left->type == N_OR8) {
                        cpuz80_1op("OR", "(HL)");
                    } else if (node->left->type == N_AND8) {
                        cpuz80_1op("AND", "(HL)");
                    } else if (node->left->type == N_XOR8) {
                        cpuz80_1op("XOR", "(HL)");
                    }
                    cpuz80_2op("LD", "(HL)", "A");
                }
                break;
            }
            if (node->right->type == N_ADDR) {
                cpuz80_node_generate(node->left, 0);
                node_get_label(node->right, 1);
                cpuz80_2op("LD", temp, "A");
                break;
            }
            if ((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16) {
                cpuz80_node_generate(node->left, 0);
                node_get_label(node->right->left, 1);
                p = temp;
                while (*p)
                    p++;
                p--;    /* Eat right parenthesis */
                if (node->right->type == N_PLUS16)
                    *p++ = '+';
                else
                    *p++ = '-';
                sprintf(p, "%d)", node->right->right->value);
                cpuz80_2op("LD", temp, "A");
                break;
            }
            cpuz80_node_generate(node->right, 0);
            if (node->left->type == N_NUM8) {
                sprintf(temp, "%d", node->left->value);
                cpuz80_2op("LD", "(HL)", temp);
            } else {
                if ((node->left->regs & REG_HL) == 0) {
                    cpuz80_node_generate(node->left, 0);
                } else {
                    cpuz80_1op("PUSH", "HL");
                    cpuz80_node_generate(node->left, 0);
                    cpuz80_1op("POP", "HL");
                }
                cpuz80_2op("LD", "(HL)", "A");
            }
            break;
        case N_ASSIGN16:    /* 16-bit assignment */
            if (node->right->type == N_ADDR) {
                cpuz80_node_generate(node->left, 0);
                node_get_label(node->right, 1);
                cpuz80_2op("LD", temp, "HL");
                break;
            }
            if ((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16) {
                cpuz80_node_generate(node->left, 0);
                node_get_label(node->right->left, 1);
                p = temp;
                while (*p)
                    p++;
                p--;    /* Eat right parenthesis */
                if (node->right->type == N_PLUS16)
                    *p++ = '+';
                else
                    *p++ = '-';
                sprintf(p, "%d)", node->right->right->value);
                cpuz80_2op("LD", temp, "HL");
                break;
            }
            cpuz80_node_generate(node->right, 0);
            if ((node->left->regs & REG_DE) == 0) {
                cpuz80_2op("EX", "DE", "HL");
                cpuz80_node_generate(node->left, 0);
            } else {
                cpuz80_1op("PUSH", "HL");
                cpuz80_node_generate(node->left, 0);
                cpuz80_1op("POP", "DE");
            }
            cpuz80_2op("LD", "A", "L");
            cpuz80_2op("LD", "(DE)", "A");
            cpuz80_1op("INC", "DE");
            cpuz80_2op("LD", "A", "H");
            cpuz80_2op("LD", "(DE)", "A");
            break;
        default:    /* Every other node, all remaining are 16-bit operations */
            if (node->type == N_MINUS16) {  /* Optimize case of subtraction of two addresses */
                if ((node->left->type == N_ADDR || ((node->left->type == N_PLUS16 || node->left->type == N_MINUS16) && node->left->left->type == N_ADDR && node->left->right->type == N_NUM16)) &&
                    (node->right->type == N_ADDR || ((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) &&
                                                     node->right->left->type == N_ADDR && node->right->right->type == N_NUM16))) {
                    char expression[MAX_LINE_SIZE * 2];
                    
                    if (node->left->type == N_PLUS16) {
                        c = node->left->right->value;
                        node_get_label(node->left->left, 0);
                    } else if (node->left->type == N_MINUS16) {
                        c = -node->left->right->value;
                        node_get_label(node->left->left, 0);
                    } else {
                        c = 0;
                        node_get_label(node->left, 0);
                    }
                    strcpy(expression, temp);
                    strcat(expression, "-");
                    if (node->right->type == N_PLUS16) {
                        c -= node->right->right->value;
                        node_get_label(node->right->left, 0);
                    } else if (node->right->type == N_MINUS16) {
                        c += node->right->right->value;
                        node_get_label(node->right->left, 0);
                    } else {
                        node_get_label(node->right, 0);
                    }
                    strcat(expression, temp);
                    if (c != 0) {
                        sprintf(temp, "+%d", c & 0xffff);
                        strcat(expression, temp);
                    }
                    cpuz80_2op("LD", "HL", expression);
                    break;
                }
            }
            /* Optimization of address plus/minus constant */
            if (node->type == N_PLUS16 || node->type == N_MINUS16) {
                if (node->left->type == N_ADDR) {
                    if (node->right->type == N_NUM16) {
                        node_get_label(node->left, 0);
                        if (node->type == N_PLUS16)
                            strcat(temp, "+");
                        else
                            strcat(temp, "-");
                        p = temp;
                        while (*p)
                            p++;
                        sprintf(p, "%d", node->right->value);
                        cpuz80_2op("LD", "HL", temp);
                        break;
                    }
                }
            }
            if (node->type == N_PLUS16) {
                if (node->left->type == N_ADDR) {
                    cpuz80_node_generate(node->right, 0);
                    node_get_label(node->left, 0);
                    cpuz80_2op("LD", "DE", temp);
                    cpuz80_2op("ADD", "HL", "DE");
                    break;
                }
                if (node->left->type == N_NUM16 || node->right->type == N_NUM16) {
                    if (node->left->type == N_NUM16)
                        explore = node->left;
                    else
                        explore = node->right;
                    c = explore->value;
                    if (c == 0 || c == 1 || c == 2 || c == 3) {
                        if (node->left != explore)
                            cpuz80_node_generate(node->left, 0);
                        else
                            cpuz80_node_generate(node->right, 0);
                        while (c) {
                            cpuz80_1op("INC", "HL");
                            c--;
                        }
                        break;
                    }
                    if (c == 0xffff || c == 0xfffe || c == 0xfffd) {
                        if (node->left != explore)
                            cpuz80_node_generate(node->left, 0);
                        else
                            cpuz80_node_generate(node->right, 0);
                        while (c < 0x10000) {
                            cpuz80_1op("DEC", "HL");
                            c++;
                        }
                        break;
                    }
                    if (c == 0xfc00 || c == 0xfd00 || c == 0xfe00 || c == 0xff00 || c == 0x0100 || c == 0x0200 || c == 0x0300 || c == 0x0400) {            /* Only worth optimizing if using less than 5 instructions */
                        if (node->left != explore)
                            cpuz80_node_generate(node->left, 0);
                        else
                            cpuz80_node_generate(node->right, 0);
                        while (c) {
                            if (c & 0x8000) {
                                cpuz80_1op("DEC", "H");
                                c += 0x0100;
                            } else {
                                cpuz80_1op("INC", "H");
                                c -= 0x0100;
                            }
                            c &= 0xffff;
                        }
                        break;
                    }
                }
            }
            if (node->type == N_MINUS16) {
                if (node->right->type == N_ADDR) {
                    cpuz80_node_generate(node->left, 0);
                    node_get_label(node->right, 0);
                    cpuz80_2op("LD", "DE", temp);
                    cpuz80_1op("OR", "A");
                    cpuz80_2op("SBC", "HL", "DE");
                    break;
                }
                if (node->right->type == N_NUM16)
                    explore = node->right;
                else
                    explore = NULL;
                if (explore != NULL && (explore->value == 0 || explore->value == 1 || explore->value == 2 || explore->value == 3)) {
                    c = explore->value;
                    cpuz80_node_generate(node->left, 0);
                    while (c) {
                        cpuz80_1op("DEC", "HL");
                        c--;
                    }
                    break;
                }
                if (explore != NULL && (explore->value == 0xffff || explore->value == 0xfffe || explore->value == 0xfffd)) {
                    c = explore->value;
                    cpuz80_node_generate(node->left, 0);
                    while (c < 0x10000) {
                        cpuz80_1op("INC", "HL");
                        c++;
                    }
                    break;
                }
                if (explore != NULL) {
                    cpuz80_node_generate(node->left, 0);
                    sprintf(temp, "%d", (0x10000 - explore->value) & 0xffff);
                    cpuz80_2op("LD", "DE", temp);
                    cpuz80_2op("ADD", "HL", "DE");
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
                        mnemonic = "OR";
                    } else if (node->type == N_AND16) {
                        mnemonic = "AND";
                    } else /*if (node->type == N_XOR16)*/ {
                        mnemonic = "XOR";
                    }
                    if (node->left != explore)
                        cpuz80_node_generate(node->left, 0);
                    else
                        cpuz80_node_generate(node->right, 0);
                    byte = value & 0xff;
                    if ((node->type == N_OR16 || node->type == N_XOR16) && byte == 0x00) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0xff) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0x00) {
                        cpuz80_2op("LD", "L", "0");
                    } else if (node->type == N_OR16 && byte == 0xff) {
                        cpuz80_2op("LD", "L", "255");
                    } else if (node->type == N_XOR16 && byte == 0xff) {
                        cpuz80_2op("LD", "A", "L");
                        cpuz80_noop("CPL");
                        cpuz80_2op("LD", "L", "A");
                    } else {
                        cpuz80_2op("LD", "A", "L");
                        sprintf(temp, "%d", byte);
                        cpuz80_1op(mnemonic, temp);
                        cpuz80_2op("LD", "L", "A");
                    }
                    byte = (value >> 8) & 0xff;
                    if ((node->type == N_OR16 || node->type == N_XOR16) && byte == 0x00) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0xff) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0x00) {
                        cpuz80_2op("LD", "H", "0");
                    } else if (node->type == N_OR16 && byte == 0xff) {
                        cpuz80_2op("LD", "H", "255");
                    } else if (node->type == N_XOR16 && byte == 0xff) {
                        cpuz80_2op("LD", "A", "H");
                        cpuz80_noop("CPL");
                        cpuz80_2op("LD", "H", "A");
                    } else {
                        cpuz80_2op("LD", "A", "H");
                        sprintf(temp, "%d", byte);
                        cpuz80_1op(mnemonic, temp);
                        cpuz80_2op("LD", "H", "A");
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
                        cpuz80_2op("LD", "HL", "0");
                    } else {
                        if (node->left != explore)
                            node = node->left;
                        else
                            node = node->right;
                        if (c >= 256) {
                            if (node->type == N_EXTEND8 || node->type == N_EXTEND8S) {
                                cpuz80_node_generate(node->left, 0);
                                cpuz80_2op("LD", "H", "A");
                                cpuz80_2op("LD", "L", "0");
                            } else {
                                cpuz80_node_generate(node, 0);
                                cpuz80_2op("LD", "H", "L");
                                cpuz80_2op("LD", "L", "0");
                            }
                            c /= 256;
                        } else {
                            cpuz80_node_generate(node, 0);
                        }
                        while (c > 1) {
                            cpuz80_2op("ADD", "HL", "HL");
                            c /= 2;
                        }
                    }
                    break;
                }
            }
            if (node->type == N_DIV16) {
                if (node->right->type == N_NUM16 && (node->right->value == 2 || node->right->value == 4 || node->right->value == 8)) {
                    cpuz80_node_generate(node->left, 0);
                    c = node->right->value;
                    do {
                        cpuz80_1op("SRL", "H");
                        cpuz80_1op("RR", "L");
                        c /= 2;
                    } while (c > 1) ;
                    break;
                }
            }
            if (node->type == N_LESSEQUAL16 || node->type == N_GREATER16) {
                if (node->left->type == N_NUM16) {
                    cpuz80_node_generate(node->right, 0);
                    sprintf(temp, "%d", node->left->value);
                    cpuz80_2op("LD", "DE", temp);
                } else if (node->left->type == N_LOAD16) {
                    cpuz80_node_generate(node->right, 0);
                    strcpy(temp, "(" LABEL_PREFIX);
                    strcat(temp, node->left->label->name);
                    strcat(temp, ")");
                    cpuz80_2op("LD", "DE", temp);
                } else {
                    cpuz80_node_generate(node->left, 0);
                    if ((node->right->regs & REG_DE) == 0) {
                        cpuz80_2op("EX", "DE", "HL");
                    } else {
                        cpuz80_1op("PUSH", "HL");
                        cpuz80_node_generate(node->right, 0);
                        cpuz80_1op("POP", "DE");
                    }
                }
            } else if ((node->type == N_EQUAL16 || node->type == N_NOTEQUAL16) && node->right->type == N_NUM16 && (node->right->value == 65535 || node->right->value == 0 || node->right->value == 1)) {
                cpuz80_node_generate(node->left, 0);
                if (node->right->value == 65535)
                    cpuz80_1op("INC", "HL");
                else if (node->right->value == 1)
                    cpuz80_1op("DEC", "HL");
                cpuz80_2op("LD", "A", "H");
                cpuz80_1op("OR", "L");
                if (node->type == N_EQUAL16) {
                    if (decision) {
                        optimized = 1;
                        sprintf(temp, INTERNAL_PREFIX "%d", decision);
                        cpuz80_2op("JP", "NZ", temp);
                    } else {
                        cpuz80_2op("LD", "A", "0");
                        cpuz80_2op("JR", "NZ", "$+3");
                        cpuz80_1op("DEC", "A");
                        cpuz80_empty();
                    }
                } else if (node->type == N_NOTEQUAL16) {
                    if (decision) {
                        optimized = 1;
                        sprintf(temp, INTERNAL_PREFIX "%d", decision);
                        cpuz80_2op("JP", "Z", temp);
                    } else {
                        cpuz80_2op("LD", "A", "0");
                        cpuz80_2op("JR", "Z", "$+3");
                        cpuz80_1op("DEC", "A");
                        cpuz80_empty();
                    }
                }
                break;
            } else {
                if (node->right->type == N_NUM16) {
                    cpuz80_node_generate(node->left, 0);
                    sprintf(temp, "%d", node->right->value);
                    cpuz80_2op("LD", "DE", temp);
                } else if (node->right->type == N_LOAD16) {
                    cpuz80_node_generate(node->left, 0);
                    strcpy(temp, "(" LABEL_PREFIX);
                    strcat(temp, node->right->label->name);
                    strcat(temp, ")");
                    cpuz80_2op("LD", "DE", temp);
                } else if (node->left->type == N_LOAD16 || node->left->type == N_NUM16) {
                    cpuz80_node_generate(node->right, 0);
                    cpuz80_2op("EX", "DE", "HL");
                    cpuz80_node_generate(node->left, 0);
                } else {
                    if ((node->left->regs & REG_DE) == 0) {
                        cpuz80_node_generate(node->right, 0);
                        cpuz80_2op("EX", "DE", "HL");
                        cpuz80_node_generate(node->left, 0);
                    } else if (is_commutative(node->type) && (node->right->regs & REG_DE) == 0) {
                        cpuz80_node_generate(node->left, 0);
                        cpuz80_2op("EX", "DE", "HL");
                        cpuz80_node_generate(node->right, 0);
                    } else {
                        cpuz80_node_generate(node->right, 0);
                        cpuz80_1op("PUSH", "HL");
                        cpuz80_node_generate(node->left, 0);
                        cpuz80_1op("POP", "DE");
                    }
                }
            }
            if (node->type == N_OR16) {
                cpuz80_2op("LD", "A", "L");
                cpuz80_1op("OR", "E");
                cpuz80_2op("LD", "L", "A");
                cpuz80_2op("LD", "A", "H");
                cpuz80_1op("OR", "D");
                cpuz80_2op("LD", "H", "A");
                if (decision) {
                    optimized = 1;
                    cpuz80_1op("OR", "L");
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "Z", temp);
                }
            } else if (node->type == N_XOR16) {
                cpuz80_2op("LD", "A", "L");
                cpuz80_1op("XOR", "E");
                cpuz80_2op("LD", "L", "A");
                cpuz80_2op("LD", "A", "H");
                cpuz80_1op("XOR", "D");
                cpuz80_2op("LD", "H", "A");
                if (decision) {
                    optimized = 1;
                    cpuz80_1op("OR", "L");
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "Z", temp);
                }
            } else if (node->type == N_AND16) {
                cpuz80_2op("LD", "A", "L");
                cpuz80_1op("AND", "E");
                cpuz80_2op("LD", "L", "A");
                cpuz80_2op("LD", "A", "H");
                cpuz80_1op("AND", "D");
                cpuz80_2op("LD", "H", "A");
                if (decision) {
                    optimized = 1;
                    cpuz80_1op("OR", "L");
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "Z", temp);
                }
            } else if (node->type == N_EQUAL16) {
                cpuz80_1op("OR", "A");
                cpuz80_2op("SBC", "HL", "DE");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "NZ", temp);
                } else {
                    cpuz80_2op("LD", "A", "0");
                    cpuz80_2op("JR", "NZ", "$+3");
                    cpuz80_1op("DEC", "A");
                    cpuz80_empty();
                }
            } else if (node->type == N_NOTEQUAL16) {
                cpuz80_1op("OR", "A");
                cpuz80_2op("SBC", "HL", "DE");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "Z", temp);
                } else {
                    cpuz80_2op("LD", "A", "0");
                    cpuz80_2op("JR", "Z", "$+3");
                    cpuz80_1op("DEC", "A");
                    cpuz80_empty();
                }
            } else if (node->type == N_LESS16 || node->type == N_GREATER16) {
                cpuz80_1op("OR", "A");
                cpuz80_2op("SBC", "HL", "DE");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "NC", temp);
                } else {
                    cpuz80_2op("LD", "A", "0");
                    cpuz80_2op("SBC", "A", "A");
                }
            } else if (node->type == N_LESSEQUAL16 || node->type == N_GREATEREQUAL16) {
                cpuz80_1op("OR", "A");
                cpuz80_2op("SBC", "HL", "DE");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    cpuz80_2op("JP", "C", temp);
                } else {
                    cpuz80_2op("LD", "A", "255");
                    cpuz80_2op("ADC", "A", "0");
                }
            } else if (node->type == N_PLUS16) {
                cpuz80_2op("ADD", "HL", "DE");
            } else if (node->type == N_MINUS16) {
                cpuz80_1op("OR", "A");
                cpuz80_2op("SBC", "HL", "DE");
            } else if (node->type == N_MUL16) {
                cpuz80_1op("CALL", "_mul16");
            } else if (node->type == N_DIV16) {
                cpuz80_1op("CALL", "_div16");
            } else if (node->type == N_MOD16) {
                cpuz80_1op("CALL", "_mod16");
            } else if (node->type == N_DIV16S) {
                cpuz80_1op("CALL", "_div16s");
            } else if (node->type == N_MOD16S) {
                cpuz80_1op("CALL", "_mod16s");
            }
            break;
    }
}
