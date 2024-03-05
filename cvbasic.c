/*
 ** CVBasic
 **
 ** by Oscar Toledo G.
 **
 ** © Copyright 2024 Óscar Toledo G.
 ** https://nanochess.org/
 **
 ** Creation date: Feb/27/2024.
 ** Revision date: Feb/28/2024. Implemented WHILE/WEND, DO/LOOP, FOR/NEXT, and EXIT.
 ** Revision date: Feb/29/2024. Implemented controller support. Added arrays, SOUND,
 **                             RESTORE/READ/DATA. Added small local optimization.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define VERSION "v0.2.0 Mar/04/2024"

#define FALSE           0
#define TRUE            1

#define MAX_LINE_SIZE    1024

#define ARRAY_PREFIX    "array_"
#define LABEL_PREFIX    "cvb_"
#define INTERNAL_PREFIX "cv"

char path[4096];

char current_file[MAX_LINE_SIZE];
int current_line;
FILE *input;
FILE *output;

int line_pos;
int line_size;
int line_start;
char line[MAX_LINE_SIZE];

int next_local = 1;

enum lexical_component {
    C_END, C_NAME,
    C_STRING, C_LABEL, C_NUM,
    C_ASSIGN,
    C_EQUAL, C_NOTEQUAL, C_LESS, C_LESSEQUAL, C_GREATER, C_GREATEREQUAL,
    C_PLUS, C_MINUS, C_MUL, C_DIV, C_MOD,
    C_LPAREN, C_RPAREN, C_COLON, C_PERIOD, C_COMMA,
    C_ERR} lex;
int value;
int value_special;
char global_label[MAX_LINE_SIZE];
char name[MAX_LINE_SIZE];
int name_size;
char assigned[MAX_LINE_SIZE];

char temp[MAX_LINE_SIZE];

#define HASH_PRIME    1103    /* A prime number */

struct label {
    struct label *next;
    int used;
    int length;         /* For arrays */
    char name[1];
};

#define MAIN_TYPE       0x03
#define TYPE_8          0x00
#define TYPE_16         0x01
#define TYPE_UNSIGNED   0x04

#define LABEL_USED      0x10
#define LABEL_DEFINED   0x20
#define LABEL_CALLED_BY_GOTO    0x40
#define LABEL_CALLED_BY_GOSUB   0x80
#define LABEL_IS_PROCEDURE  0x100
#define LABEL_IS_VARIABLE   0x200
#define LABEL_IS_ARRAY      0x400

struct label *label_hash[HASH_PRIME];

struct label *array_hash[HASH_PRIME];

struct label *inside_proc;
struct label *frame_drive;

struct constant {
    struct constant *next;
    int value;
    char name[1];
};

struct constant *constant_hash[HASH_PRIME];

enum node_type {
    N_OR8, N_OR16,
    N_XOR8, N_XOR16,
    N_AND8, N_AND16,
    N_EQUAL8, N_EQUAL16, N_NOTEQUAL8, N_NOTEQUAL16, N_LESS8, N_LESS16, N_LESSEQUAL8, N_LESSEQUAL16, N_GREATER8, N_GREATER16, N_GREATEREQUAL8, N_GREATEREQUAL16,
    N_PLUS8, N_PLUS16, N_MINUS8, N_MINUS16,
    N_MUL, N_DIV, N_MOD,
    N_NEG8, N_NEG16, N_NOT8, N_NOT16,
    N_EXTEND8, N_REDUCE16,
    N_LOAD8, N_LOAD16,
    N_ASSIGN8, N_ASSIGN16,
    N_READ8, N_READ16,
    N_NUM8, N_NUM16,
    N_PEEK8, N_PEEK16, N_VPEEK, N_INP, N_ABS16,
    N_JOY1, N_JOY2, N_KEY1, N_KEY2,
    N_RANDOM, N_FRAME,
    N_ADDR,
};

struct node {
    enum node_type type;
    int value;
    struct node *left;
    struct node *right;
    struct label *label;
    int regs;
};

int optimized;

void node_delete(struct node *);

struct node *evaluate_level_0(int *);
struct node *evaluate_level_1(int *);
struct node *evaluate_level_2(int *);
struct node *evaluate_level_3(int *);
struct node *evaluate_level_4(int *);
struct node *evaluate_level_5(int *);
struct node *evaluate_level_6(int *);
struct node *evaluate_level_7(int *);

/*
** Representation for a loop
*/
struct loop {
    struct loop *next;
    int type;           /* 0=FOR, 1=WHILE, 2=IF, 3=DO WHILE/UNTIL LOOP, 4=DO LOOP WHILE/UNTIL */
    struct node *step;
    struct node *final;
    int label_loop;     /* Main label, in C this would be destination for 'continue' */
    int label_exit;     /* Exit label, in C this would be destination for 'break' */
    char var[1];
};

struct loop *loops;

unsigned char bitmap[32];
int bitmap_byte;

/*
 ** Emit an error
 */
void emit_error(char *string)
{
    fprintf(stderr, "ERROR: %s at line %d (%s)\n", string, current_line, current_file);
}

/*
 ** Emit a warning
 */
void emit_warning(char *string)
{
    fprintf(stderr, "Warning: %s at line %d (%s)\n", string, current_line, current_file);
}

void z80_label(char *label)
{
    fprintf(output, "%s:\n", label);
}

void z80_noop(char *mnemonic)
{
    fprintf(output, "\t%s\n", mnemonic);
}

void z80_1op(char *mnemonic, char *operand)
{
    fprintf(output, "\t%s %s\n", mnemonic, operand);
}

void z80_2op(char *mnemonic, char *operand1, char *operand2)
{
    fprintf(output, "\t%s %s,%s\n", mnemonic, operand1, operand2);
}

/*
 ** Node creation.
 ** It also optimizes common patterns of expression node trees.
 */
struct node *node_create(enum node_type type, int value, struct node *left, struct node *right)
{
    struct node *new_node;
    
    switch (type) {
        case N_REDUCE16:    /* Reduce a 16-bit value to 8-bit */
            if (left->type == N_NUM16) {
                left->type = N_NUM8;
                left->value &= 255;
                return left;
            }
            /*
             ** Optimize expressions that extended an 8-bit variable and then reduced it again.
             **
             **      N_REDUCE16 (intended)
             **        /    \
             **    N_PLUS16  N_NUM16
             **        |
             **    N_EXTEND8
             */
            if ((left->type == N_PLUS16 || left->type == N_MINUS16 || left->type == N_AND16 || left->type == N_OR16 || left->type == N_XOR16) && (left->left->type == N_EXTEND8) && (left->right->type == N_NUM16)) {
                if (left->type == N_PLUS16)
                    left->type = N_PLUS8;
                else if (left->type == N_MINUS16)
                    left->type = N_MINUS8;
                else if (left->type == N_AND16)
                    left->type = N_AND8;
                else if (left->type == N_OR16)
                    left->type = N_OR8;
                else if (left->type == N_XOR16)
                    left->type = N_XOR8;
                left->right->type = N_NUM8;
                left->right->value &= 0xff;
                /* Remove the N_EXTEND8 */
                new_node = left->left;
                left->left = new_node->left;
                new_node->left = NULL;
                node_delete(new_node);
                return left;
            }
            break;
        case N_EXTEND8: /* Extend 8-bit expression to 16-bit */
            if (left->type == N_NUM8) {
                left->type = N_NUM16;
                left->value &= 255;
                return left;
            }
            break;
        case N_NEG8:    /* 8-bit negation */
            if (left->type == N_NUM8) {     /* Optimize constant case */
                left->value = -left->value & 0xff;
                return left;
            }
            break;
        case N_NEG16:   /* 16-bit negation */
            if (left->type == N_NUM16) {    /* Optimize constant case */
                left->value = -left->value & 0xffff;
                return left;
            }
            break;
        case N_NOT8:    /* 8-bit complement */
            if (left->type == N_NUM8) {     /* Optimize constant case */
                left->value = ~left->value & 0xff;
                return left;
            }
            break;
        case N_NOT16:   /* 16-bit complement */
            if (left->type == N_NUM16) {    /* Optimize constant case */
                left->value = ~left->value & 0xffff;
                return left;
            }
            break;
        case N_MOD:     /* Modulo */
            if (right->type == N_NUM16) {   /* Optimize power of 2 constant case */
                if (right->value == 2 || right->value == 4 || right->value == 8 || right->value == 16
                    || right->value == 32 || right->value == 64 || right->value == 128 || right->value == 256
                    || right->value == 512 || right->value == 1024 || right->value == 2048 || right->value == 4096
                    || right->value == 8192 || right->value == 16384 || right->value == 32768) {
                    right->value--;
                    type = N_AND16;
                }
            }
            break;
        case N_PLUS16:  /* 16-bit addition */
            if (left->type == N_NUM16 && right->type == N_NUM16) {  /* Optimize constant case */
                left->value = (left->value + right->value) & 0xffff;
                node_delete(right);
                return left;
            }
            if (left->type == N_NUM16) {    /* Move constant to right */
                new_node = left;
                left = right;
                right = new_node;
            }
            if (right->type == N_NUM16 && right->value == 0) {  /* Remove zero add */
                node_delete(right);
                return left;
            }
            break;
        case N_MINUS16: /* 16-bit subtraction */
            if (left->type == N_NUM16 && right->type == N_NUM16) {  /* Optimize constant case */
                left->value = (left->value - right->value) & 0xffff;
                node_delete(right);
                return left;
            }
            if (right->type == N_NUM16 && right->value == 0) {  /* Remove zero subtraction */
                node_delete(right);
                return left;
            }
            break;
        case N_AND16:   /* 16-bit AND */
            if (left->type == N_NUM16 && right->type == N_NUM16) {  /* Optimize constant case */
                left->value &= right->value;
                node_delete(right);
                return left;
            }
            if (left->type == N_NUM16) {    /* Move constant to right */
                new_node = left;
                left = right;
                right = new_node;
            }
            if (right->type == N_NUM16) {   /* Remove no operation */
                if (right->value == 0xffff) {
                    node_delete(right);
                    return left;
                }
                if (right->value == 0x0000) {
                    node_delete(left);
                    return right;
                }
            }
            break;
        case N_OR16:    /* 16-bit OR */
            if (left->type == N_NUM16 && right->type == N_NUM16) {  /* Optimize constant case */
                left->value |= right->value;
                node_delete(right);
                return left;
            }
            if (left->type == N_NUM16) {    /* Move constant to right */
                new_node = left;
                left = right;
                right = new_node;
            }
            if (right->type == N_NUM16) {   /* Remove no operation */
                if (right->value == 0x0000) {
                    node_delete(right);
                    return left;
                }
                if (right->value == 0xffff) {
                    node_delete(left);
                    return right;
                }
            }
            break;
        case N_XOR16:   /* 16-bit XOR */
            if (left->type == N_NUM16 && right->type == N_NUM16) {  /* Optimize constant case */
                left->value ^= right->value;
                node_delete(right);
                return left;
            }
            if (left->type == N_NUM16) {    /* Move constant to right */
                new_node = left;
                left = right;
                right = new_node;
            }
            if (right->type == N_NUM16) {   /* Remove no operation */
                if (right->value == 0) {
                    node_delete(right);
                    return left;
                }
            }
            break;
        case N_PLUS8:   /* 8-bit addition */
            if (left->type == N_NUM8 && right->type == N_NUM8) {    /* Optimize constant case */
                left->value = (left->value + right->value) & 0xff;
                node_delete(right);
                return left;
            }
            if (left->type == N_NUM8) {    /* Move constant to right */
                new_node = left;
                left = right;
                right = new_node;
            }
            if (right->type == N_NUM8 && right->value == 0) {
                node_delete(right);
                return left;
            }
            break;
        case N_MINUS8:  /* 8-bit subtraction */
            if (left->type == N_NUM8 && right->type == N_NUM8) {    /* Optimize constant case */
                left->value = (left->value - right->value) & 0xff;
                node_delete(right);
                return left;
            }
            if (right->type == N_NUM8 && right->value == 0) {   /* Remove no operation */
                node_delete(right);
                return left;
            }
            break;
        case N_AND8:    /* 8-bit AND */
            if (left->type == N_NUM8 && right->type == N_NUM8) {    /* Optimize constant case */
                left->value &= right->value;
                node_delete(right);
                return left;
            }
            if (left->type == N_NUM8) {    /* Move constant to right */
                new_node = left;
                left = right;
                right = new_node;
            }
            if (right->type == N_NUM8) {    /* Remove no operation */
                if (right->value == 0xff) {
                    node_delete(right);
                    return left;
                }
                if (right->value == 0x00) {
                    node_delete(left);
                    return right;
                }
            }
            break;
        case N_OR8:     /* 8-bit OR */
            if (left->type == N_NUM8 && right->type == N_NUM8) {    /* Optimize constant case */
                left->value |= right->value;
                node_delete(right);
                return left;
            }
            if (left->type == N_NUM8) {    /* Move constant to right */
                new_node = left;
                left = right;
                right = new_node;
            }
            if (right->type == N_NUM8) {    /* Remove no operation */
                if (right->value == 0x00) {
                    node_delete(right);
                    return left;
                }
                if (right->value == 0xff) {
                    node_delete(left);
                    return right;
                }
            }
            break;
        case N_XOR8:    /* 8-bit XOR */
            if (left->type == N_NUM8 && right->type == N_NUM8) {    /* Optimize constant case */
                left->value ^= right->value;
                node_delete(right);
                return left;
            }
            if (left->type == N_NUM8) {    /* Move constant to right */
                new_node = left;
                left = right;
                right = new_node;
            }
            if (right->type == N_NUM8) {    /* Remove no operation */
                if (right->value == 0x00) {
                    node_delete(right);
                    return left;
                }
            }
            break;
        default:
            break;
    }
    new_node = malloc(sizeof(struct node));
    if (new_node == NULL) {
        emit_error("out of memory");
        exit(1);
    }
    new_node->type = type;
    new_node->value = value;
    new_node->left = left;
    new_node->right = right;
    new_node->label = NULL;
    return new_node;
}

