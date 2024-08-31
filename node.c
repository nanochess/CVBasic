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
#include "cpuz80.h"
#include "cpu6502.h"
#include "cpu9900.h"

/*
 ** Comparison of tree nodes.
 */
int node_same_tree(struct node *node1, struct node *node2)
{
    if (node1->type != node2->type)
        return 0;
    if (node1->value != node2->value)
        return 0;
    if (node1->label != node2->label)
        return 0;
    if (node1->left != NULL && node2->left != NULL) {
        if (node_same_tree(node1->left, node2->left) == 0)
            return 0;
    } else if (node1->left != NULL || node2->left != NULL) {
        return 0;
    }
    if (node1->right != NULL && node2->right != NULL) {
        if (node_same_tree(node1->right, node2->right) == 0)
            return 0;
    } else if (node1->right != NULL || node2->right != NULL) {
        return 0;
    }
    return 1;
}

/*
 ** Comparison of node addresses.
 **
 ** node1 is a read node.
 ** node2 is a write node (address).
 */
int node_same_address(struct node *node1, struct node *node2)
{
    if (node1->type == N_LOAD8) {
        if (node2->type != N_ADDR)
            return 0;
        if (node1->label != node2->label)
            return 0;
        return 1;
    }
    if (node1->type == N_LOAD16) {
        if (node2->type != N_ADDR)
            return 0;
        if (node1->label != node2->label)
            return 0;
        return 1;
    }
    if (node1->type == N_PEEK8) {
        node1 = node1->left;
    } else if (node1->type == N_PEEK16) {
        node1 = node1->left;
    } else {
        return 0;
    }
    return node_same_tree(node1, node2);
}

static char *node_types[] = {
    "N_OR8", "N_OR16",
    "N_XOR8", "N_XOR16",
    "N_AND8", "N_AND16",
    "N_EQUAL8", "N_EQUAL16", "N_NOTEQUAL8", "N_NOTEQUAL16",
    "N_LESS8", "N_LESS16", "N_LESSEQUAL8", "N_LESSEQUAL16",
    "N_GREATER8", "N_GREATER16", "N_GREATEREQUAL8", "N_GREATEREQUAL16",
    "N_LESS8S", "N_LESS16S", "N_LESSEQUAL8S", "N_LESSEQUAL16S",
    "N_GREATER8S", "N_GREATER16S", "N_GREATEREQUAL8S", "N_GREATEREQUAL16S",
    "N_PLUS8", "N_PLUS16", "N_MINUS8", "N_MINUS16",
    "N_MUL8", "N_MUL16", "N_DIV8", "N_DIV16", "N_DIV16S", "N_MOD16", "N_MOD16S",
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
int is_power_of_two(int value)
{
    if (value == 2 || value == 4 || value == 8 || value == 16
        || value == 32 || value == 64 || value == 128 || value == 256
        || value == 512 || value == 1024 || value == 2048 || value == 4096
        || value == 8192 || value == 16384 || value == 32768)
        return 1;
    return 0;
}

/*
 ** Check if a node is commutative
 */
int is_commutative(enum node_type type)
{
    if (type == N_PLUS8 || type == N_PLUS16
        || type == N_MUL8 || type == N_MUL16
        || type == N_OR8 || type == N_OR16
        || type == N_AND8 || type == N_AND16
        || type == N_XOR8 || type == N_XOR16
        || type == N_EQUAL8 || type == N_EQUAL16
        || type == N_NOTEQUAL8 || type == N_NOTEQUAL16)
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
    return (int) (32.0 / width + x * 64 / width) + 8;
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
#if 1
    {
        char *hex = "0123456789abcdef";
        
    *p++ = '(';
        *p++ = hex[tree->regs >> 4];
        *p++ = hex[tree->regs & 0x0f];
    *p++ = ')';
    }
#endif
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
            if ((left->type == N_PLUS16 ||
                 left->type == N_MINUS16 ||
                 left->type == N_AND16 ||
                 left->type == N_OR16 ||
                 left->type == N_XOR16 ||
                 (left->type == N_MUL16 && left->right->type == N_NUM16 &&
                  is_power_of_two(left->right->value & 0xff)) ||
                 (left->type == N_DIV16 && left->right->type == N_NUM16 &&
                  is_power_of_two(left->right->value & 0xff))) &&
                (left->left->type == N_EXTEND8 || left->left->type == N_EXTEND8S) && left->right->type == N_NUM16) {
                
                if (left->type == N_PLUS16)
                    left->type = N_PLUS8;
                else if (left->type == N_MINUS16)
                    left->type = N_MINUS8;
                else if (left->type == N_MUL16)
                    left->type = N_MUL8;
                else if (left->type == N_DIV16)
                    left->type = N_DIV8;
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
             **
             ** Division cannot be optimized to 8-bit because we don't know if there
             ** are extra precision bits.
             */
            if ((left->type == N_PLUS16 ||
                 left->type == N_MINUS16 ||
                 left->type == N_AND16 ||
                 left->type == N_OR16 ||
                 left->type == N_XOR16 ||
                 (left->type == N_MUL16 && left->right->type == N_NUM16 && is_power_of_two(left->right->value & 0xff))) &&
                (left->right->type == N_NUM16)) {
                
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
            
            /*
             ** Optimize a just expanded value
             */
            if (left->type == N_EXTEND8)
                return left->left;
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
    new_node->x = 0;
    new_node->regs = 0;
    return new_node;
}

/*
 ** Get the assembler label for the CVBasic label.
 ** parenthesis:
        1 - open and close ()
        2 - #
        3 - open only (
        4 - @
 */
void node_get_label(struct node *node, int parenthesis)
{
    temp[0] = '\0';
    if (parenthesis == 1 || parenthesis == 3)
        strcat(temp, "(");
    else if (parenthesis == 2)
        strcat(temp, "#");
    else if (parenthesis == 4)
        strcat(temp, "@");
    if (node->label->length) {
        strcat(temp, ARRAY_PREFIX);
    } else {
        strcat(temp, LABEL_PREFIX);
    }
    strcat(temp, node->label->name);
    if (parenthesis == 1)
        strcat(temp, ")");
}

/*
 ** Label register usage in tree
 **
 ** This should match exactly register usage in node_generate.
 */
void node_label(struct node *node)
{
    if (target == CPU_Z80)
        cpuz80_node_label(node);
    if (target == CPU_6502)
        cpu6502_node_label(node);
    if (target == CPU_9900)
        cpu9900_node_label(node);
}

/*
 ** Generate code for tree
 */
void node_generate(struct node *node, int decision)
{
    if (target == CPU_Z80)
        cpuz80_node_generate(node, decision);
    if (target == CPU_6502)
        cpu6502_node_generate(node, decision);
    if (target == CPU_9900)
        cpu9900_node_generate(node, decision);
}

/*
 ** Delete an expression node
 */
void node_delete(struct node *tree)
{
    if (tree == NULL)
        return;
    if (tree->left != NULL)
        node_delete(tree->left);
    if (tree->right != NULL)
        node_delete(tree->right);
    free(tree);
}


