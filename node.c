/*
 ** CVBasic - Create/handle/generate Z80 code for expression nodes
 **
 ** by Oscar Toledo G.
 **
 ** © Copyright 2024 Óscar Toledo G.
 ** https://nanochess.org/
 **
 ** Creation date: Jun/21/2024.
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "cvbasic.h"
#include "node.h"

extern int optimized;
extern char temp[];

char *node_types[] = {
    "N_OR8", "N_OR16",
    "N_XOR8", "N_XOR16",
    "N_AND8", "N_AND16",
    "N_EQUAL8", "N_EQUAL16", "N_NOTEQUAL8", "N_NOTEQUAL16",
    "N_LESS8", "N_LESS16", "N_LESSEQUAL8", "N_LESSEQUAL16",
    "N_GREATER8", "N_GREATER16", "N_GREATEREQUAL8", "N_GREATEREQUAL16",
    "N_LESS8S", "N_LESS16S", "N_LESSEQUAL8S", "N_LESSEQUAL16S",
    "N_GREATER8S", "N_GREATER16S", "N_GREATEREQUAL8S", "N_GREATEREQUAL16S",
    "N_PLUS8", "N_PLUS16", "N_MINUS8", "N_MINUS16",
    "N_MUL8", "N_MUL16", "N_DIV16", "N_DIV16S", "N_MOD16", "N_MOD16S",
    "N_NEG8", "N_NEG16", "N_NOT8", "N_NOT16",
    "N_EXTEND8", "N_EXTEND8S", "N_REDUCE16",
    "N_LOAD8", "N_LOAD16",
    "N_ASSIGN8", "N_ASSIGN16",
    "N_READ8", "N_READ16",
    "N_NUM8", "N_NUM16",
    "N_PEEK8", "N_PEEK16", "N_VPEEK", "N_INP", "N_ABS16", "N_SGN16",
    "N_JOY1", "N_JOY2", "N_KEY1", "N_KEY2",
    "N_RANDOM", "N_FRAME", "N_MUSIC", "N_NTSC", "N_POS",
    "N_ADDR",
    "N_USR",
};

/*
 ** Check if a number is a power of two
 */
static int is_power_of_two(int value)
{
    if (value == 2 || value == 4 || value == 8 || value == 16
        || value == 32 || value == 64 || value == 128 || value == 256
        || value == 512 || value == 1024 || value == 2048 || value == 4096
        || value == 8192 || value == 16384 || value == 32768)
        return 1;
    return 0;
}

/*
 ** Traverse a tree to measure it
 **
 ** This algorithm simply assigns horizontal space as needed.
 ** A better algorithm would center the top node and put subtrees at left and right.
 */
static void node_traverse(struct node *tree, int y, int *depth, int *width)
{
    if (tree->left != NULL && tree->right != NULL) {
        node_traverse(tree->left, y + 1, depth, width);
        tree->x = width[0]++;
        node_traverse(tree->right, y + 1, depth, width);
    } else if (tree->left != NULL) {
        node_traverse(tree->left, y + 1, depth, width);
        tree->x = tree->left->x;
    } else {
        tree->x = width[0]++;
    }
    if (y > *depth)
        *depth = y;
}

/*
 ** Get the column for a node
 */
static int node_column(int x, int width)
{
    return (32.0 / width + x * 64 / width) + 8;
}

/*
 ** Display a tree
 */
static void node_display(struct node *tree, int y, int max, char *report)
{
    int real_x;
    int real_y;
    int c;
    char *p;
    char *s;
    
    real_x = node_column(tree->x, max);
    real_y = y * 2;
    s = node_types[tree->type];
    p = report + real_y * 80 + real_x - (strlen(s) + 1) / 2;
    while (*s)
        *p++ = *s++;
    if (tree->left != NULL && tree->right != NULL) {
        c = (real_x + node_column(tree->left->x, max) + 1) / 2;
        report[(real_y + 1) * 80 + c] = '/';
        node_display(tree->left, y + 1, max, report);
        c = (real_x + node_column(tree->right->x, max) + 1) / 2;
        report[(real_y + 1) * 80 + c] = '\\';
        node_display(tree->right, y + 1, max, report);
    } else if (tree->left != NULL) {
        report[(real_y + 1) * 80 + real_x] = '|';
        node_display(tree->left, y + 1, max, report);
    }
}

/*
 ** Convert a node to a visual representation
 */