#define MAX_REGS  100

void node_label(struct node *node)
{
    int c;
    int d;
    
    if (node->left == NULL && node->right == NULL) {
        node->regs = 1;
        return;
    }
    if (node->right == NULL) {
        node_label(node->left);
        node->regs = node->left->regs;
        return;
    }
    node_label(node->left);
    node_label(node->right);
    c = node->left->regs;
    d = node->right->regs;
    if (d > c)
        c = d;
    else if (c == d)
        c++;
    node->regs = c;
}

/*
 ** Argument reg is not yet used, nor sorted evaluation order.
 */
void node_generate(struct node *node, int decision)
{
    struct label *label;
    struct node *explore;
    
    switch (node->type) {
        case N_ADDR:
            label = node->label;
            if (label->length) {
                strcpy(temp, ARRAY_PREFIX);
                strcat(temp, node->label->name);
                z80_2op("LD", "HL", temp);
            } else {
                strcpy(temp, LABEL_PREFIX);
                strcat(temp, node->label->name);
                z80_2op("LD", "HL", temp);
            }
            break;
        case N_NEG8:
            node_generate(node->left, 0);
            z80_noop("NEG");
            break;
        case N_NOT8:
            node_generate(node->left, 0);
            z80_noop("CPL");
            break;
        case N_NEG16:
            node_generate(node->left, 0);
            z80_2op("LD", "A", "H");
            z80_noop("CPL");
            z80_2op("LD", "H", "A");
            z80_2op("LD", "A", "L");
            z80_noop("CPL");
            z80_2op("LD", "L", "A");
            z80_1op("INC", "HL");
            break;
        case N_NOT16:
            node_generate(node->left, 0);
            z80_2op("LD", "A", "H");
            z80_noop("CPL");
            z80_2op("LD", "H", "A");
            z80_2op("LD", "A", "L");
            z80_noop("CPL");
            z80_2op("LD", "L", "A");
            break;
        case N_ABS16:
            node_generate(node->left, 0);
            z80_1op("CALL", "_abs16");
            break;
        case N_EXTEND8:
            node_generate(node->left, 0);
            z80_2op("LD", "L", "A");
            z80_2op("LD", "H", "0");
            break;
        case N_REDUCE16:
            node_generate(node->left, 0);
            z80_2op("LD", "A", "L");
            break;
        case N_READ8:
            z80_2op("LD", "HL", "(read_pointer)");
            z80_2op("LD", "A", "(HL)");
            z80_1op("INC", "HL");
            z80_2op("LD", "(read_pointer)", "HL");
            break;
        case N_READ16:
            z80_2op("LD", "HL", "(read_pointer)");
            z80_2op("LD", "E", "(HL)");
            z80_1op("INC", "HL");
            z80_2op("LD", "D", "(HL)");
            z80_1op("INC", "HL");
            z80_2op("LD", "(read_pointer)", "HL");
            z80_2op("EX", "DE", "HL");
            break;
        case N_LOAD8:
            strcpy(temp, "(" LABEL_PREFIX);
            strcat(temp, node->label->name);
            strcat(temp, ")");
            z80_2op("LD", "A", temp);
            break;
        case N_LOAD16:
            strcpy(temp, "(" LABEL_PREFIX);
            strcat(temp, node->label->name);
            strcat(temp, ")");
            z80_2op("LD", "HL", temp);
            break;
        case N_NUM8:
            if (node->value == 0) {
                z80_1op("SUB", "A");
            } else {
                sprintf(temp, "%d", node->value);
                z80_2op("LD", "A", temp);
            }
            break;
        case N_NUM16:
            sprintf(temp, "%d", node->value);
            z80_2op("LD", "HL", temp);
            break;
        case N_PEEK8:
            node_generate(node->left, 0);
            z80_2op("LD", "A", "(HL)");
            break;
        case N_PEEK16:
            node_generate(node->left, 0);
            z80_2op("LD", "A", "(HL)");
            z80_1op("INC", "HL");
            z80_2op("LD", "H", "(HL)");
            z80_2op("LD", "L", "A");
            break;
        case N_VPEEK:
            node_generate(node->left, 0);
            z80_1op("CALL", "nmi_off");
            z80_1op("CALL", "RDVRM");
            z80_1op("CALL", "nmi_on");
            break;
        case N_INP:
            node_generate(node->left, 0);
            z80_2op("LD", "C", "L");
            z80_2op("IN", "A", "(C)");
            break;
        case N_JOY1:
            z80_2op("LD", "A", "(joy1_data)");
            break;
        case N_JOY2:
            z80_2op("LD", "A", "(joy2_data)");
            break;
        case N_KEY1:
            z80_2op("LD", "A", "(key1_data)");
            break;
        case N_KEY2:
            z80_2op("LD", "A", "(key2_data)");
            break;
        case N_RANDOM:
            z80_1op("CALL", "random");
            break;
        case N_FRAME:
            z80_2op("LD", "HL", "(frame)");
            break;
        case N_OR8:
        case N_XOR8:
        case N_AND8:
        case N_EQUAL8:
        case N_NOTEQUAL8:
        case N_LESS8:
        case N_LESSEQUAL8:
        case N_GREATER8:
        case N_GREATEREQUAL8:
        case N_PLUS8:
        case N_MINUS8:
            if (node->type == N_LESSEQUAL8 || node->type == N_GREATER8) {
                if (node->left->type == N_NUM8) {
                    node_generate(node->right, 0);
                    sprintf(temp, "%d", node->left->value & 0xff);
                } else {
                    node_generate(node->left, 0);
                    z80_1op("PUSH", "AF");
                    node_generate(node->right, 0);
                    z80_1op("POP", "BC");
                    strcpy(temp, "B");
                }
            } else {
                if (node->right->type == N_NUM8) {
                    int c;

                    c = node->right->value & 0xff;
                    node_generate(node->left, 0);
                    if (node->type == N_OR8 && c == 0)
                        return;
                    if (node->type == N_AND8 && c == 255)
                        return;
                    if (node->type == N_PLUS8 && c == 0)
                        return;
                    if (node->type == N_MINUS8 && c == 0)
                        return;
                    if (node->type == N_PLUS8 && c == 1) {
                        z80_1op("INC", "A");
                        return;
                    }
                    if (node->type == N_MINUS8 && c == 1) {
                        z80_1op("DEC", "A");
                        return;
                    }
                    sprintf(temp, "%d", c);
                } else {
                    node_generate(node->right, 0);
                    z80_1op("PUSH", "AF");
                    node_generate(node->left, 0);
                    z80_1op("POP", "BC");
                    strcpy(temp, "B");
                }
            }
            if (node->type == N_OR8) {
                z80_1op("OR", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "Z", temp);
                }
            } else if (node->type == N_XOR8) {
                z80_1op("XOR", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "Z", temp);
                }
            } else if (node->type == N_AND8) {
                z80_1op("AND", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "Z", temp);
                }
            } else if (node->type == N_EQUAL8) {
                z80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "NZ", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "NZ", "$+3");
                    z80_1op("DEC", "A");
                }
            } else if (node->type == N_NOTEQUAL8) {
                z80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "Z", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "Z", "$+3");
                    z80_1op("DEC", "A");
                }
            } else if (node->type == N_LESS8) {
                z80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "NC", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "NC", "$+3");
                    z80_1op("DEC", "A");
                }
            } else if (node->type == N_LESSEQUAL8) {
                z80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "C", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "C", "$+3");
                    z80_1op("DEC", "A");
                }
            } else if (node->type == N_GREATER8) {
                z80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "NC", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "NC", "$+3");
                    z80_1op("DEC", "A");
                }
            } else if (node->type == N_GREATEREQUAL8) {
                z80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "C", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "C", "$+3");
                    z80_1op("DEC", "A");
                }
            } else if (node->type == N_PLUS8) {
                z80_2op("ADD", "A", temp);
            } else if (node->type == N_MINUS8) {
                z80_1op("SUB", temp);
            }
            break;
        case N_ASSIGN8:
            node_generate(node->right, 0);
            z80_1op("PUSH", "HL");
            node_generate(node->left, 0);
            z80_1op("POP", "HL");
            z80_2op("LD", "(HL)", "A");
            break;
        default:
            if (node->type == N_PLUS16) {
                if (node->left->type == N_NUM16)
                    explore = node->left;
                else if (node->right->type == N_NUM16)
                    explore = node->right;
                else
                    explore = NULL;
                if (explore != NULL && (explore->value == 0 || explore->value == 1 || explore->value == 2 || explore->value == 3)) {
                    int c = explore->value;
                    
                    if (node->left != explore)
                        node_generate(node->left, 0);
                    else
                        node_generate(node->right, 0);
                    while (c) {
                        z80_1op("INC", "HL");
                        c--;
                    }
                    return;
                }
                if (node->left->type == N_ADDR) {
                    node_generate(node->right, 0);
                    label = node->left->label;
                    if (label->length) {
                        strcpy(temp, ARRAY_PREFIX);
                        strcat(temp, label->name);
                        z80_2op("LD", "DE", temp);
                    } else {
                        strcpy(temp, LABEL_PREFIX);
                        strcat(temp, label->name);
                        z80_2op("LD", "DE", temp);
                    }
                    z80_2op("ADD", "HL", "DE");
                    return;
                }
            }
            if (node->type == N_MINUS16) {
                if (node->right->type == N_NUM16)
                    explore = node->right;
                else
                    explore = NULL;
                if (explore != NULL && (explore->value == 0 || explore->value == 1 || explore->value == 2 || explore->value == 3)) {
                    int c = explore->value;
                    
                    if (node->left != explore)
                        node_generate(node->left, 0);
                    else
                        node_generate(node->right, 0);
                    while (c) {
                        z80_1op("DEC", "HL");
                        c--;
                    }
                    return;
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
                    } else if (node->type == N_XOR16) {
                        mnemonic = "XOR";
                    }
                    if (node->left != explore)
                        node_generate(node->left, 0);
                    else
                        node_generate(node->right, 0);
                    byte = value & 0xff;
                    if ((node->type == N_OR16 || node->type == N_XOR16) && byte == 0x00) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0xff) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0x00) {
                        z80_2op("LD", "L", "0");
                    } else if (node->type == N_OR16 && byte == 0xff) {
                        z80_2op("LD", "L", "255");
                    } else if (node->type == N_XOR16 && byte == 0xff) {
                        z80_2op("LD", "A", "L");
                        z80_noop("CPL");
                        z80_2op("LD", "L", "A");
                    } else {
                        z80_2op("LD", "A", "L");
                        sprintf(temp, "%d", byte);
                        z80_1op(mnemonic, temp);
                        z80_2op("LD", "L", "A");
                    }
                    byte = (value >> 8) & 0xff;
                    if ((node->type == N_OR16 || node->type == N_XOR16) && byte == 0x00) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0xff) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && byte == 0x00) {
                        z80_2op("LD", "H", "0");
                    } else if (node->type == N_OR16 && byte == 0xff) {
                        z80_2op("LD", "H", "255");
                    } else if (node->type == N_XOR16 && byte == 0xff) {
                        z80_2op("LD", "A", "H");
                        z80_noop("CPL");
                        z80_2op("LD", "H", "A");
                    } else {
                        z80_2op("LD", "A", "H");
                        sprintf(temp, "%d", byte);
                        z80_1op(mnemonic, temp);
                        z80_2op("LD", "H", "A");
                    }
                    return;
                }
            }
            if (node->type == N_MUL) {
                if (node->left->type == N_NUM16)
                    explore = node->left;
                else if (node->right->type == N_NUM16)
                    explore = node->right;
                else
                    explore = NULL;
                if (explore != NULL && (explore->value == 0 || explore->value == 1 || explore->value == 2 || explore->value == 4 || explore->value == 8 || explore->value == 16 || explore->value == 32 || explore->value == 64 || explore->value == 128 || explore->value == 256)) {
                    int c = explore->value;
                    
                    if (node->left != explore)
                        node_generate(node->left, 0);
                    else
                        node_generate(node->right, 0);
                    if (c == 1) {
                        
                    } else if (c == 256) {
                        z80_2op("LD", "H", "L");
                        z80_2op("LD", "L", "0");
                    } else {
                        do {
                            z80_2op("ADD", "HL", "HL");
                            c /= 2;
                        } while (c > 1) ;
                    }
                    return;
                }
            }
            if (node->type == N_LESSEQUAL16 || node->type == N_GREATER16) {
                if (node->left->type == N_NUM16) {
                    node_generate(node->right, 0);
                    sprintf(temp, "%d", node->left->value);
                    z80_2op("LD", "DE", temp);
                } else if (node->left->type == N_LOAD16) {
                    node_generate(node->right, 0);
                    strcpy(temp, "(" LABEL_PREFIX);
                    strcat(temp, node->left->label->name);
                    strcat(temp, ")");
                    z80_2op("LD", "DE", temp);
                } else {
                    node_generate(node->left, 0);
                    z80_1op("PUSH", "HL");
                    node_generate(node->right, 0);
                    z80_1op("POP", "DE");
                }
            } else {
                if (node->right->type == N_NUM16) {
                    node_generate(node->left, 0);
                    sprintf(temp, "%d", node->right->value);
                    z80_2op("LD", "DE", temp);
                } else if (node->right->type == N_LOAD16) {
                    node_generate(node->left, 0);
                    strcpy(temp, "(" LABEL_PREFIX);
                    strcat(temp, node->right->label->name);
                    strcat(temp, ")");
                    z80_2op("LD", "DE", temp);
                } else {
                    node_generate(node->right, 0);
                    z80_1op("PUSH", "HL");
                    node_generate(node->left, 0);
                    z80_1op("POP", "DE");
                }
            }
            if (node->type == N_OR16) {
                z80_2op("LD", "A", "L");
                z80_1op("OR", "E");
                z80_2op("LD", "L", "A");
                z80_2op("LD", "A", "H");
                z80_1op("OR", "D");
                z80_2op("LD", "H", "A");
                if (decision) {
                    optimized = 1;
                    z80_1op("OR", "L");
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "Z", temp);
                }
            } else if (node->type == N_XOR16) {
                z80_2op("LD", "A", "L");
                z80_1op("XOR", "E");
                z80_2op("LD", "L", "A");
                z80_2op("LD", "A", "H");
                z80_1op("XOR", "D");
                z80_2op("LD", "H", "A");
                if (decision) {
                    optimized = 1;
                    z80_1op("OR", "L");
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "Z", temp);
                }
            } else if (node->type == N_AND16) {
                z80_2op("LD", "A", "L");
                z80_1op("AND", "E");
                z80_2op("LD", "L", "A");
                z80_2op("LD", "A", "H");
                z80_1op("AND", "D");
                z80_2op("LD", "H", "A");
                if (decision) {
                    optimized = 1;
                    z80_1op("OR", "L");
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "Z", temp);
                }
            } else if (node->type == N_EQUAL16) {
                z80_1op("OR", "A");
                z80_2op("SBC", "HL", "DE");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "NZ", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "NZ", "$+3");
                    z80_1op("DEC", "A");
                }
            } else if (node->type == N_NOTEQUAL16) {
                z80_1op("OR", "A");
                z80_2op("SBC", "HL", "DE");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "Z", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "Z", "$+3");
                    z80_1op("DEC", "A");
                }
            } else if (node->type == N_LESS16) {
                z80_1op("OR", "A");
                z80_2op("SBC", "HL", "DE");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "NC", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "NC", "$+3");
                    z80_1op("DEC", "A");
                }
            } else if (node->type == N_LESSEQUAL16) {
                z80_1op("OR", "A");
                z80_2op("SBC", "HL", "DE");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "C", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "C", "$+3");
                    z80_1op("DEC", "A");
                }
            } else if (node->type == N_GREATER16) {
                z80_1op("OR", "A");
                z80_2op("SBC", "HL", "DE");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "NC", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "NC", "$+3");
                    z80_1op("DEC", "A");
                }
            } else if (node->type == N_GREATEREQUAL16) {
                z80_1op("OR", "A");
                z80_2op("SBC", "HL", "DE");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "C", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "C", "$+3");
                    z80_1op("DEC", "A");
                }
            } else if (node->type == N_PLUS16) {
                z80_2op("ADD", "HL", "DE");
            } else if (node->type == N_MINUS16) {
                z80_1op("OR", "A");
                z80_2op("SBC", "HL", "DE");
            } else if (node->type == N_MUL) {
                z80_1op("CALL", "_mul16");
            } else if (node->type == N_DIV) {
                z80_1op("CALL", "_div16");
            } else if (node->type == N_MOD) {
                z80_1op("CALL", "_mod16");
            } else if (node->type == N_ASSIGN16) {
                z80_2op("LD", "A", "L");
                z80_2op("LD", "(DE)", "A");
                z80_1op("INC", "DE");
                z80_2op("LD", "A", "H");
                z80_2op("LD", "(DE)", "A");
            }
            break;
    }
}

