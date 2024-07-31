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
#include "cvbasic.h"

static char z80_a_content[MAX_LINE_SIZE];
static char z80_hl_content[MAX_LINE_SIZE];
static int z80_flag_z_valid;

/*
 ** Emit a Z80 label
 */
void z80_label(char *label)
{
    fprintf(output, "%s:\n", label);
    z80_a_content[0] = '\0';
    z80_hl_content[0] = '\0';
    z80_flag_z_valid = 0;
}

/*
 ** Reset A register (technically a null label)
 */
void z80_empty(void)
{
    z80_a_content[0] = '\0';
    z80_flag_z_valid = 0;
}

/*
 ** Emit a Z80 instruction with no operand
 */
void z80_noop(char *mnemonic)
{
    fprintf(output, "\t%s\n", mnemonic);
    z80_a_content[0] = '\0';
    z80_hl_content[0] = '\0';
    z80_flag_z_valid = 0;
}

/*
 ** Emit a Z80 instruction with a single operand
 */
void z80_1op(char *mnemonic, char *operand)
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

    fprintf(output, "\t%s %s\n", mnemonic, operand);
    
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
        fprintf(stderr, "z80_1op: not found mnemonic %s\n", mnemonic);
    }
}

/*
 ** Emit a Z80 instruction with two operands
 */
void z80_2op(char *mnemonic, char *operand1, char *operand2)
{
    
    /*
     ** Optimize constant expressions (both constants and access to memory variables)
     */
    if (strcmp(mnemonic, "LD") == 0) {
        if (strcmp(operand1, "A") == 0) {
            if (strcmp(operand2, z80_a_content) == 0)
                return;
            if (strcmp(operand2, z80_hl_content) == 0)
                operand2 = "L";
        } else if (strcmp(operand1, "HL") == 0) {
            if (strcmp(operand2, z80_hl_content) == 0)
                return;
        }
    }
    
    fprintf(output, "\t%s %s,%s\n", mnemonic, operand1, operand2);
    
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
    } else if (strcmp(mnemonic, "ADD") == 0 || strcmp(mnemonic, "SBC") == 0) {
        if (strcmp(operand1, "A") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 1;
        } else {
            z80_hl_content[0] = '\0';
            z80_flag_z_valid = 0;
        }
    } else if (strcmp(mnemonic, "LD") == 0) {
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