void node_visual(struct node *tree)
{
    int depth;
    char *report;
    int c;
    int width;
    int max;
    
    width = 0;
    depth = 0;
    node_traverse(tree, 0, &depth, &width);
    if (width < 12)
        width = 12;
    report = malloc((80 * (depth + 1) * 2 + 1) * sizeof(char));
    memset(&report[0], ' ', 80 * (depth + 1) * 2);
    report[80 * (depth + 1) * 2] = '\0';
    for (c = 0; c < (depth + 1) * 2; c++)
    report[79 + 80 * c] = '\n';
    node_display(tree, 0, width, report);
    fprintf(stderr, "%s", report);
}

/*
 ** Node creation.
 ** It also optimizes common patterns of expression node trees.
 */
struct node *node_create(enum node_type type, int value, struct node *left, struct node *right)
{
    struct node *new_node;
    struct node *extract;
    
    /*
     ** Convert signed operations to simpler operations
     ** This way no special code is needed in node_generate.
     */
    switch (type) {
        case N_LESS8S:
        case N_LESSEQUAL8S:
        case N_GREATER8S:
        case N_GREATEREQUAL8S:
            left = node_create(N_XOR8, 0, left, node_create(N_NUM8, 0x80, NULL, NULL));
            right = node_create(N_XOR8, 0, right, node_create(N_NUM8, 0x80, NULL, NULL));
            if (type == N_LESS8S)
                type = N_LESS8;
            else if (type == N_LESSEQUAL8S)
                type = N_LESSEQUAL8;
            else if (type == N_GREATER8S)
                type = N_GREATER8;
            else if (type == N_GREATEREQUAL8S)
                type = N_GREATEREQUAL8;
            break;
        case N_LESS16S:
        case N_LESSEQUAL16S:
        case N_GREATER16S:
        case N_GREATEREQUAL16S:
            left = node_create(N_XOR16, 0, left, node_create(N_NUM16, 0x8000, NULL, NULL));
            right = node_create(N_XOR16, 0, right, node_create(N_NUM16, 0x8000, NULL, NULL));
            if (type == N_LESS16S)
                type = N_LESS16;
            else if (type == N_LESSEQUAL16S)
                type = N_LESSEQUAL16;
            else if (type == N_GREATER16S)
                type = N_GREATER16;
            else if (type == N_GREATEREQUAL16S)
                type = N_GREATEREQUAL16;
            break;
        default:
            /* We are good :) */
            break;
    }
    