/*
 ** Delete an expression node
 */
void node_delete(struct node *tree)
{
    if (tree->left != NULL)
        node_delete(tree->left);
    if (tree->right != NULL)
        node_delete(tree->right);
    free(tree);
}

/*
 ** Calculate a hash value for a name
 */
int label_hash_value(char *name)
{
    unsigned int value;
    
    value = 0;
    while (*name) {
        value *= 11;    /* Another prime number */
        value += *name++;
    }
    return value % HASH_PRIME;
}

/*
 ** Search for a constant
 */
struct constant *constant_search(char *name)
{
    struct constant *explore;
    
    explore = constant_hash[label_hash_value(name)];
    while (explore != NULL) {
        if (strcmp(explore->name, name) == 0)
            return explore;
    }
    return NULL;
}

/*
 ** Add a constant
 */
struct constant *constant_add(char *name)
{
    struct constant **previous;
    struct constant *explore;
    struct constant *new_one;
    
    new_one = malloc(sizeof(struct constant) + strlen(name));
    if (new_one == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    new_one->value = 0;
    strcpy(new_one->name, name);
    previous = &constant_hash[label_hash_value(name)];
    new_one->next = *previous;
    *previous = new_one;
    return new_one;
}

/*
 ** Search for a label
 */
struct label *label_search(char *name)
{
    struct label *explore;
    
    explore = label_hash[label_hash_value(name)];
    while (explore != NULL) {
        if (strcmp(explore->name, name) == 0)
            return explore;
    }
    return NULL;
}

/*
 ** Add a label
 */
struct label *label_add(char *name)
{
    struct label **previous;
    struct label *explore;
    struct label *new_one;
    
    new_one = malloc(sizeof(struct label) + strlen(name));
    if (new_one == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    new_one->used = 0;
    strcpy(new_one->name, name);
    previous = &label_hash[label_hash_value(name)];
    new_one->length = 0;
    new_one->next = *previous;
    *previous = new_one;
    return new_one;
}

/*
 ** Search for an array
 */
struct label *array_search(char *name)
{
    struct label *explore;
    
    explore = array_hash[label_hash_value(name)];
    while (explore != NULL) {
        if (strcmp(explore->name, name) == 0)
            return explore;
    }
    return NULL;
}

/*
 ** Add an array
 */
struct label *array_add(char *name)
{
    struct label **previous;
    struct label *explore;
    struct label *new_one;
    
    new_one = malloc(sizeof(struct label) + strlen(name));
    if (new_one == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    new_one->used = 0;
    strcpy(new_one->name, name);
    previous = &array_hash[label_hash_value(name)];
    new_one->next = *previous;
    *previous = new_one;
    return new_one;
}

/*
 ** Avoid spaces
 */
int lex_skip_spaces(void) {
    int something = 0;
    
    if (line_pos == 0)
        something = 1;
    while (line_pos < line_size && isspace(line[line_pos])) {
        line_pos++;
        something = 1;
    }
    return something;
}

/*
 ** Sneak-peek to next character
 */
int lex_sneak_peek(void) {
    lex_skip_spaces();
    if (line_pos == line_size)
        return '\0';
    return toupper(line[line_pos]);
}

/*
 ** Gets another lexical component
 ** Output:
 **  lex = lexical component
 **  name = identifier or string
 **  value = value
 */
void get_lex(void) {
    int spaces;
    char *p;
    
    spaces = lex_skip_spaces();
    if (line_pos == line_size) {
        lex = C_END;
        return;
    }
    if (isalpha(line[line_pos]) ||
        line[line_pos] == '#' ||
        (spaces && line[line_pos] == '.') ||
        (line_pos > 0 && line[line_pos - 1] == ',' && line[line_pos] == '.') ||
        (line_pos > 0 && line[line_pos - 1] == ':' && line[line_pos] == '.')) {  // Name, label or local label
        if (line[line_pos] == '.') {
            strcpy(name, global_label);
            p = name + strlen(name);
            value = 1;
        } else {
            name[0] = '\0';
            p = name;
            value = 0;
        }
        *p++ = toupper(line[line_pos]);
        line_pos++;
        while (line_pos < line_size
               && (isalnum(line[line_pos]) || line[line_pos] == '_' || line[line_pos] == '#')) {
            *p++ = toupper(line[line_pos]);
            line_pos++;
        }
        *p = '\0';
        name_size = p - name;
        if (line_pos < line_size && line[line_pos] == ':' && line_start
            && strcmp(name, "RETURN") != 0 && strcmp(name, "CLS") != 0 && strcmp(name, "WAIT") != 0
            && strcmp(name, "RESTORE") != 0 && strcmp(name, "WEND") != 0
            && strcmp(name, "DO") != 0 && strcmp(name, "NEXT") != 0) {
            lex = C_LABEL;
            line_pos++;
        } else {
            lex = C_NAME;
        }
        line_start = 0;
        return;
    }
    if (isdigit(line[line_pos])) {  // Decimal number
        value_special = 0;
        value = 0;
        while (line_pos < line_size && isdigit(line[line_pos]))
            value = (value * 10) + line[line_pos++] - '0';
        if (line[line_pos] == '.') {
            line_pos++;
            value_special = 1;
        }
        lex = C_NUM;
        line_start = 0;
        return;
    }
    if (line[line_pos] == '$' && line_pos + 1 < line_size
        && isxdigit(line[line_pos + 1])) {  // Hexadecimal number
        value_special = 0;
        value = 0;
        line_pos++;
        while (line_pos < line_size && isxdigit(line[line_pos])) {
            int temp;
            
            temp = toupper(line[line_pos]) - '0';
            if (temp > 9)
                temp -= 7;
            value = (value << 4) | temp;
            line_pos++;
        }
        if (line[line_pos] == '.') {
            line_pos++;
            value_special = 1;
        }
        lex = C_NUM;
        line_start = 0;
        return;
    }
    if (line[line_pos] == '&' && line_pos + 1 < line_size
        && (line[line_pos + 1] == '0' || line[line_pos + 1] == '1')) {  // Binary number
        value_special = 0;
        value = 0;
        line_pos++;
        while (line_pos < line_size && (line[line_pos] == '0' || line[line_pos] == '1')) {
            value = (value << 1) | (line[line_pos] & 1);
            line_pos++;
        }
        if (line[line_pos] == '.') {
            line_pos++;
            value_special = 1;
        }
        lex = C_NUM;
        line_start = 0;
        return;
    }
    if (line[line_pos] == '"') {  // String
        line_pos++;
        name[0] = '\0';
        p = name;
        while (line_pos < line_size && line[line_pos] != '"') {
            int c;
            int digits;
            
            if (line[line_pos] == '\\') {
                line_pos++;
                if (line_pos < line_size && (line[line_pos] == '"' || line[line_pos] == '\\')) {
                    c = line[line_pos++];
                } else {
                    c = 0;
                    digits = 0;
                    while (line_pos < line_size && isdigit(line[line_pos])) {
                        c = c * 10 + (line[line_pos] - '0');
                        line_pos++;
                        if (++digits == 3)
                            break;
                    }
                    if (c < 0)
                        c = 0;
                    if (c > 255)
                        c = 255;
                }
            } else {
                c = line[line_pos++];
            }
            *p++ = c;
        }
        name_size = p - name;
        if (line_pos < line_size && line[line_pos] == '"') {
            line_pos++;
        } else {
            emit_error("unfinished string");
        }
        lex = C_STRING;
        line_start = 0;
        return;
    }
    line_start = 0;
    switch (line[line_pos]) {
        case '=':
            line_pos++;
            lex = C_EQUAL;
            break;
        case '+':
            line_pos++;
            lex = C_PLUS;
            break;
        case '-':
            line_pos++;
            lex = C_MINUS;
            break;
        case '(':
            line_pos++;
            lex = C_LPAREN;
            break;
        case ')':
            line_pos++;
            lex = C_RPAREN;
            break;
        case '<':
            line_pos++;
            lex = C_LESS;
            if (line[line_pos] == '=') {
                line_pos++;
                lex = C_LESSEQUAL;
            } else if (line[line_pos] == '>') {
                line_pos++;
                lex = C_NOTEQUAL;
            }
            break;
        case '>':
            line_pos++;
            lex = C_GREATER;
            if (line[line_pos] == '=') {
                line_pos++;
                lex = C_GREATEREQUAL;
            }
            break;
        case '*':
            line_pos++;
            lex = C_MUL;
            break;
        case '/':
            line_pos++;
            lex = C_DIV;
            break;
        case '%':
            line_pos++;
            lex = C_MOD;
            break;
        case ':':
            line_pos++;
            lex = C_COLON;
            break;
        case '.':
            line_pos++;
            lex = C_PERIOD;
            break;
        case ',':
            line_pos++;
            lex = C_COMMA;
            break;
        case '\'':
            line_pos = line_size;
            lex = C_END;
            break;
        default:
            line_pos++;
            lex = C_ERR;
            break;
    }
}

/*
 ** Extend types
 */
int extend_types(struct node **node1, int type1, struct node **node2, int type2)
{
    if ((type1 & MAIN_TYPE) == TYPE_8) {
        *node1 = node_create(N_EXTEND8, 0, *node1, NULL);
    }
    if ((type2 & MAIN_TYPE) == TYPE_8) {
        *node2 = node_create(N_EXTEND8, 0, *node2, NULL);
    }
    return TYPE_16;   /* Promote to 16-bit */
}

/*
 ** Mix types
 */
int mix_types(struct node **node1, int type1, struct node **node2, int type2)
{
    if ((type1 & MAIN_TYPE) == TYPE_8 && (type2 & MAIN_TYPE) == TYPE_8)   /* Both are 8-bit */
        return TYPE_8;
    if ((type1 & MAIN_TYPE) == TYPE_16 && (type2 & MAIN_TYPE) == TYPE_16)   /* Both are 16-bit */
        return TYPE_16;
    return extend_types(node1, type1, node2, type2);
}

/*
 ** Evaluates an expression
 ** Result in A or HL.
 */
int evaluate_expression(int cast, int to_type, int label)
{
    struct node *tree;
    int type;
    
    optimized = 0;
    tree = evaluate_level_0(&type);
    if (cast == 1) {
        if (to_type == TYPE_8 && (type & MAIN_TYPE) == TYPE_16) {
            tree = node_create(N_REDUCE16, 0, tree, NULL);
            type = TYPE_8;
        } else if (to_type == TYPE_16 && (type & MAIN_TYPE) == TYPE_8) {
            tree = node_create(N_EXTEND8, 0, tree, NULL);
            type = TYPE_16;
        }
    }
    if (label != 0) {   /* Decision with small AND */
        if (tree->type == N_AND16 && tree->right->type == N_NUM16
            && (tree->right->value & ~0xff) == 0 && tree->left->type == N_LOAD16) {
            tree->left->type = N_LOAD8;
            tree->right->type = N_NUM8;
            tree->type = N_AND8;
            type = TYPE_8;
        }
    }
    if (label != 0 && (tree->type == N_NUM8 || tree->type == N_NUM16)) {
        if (tree->value == 0) {
            sprintf(temp, INTERNAL_PREFIX "%d", label);
            z80_1op("JP", temp);    /* Jump over */
        } else {
            /* No code generated :) */
        }
        node_delete(tree);
        return type;
    }
    node_label(tree);
    node_generate(tree, label);
    node_delete(tree);
    if (label != 0 && !optimized) {
        if ((type & MAIN_TYPE) == TYPE_8) {
            z80_1op("OR", "A");
        } else {
            z80_2op("LD", "A", "H");
            z80_1op("OR", "L");
        }
        sprintf(temp, INTERNAL_PREFIX "%d", label);
        z80_2op("JP", "Z", temp);
    }
    return type;
}

/*
 ** Expression evaluation level 0 (OR)
 */
struct node *evaluate_level_0(int *type)
{
    struct node *left;
    struct node *right;
    int type2;
    
    left = evaluate_level_1(type);
    while (1) {
        if (lex == C_NAME && strcmp(name, "OR") == 0) {
            get_lex();
            right = evaluate_level_1(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_OR8, 0, left, right);
            else
                left = node_create(N_OR16, 0, left, right);
        } else {
            break;
        }
    }
    return left;
}

/*
 ** Expression evaluation level 1 (XOR)
 */
struct node *evaluate_level_1(int *type)
{
    struct node *left;
    struct node *right;
    int type2;
    
    left = evaluate_level_2(type);
    while (1) {
        if (lex == C_NAME && strcmp(name, "XOR") == 0) {
            get_lex();
            right = evaluate_level_2(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_XOR8, 0, left, right);
            else
                left = node_create(N_XOR16, 0, left, right);
        } else {
            break;
        }
    }
    return left;
}

/*
 ** Expression evaluation level 2 (AND)
 */
struct node *evaluate_level_2(int *type)
{
    struct node *left;
    struct node *right;
    int type2;
    
    left = evaluate_level_3(type);
    while (1) {
        if (lex == C_NAME && strcmp(name, "AND") == 0) {
            get_lex();
            right = evaluate_level_3(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_AND8, 0, left, right);
            else
                left = node_create(N_AND16, 0, left, right);
        } else {
            break;
        }
    }
    return left;
}

/*
 ** Expression evaluation level 3 (= <> < <= > >=)
 */
struct node *evaluate_level_3(int *type)
{
    struct node *left;
    struct node *right;
    int type2;
    
    left = evaluate_level_4(type);
    while (1) {
        if (lex == C_EQUAL) {
            get_lex();
            right = evaluate_level_4(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_EQUAL8, 0, left, right);
            else
                left = node_create(N_EQUAL16, 0, left, right);
            *type = TYPE_8;
        } else if (lex == C_NOTEQUAL) {
            get_lex();
            right = evaluate_level_4(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_NOTEQUAL8, 0, left, right);
            else
                left = node_create(N_NOTEQUAL16, 0, left, right);
            *type = TYPE_8;
        } else if (lex == C_LESS) {
            get_lex();
            right = evaluate_level_4(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_LESS8, 0, left, right);
            else
                left = node_create(N_LESS16, 0, left, right);
            *type = TYPE_8;
        } else if (lex == C_LESSEQUAL) {
            get_lex();
            right = evaluate_level_4(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_LESSEQUAL8, 0, left, right);
            else
                left = node_create(N_LESSEQUAL16, 0, left, right);
            *type = TYPE_8;
        } else if (lex == C_GREATER) {
            get_lex();
            right = evaluate_level_4(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_GREATER8, 0, left, right);
            else
                left = node_create(N_GREATER16, 0, left, right);
            *type = TYPE_8;
        } else if (lex == C_GREATEREQUAL) {
            get_lex();
            right = evaluate_level_4(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_GREATEREQUAL8, 0, left, right);
            else
                left = node_create(N_GREATEREQUAL16, 0, left, right);
            *type = TYPE_8;
        } else {
            break;
        }
    }
    return left;
}

/*
 ** Expression evaluation level 4 (+ - )
 */
struct node *evaluate_level_4(int *type)
{
    struct node *left;
    struct node *right;
    int type2;
    
    left = evaluate_level_5(type);
    while (1) {
        if (lex == C_PLUS) {
            get_lex();
            right = evaluate_level_5(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_PLUS8, 0, left, right);
            else
                left = node_create(N_PLUS16, 0, left, right);
        } else if (lex == C_MINUS) {
            get_lex();
            right = evaluate_level_5(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_MINUS8, 0, left, right);
            else
                left = node_create(N_MINUS16, 0, left, right);
        } else {
            break;
        }
    }
    return left;
}

/*
 ** Expression evaluation level 5 (* / %)
 */
struct node *evaluate_level_5(int *type)
{
    struct node *left;
    struct node *right;
    int type2;
    
    left = evaluate_level_6(type);
    while (1) {
        if (lex == C_MUL) {
            get_lex();
            right = evaluate_level_6(&type2);
            *type = extend_types(&left, *type, &right, type2);
            left = node_create(N_MUL, 0, left, right);
        } else if (lex == C_DIV) {
            get_lex();
            right = evaluate_level_6(&type2);
            *type = extend_types(&left, *type, &right, type2);
            left = node_create(N_DIV, 0, left, right);
        } else if (lex == C_MOD) {
            get_lex();
            right = evaluate_level_6(&type2);
            *type = extend_types(&left, *type, &right, type2);
            left = node_create(N_MOD, 0, left, right);
        } else {
            break;
        }
    }
    return left;
}

/*
 ** Expression evaluation level 6 (- NOT)
 */
struct node *evaluate_level_6(int *type)
{
    struct node *left;
    
    if (lex == C_MINUS) {
        get_lex();
        
        left = evaluate_level_7(type);
        if ((*type & MAIN_TYPE) == TYPE_8)
            left = node_create(N_NEG8, 0, left, NULL);
        else
            left = node_create(N_NEG16, 0, left, NULL);
    } else if (lex == C_NAME && strcmp(name, "NOT") == 0) {
        get_lex();
        
        left = evaluate_level_7(type);
        if ((*type & MAIN_TYPE) == TYPE_8)
            left = node_create(N_NOT8, 0, left, NULL);
        else
            left = node_create(N_NOT16, 0, left, NULL);
    } else {
        left = evaluate_level_7(type);
    }
    return left;
}

/*
 ** Expression evaluation level 7 (parenthesis, variables, and values)
 */
struct node *evaluate_level_7(int *type)
{
    struct node *tree;
    struct label *label;
    struct constant *constant;
    