    /*
     ** Do constant optimization and optimize some trees.
     */
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
            if ((left->type == N_PLUS16 || left->type == N_MINUS16 || left->type == N_AND16 || left->type == N_OR16 || left->type == N_XOR16 || (left->type == N_MUL16 && left->right->type == N_NUM16 && is_power_of_two(left->right->value & 0xff))) && (left->left->type == N_EXTEND8 || left->left->type == N_EXTEND8S) && left->right->type == N_NUM16) {
                if (left->type == N_PLUS16)
                    left->type = N_PLUS8;
                else if (left->type == N_MINUS16)
                    left->type = N_MINUS8;
                else if (left->type == N_MUL16)
                    left->type = N_MUL8;
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
            
            /*
             ** Optimize expressions to avoid 16-bit operations when 8-bit are enough.
             */
            if ((left->type == N_PLUS16 || left->type == N_MINUS16 || left->type == N_AND16 || left->type == N_OR16 || left->type == N_XOR16 || (left->type == N_MUL16 && left->right->type == N_NUM16 && is_power_of_two(left->right->value & 0xff))) && (left->right->type == N_NUM16)) {
                
                if (left->type == N_PLUS16)
                    left->type = N_PLUS8;
                else if (left->type == N_MINUS16)
                    left->type = N_MINUS8;
                else if (left->type == N_MUL16)
                    left->type = N_MUL8;
                else if (left->type == N_AND16)
                    left->type = N_AND8;
                else if (left->type == N_OR16)
                    left->type = N_OR8;
                else if (left->type == N_XOR16)
                    left->type = N_XOR8;
                left->right->type = N_NUM8;
                left->right->value &= 0xff;
                
                /*
                 ** Move down the N_REDUCE16 calling node_create to
                 ** make recursive optimization.
                 */
                extract = left;
                type = left->type;
                right = left->right;
                left = node_create(N_REDUCE16, 0, left->left, NULL);
                value = 0;
                
                extract->left = NULL;
                extract->right = NULL;
                node_delete(extract);
            }
            
            /*
             ** Optimize a 16-bit variable read to a 8-bit variable read
             */
            if (left->type == N_LOAD16) {
                left->type = N_LOAD8;
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
        case N_EXTEND8S: /* Extend 8-bit signed expression to 16-bit */
            if (left->type == N_NUM8) {
                left->type = N_NUM16;
                left->value &= 255;
                if (left->value >= 128)
                    left->value |= 0xff00;
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
        case N_MUL16:   /* 16-bit multiplication */
            if (left->type == N_NUM16 && right->type == N_NUM16) {  /* Optimize constant case */
                left->value = (left->value * right->value) & 0xffff;
                node_delete(right);
                return left;
            }
            if (left->type == N_NUM16) {    /* Move constant to right */
                new_node = left;
                left = right;
                right = new_node;
            }
            if (right->type == N_NUM16 && right->value == 0) {  /* Nullify zero multiplication */
                node_delete(left);
                return right;
            }
            break;
        case N_DIV16:   /* 16-bit unsigned division */
            if (left->type == N_NUM16 && right->type == N_NUM16) {  /* Optimize constant case */
                left->value = left->value / right->value;
                node_delete(right);
                return left;
            }
            if (right->type == N_NUM16 && right->value == 1) {
                node_delete(right);
                return left;
            }
            break;
        case N_MOD16:   /* 16-bit unsigned modulo */
            if (left->type == N_NUM16 && right->type == N_NUM16) {  /* Optimize constant case */
                left->value = left->value % right->value;
                node_delete(right);
                return left;
            }
            if (right->type == N_NUM16) {   /* Optimize power of 2 constant case */
                if (is_power_of_two(right->value)) {
                    right->value--;
                    type = N_AND16;
                }
            }
            break;
        case N_EQUAL16:
        case N_NOTEQUAL16:
        case N_LESS16:
        case N_LESSEQUAL16:
        case N_GREATER16:
        case N_GREATEREQUAL16:
            if (left->type == N_EXTEND8 && right->type == N_NUM16 && (right->value & ~0xff) == 0) {
                extract = left;
                if (type == N_EQUAL16)
                    type = N_EQUAL8;
                else if (type == N_NOTEQUAL16)
                    type = N_NOTEQUAL8;
                else if (type == N_LESS16)
                    type = N_LESS8;
                else if (type == N_LESSEQUAL16)
                    type = N_LESSEQUAL8;
                else if (type == N_GREATER16)
                    type = N_GREATER8;
                else if (type == N_GREATEREQUAL16)
                    type = N_GREATEREQUAL8;
                left = left->left;
                right->type = N_NUM8;
                
                extract->left = NULL;
                node_delete(extract);
            }
            break;
        case N_PLUS16:  /* 16-bit addition */
            if (left->type == N_NUM16 && right->type == N_NUM16) {  /* Optimize constant case */
                left->value = (left->value + right->value) & 0xffff;
                node_delete(right);
                return left;
            }
            
            /*
             ** Collapse several additions/subtractions
             **
             **         N_PLUS16
             **           /  \
             **      N_PLUS16  N_NUM16
             **       /   \
             **          N_NUM16
             */
            if (left->type == N_PLUS16 && left->right->type == N_NUM16 && right->type == N_NUM16) {
                left->right->value = (left->right->value + right->value) & 0xffff;
                node_delete(right);
                return left;
            }
            if (left->type == N_MINUS16 && left->right->type == N_NUM16 && right->type == N_NUM16) {
                left->right->value = (left->right->value - right->value) & 0xffff;
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
            
            /*
             ** Collapse several additions/subtractions
             **
             **         N_MINUS16
             **           /  \
             **     N_MINUS16  N_NUM16
             **       /   \
             **          N_NUM16
             */
            if (left->type == N_PLUS16 && left->right->type == N_NUM16 && right->type == N_NUM16) {
                left->right->value = (left->right->value - right->value) & 0xffff;
                node_delete(right);
                return left;
            }
            if (left->type == N_MINUS16 && left->right->type == N_NUM16 && right->type == N_NUM16) {
                left->right->value = (left->right->value + right->value) & 0xffff;
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
                if ((right->value & 0xff00) == 0x0000 && left->type == N_EXTEND8) {
                    left->type = N_AND8;
                    right->type = N_NUM8;
                    left->right = right;
                    type = N_EXTEND8;
                    right = NULL;
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
                if ((right->value & 0xff00) == 0x0000 && left->type == N_EXTEND8) {
                    left->type = N_OR8;
                    right->type = N_NUM8;
                    left->right = right;
                    type = N_EXTEND8;
                    right = NULL;
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
                if ((right->value & 0xff00) == 0x0000 && left->type == N_EXTEND8) {
                    left->type = N_XOR8;
                    right->type = N_NUM8;
                    left->right = right;
                    type = N_EXTEND8;
                    right = NULL;
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
    
    /*
     ** Optimize difficult comparisons with constants to use simpler comparisons.
     */
    switch (type) {
        case N_LESSEQUAL8:  /* 8-bit <= */
            if (right->type == N_NUM8 && right->value < 255) {
                type = N_LESS8;
                right->value++;
            }
            break;
        case N_GREATER8:  /* 8-bit > */
            if (right->type == N_NUM8 && right->value < 255) {
                type = N_GREATEREQUAL8;
                right->value++;
            }
            break;
        case N_LESSEQUAL16:  /* 16-bit <= */
            if (right->type == N_NUM16 && right->value < 65535) {
                type = N_LESS16;
                right->value++;
            }
            break;
        case N_GREATER16:  /* 16-bit > */
            if (right->type == N_NUM16 && right->value < 65535) {
                type = N_GREATEREQUAL16;
                right->value++;
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

/*
 ** Get the assembler label for the CVBasic label.
 */
static void node_get_label(struct node *node, int parenthesis)
{
    temp[0] = '\0';
    if (parenthesis)
        strcat(temp, "(");
    if (node->label->length) {
        strcat(temp, ARRAY_PREFIX);
    } else {
        strcat(temp, LABEL_PREFIX);
    }
    strcat(temp, node->label->name);
    if (parenthesis)
        strcat(temp, ")");
}

/*
 ** Argument reg is not yet used, nor sorted evaluation order.
 */
void node_generate(struct node *node, int decision)
{
    struct label *label;
    struct node *explore;
    
    switch (node->type) {
        case N_USR:     /* Assembly language function with result */
            if (node->left != NULL)
                node_generate(node->left, 0);
            z80_1op("CALL", node->label->name);
            break;
        case N_ADDR:    /* Get address of variable */
            node_get_label(node, 0);
            z80_2op("LD", "HL", temp);
            break;
        case N_NEG8:    /* Negate 8-bit value */
            node_generate(node->left, 0);
            z80_noop("NEG");
            break;
        case N_NOT8:    /* Complement 8-bit value */
            node_generate(node->left, 0);
            z80_noop("CPL");
            break;
        case N_NEG16:   /* Negate 16-bit value */
            node_generate(node->left, 0);
            z80_2op("LD", "A", "H");
            z80_noop("CPL");
            z80_2op("LD", "H", "A");
            z80_2op("LD", "A", "L");
            z80_noop("CPL");
            z80_2op("LD", "L", "A");
            z80_1op("INC", "HL");
            break;
        case N_NOT16:   /* Complement 16-bit value */
            node_generate(node->left, 0);
            z80_2op("LD", "A", "H");
            z80_noop("CPL");
            z80_2op("LD", "H", "A");
            z80_2op("LD", "A", "L");
            z80_noop("CPL");
            z80_2op("LD", "L", "A");
            break;
        case N_ABS16:   /* Get absolute 16-bit value */
            node_generate(node->left, 0);
            z80_1op("CALL", "_abs16");
            break;
        case N_SGN16:   /* Get sign of 16-bit value */
            node_generate(node->left, 0);
            z80_1op("CALL", "_sgn16");
            break;
        case N_POS:     /* Get screen cursor position */
            z80_2op("LD", "HL", "(cursor)");
            break;
        case N_EXTEND8S:    /* Extend 8-bit signed value to 16-bit */
            node_generate(node->left, 0);
            z80_2op("LD", "L", "A");
            z80_noop("RLA");
            z80_2op("SBC", "A", "A");
            z80_2op("LD", "H", "A");
            break;
        case N_EXTEND8: /* Extend 8-bit value to 16-bit */
            if (node->left->type == N_LOAD8) {  /* Reading 8-bit variable */
                node->left->type = N_LOAD16;
                node_generate(node->left, 0);
                node->left->type = N_LOAD8;
                z80_2op("LD", "H", "0");
                break;
            }
            if (node->left->type == N_PEEK8) {    /* If reading 8-bit memory */
                if (node->left->left->type == N_ADDR
                    || ((node->left->left->type == N_PLUS16 || node->left->left->type == N_MINUS16) && node->left->left->left->type == N_ADDR && node->left->left->right->type == N_NUM16)) {   /* Is it variable? */
                    node->left->type = N_PEEK16;
                    node_generate(node->left, 0);
                    node->left->type = N_PEEK8;
                    z80_2op("LD", "H", "0");
                    break;
                } else {    /* Optimize to avoid LD A,(HL) / LD L,A */
                    node_generate(node->left->left, 0);
                    z80_2op("LD", "L", "(HL)");
                    z80_2op("LD", "H", "0");
                    break;
                }
            }
            node_generate(node->left, 0);
            z80_2op("LD", "L", "A");
            z80_2op("LD", "H", "0");
            break;
        case N_REDUCE16:    /* Reduce 16-bit value to 8-bit */
            node_generate(node->left, 0);
            z80_2op("LD", "A", "L");
            break;
        case N_READ8:   /* Read 8-bit value */
            z80_2op("LD", "HL", "(read_pointer)");
            z80_2op("LD", "A", "(HL)");
            z80_1op("INC", "HL");
            z80_2op("LD", "(read_pointer)", "HL");
            break;
        case N_READ16:  /* Read 16-bit value */
            z80_2op("LD", "HL", "(read_pointer)");
            z80_2op("LD", "E", "(HL)");
            z80_1op("INC", "HL");
            z80_2op("LD", "D", "(HL)");
            z80_1op("INC", "HL");
            z80_2op("LD", "(read_pointer)", "HL");
            z80_2op("EX", "DE", "HL");
            break;
        case N_LOAD8:   /* Load 8-bit value from address */
            strcpy(temp, "(" LABEL_PREFIX);
            strcat(temp, node->label->name);
            strcat(temp, ")");
            z80_2op("LD", "A", temp);
            break;
        case N_LOAD16:  /* Load 16-bit value from address */
            strcpy(temp, "(" LABEL_PREFIX);
            strcat(temp, node->label->name);
            strcat(temp, ")");
            z80_2op("LD", "HL", temp);
            break;
        case N_NUM8:    /* Load 8-bit constant */
            if (node->value == 0) {
                z80_1op("SUB", "A");
            } else {
                sprintf(temp, "%d", node->value);
                z80_2op("LD", "A", temp);
            }
            break;
        case N_NUM16:   /* Load 16-bit constant */
            sprintf(temp, "%d", node->value);
            z80_2op("LD", "HL", temp);
            break;
        case N_PEEK8:   /* Load 8-bit content */
            if (node->left->type == N_ADDR) {   /* Optimize address */
                node_get_label(node->left, 1);
                z80_2op("LD", "A", temp);
                break;
            }
            if ((node->left->type == N_PLUS16 || node->left->type == N_MINUS16)
                && node->left->left->type == N_ADDR
                && node->left->right->type == N_NUM16) {    /* Optimize address plus constant */
                char *p;
                
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
                z80_2op("LD", "A", temp);
                break;
            }
            node_generate(node->left, 0);
            z80_2op("LD", "A", "(HL)");
            break;
        case N_PEEK16:  /* Load 16-bit content */
            if (node->left->type == N_ADDR) {   /* Optimize address */
                node_get_label(node->left, 1);
                z80_2op("LD", "HL", temp);
                break;
            }
            if ((node->left->type == N_PLUS16 || node->left->type == N_MINUS16)
                && node->left->left->type == N_ADDR
                && node->left->right->type == N_NUM16) {    /* Optimize address plus constant */
                char *p;
                
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
                z80_2op("LD", "HL", temp);
                break;
            }
            node_generate(node->left, 0);
            z80_2op("LD", "A", "(HL)");
            z80_1op("INC", "HL");
            z80_2op("LD", "H", "(HL)");
            z80_2op("LD", "L", "A");
            break;
        case N_VPEEK:   /* Read VRAM */
            node_generate(node->left, 0);
            z80_1op("CALL", "nmi_off");
            z80_1op("CALL", "RDVRM");
            z80_1op("CALL", "nmi_on");
            break;
        case N_INP:     /* Read port */
            node_generate(node->left, 0);
            z80_2op("LD", "C", "L");
            z80_2op("IN", "A", "(C)");
            break;
        case N_JOY1:    /* Read joystick 1 */
            z80_2op("LD", "A", "(joy1_data)");
            break;
        case N_JOY2:    /* Read joystick 2 */
            z80_2op("LD", "A", "(joy2_data)");
            break;
        case N_KEY1:    /* Read keypad 1 */
            z80_2op("LD", "A", "(key1_data)");
            break;
        case N_KEY2:    /* Read keypad 2 */
            z80_2op("LD", "A", "(key2_data)");
            break;
        case N_RANDOM:  /* Read pseudorandom generator */
            z80_1op("CALL", "random");
            break;
        case N_FRAME:   /* Read current frame number */
            z80_2op("LD", "HL", "(frame)");
            break;
        case N_MUSIC:   /* Read music playing status */
            z80_2op("LD", "A", "(music_playing)");
            break;
        case N_NTSC:    /* Read NTSC flag */
            z80_2op("LD", "A", "(ntsc)");
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
            if (node->type == N_OR8 && node->left->type == N_JOY1 && node->right->type == N_JOY2) {
                z80_2op("LD", "HL", "(joy1_data)");
                z80_2op("LD", "A", "H");
                z80_1op("OR", "L");
                break;
            }
            if (node->type == N_AND8 && node->left->type == N_KEY1 && node->right->type == N_KEY2) {
                z80_2op("LD", "HL", "(key1_data)");
                z80_2op("LD", "A", "H");
                z80_1op("AND", "L");
                break;
            }
            if (node->type == N_MUL8 && node->right->type == N_NUM8 && is_power_of_two(node->right->value)) {
                int c;
                
                node_generate(node->left, 0);
                c = node->right->value;
                while (c > 1) {
                    z80_2op("ADD", "A", "A");
                    c /= 2;
                }
                break;
            }
            if (node->type == N_LESSEQUAL8 || node->type == N_GREATER8) {
                if (node->left->type == N_NUM8) {
                    node_generate(node->right, 0);
                    sprintf(temp, "%d", node->left->value & 0xff);
                } else {
                    node_generate(node->left, 0);
                    if (node->right->type == N_NUM8 || node->right->type == N_LOAD8
                        || node->right->type == N_JOY1 || node->right->type == N_JOY2
                        || node->right->type == N_KEY1 || node->right->type == N_KEY2
                        || node->right->type == N_NTSC || node->right->type == N_MUSIC) {
                        z80_2op("LD", "B", "A");
                        node_generate(node->right, 0);
                    } else {
                        z80_1op("PUSH", "AF");
                        node_generate(node->right, 0);
                        z80_1op("POP", "BC");
                    }
                    strcpy(temp, "B");
                }
            } else if (node->right->type == N_NUM8) {
                int c;
                
                c = node->right->value & 0xff;
                node_generate(node->left, 0);
                if (node->type == N_PLUS8 && c == 1 || node->type == N_MINUS8 && c == 255) {
                    z80_1op("INC", "A");
                    break;
                }
                if (node->type == N_PLUS8 && c == 255 || node->type == N_MINUS8 && c == 1) {
                    z80_1op("DEC", "A");
                    break;
                }
                sprintf(temp, "%d", c);
            } else {
                node_generate(node->right, 0);
                if (node->left->type == N_NUM8 || node->left->type == N_LOAD8
                    || node->left->type == N_JOY1 || node->left->type == N_JOY2
                    || node->left->type == N_KEY1 || node->left->type == N_KEY2
                    || node->left->type == N_NTSC || node->left->type == N_MUSIC) {
                    z80_2op("LD", "B", "A");
                    node_generate(node->left, 0);
                } else {
                    z80_1op("PUSH", "AF");
                    node_generate(node->left, 0);
                    z80_1op("POP", "BC");
                }
                strcpy(temp, "B");
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
                if (strcmp(temp, "0") == 0)
                    z80_1op("AND", "A");
                else
                    z80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "NZ", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "NZ", "$+3");
                    z80_1op("DEC", "A");
                    z80_empty();
                }
            } else if (node->type == N_NOTEQUAL8) {
                if (strcmp(temp, "0") == 0)
                    z80_1op("AND", "A");
                else
                    z80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "Z", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "Z", "$+3");
                    z80_1op("DEC", "A");
                    z80_empty();
                }
            } else if (node->type == N_LESS8) {
                if (strcmp(temp, "0") == 0)
                    z80_1op("AND", "A");
                else
                    z80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "NC", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "NC", "$+3");
                    z80_1op("DEC", "A");
                    z80_empty();
                }
            } else if (node->type == N_LESSEQUAL8) {
                if (strcmp(temp, "0") == 0)
                    z80_1op("AND", "A");
                else
                    z80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "C", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "C", "$+3");
                    z80_1op("DEC", "A");
                    z80_empty();
                }
            } else if (node->type == N_GREATER8) {
                if (strcmp(temp, "0") == 0)
                    z80_1op("AND", "A");
                else
                    z80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "NC", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "NC", "$+3");
                    z80_1op("DEC", "A");
                    z80_empty();
                }
            } else if (node->type == N_GREATEREQUAL8) {
                if (strcmp(temp, "0") == 0)
                    z80_1op("AND", "A");
                else
                    z80_1op("CP", temp);
                if (decision) {
                    optimized = 1;
                    sprintf(temp, INTERNAL_PREFIX "%d", decision);
                    z80_2op("JP", "C", temp);
                } else {
                    z80_2op("LD", "A", "0");
                    z80_2op("JR", "C", "$+3");
                    z80_1op("DEC", "A");
                    z80_empty();
                }
            } else if (node->type == N_PLUS8) {
                z80_2op("ADD", "A", temp);
            } else if (node->type == N_MINUS8) {
                z80_1op("SUB", temp);
            }
            break;
        case N_ASSIGN8: /* 8-bit assignment */
            if (node->right->type == N_ADDR) {
                node_generate(node->left, 0);
                node_get_label(node->right, 1);
                z80_2op("LD", temp, "A");
                break;
            }
            if ((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16) {
                char *p;
                
                node_generate(node->left, 0);
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
                z80_2op("LD", temp, "A");
                break;
            }
            node_generate(node->right, 0);
            if (node->left->type == N_NUM8) {
                sprintf(temp, "%d", node->left->value);
                z80_2op("LD", "(HL)", temp);
            } else {
                z80_1op("PUSH", "HL");
                node_generate(node->left, 0);
                z80_1op("POP", "HL");
                z80_2op("LD", "(HL)", "A");
            }
            break;
        case N_ASSIGN16:    /* 16-bit assignment */
            if (node->right->type == N_ADDR) {
                node_generate(node->left, 0);
                node_get_label(node->right, 1);
                z80_2op("LD", temp, "HL");
                break;
            }
            if ((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16) {
                char *p;
                
                node_generate(node->left, 0);
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
                z80_2op("LD", temp, "HL");
                break;
            }
            node_generate(node->right, 0);
            z80_1op("PUSH", "HL");
            node_generate(node->left, 0);
            z80_1op("POP", "DE");
            z80_2op("LD", "A", "L");
            z80_2op("LD", "(DE)", "A");
            z80_1op("INC", "DE");
            z80_2op("LD", "A", "H");
            z80_2op("LD", "(DE)", "A");
            break;
        default:    /* Every other node, all remaining are 16-bit operations */
            if (node->type == N_PLUS16 || node->type == N_MINUS16) {
                if (node->left->type == N_ADDR) {
                    if (node->right->type == N_NUM16) {
                        char *p;
                        
                        node_get_label(node->left, 0);
                        if (node->type == N_PLUS16)
                            strcat(temp, "+");
                        else
                            strcat(temp, "-");
                        p = temp;
                        while (*p)
                            p++;
                        sprintf(p, "%d", node->right->value);
                        z80_2op("LD", "HL", temp);
                        break;
                    }
                }
            }
            if (node->type == N_PLUS16) {
                if (node->left->type == N_ADDR) {
                    node_generate(node->right, 0);
                    node_get_label(node->left, 0);
                    z80_2op("LD", "DE", temp);
                    z80_2op("ADD", "HL", "DE");
                    break;
                }
                if (node->left->type == N_NUM16 || node->right->type == N_NUM16) {
                    int c;
                    int d;
                    
                    if (node->left->type == N_NUM16)
                        explore = node->left;
                    else
                        explore = node->right;
                    c = explore->value;
                    if (c == 0 || c == 1 || c == 2 || c == 3) {
                        if (node->left != explore)
                            node_generate(node->left, 0);
                        else
                            node_generate(node->right, 0);
                        while (c) {
                            z80_1op("INC", "HL");
                            c--;
                        }
                        break;
                    }
                    if (c == 0xffff || c == 0xfffe || c == 0xfffd) {
                        if (node->left != explore)
                            node_generate(node->left, 0);
                        else
                            node_generate(node->right, 0);
                        while (c < 0x10000) {
                            z80_1op("DEC", "HL");
                            c++;
                        }
                        break;
                    }
                    if (c == 0xfc00 || c == 0xfd00 || c == 0xfe00 || c == 0xff00 || c == 0x0100 || c == 0x0200 || c == 0x0300 || c == 0x0400) {            /* Only worth optimizing if using less than 5 instructions */
                        if (node->left != explore)
                            node_generate(node->left, 0);
                        else
                            node_generate(node->right, 0);
                        while (c) {
                            if (c & 0x8000) {
                                z80_1op("DEC", "H");
                                c += 0x0100;
                            } else {
                                z80_1op("INC", "H");
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
                    node_generate(node->left, 0);
                    node_get_label(node->right, 0);
                    z80_2op("LD", "DE", temp);
                    z80_1op("AND", "A");
                    z80_2op("SBC", "HL", "DE");
                    break;
                }
                if (node->right->type == N_NUM16)
                    explore = node->right;
                else
                    explore = NULL;
                if (explore != NULL && (explore->value == 0 || explore->value == 1 || explore->value == 2 || explore->value == 3)) {
                    int c = explore->value;
                    
                    node_generate(node->left, 0);
                    while (c) {
                        z80_1op("DEC", "HL");
                        c--;
                    }
                    break;
                }
                if (explore != NULL && (explore->value == 0xffff || explore->value == 0xfffe || explore->value == 0xfffd)) {
                    int c = explore->value;
                    
                    node_generate(node->left, 0);
                    while (c < 0x10000) {
                        z80_1op("INC", "HL");
                        c++;
                    }
                    break;
                }
                if (explore != NULL) {
                    node_generate(node->left, 0);
                    sprintf(temp, "%d", (0x10000 - explore->value) & 0xffff);
                    z80_2op("LD", "DE", temp);
                    z80_2op("ADD", "HL", "DE");
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
                        z80_2op("LD", "HL", "0");
                    } else {
                        if (node->left != explore)
                            node = node->left;
                        else
                            node = node->right;
                        if (c >= 256) {
                            if (node->type == N_EXTEND8 || node->type == N_EXTEND8S) {
                                node_generate(node->left, 0);
                                z80_2op("LD", "H", "A");
                                z80_2op("LD", "L", "0");
                            } else {
                                node_generate(node, 0);
                                z80_2op("LD", "H", "L");
                                z80_2op("LD", "L", "0");
                            }
                            c /= 256;
                        } else {
                            node_generate(node, 0);
                        }
                        while (c > 1) {
                            z80_2op("ADD", "HL", "HL");
                            c /= 2;
                        }
                    }
                    break;
                }
            }
            if (node->type == N_DIV16) {
                if (node->right->type == N_NUM16 && (node->right->value == 2 || node->right->value == 4 || node->right->value == 8)) {
                    int c;
                    
                    node_generate(node->left, 0);
                    c = node->right->value;
                    do {
                        z80_1op("SRL", "H");
                        z80_1op("RR", "L");
                        c /= 2;
                    } while (c > 1) ;
                    break;
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
            } else if ((node->type == N_EQUAL16 || node->type == N_NOTEQUAL16) && node->right->type == N_NUM16 && (node->right->value == 65535 || node->right->value == 0 || node->right->value == 1)) {
                node_generate(node->left, 0);
                if (node->right->value == 65535)
                    z80_1op("INC", "HL");
                else if (node->right->value == 1)
                    z80_1op("DEC", "HL");
                z80_2op("LD", "A", "H");
                z80_1op("OR", "L");
                if (node->type == N_EQUAL16) {
                    if (decision) {
                        optimized = 1;
                        sprintf(temp, INTERNAL_PREFIX "%d", decision);
                        z80_2op("JP", "NZ", temp);
                    } else {
                        z80_2op("LD", "A", "0");
                        z80_2op("JR", "NZ", "$+3");
                        z80_1op("DEC", "A");
                        z80_empty();
                    }
                } else if (node->type == N_NOTEQUAL16) {
                    if (decision) {
                        optimized = 1;
                        sprintf(temp, INTERNAL_PREFIX "%d", decision);
                        z80_2op("JP", "Z", temp);
                    } else {
                        z80_2op("LD", "A", "0");
                        z80_2op("JR", "Z", "$+3");
                        z80_1op("DEC", "A");
                        z80_empty();
                    }
                }
                break;
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
                } else if (node->left->type == N_LOAD16 || node->left->type == N_NUM16) {
                    node_generate(node->right, 0);
                    z80_2op("EX", "DE", "HL");
                    node_generate(node->left, 0);
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
                    z80_empty();
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
                    z80_empty();
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
                    z80_empty();
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
                    z80_empty();
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
                    z80_empty();
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
                    z80_empty();
                }
            } else if (node->type == N_PLUS16) {
                z80_2op("ADD", "HL", "DE");
            } else if (node->type == N_MINUS16) {
                z80_1op("OR", "A");
                z80_2op("SBC", "HL", "DE");
            } else if (node->type == N_MUL16) {
                z80_1op("CALL", "_mul16");
            } else if (node->type == N_DIV16) {
                z80_1op("CALL", "_div16");
            } else if (node->type == N_MOD16) {
                z80_1op("CALL", "_mod16");
            } else if (node->type == N_DIV16S) {
                z80_1op("CALL", "_div16s");
            } else if (node->type == N_MOD16S) {
                z80_1op("CALL", "_mod16s");
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