    if (lex == C_LPAREN) {
        get_lex();
        tree = evaluate_level_0(type);
        if (lex != C_RPAREN)
            emit_error("missing right parenthesis");
        else
            get_lex();
        return tree;
    }
    if (lex == C_NAME) {
        if (strcmp(name, "INP") == 0) {
            get_lex();
            if (lex != C_LPAREN) {
                emit_error("missing left parenthesis in PEEK");
            }
            get_lex();
            tree = evaluate_level_0(type);
            if ((*type & MAIN_TYPE) == TYPE_8)
                tree = node_create(N_EXTEND8, 0, tree, NULL);
            tree = node_create(N_INP, 0, tree, NULL);
            if (lex != C_RPAREN) {
                emit_error("missing right parenthesis in PEEK");
            }
            get_lex();
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "PEEK") == 0) {
            get_lex();
            if (lex != C_LPAREN) {
                emit_error("missing left parenthesis in PEEK");
            }
            get_lex();
            tree = evaluate_level_0(type);
            if ((*type & MAIN_TYPE) == TYPE_8)
                tree = node_create(N_EXTEND8, 0, tree, NULL);
            tree = node_create(N_PEEK8, 0, tree, NULL);
            if (lex != C_RPAREN) {
                emit_error("missing right parenthesis in PEEK");
            }
            get_lex();
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "VPEEK") == 0) {
            get_lex();
            if (lex != C_LPAREN) {
                emit_error("missing left parenthesis in VPEEK");
            }
            get_lex();
            tree = evaluate_level_0(type);
            if ((*type & MAIN_TYPE) == TYPE_8)
                tree = node_create(N_EXTEND8, 0, tree, NULL);
            tree = node_create(N_VPEEK, 0, tree, NULL);
            if (lex != C_RPAREN) {
                emit_error("missing right parenthesis in VPEEK");
            }
            get_lex();
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "CONT") == 0) {
            get_lex();
            if (lex == C_PERIOD) {
                get_lex();
                if (lex != C_NAME) {
                    emit_error("CONT syntax error");
                } else if (strcmp(name, "UP") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_JOY2, 1, NULL, NULL));
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 1, NULL, NULL));
                } else if (strcmp(name, "RIGHT") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_JOY2, 1, NULL, NULL));
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 2, NULL, NULL));
                } else if (strcmp(name, "DOWN") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_JOY2, 1, NULL, NULL));
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 4, NULL, NULL));
                } else if (strcmp(name, "LEFT") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_JOY2, 1, NULL, NULL));
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 8, NULL, NULL));
                } else if (strcmp(name, "BUTTON") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_JOY2, 1, NULL, NULL));
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 0x40, NULL, NULL));
                } else if (strcmp(name, "BUTTON2") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_JOY2, 1, NULL, NULL));
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 0x80, NULL, NULL));
                } else if (strcmp(name, "KEY") == 0) {
                    get_lex();
                    tree = node_create(N_KEY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_KEY2, 1, NULL, NULL));
                }
            } else {
                tree = node_create(N_JOY1, 0, NULL, NULL);
                tree = node_create(N_AND8, 0, tree, node_create(N_JOY2, 1, NULL, NULL));
            }
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "CONT1") == 0) {
            get_lex();
            if (lex == C_PERIOD) {
                get_lex();
                if (lex != C_NAME) {
                    emit_error("CONT1 syntax error");
                } else if (strcmp(name, "UP") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 1, NULL, NULL));
                } else if (strcmp(name, "RIGHT") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 2, NULL, NULL));
                } else if (strcmp(name, "DOWN") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 4, NULL, NULL));
                } else if (strcmp(name, "LEFT") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 8, NULL, NULL));
                } else if (strcmp(name, "BUTTON") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 0x40, NULL, NULL));
                } else if (strcmp(name, "BUTTON2") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 0x80, NULL, NULL));
                } else if (strcmp(name, "KEY") == 0) {
                    get_lex();
                    tree = node_create(N_KEY1, 0, NULL, NULL);
                }
            } else {
                tree = node_create(N_JOY1, 0, NULL, NULL);
            }
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "CONT2") == 0) {
            get_lex();
            if (lex == C_PERIOD) {
                get_lex();
                if (lex != C_NAME) {
                    emit_error("CONT2 syntax error");
                } else if (strcmp(name, "UP") == 0) {
                    get_lex();
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 1, NULL, NULL));
                } else if (strcmp(name, "RIGHT") == 0) {
                    get_lex();
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 2, NULL, NULL));
                } else if (strcmp(name, "DOWN") == 0) {
                    get_lex();
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 4, NULL, NULL));
                } else if (strcmp(name, "LEFT") == 0) {
                    get_lex();
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 8, NULL, NULL));
                } else if (strcmp(name, "BUTTON") == 0) {
                    get_lex();
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 0x40, NULL, NULL));
                } else if (strcmp(name, "BUTTON2") == 0) {
                    get_lex();
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 0x80, NULL, NULL));
                } else if (strcmp(name, "KEY") == 0) {
                    get_lex();
                    tree = node_create(N_KEY2, 0, NULL, NULL);
                }
            } else {
                tree = node_create(N_JOY2, 0, NULL, NULL);
            }
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "ABS") == 0) {
            get_lex();
            if (lex != C_LPAREN)
                emit_error("missing left parenthesis in ABS");
            get_lex();
            tree = evaluate_level_0(type);
            if ((*type & MAIN_TYPE) == TYPE_8)
                tree = node_create(N_EXTEND8, 0, tree, NULL);
            tree = node_create(N_ABS16, 0, tree, NULL);
            if (lex != C_RPAREN) {
                emit_error("missing right parenthesis in ABS");
            }
            get_lex();
            *type = TYPE_16;
            return tree;
        }
        if (strcmp(name, "RANDOM") == 0) {
            get_lex();
            if (lex == C_LPAREN) {
                get_lex();
                tree = evaluate_level_0(type);
                if ((*type & MAIN_TYPE) == TYPE_8)
                    tree = node_create(N_EXTEND8, 0, tree, NULL);
                tree = node_create(N_MOD, 0, node_create(N_RANDOM, 0, NULL, NULL), tree);
                if (lex != C_RPAREN) {
                    emit_error("missing right parenthesis in RANDOM");
                }
                get_lex();
            } else {
                tree = node_create(N_RANDOM, 0, NULL, NULL);
            }
            *type = TYPE_16;
            return tree;
        }
        if (strcmp(name, "FRAME") == 0) {
            get_lex();
            tree = node_create(N_FRAME, 0, NULL, NULL);
            *type = TYPE_16;
            return tree;
        }
        if (lex_sneak_peek() == '(') {  // Indexed access
            int type2;
            struct node *addr;
            
            if (name[0] == '#')
                *type = TYPE_16;
            else
                *type = TYPE_8;
            label = array_search(name);
            if (label != NULL) {    /* Found array */
            } else {
                label = label_search(name);
                if (label != NULL) {
                    if (label->used & LABEL_IS_VARIABLE) {
                        emit_error("using array but not defined");
                    }
                } else {
                    label = label_add(name);
                }
            }
            get_lex();
            if (lex != C_LPAREN)
                emit_error("missing left parenthesis in array access");
            else
                get_lex();
            tree = evaluate_level_0(&type2);
            if (lex != C_RPAREN)
                emit_error("missing right parenthesis in array access");
            else
                get_lex();
            addr = node_create(N_ADDR, 0, NULL, NULL);
            addr->label = label;
            if ((type2 & MAIN_TYPE) == TYPE_8)
                tree = node_create(N_EXTEND8, 0, tree, NULL);
            if (*type == TYPE_16) {
                tree = node_create(N_MUL, 0, tree,
                                   node_create(N_NUM16, 2, NULL, NULL));
            }
            tree = node_create(*type == TYPE_16 ? N_PEEK16 : N_PEEK8, 0,
                               node_create(N_PLUS16, 0, addr, tree), NULL);
            return tree;
        }
        constant = constant_search(name);
        if (constant != NULL) {
            get_lex();
            if (constant->name[0] == '#') {
                *type = TYPE_16;
                return node_create(N_NUM16, constant->value & 0xffff, NULL, NULL);
            }
            *type = TYPE_8;
            return node_create(N_NUM8, constant->value & 0xff, NULL, NULL);
        }
        label = label_search(name);
        if (label != NULL && (label->used & LABEL_IS_VARIABLE) == 0) {
            char buffer[MAX_LINE_SIZE];
            
            sprintf(buffer, "variable name '%s' already defined with other purpose", name);
            emit_error(buffer);
            label = NULL;
        }
        if (label == NULL) {
            char buffer[MAX_LINE_SIZE];
            
            label = label_add(name);
            if (name[0] == '#')
                label->used = TYPE_16;
            else
                label->used = TYPE_8;
            label->used |= LABEL_IS_VARIABLE;
        }
        get_lex();
        if ((label->used & MAIN_TYPE) == TYPE_8)
            tree = node_create(N_LOAD8, 0, NULL, NULL);
        else
            tree = node_create(N_LOAD16, 0, NULL, NULL);
        tree->label = label;
        *type = label->used & MAIN_TYPE;
        return tree;
    }
    if (lex == C_NUM) {
        int temp;
        
        temp = value;
        get_lex();
        if (value_special) {
            *type = TYPE_8;
            return node_create(N_NUM8, temp & 0xff, NULL, NULL);
        }
        *type = TYPE_16;
        return node_create(N_NUM16, temp & 0xffff, NULL, NULL);
    }
    emit_error("bad syntax por expression");
    *type = TYPE_16;
    return node_create(N_NUM16, 0, NULL, NULL);
}

/*
 ** Compile an assignment
 */
void compile_assignment(int is_read)
{
    struct node *tree;
    struct node *addr;
    int type;
    int type2;
    struct label *label;
    
    if (lex != C_NAME) {
        emit_error("name required for assignment");
        return;
    }
    if (lex_sneak_peek() == '(') {  // Indexed access
        int type2;
        struct node *addr;
        
        if (name[0] == '#')
            type2 = TYPE_16;
        else
            type2 = TYPE_8;
        label = array_search(name);
        if (label == NULL) {    /* Found array */
            emit_error("using array without previous DIM, autoassigning DIM(10)");
            label = array_add(name);
            label->length = 10;
        }
        get_lex();
        if (lex != C_LPAREN)
            emit_error("missing left parenthesis in array access");
        else
            get_lex();
        tree = evaluate_level_0(&type);
        if (lex != C_RPAREN)
            emit_error("missing right parenthesis in array access");
        else
            get_lex();
        addr = node_create(N_ADDR, 0, NULL, NULL);
        addr->label = label;
        if ((type & MAIN_TYPE) == TYPE_8)
            tree = node_create(N_EXTEND8, 0, tree, NULL);
        if (type2 == TYPE_16) {
            tree = node_create(N_MUL, 0, tree,
                               node_create(N_NUM16, 2, NULL, NULL));
        }
        addr = node_create(N_PLUS16, 0, addr, tree);
        if (is_read) {
            tree = node_create(is_read == 1 ? N_READ16 : N_READ8, 0, NULL, NULL);
            type = is_read == 1 ? TYPE_16 : TYPE_8;
        } else {
            if (lex != C_EQUAL) {
                emit_error("required '=' for assignment");
                return;
            }
            get_lex();
            tree = evaluate_level_0(&type);
        }
        if (type2 == TYPE_16 && (type & MAIN_TYPE) == TYPE_8)
            tree = node_create(N_EXTEND8, 0, tree, NULL);
        else if (type2 == TYPE_8 && (type & MAIN_TYPE) == TYPE_16)
            tree = node_create(N_REDUCE16, 0, tree, NULL);
        if (type2 == TYPE_16)
            tree = node_create(N_ASSIGN16, 0, tree, addr);
        else if (type2 == TYPE_8)
            tree = node_create(N_ASSIGN8, 0, tree, addr);
        tree->label = label;
        node_label(tree);
        node_generate(tree, 0);
        node_delete(tree);
        return;
    }
    strcpy(assigned, name);
    label = label_search(name);
    if (label != NULL && (label->used & LABEL_IS_VARIABLE) == 0) {
        char buffer[MAX_LINE_SIZE];
        
        sprintf(buffer, "variable name '%s' already defined with other purpose", name);
        emit_error(buffer);
        label = NULL;
    }
    if (label == NULL) {
        char buffer[MAX_LINE_SIZE];
       
        label = label_add(name);
        if (name[0] == '#')
            label->used = TYPE_16;
        else
            label->used = TYPE_8;
        label->used |= LABEL_IS_VARIABLE;
    }
    get_lex();
    if (is_read) {
        tree = node_create(is_read == 1 ? N_READ16 : N_READ8, 0, NULL, NULL);
        type = is_read == 1 ? TYPE_16 : TYPE_8;
    } else {
        if (lex != C_EQUAL) {
            emit_error("required '=' for assignment");
            return;
        }
        get_lex();
        tree = evaluate_level_0(&type);
    }
    if ((label->used & MAIN_TYPE) == TYPE_16 && (type & MAIN_TYPE) == TYPE_8)
        tree = node_create(N_EXTEND8, 0, tree, NULL);
    else if ((label->used & MAIN_TYPE) == TYPE_8 && (type & MAIN_TYPE) == TYPE_16)
        tree = node_create(N_REDUCE16, 0, tree, NULL);
    node_label(tree);
    node_generate(tree, 0);
    node_delete(tree);
    strcpy(temp, "(" LABEL_PREFIX);
    strcat(temp, label->name);
    strcat(temp, ")");
    if ((label->used & MAIN_TYPE) == TYPE_8) {
        z80_2op("LD", temp, "A");
    } else {
        z80_2op("LD", temp, "HL");
    }
}

/*
 ** Compile a statement
 */
void compile_statement(int check_for_else)
{
    struct label *label;
    int label_number;
    int type;
    
    while (1) {
        if (lex == C_NAME) {
            if (strcmp(name, "GOTO") == 0) {
                get_lex();
                if (lex != C_NAME) {
                    emit_error("bad syntax for GOTO");
                } else {
                    label = label_search(name);
                    if (label == NULL) {
                        label = label_add(name);
                    }
                    label->used |= LABEL_USED;
                    label->used |= LABEL_CALLED_BY_GOTO;
                    strcpy(temp, LABEL_PREFIX);
                    strcat(temp, name);
                    z80_1op("JP", temp);
                    get_lex();
                }
            } else if (strcmp(name, "GOSUB") == 0) {
                get_lex();
                if (lex != C_NAME) {
                    emit_error("bad syntax for GOSUB");
                } else {
                    label = label_search(name);
                    if (label == NULL) {
                        label = label_add(name);
                    }
                    label->used |= LABEL_USED;
                    label->used |= LABEL_CALLED_BY_GOSUB;
                    strcpy(temp, LABEL_PREFIX);
                    strcat(temp, name);
                    z80_1op("CALL", temp);
                    get_lex();
                }
            } else if (strcmp(name, "RETURN") == 0) {
                get_lex();
                z80_noop("RET");
            } else if (strcmp(name, "IF") == 0) {
                struct node *tree;
                int type;
                int label;
                int there_is_else;
                int label2;
                struct loop *new_loop;
                int block;
                
                get_lex();
                label = next_local++;
                type = evaluate_expression(0, 0, label);
                if (lex == C_NAME && strcmp(name, "GOTO") == 0) {
                    compile_statement(FALSE);
                    block = 0;
                } else if (lex != C_NAME || strcmp(name, "THEN") != 0) {
                    emit_error("missing THEN in IF");
                    block = 0;
                } else {
                    get_lex();
                    if (lex == C_END) {
                        block = 1;
                        new_loop = malloc(sizeof(struct loop));
                        if (new_loop == NULL) {
                            fprintf(stderr, "out of memory");
                            exit(1);
                        }
                        new_loop->type = 2;
                        new_loop->step = NULL;
                        new_loop->final = NULL;
                        new_loop->var[0] = 0;
                        new_loop->label_loop = label;
                        new_loop->label_exit = 0;
                        new_loop->next = loops;
                        loops = new_loop;
                    } else {
                        compile_statement(TRUE);
                        block = 0;
                    }
                }
                if (block)
                    break;
                if (lex == C_NAME && strcmp(name, "ELSE") == 0) {
                    there_is_else = 1;
                    get_lex();
                    label2 = next_local++;
                    sprintf(temp, INTERNAL_PREFIX "%d", label2);
                    z80_1op("JP", temp);
                } else {
                    there_is_else = 0;
                }
                sprintf(temp, INTERNAL_PREFIX "%d", label);
                z80_label(temp);
                if (there_is_else) {
                    compile_statement(TRUE);
                    sprintf(temp, INTERNAL_PREFIX "%d", label2);
                    z80_label(temp);
                }
            } else if (strcmp(name, "ELSEIF") == 0) {
                int type;
                struct node *tree;
                
                get_lex();
                if (loops == NULL) {
                    emit_error("ELSEIF without IF");
                } else if (loops->type != 2 || loops->label_loop == 0) {
                    emit_error("bad nested ELSEIF");
                } else {
                    if (loops->var[0] != 1) {
                        loops->label_exit = next_local++;
                        loops->var[0] = 1;
                    }
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                    z80_1op("JP", temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                    z80_label(temp);
                    loops->label_loop = next_local++;
                    type = evaluate_expression(0, 0, loops->label_loop);
                    if (lex == C_NAME && strcmp(name, "GOTO") == 0) {
                        compile_statement(FALSE);
                    } else if (lex != C_NAME || strcmp(name, "THEN") != 0) {
                        emit_error("missing THEN in ELSEIF");
                    } else {
                        get_lex();
                    }
                }
                if (lex == C_END)
                    break;
                continue;
            } else if (strcmp(name, "ELSE") == 0) {
                if (check_for_else)
                    break;
                get_lex();
                if (loops == NULL) {
                    emit_error("ELSE without IF");
                } else if (loops->type != 2) {
                    emit_error("bad nested ELSE");
                } else if (loops->label_loop == 0) {
                    emit_error("more than one ELSE");
                } else {
                    if (loops->var[0] != 1) {
                        loops->label_exit = next_local++;
                        loops->var[0] = 1;
                    }
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                    z80_1op("JP", temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                    z80_label(temp);
                    loops->label_loop = 0;
                }
                if (lex == C_END)
                    break;
                continue;
            } else if (strcmp(name, "END") == 0) {
                struct loop *popping;
                
                get_lex();
                if (lex != C_NAME || strcmp(name, "IF") != 0) {
                    emit_error("wrong END");
                } else {
                    get_lex();
                    if (loops == NULL || loops->type != 2) {
                        emit_error("Bad nested END IF");
                    } else {
                        if (loops->var[0] == 1) {
                            sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                            z80_label(temp);
                        }
                        if (loops->label_loop != 0) {
                            sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                            z80_label(temp);
                        }
                        popping = loops;
                        loops = loops->next;
                        free(popping);
                    }
                }
            } else if (strcmp(name, "FOR") == 0) {
                struct loop *new_loop;
                int label_loop;
                char loop[MAX_LINE_SIZE];
                struct node *final = NULL;
                struct node *step = NULL;
                struct node *var;
                int positive;
                int type;
                int end_value;
                int step_value;
                int type_var;
                enum node_type comparison;
                
                get_lex();
                compile_assignment(0);
                new_loop = malloc(sizeof(struct loop) + strlen(assigned) + 1);
                if (new_loop == NULL) {
                    fprintf(stderr, "Out of memory");
                    exit(1);
                }
                strcpy(new_loop->var, assigned);
                if (assigned[0] == '#')
                    type_var = TYPE_16;
                else
                    type_var = TYPE_8;
                label_loop = next_local++;
                sprintf(temp, INTERNAL_PREFIX "%d", label_loop);
                z80_label(temp);
                if (lex != C_NAME || strcmp(name, "TO") != 0) {
                    emit_error("missing TO in FOR");
                } else {
                    get_lex();
                    final = evaluate_level_0(&type);
                    if (type_var == TYPE_16 && (type & MAIN_TYPE) == TYPE_8)
                        final = node_create(N_EXTEND8, 0, final, NULL);
                    else if (type_var == TYPE_8 && (type & MAIN_TYPE) == TYPE_16)
                        final = node_create(N_REDUCE16, 0, final, NULL);
                    positive = 1;
                    var = node_create(type_var == TYPE_16 ? N_LOAD16 : N_LOAD8, 0, NULL, NULL);
                    var->label = label_search(new_loop->var);
                    if (lex == C_NAME && strcmp(name, "STEP") == 0) {
                        get_lex();
                        if (lex == C_MINUS) {
                            get_lex();
                            step = evaluate_level_0(&type);
                            if (type_var == TYPE_16 && (type & MAIN_TYPE) == TYPE_8)
                                step = node_create(N_EXTEND8, 0, step, NULL);
                            else if (type_var == TYPE_8 && (type & MAIN_TYPE) == TYPE_16)
                                step = node_create(N_REDUCE16, 0, step, NULL);
                            step = node_create(type_var == TYPE_16 ? N_MINUS16 : N_MINUS8, 0,
                                            var, step);
                            positive = 0;
                        } else {
                            step = evaluate_level_0(&type);
                            if (type_var == TYPE_16 && (type & MAIN_TYPE) == TYPE_8)
                                step = node_create(N_EXTEND8, 0, step, NULL);
                            else if (type_var == TYPE_8 && (type & MAIN_TYPE) == TYPE_16)
                                step = node_create(N_REDUCE16, 0, step, NULL);
                            step = node_create(type_var == TYPE_16 ? N_PLUS16 : N_PLUS8, 0, var, step);
                        }
                    } else {
                        step_value = 1;
                        step = node_create(type_var == TYPE_16 ? N_NUM16 : N_NUM8, 1, NULL, NULL);
                        step = node_create(type_var == TYPE_16 ? N_PLUS16 : N_PLUS8, 0, var, step);
                    }
                    var = node_create(type_var == TYPE_16 ? N_LOAD16 : N_LOAD8, 0, NULL, NULL);
                    var->label = label_search(new_loop->var);
                    if (type_var == TYPE_16) {
                        comparison = positive ? N_GREATER16 : N_LESS16;
                    } else {
                        comparison = positive ? N_GREATER8 : N_LESS8;
                    }
                    final = node_create(comparison, 0, var, final);
                }
                new_loop->type = 0;
                new_loop->step = step;
                new_loop->final = final;
                new_loop->label_loop = label_loop;
                new_loop->label_exit = 0;
                new_loop->next = loops;
                loops = new_loop;
            } else if (strcmp(name, "NEXT") == 0) {
                struct loop *popping;
                
                get_lex();
                if (loops == NULL) {
                    emit_error("NEXT without FOR");
                } else {
                    struct node *final = loops->final;
                    struct node *step = loops->step;
                    int label_loop = loops->label_loop;
                    int label_exit = loops->label_exit;
                    
                    if (loops->type != 0) {
                        emit_error("bad nested NEXT");
                        if (lex == C_NAME)
                            get_lex();
                    } else {
                        if (lex == C_NAME) {
                            if (strcmp(name, loops->var) != 0)
                                emit_error("bad nested NEXT");
                            get_lex();
                        }
                        node_label(step);
                        node_generate(step, 0);
                        sprintf(temp, "(" LABEL_PREFIX "%s" ")", loops->var);
                        if (loops->var[0] == '#') {
                            z80_2op("LD", temp, "HL");
                        } else {
                            z80_2op("LD", temp, "A");
                        }
                        if (final != NULL) {
                            node_label(final);
                            node_generate(final, 0);
                            z80_1op("OR", "A");
                            sprintf(temp, INTERNAL_PREFIX "%d", label_loop);
                            z80_2op("JP", "Z", temp);
                            node_delete(final);
                        }
                        if (step != NULL) {
                            node_delete(step);
                        }
                        if (label_exit != 0) {
                            sprintf(temp, INTERNAL_PREFIX "%d", label_exit);
                            z80_label(temp);
                        }
                        popping = loops;
                        loops = loops->next;
                        free(popping);
                    }
                }
            } else if (strcmp(name, "WHILE") == 0) {
                int label_loop;
                int label_exit;
                int type;
                struct loop *new_loop;
                
                get_lex();
                label_loop = next_local++;
                label_exit = next_local++;
                sprintf(temp, INTERNAL_PREFIX "%d", label_loop);
                z80_label(temp);
                type = evaluate_expression(0, 0, label_exit);
                new_loop = malloc(sizeof(struct loop));
                if (new_loop == NULL) {
                    fprintf(stderr, "Out of memory\n");
                    exit(1);
                }
                new_loop->type = 1;
                new_loop->step = NULL;
                new_loop->final = NULL;
                new_loop->var[0] = '\0';
                new_loop->label_loop = label_loop;
                new_loop->label_exit = label_exit;
                new_loop->next = loops;
                loops = new_loop;
            } else if (strcmp(name, "WEND") == 0) {
                struct loop *popping;
                
                get_lex();
                if (loops == NULL) {
                    emit_error("WEND without WHILE");
                } else if (loops->type != 1) {
                    emit_error("bad nested WEND");
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                    z80_1op("JP", temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                    z80_label(temp);
                    popping = loops;
                    loops = loops->next;
                    free(popping);
                }
            } else if (strcmp(name, "DO") == 0) {
                int label_loop;
                int label_exit;
                int type;
                struct loop *new_loop;
                
                get_lex();
                label_loop = next_local++;
                label_exit = next_local++;
                sprintf(temp, INTERNAL_PREFIX "%d", label_loop);
                z80_label(temp);
                new_loop = malloc(sizeof(struct loop));
                if (new_loop == NULL) {
                    fprintf(stderr, "Out of memory\n");
                    exit(1);
                }
                if (lex == C_NAME && strcmp(name, "WHILE") == 0) {
                    get_lex();
                    type = evaluate_expression(0, 0, label_exit);
                    new_loop->var[0] = '1'; /* Uses exit label */
                    new_loop->type = 3;     /* Condition at top */
                } else if (lex == C_NAME && strcmp(name, "UNTIL") == 0) {
                    int label_temp = next_local++;
                    
                    get_lex();
                    type = evaluate_expression(0, 0, label_temp);
                    /* Let optimizer to solve this =P */
                    sprintf(temp, INTERNAL_PREFIX "%d", label_exit);
                    z80_1op("JP", temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", label_temp);
                    z80_label(temp);
                    new_loop->var[0] = '1'; /* Uses exit label */
                    new_loop->type = 3;  /* Condition at top */
                } else {
                    new_loop->var[0] = '\0'; /* Doesn't use exit label (yet) */
                    new_loop->type = 4;  /* Condition at bottom */
                }
                new_loop->step = NULL;
                new_loop->final = NULL;
                new_loop->label_loop = label_loop;
                new_loop->label_exit = label_exit;
                new_loop->next = loops;
                loops = new_loop;
            } else if (strcmp(name, "LOOP") == 0) {
                struct loop *popping;
                
                get_lex();
                if (loops == NULL) {
                    emit_error("LOOP without DO");
                } else if (loops->type == 3) {
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                    z80_1op("JP", temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                    z80_label(temp);
                    popping = loops;
                    loops = loops->next;
                    free(popping);
                } else if (loops->type == 4) {
                    int type;
                    
                    if (lex == C_NAME && strcmp(name, "WHILE") == 0) {
                        int label_temp = next_local++;
                        
                        get_lex();
                        type = evaluate_expression(0, 0, label_temp);
                        /* Let optimizer to solve this =P */
                        sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                        z80_1op("JP", temp);
                        sprintf(temp, INTERNAL_PREFIX "%d", label_temp);
                        z80_label(temp);
                    } else if (lex == C_NAME && strcmp(name, "UNTIL") == 0) {
                        get_lex();
                        type = evaluate_expression(0, 0, loops->label_loop);
                    } else {
                        emit_error("LOOP without condition");
                    }
                    if (loops->var[0] == '1') {  /* Uses exit label? */
                        sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                        z80_label(temp);
                    }
                    popping = loops;
                    loops = loops->next;
                    free(popping);
                } else {
                    emit_error("bad nested LOOP");
                }
            } else if (strcmp(name, "EXIT") == 0) {
                struct loop *loop_explorer;
                
                get_lex();
                
                // Avoid IF blocks
                loop_explorer = loops;
                while (loop_explorer != NULL) {
                    if (loop_explorer->type != 2)
                        break;
                    loop_explorer = loop_explorer->next;
                }
                if (loops == NULL || loop_explorer == NULL) {
                    emit_error("nowhere to EXIT");
                } else {
                    if (lex != C_NAME) {
                        emit_error("missing type of EXIT, WHILE/FOR/DO");
                    } else if (strcmp(name, "FOR") == 0) {
                        get_lex();
                        if (loop_explorer->type != 0) {
                            emit_error("EXIT FOR without FOR");
                        } else {
                            if (loop_explorer->label_exit == 0)
                                loop_explorer->label_exit = next_local++;
                            sprintf(temp, INTERNAL_PREFIX "%d", loop_explorer->label_exit);
                            z80_1op("JP", temp);
                        }
                    } else if (strcmp(name, "WHILE") == 0) {
                        get_lex();
                        if (loop_explorer->type != 1) {
                            emit_error("EXIT WHILE without WHILE");
                        } else {
                            sprintf(temp, INTERNAL_PREFIX "%d", loop_explorer->label_exit);
                            z80_1op("JP", temp);
                        }
                    } else if (strcmp(name, "DO") == 0) {
                        get_lex();
                        if (loop_explorer->type != 3 && loop_explorer->type != 4) {
                            emit_error("EXIT DO without DO");
                        } else {
                            loop_explorer->var[0] = '1';
                            sprintf(temp, INTERNAL_PREFIX "%d", loop_explorer->label_exit);
                            z80_1op("JP", temp);
                        }
                    } else {
                        emit_error("only supported EXIT WHILE/FOR/DO");
                        get_lex();
                    }
                }
            } else if (strcmp(name, "POKE") == 0) {
                struct node *tree;
                int type;
                
                get_lex();
                type = evaluate_expression(1, TYPE_16, 0);
                z80_1op("PUSH", "HL");
                if (lex == C_COMMA)
                    get_lex();
                else
                    emit_error("missing comma in POKE");
                type = evaluate_expression(1, TYPE_8, 0);
                z80_1op("POP", "HL");
                z80_2op("LD", "(HL)", "A");
            } else if (strcmp(name, "VPOKE") == 0) {
                struct node *tree;
                int type;
                
                get_lex();
                type = evaluate_expression(1, TYPE_16, 0);
                z80_1op("PUSH", "HL");
                if (lex == C_COMMA)
                    get_lex();
                else
                    emit_error("missing comma in VPOKE");
                type = evaluate_expression(1, TYPE_8, 0);
                z80_1op("POP", "HL");
                z80_1op("CALL", "NMI_OFF");
                z80_1op("CALL", "WRTVRM");
                z80_1op("CALL", "NMI_ON");
            } else if (strcmp(name, "REM") == 0) {
                line_pos = line_size;
                get_lex();
            } else if (strcmp(name, "CLS") == 0) {
                get_lex();
                z80_1op("CALL", "cls");
            } else if (strcmp(name, "WAIT") == 0) {
                get_lex();
                z80_noop("HALT");
            } else if (strcmp(name, "RESTORE") == 0) {
                get_lex();
                if (lex != C_NAME) {
                    emit_error("bad syntax for RESTORE");
                } else {
                    label = label_search(name);
                    if (label == NULL) {
                        label = label_add(name);
                    }
                    sprintf(temp, LABEL_PREFIX "%s", name);
                    z80_2op("LD", "HL", temp);
                    z80_2op("LD", "(read_pointer)", "HL");
                    get_lex();
                }
            } else if (strcmp(name, "READ") == 0) {
                int c;
                
                get_lex();
                if (lex == C_NAME && strcmp(name, "BYTE") == 0) {
                    get_lex();
                    c = 2;
                } else {
                    c = 1;
                }
                while (1) {
                    compile_assignment(c);
                    if (lex != C_COMMA)
                        break;
                    get_lex();
                }
            } else if (strcmp(name, "OUT") == 0) {
                struct node *tree;
                int type;
                
                get_lex();
                type = evaluate_expression(1, TYPE_8, 0);
                z80_2op("LD", "C", "A");
                z80_1op("PUSH", "BC");
                if (lex == C_COMMA)
                    get_lex();
                else
                    emit_error("missing comma in OUT");
                type = evaluate_expression(1, TYPE_8, 0);
                z80_1op("POP", "BC");
                z80_2op("OUT", "(C)", "A");
            } else if (strcmp(name, "PRINT") == 0) {
                int label;
                int label2;
                int c;
                
                get_lex();
                if (lex == C_NAME && strcmp(name, "AT") == 0) {
                    get_lex();
                    type = evaluate_expression(1, TYPE_16, 0);
                    z80_2op("LD", "(cursor)", "HL");
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma");
                }
                while (1) {
                    if (lex == C_STRING) {
                        if (name_size) {
                            label = next_local++;
                            label2 = next_local++;
                            sprintf(temp, INTERNAL_PREFIX "%d", label);
                            z80_2op("LD", "HL", temp);
                            sprintf(temp, "%d", name_size);
                            z80_2op("LD", "A", temp);
                            z80_1op("CALL", "print_string");
                            sprintf(temp, INTERNAL_PREFIX "%d", label2);
                            z80_1op("JP", temp);
                            sprintf(temp, INTERNAL_PREFIX "%d", label);
                            z80_label(temp);
                            for (c = 0; c < name_size; c++) {
                                if ((c & 7) == 0) {
                                    fprintf(output, "\tDB ");
                                }
                                fprintf(output, "$%02x", name[c] & 0xff);
                                if ((c & 7) == 7 || c + 1 == name_size) {
                                    fprintf(output, "\n");
                                } else {
                                    fprintf(output, ",");
                                }
                            }
                            sprintf(temp, INTERNAL_PREFIX "%d", label2);
                            z80_label(temp);
                        }
                        get_lex();
                    } else {
                        type = evaluate_expression(1, TYPE_16, 0);
                        z80_1op("CALL", "print_number");
                    }
                    if (lex != C_COMMA)
                        break;
                    get_lex();
                }
            } else if (strcmp(name, "DEFINE") == 0) {
                get_lex();
                if (lex != C_NAME) {
                    emit_error("syntax error in DEFINE");
                } else if (strcmp(name, "SPRITE") == 0) {
                    get_lex();
                    type = evaluate_expression(1, TYPE_16, 0);
                    z80_1op("PUSH", "HL");
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in DEFINE");
                    type = evaluate_expression(1, TYPE_8, 0);
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in DEFINE");
                    if (lex != C_NAME) {
                        emit_error("missing label in DEFINE");
                    } else {
                        strcpy(temp, LABEL_PREFIX);
                        strcat(temp, name);
                        z80_2op("LD", "HL", temp);
                        get_lex();
                    }
                    z80_1op("CALL", "define_sprite");
                } else if (strcmp(name, "CHAR") == 0) {
                    get_lex();
                    type = evaluate_expression(1, TYPE_16, 0);
                    z80_1op("PUSH", "HL");
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in DEFINE");
                    type = evaluate_expression(1, TYPE_8, 0);
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in DEFINE");
                    if (lex != C_NAME) {
                        emit_error("missing label in DEFINE");
                    } else {
                        strcpy(temp, LABEL_PREFIX);
                        strcat(temp, name);
                        z80_2op("LD", "HL", temp);
                        get_lex();
                    }
                    z80_1op("CALL", "define_char");
                } else if (strcmp(name, "COLOR") == 0) {
                    get_lex();
                    type = evaluate_expression(1, TYPE_16, 0);
                    z80_1op("PUSH", "HL");
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in DEFINE");
                    type = evaluate_expression(1, TYPE_8, 0);
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in DEFINE");
                    if (lex != C_NAME) {
                        emit_error("missing label in DEFINE");
                    } else {
                        strcpy(temp, LABEL_PREFIX);
                        strcat(temp, name);
                        z80_2op("LD", "HL", temp);
                        get_lex();
                    }
                    z80_1op("CALL", "define_color");
                } else {
                    emit_error("syntax error in DEFINE");
                }
            } else if (strcmp(name, "SPRITE") == 0) {
                get_lex();
                type = evaluate_expression(1, TYPE_8, 0);
                z80_1op("PUSH", "AF");
                if (lex == C_COMMA)
                    get_lex();
                else
                    emit_error("missing comma in SPRITE");
                type = evaluate_expression(1, TYPE_8, 0);
                z80_1op("PUSH", "AF");
                if (lex == C_COMMA)
                    get_lex();
                else
                    emit_error("missing comma in SPRITE");
                type = evaluate_expression(1, TYPE_8, 0);
                z80_1op("PUSH", "AF");
                if (lex == C_COMMA)
                    get_lex();
                else
                    emit_error("missing comma in SPRITE");
                type = evaluate_expression(1, TYPE_8, 0);
                z80_1op("PUSH", "AF");
                if (lex == C_COMMA)
                    get_lex();
                else
                    emit_error("missing comma in SPRITE");
                type = evaluate_expression(1, TYPE_8, 0);
                z80_1op("CALL", "update_sprite");
            } else if (strcmp(name, "DATA") == 0) {
                get_lex();
                if (lex == C_NAME && strcmp(name, "BYTE") == 0) {
                    get_lex();
                    while (1) {
                        if (lex == C_STRING) {
                            int c;
                            
                            for (c = 0; c < name_size; c++) {
                                if ((c & 7) == 0) {
                                    fprintf(output, "\tDB ");
                                }
                                fprintf(output, "$%02x", name[c] & 0xff);
                                if ((c & 7) == 7 || c + 1 == name_size) {
                                    fprintf(output, "\n");
                                } else {
                                    fprintf(output, ",");
                                }
                            }
                            get_lex();
                        } else if (lex == C_NUM) {
                            sprintf(temp, "\tDB $%02x", value & 0xff);
                            fprintf(output, "%s\n", temp);
                            get_lex();
                        } else {
                            emit_error("syntax error in DATA");
                            break;
                        }
                        if (lex != C_COMMA)
                            break;
                        get_lex();
                    }
                } else {
                    while (1) {
                        if (lex == C_NUM) {
                            sprintf(temp, "\tDW $%04x", value & 0xffff);
                            fprintf(output, "%s\n", temp);
                            get_lex();
                        } else {
                            emit_error("syntax error in DATA");
                            break;
                        }
                        if (lex != C_COMMA)
                            break;
                        get_lex();
                    }

                }
            } else if (strcmp(name, "BITMAP") == 0) {
                get_lex();
                if (lex != C_STRING || (name_size != 8 && name_size != 16)) {
                    emit_error("syntax error in BITMAP");
                } else if (name_size == 16) {   /* Sprites */
                    int c;
                    
                    value = 0;
                    for (c = 0; c < 16; c++) {
                        if (name[c] != 0x30 && name[c] != 0x5f   /* 0 and _ */
                            && name[c] != 0x20 && name[c] != 0x2e)  /* space and . */
                            value |= 0x8000 >> c;
                    }
                    get_lex();
                    bitmap[bitmap_byte] = value >> 8;
                    bitmap[bitmap_byte + 16] = value;
                    bitmap_byte++;
                    if (bitmap_byte >= 16) {
                        bitmap_byte = 0;
                        for (c = 0; c < 32; c += 8) {
                            sprintf(temp, "\tDB $%02x,$%02x,$%02x,$%02x,$%02x,$%02x,$%02x,$%02x\n",
                                    bitmap[c], bitmap[c + 1], bitmap[c + 2], bitmap[c + 3],
                                    bitmap[c + 4], bitmap[c + 5], bitmap[c + 6], bitmap[c + 7]);
                            fprintf(output, "%s", temp);
                        }
                    }
                    
                } else {
                    int c;
                    
                    value = 0;
                    for (c = 0; c < 8; c++) {
                        if (name[c] != 0x30 && name[c] != 0x5f   /* 0 and _ */
                            && name[c] != 0x20 && name[c] != 0x2e)  /* space and . */
                            value |= 0x80 >> c;
                    }
                    get_lex();
                    bitmap[bitmap_byte] = value;
                    bitmap_byte++;
                    if (bitmap_byte >= 8) {
                        bitmap_byte = 0;
                        c = 0;
                        sprintf(temp, "\tDB $%02x,$%02x,$%02x,$%02x,$%02x,$%02x,$%02x,$%02x\n",
                                bitmap[c], bitmap[c + 1], bitmap[c + 2], bitmap[c + 3],
                                bitmap[c + 4], bitmap[c + 5], bitmap[c + 6], bitmap[c + 7]);
                        fprintf(output, "%s", temp);
                    }
                }
            } else if (strcmp(name, "CONST") == 0) {
                struct constant *c;
                
                get_lex();
                if (lex != C_NAME) {
                    emit_error("name required for constant assignment");
                    return;
                }
                c = constant_search(name);
                if (c != NULL) {
                    emit_error("constant redefined");
                } else {
                    c = constant_add(name);
                }
                strcpy(assigned, name);;
                get_lex();
                if (lex != C_EQUAL) {
                    emit_error("required '=' for constant assignment");
                } else {
                    struct node *tree;
                    int type;
                    
                    get_lex();
                    tree = evaluate_level_0(&type);
                    if (tree->type != N_NUM8 && tree->type != N_NUM16) {
                        emit_error("not a constant expression in CONST");
                    } else {
                        c->value = tree->value;
                    }
                    node_delete(tree);
                    tree = NULL;
                }
            } else if (strcmp(name, "DIM") == 0) {
                char array[MAX_LINE_SIZE];
                struct label *new_array;
                struct node *tree;
                int type;
                int c;
                
                while (1) {
                    get_lex();
                    if (lex != C_NAME) {
                        emit_error("missing name in DIM");
                        break;
                    }
                    strcpy(array, name);
                    get_lex();
                    if (lex == C_LPAREN) {
                        get_lex();
                        tree = evaluate_level_0(&type);
                        if (tree->type != N_NUM8 && tree->type != N_NUM16) {
                            emit_error("not a constant expression in DIM");
                            break;
                        }
                        c = tree->value;
                        if (lex != C_RPAREN) {
                            emit_error("missing right parenthesis in DIM");
                        } else {
                            get_lex();
                        }
                    } else {
                        emit_error("missing left parenthesis in DIM");
                    }
                    new_array = array_search(array);
                    if (new_array != NULL) {
                        emit_error("array already defined");
                    } else {
                        new_array = array_add(array);
                        new_array->length = c;
                    }
                    if (lex != C_COMMA)
                        break;
                }
            } else if (strcmp(name, "ON") == 0) {
                struct label *label;
                int table;
                int c;
                int max_value;
                int gosub;
                int fast;
                struct label *options[256];
                int new_label;
                int type;
                
                get_lex();
                if (lex == C_NAME && strcmp(name, "FRAME") == 0) {  // Frame-driven games
                    get_lex();
                    if (lex != C_NAME || strcmp(name, "GOSUB") != 0) {
                        emit_error("Bad syntax for ON FRAME GOSUB");
                    }
                    get_lex();
                    if (lex != C_NAME) {
                        emit_error("Missing label for ON FRAME GOSUB");
                    }
                    if (frame_drive != NULL) {
                        emit_error("More than one ON FRAME GOSUB");
                    }
                    label = label_search(name);
                    if (label == NULL) {
                        label = label_add(name);
                    }
                    label->used |= LABEL_USED;
                    label->used |= LABEL_CALLED_BY_GOSUB;
                    frame_drive = label;
                    get_lex();
                } else {
                    type = evaluate_expression(0, 0, 0);
                    fast = 0;
                    if (lex == C_NAME && strcmp(name, "FAST") == 0) {
                        get_lex();
                        fast = 1;
                    }
                    gosub = 0;
                    if (lex != C_NAME || (strcmp(name, "GOTO") != 0 && strcmp(name, "GOSUB") != 0)) {
                        emit_error("required GOTO or GOSUB after ON");
                    } else if (strcmp(name, "GOTO") == 0) {
                        get_lex();
                    } else if (strcmp(name, "GOSUB") == 0) {
                        get_lex();
                        gosub = 1;
                    }
                    max_value = 0;
                    while (1) {
                        if (max_value == sizeof(options) / sizeof(struct label *)) {
                            emit_error("too many options for ON statement");
                            max_value--;
                        }
                        if (lex == C_NAME) {
                            label = label_search(name);
                            if (label == NULL) {
                                label = label_add(name);
                            }
                            label->used |= LABEL_USED;
                            if (gosub != 0) {
                                label->used |= LABEL_CALLED_BY_GOSUB;
                            } else {
                                label->used |= LABEL_CALLED_BY_GOTO;
                            }
                            options[max_value++] = label;
                            get_lex();
                        } else {
                            options[max_value++] = NULL;
                        }
                        if (lex != C_COMMA)
                            break;
                        get_lex();
                    }
                    table = next_local++;
                    new_label = next_local++;
                    if (fast == 0) {
                        if ((type & MAIN_TYPE) == TYPE_8) {
                            sprintf(temp, "%d", max_value);
                            z80_1op("CP", temp);
                        } else {
                            sprintf(temp, "%d", max_value);
                            z80_2op("LD", "DE", temp);
                            z80_1op("AND", "A");
                            z80_2op("SBC", "HL", "DE");
                            z80_2op("ADD", "HL", "DE");
                        }
                        sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                        z80_2op("JP", "NC", temp);
                    }
                    if (gosub) {
                        sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                        z80_2op("LD", "DE", temp);
                        z80_1op("PUSH", "DE");
                    }
                    if ((type & MAIN_TYPE) == TYPE_8) {
                        z80_2op("LD", "L", "A");
                        z80_2op("LD", "H", "0");
                    }
                    z80_2op("ADD", "HL", "HL");
                    sprintf(temp, INTERNAL_PREFIX "%d", table);
                    z80_2op("LD", "DE", temp);
                    z80_2op("ADD", "HL", "DE");
                    z80_2op("LD", "A", "(HL)");
                    z80_1op("INC", "HL");
                    z80_2op("LD", "H", "(HL)");
                    z80_2op("LD", "L", "A");
                    z80_1op("JP", "(HL)");
                    sprintf(temp, INTERNAL_PREFIX "%d", table);
                    z80_label(temp);
                    for (c = 0; c < max_value; c++) {
                        if (options[c] != NULL) {
                            sprintf(temp, LABEL_PREFIX "%s", options[c]->name);
                        } else {
                            sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                        }
                        z80_1op("DW", temp);
                    }
                    sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                    z80_label(temp);
                }
            } else if (strcmp(name, "SOUND") == 0) {
                get_lex();
                if (lex != C_NUM) {
                    emit_error("syntax error in SOUND");
                } else {
                    switch (value) {
                        case 0:
                            get_lex();
                            if (lex != C_COMMA) {
                                emit_error("missing comma in sound");
                            } else {
                                get_lex();
                            }
                            if (lex != C_COMMA) {
                                type = evaluate_expression(1, TYPE_16, 0);
                                z80_2op("LD", "A", "$80");
                                z80_1op("CALL", "sn76489_freq");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_2op("LD", "B", "$90");
                                z80_1op("CALL", "sn76489_vol");
                            }
                            break;
                        case 1:
                            get_lex();
                            if (lex != C_COMMA) {
                                emit_error("missing comma in sound");
                            } else {
                                get_lex();
                            }
                            if (lex != C_COMMA) {
                                type = evaluate_expression(1, TYPE_16, 0);
                                z80_2op("LD", "A", "$a0");
                                z80_1op("CALL", "sn76489_freq");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_2op("LD", "B", "$b0");
                                z80_1op("CALL", "sn76489_vol");
                            }
                            break;
                        case 2:
                            get_lex();
                            if (lex != C_COMMA) {
                                emit_error("missing comma in sound");
                            } else {
                                get_lex();
                            }
                            if (lex != C_COMMA) {
                                type = evaluate_expression(1, TYPE_16, 0);
                                z80_2op("LD", "A", "$c0");
                                z80_1op("CALL", "sn76489_freq");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_2op("LD", "B", "$d0");
                                z80_1op("CALL", "sn76489_vol");
                            }
                            break;
                        case 3:
                            get_lex();
                            if (lex != C_COMMA) {
                                emit_error("missing comma in sound");
                            } else {
                                get_lex();
                            }
                            if (lex != C_COMMA) {
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_1op("CALL", "sn76489_control");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_2op("LD", "B", "$f0");
                                z80_1op("CALL", "sn76489_vol");
                            }
                            break;
                    }
                }
            } else {
                compile_assignment(0);
            }
        } else {
            emit_error("syntax error in statement");
        }
        if (lex != C_COLON)
            break;
        get_lex();
    }
}

/*
 ** Compile a source code file.
 */
void compile_basic(void)
{
    struct label *label;
    int label_exists;
    char *p;

    current_line = 0;
    while (fgets(line, sizeof(line) - 1, input)) {
        current_line++;
        line_size = strlen(line);
        line_start = 1;
        line_pos = 0;
        label_exists = 0;
        label = NULL;
        get_lex();
        if (lex == C_LABEL) {
            if (value == 0)
                strcpy(global_label, name);
            label = label_search(name);
            if (label != NULL) {
                if (label->used & LABEL_DEFINED) {
                    char buffer[MAX_LINE_SIZE];
                    
                    sprintf(buffer, "already defined '%s' label", name);
                    emit_error(buffer);
                }
            } else {
                label = label_add(name);
            }
            label->used |= LABEL_DEFINED;
            strcpy(temp, LABEL_PREFIX);
            strcat(temp, name);
            z80_label(temp);
            get_lex();
            label_exists = 1;
        }
        if (lex == C_NAME) {
            if (strcmp(name, "PROCEDURE") == 0) {
                if (!label_exists)
                    emit_error("PROCEDURE without label in same line");
                else
                    label->used |= LABEL_IS_PROCEDURE;
                if (inside_proc)
                    emit_error("starting PROCEDURE without ENDing previous PROCEDURE");
                get_lex();
                inside_proc = label;
            } else if (strcmp(name, "END") == 0 && lex_sneak_peek() != 'I') {  // END (and not END IF)
                if (!inside_proc)
                    emit_warning("END without PROCEDURE");
                /*                    else if (loops.size() > 0)
                 emit_error("Ending PROCEDURE with control block still open");*/ /* !!! */
                get_lex();
                z80_noop("RET");
                inside_proc = NULL;
            } else if (strcmp(name, "INCLUDE") == 0) {
                int quotes;
                FILE *old_input = input;
                int old_line = current_line;
                
                while (line_pos < line_size && isspace(line[line_pos]))
                    line_pos++;
                
                // Separate filename, admit use of quotes
                if (line_pos < line_size && line[line_pos] == '"') {
                    quotes = 1;
                    line_pos++;
                } else {
                    quotes = 0;
                }
                p = &path[0];
                while (p < &path[4095] && line_pos < line_size) {
                    if (quotes && line[line_pos] == '"')
                        break;
                    *p++ = line[line_pos++];
                }
                if (quotes) {
                    if (line_pos >= line_size || line[line_pos] != '"')
                        emit_error("missing quotes in INCLUDE");
                    else
                        line_pos++;
                } else {
                    while (p > &path[0] && isspace(*(p - 1)))
                        p--;
                }
                *p = '\0';
                
                input = fopen(path, "r");
                if (input == NULL) {
                    emit_error("INCLUDE not successful");
                } else {
                    compile_basic();
                    fclose(input);
                }
                input = old_input;
                current_line = old_line;
                lex = C_END;
            } else {
                compile_statement(FALSE);
            }
        }
        if (lex != C_END)
            emit_error("Extra characters");
    }
}

/*
 ** Main program
 */
int main(int argc, char *argv[])
{
    struct label *label;
    FILE *prologue;
    int c;
    int size;
    char *p;
    int bytes_used;
    
    fprintf(stderr, "\nCVBasic compiler " VERSION "\n");
    fprintf(stderr, "(c) 2024 Oscar Toledo G. https://nanochess.org/\n\n");
    
    if (argc < 3) {
        fprintf(stderr, "Usage:\n");
        fprintf(stderr, "\n");
        fprintf(stderr, "    cvbasic input.bas output.asm\n");
        exit(1);
    }
    strcpy(current_file, argv[1]);
    input = fopen(current_file, "r");
    if (input == NULL) {
        fprintf(stderr, "Couldn't open '%s' source file.\n", current_file);
        exit(1);
    }
    output = fopen(argv[2], "w");
    if (output == NULL) {
        fprintf(stderr, "Couldn't open '%s' output file.\n", argv[2]);
        exit(1);
    }
    prologue = fopen("cvbasic_prologue.asm", "r");
    if (prologue == NULL) {
        fprintf(stderr, "Unable to open cvbasic_prologue.asm.\n");
        exit(1);
    }
    while (fgets(line, sizeof(line) - 1, prologue)) {
        fputs(line, output);
    }
    fclose(prologue);
    inside_proc = NULL;
    frame_drive = NULL;
   
    compile_basic();
    fclose(input);

    prologue = fopen("cvbasic_epilogue.asm", "r");
    if (prologue == NULL) {
        fprintf(stderr, "Unable to open cvbasic_epilogue.asm.\n");
        exit(1);
    }
    while (fgets(line, sizeof(line) - 1, prologue)) {
        p = line;
        while (*p && isspace(*p))
            p++;
        if (memcmp(p, ";CVBASIC MARK DON'T CHANGE", 26) == 0) {  /* Location to replace */
            if (frame_drive != NULL) {
                fprintf(output, "\tCALL " LABEL_PREFIX "%s\n", frame_drive->name);
            }
        } else {
            fputs(line, output);
        }
    }
    fclose(prologue);
    bytes_used = 0;
    for (c = 0; c < HASH_PRIME; c++) {
        label = label_hash[c];
        while (label != NULL) {
            strcpy(temp, LABEL_PREFIX);
            strcat(temp, label->name);
            strcat(temp, ":\t");
            if (label->used & LABEL_IS_VARIABLE) {
                if ((label->used & MAIN_TYPE) == TYPE_8) {
                    strcat(temp, "rb 1");
                    bytes_used++;
                } else {
                    strcat(temp, "rb 2");
                    bytes_used += 2;
                }
                fprintf(output, "%s\n", temp);
            }
            label = label->next;
        }
    }
    for (c = 0; c < HASH_PRIME; c++) {
        label = array_hash[c];
        while (label != NULL) {
            if (label->name[0] == '#')
                size = 2;
            else
                size = 1;
            sprintf(temp, ARRAY_PREFIX "%s:\trb %d", label->name, label->length * size);
            fprintf(output, "%s\n", temp);
            bytes_used += label->length * size;
            label = label->next;
        }
    }
    fclose(output);
    fprintf(stderr, "%d RAM bytes used of %d bytes available.\n", bytes_used,
            1024 -  /* Total RAM memory */
            64 -    /* Stack requirements */
            145);   /* Support variables */
    fprintf(stderr, "Compilation finished.\n\n");
    exit(0);
}

