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

static char cpu9900_line[MAX_LINE_SIZE] = "";
static char cpu9900_lastline[MAX_LINE_SIZE] = "";

static void cpu9900_emit_line(void);
static int getargument(char *src, char *dest, int start);

// parse a string to extract one assembly argument
int getargument(char *src, char *dest, int start) {
    static int idx = 0;
    char *p = src;
    
    src += start;
    
    if (strlen(src) > 127) {
        // make sure it never matches
        sprintf(dest,"nomatch%d", ++idx);
        return 0;
    }
    
    while (*src == ' ') ++src;
    
    while ((*src > ' ')&&(*src <= 'z')&&(*src != ',')) {
        *(dest++) = *(src++);
    }
    *dest = '\0';
    
    return src-p+1;
}

// Final emit phase. Some peephole optimizations can be placed here
// The Z80 code maintains three lines in order to be able to do this.
void cpu9900_emit_line(void)
{
    // xdt99 doesn't like '#' in labels, it has meaning, so map it to _
    char buf[MAX_LINE_SIZE];
    strncpy(buf, cpu9900_line, MAX_LINE_SIZE);
    buf[MAX_LINE_SIZE-1]='\0';
    char *p = buf;
    while (p != NULL) {
        p = strchr(p, '#');
        if (NULL != p) {
            *p = '_';
        }
    }
    
    // there's some simple things we can check for (is this too strict? Can improve later)
    // it's a little too focused on the exact formatting, we should add some parsing
    // to make it more resiliant.
    
    // Replace immediate operations for 0, 1 or 2
    if (0 == strcmp(buf, "\tli r0,0\n")) {
        strcpy(buf, "\tclr r0\n");
    } else if (0 == strcmp(buf,"\tai r0,0\n")) {
        strcpy(buf, "\t;ai r0,0\n");
    } else if (0 == strcmp(buf,"\tai r0,1\n")) {
        strcpy(buf, "\tinc r0\n");
    } else if (0 == strcmp(buf,"\tai r0,2\n")) {
        strcpy(buf, "\tinct r0\n");
    } else if (0 == strcmp(buf,"\tai r0,-1\n")) {
        strcpy(buf, "\tdec r0\n");
    } else if (0 == strcmp(buf,"\tai r0,-2\n")) {
        strcpy(buf, "\tdect r0\n");
    }
    
    // remove second half of mov a,b / mov b,a, which happens a lot
    // all bets are off if there is a label, but try to catch comments
    if ((buf[0] != ';')&&(buf[1] != ';')) {
        // are they both movs?
        if ((0 == strncmp(buf, "\tmov", 4)) && (0 == strncmp(cpu9900_lastline, "\tmov", 4))) {
            // yes, are they both the same size?
            if (buf[4] == cpu9900_lastline[4]) {
                // yes. see if they are using the same source and dest (in either order)
                char s1[128],s2[128],s3[128],s4[128];
                int p = getargument(buf, s1, 5);
                getargument(buf, s2, p);
                p = getargument(cpu9900_lastline, s3, 5);
                getargument(cpu9900_lastline, s4, p);
                //printf("%s,%s -> %s,%s\n", s1, s2, s3, s4);
                if (
                    ((0 == strcmp(s1,s3)) || (0 == strcmp(s1, s4))) &&
                    ((0 == strcmp(s2,s3)) || (0 == strcmp(s2, s4)))
                   ) {
                       // drop this one - won't have formatting but that's okay
                       int n = strlen(cpu9900_line)-1;
                       cpu9900_line[n] = '\0';   // remove trailing \n
                       sprintf(buf, "\t;%s\n", &cpu9900_line[2]);
                }
            }
        }
        strcpy(cpu9900_lastline, buf);
    }
    
    fprintf(output, "%s", buf);
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
                    cpu9900_noop("; Unclear code - N_LESSEQUAL8 || N_GREATER8 left=N_NUM8");
                    cpu9900_node_generate(node->right, 0);
                    sprintf(temp,"%d",(node->left->value&0xff)*256);
                    cpu9900_2op("li","r1",temp);
                    strcpy(temp, "r1");
                } else {
                    cpu9900_noop("; Unclear code - N_LESSEQUAL8 || N_GREATER8 left!=N_NUM8");
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
                c = node->right->value & 0xff;
                cpu9900_node_generate(node->left, 0);
                sprintf(temp, "%d", c*256);
            } else {
                cpu9900_noop("; Unclear code - node->right->type != N_NUM8 - check if reverse okay");
                // again, why this order? TODO: can we just reverse the node_generate order?
                cpu9900_node_generate(node->left, 0);
                cpu9900_2op("mov","r0","r2");
                cpu9900_node_generate(node->right, 0);
                cpu9900_2op("mov","r0","r1");
                cpu9900_2op("mov","r2","r0");
                strcpy(temp, "r1");
            }
            if (node->type == N_OR8) {
                // if temp is a number, use ORI, else use SOCB
                if ((temp[0]>='0')&&(temp[0]<='9')) {
                    // todo: but is it already a byte value?
                    cpu9900_noop("; TODO: check the next line is a byte value");
                    cpu9900_2op("ori","r0",temp);
                } else {
                    cpu9900_2op("socb",temp,"r0");
                }
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_XOR8) {
                cpu9900_2op("xor", temp, "r0");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_AND8) {
                // if temp is a number, use ANDI, else use INV,SZCB
                if ((temp[0]>='0')&&(temp[0]<='9')) {
                    // todo: but is it already a byte value?
                    cpu9900_noop("; TODO: check the next line is a byte value");
                    cpu9900_2op("andi","r0",temp);
                } else {
                    cpu9900_1op("inv","r0");
                    cpu9900_2op("szcb",temp,"r0");
                }
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_EQUAL8) {
                cpu9900_2op("andi","r0",">ff00");
                // if temp is a number, use CI, else use CB
                if ((temp[0]>='0')&&(temp[0]<='9')) {
                    cpu9900_2op("ci","r0",temp);
                } else {
                    cpu9900_2op("cb",temp,"r0");
                }
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jeq", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("beq", temp);
                    cpu9900_1op("clr", "r0");
                    cpu9900_1op("jmp", "$+4");
                    cpu9900_label(temp);
                    cpu9900_1op("seto", "r0");
                    cpu9900_empty();
                }
            } else if (node->type == N_NOTEQUAL8) {
                cpu9900_2op("andi","r0",">ff00");
                // if temp is a number, use CI, else use CB
                if ((temp[0]>='0')&&(temp[0]<='9')) {
                    cpu9900_2op("ci","r0",temp);
                } else {
                    cpu9900_2op("cb",temp,"r0");
                }
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp);
                    cpu9900_1op("clr", "r0");
                    cpu9900_1op("jmp", "$+4");
                    cpu9900_label(temp);
                    cpu9900_1op("seto", "r0");
                    cpu9900_empty();
                }
            } else if (node->type == N_LESS8) {
                cpu9900_2op("andi","r0",">ff00");
                // if temp is a number, use CI, else use CB
                if ((temp[0]>='0')&&(temp[0]<='9')) {
                    cpu9900_2op("ci","r0",temp);
                } else {
                    cpu9900_noop("; TODO: check the next line compare order");
                    cpu9900_2op("cb",temp,"r0");
                }
                if (decision) {
                    // TODO: unsigned??
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jl", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jl", temp);
                    cpu9900_1op("clr", "r0");
                    cpu9900_1op("jmp", "$+4");
                    cpu9900_label(temp);
                    cpu9900_1op("seto", "r0");
                    cpu9900_empty();
                }
            } else if (node->type == N_LESSEQUAL8) {
                cpu9900_2op("andi","r0",">ff00");
                // if temp is a number, use CI, else use CB
                if ((temp[0]>='0')&&(temp[0]<='9')) {
                    cpu9900_2op("ci","r0",temp);
                } else {
                    cpu9900_noop("; TODO: check the next line compare order");
                    cpu9900_2op("cb",temp,"r0");
                }
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jhe", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jhe", temp);
                    cpu9900_1op("clr", "r0");
                    cpu9900_1op("jmp", "$+4");
                    cpu9900_label(temp);
                    cpu9900_1op("seto", "r0");
                    cpu9900_empty();
                }
            } else if (node->type == N_GREATER8) {
                cpu9900_2op("andi","r0",">ff00");
                // if temp is a number, use CI, else use CB
                if ((temp[0]>='0')&&(temp[0]<='9')) {
                    cpu9900_2op("ci","r0",temp);
                } else {
                    cpu9900_noop("; TODO: check the next line compare order");
                    cpu9900_2op("cb",temp,"r0");
                }
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jl", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jl", temp);
                    cpu9900_1op("clr", "r0");
                    cpu9900_1op("jmp", "$+4");
                    cpu9900_label(temp);
                    cpu9900_1op("seto", "r0");
                    cpu9900_empty();
                }
            } else if (node->type == N_GREATEREQUAL8) {
                cpu9900_2op("andi","r0",">ff00");
                // if temp is a number, use CI, else use CB
                if ((temp[0]>='0')&&(temp[0]<='9')) {
                    cpu9900_2op("ci","r0",temp);
                } else {
                    cpu9900_noop("; TODO: check the next line compare order");
                    cpu9900_2op("cb",temp,"r0");
                }
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jhe", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jhe", temp);
                    cpu9900_1op("clr", "r0");
                    cpu9900_1op("jmp", "$+4");
                    cpu9900_label(temp);
                    cpu9900_1op("seto", "r0");
                    cpu9900_empty();
                }
            } else if (node->type == N_PLUS8) {
                // if temp is a number, use AI, else use AB
                if ((temp[0]>='0')&&(temp[0]<='9')) {
                    cpu9900_2op("ai","r0",temp);
                } else {
                    cpu9900_2op("ab",temp,"r0");
                }
            } else if (node->type == N_MINUS8) {
                // if temp is a number, use AI -x, else use SB
                if ((temp[0]>='0')&&(temp[0]<='9')) {
                    // todo: but is it already a byte value?
                    cpu9900_noop("; TODO: check the next line is a byte value");
                    memmove(&temp[1],&temp[0],strlen(temp)+1);
                    temp[0]='-';
                    cpu9900_2op("ai","r0",temp);
                    memmove(&temp[0],&temp[1],strlen(temp));
                } else {
                    cpu9900_2op("sb",temp,"r0");
                }
            }
            break;
        case N_ASSIGN8: /* 8-bit assignment */
            if (node->right->type == N_ADDR) {
                cpu9900_node_generate(node->left, 0);
                node_get_label(node->right, ADDRESS);
                cpu9900_2op("movb", "r0", temp);
                break;
            }
            if ((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16) {
                char *p;
                
                cpu9900_node_generate(node->left, 0);
                node_get_label(node->right->left, ADDRESS);
                p = temp;
                while (*p)
                    p++;
                if (node->right->type == N_PLUS16)
                    *p++ = '+';
                else
                    *p++ = '-';
                sprintf(p, "%d", node->right->right->value);
                cpu9900_2op("movb", "r0", temp);
                break;
            }
            cpu9900_node_generate(node->left, 0);
            cpu9900_2op("movb","r0","r1");
            cpu9900_node_generate(node->right, 0);
            cpu9900_2op("movb", "r1", "*r0");
            break;
        case N_ASSIGN16:    /* 16-bit assignment */
            if (node->right->type == N_ADDR) {
                cpu9900_node_generate(node->left, 0);
                node_get_label(node->right, ADDRESS);
                cpu9900_2op("mov","r0",temp);
                break;
            }
            if ((node->right->type == N_PLUS16 || node->right->type == N_MINUS16) && node->right->left->type == N_ADDR && node->right->right->type == N_NUM16) {
                char *p;
                
                cpu9900_node_generate(node->left, 0);
                node_get_label(node->right->left, ADDRESS);
                p = temp;
                while (*p)
                    p++;
                if (node->right->type == N_PLUS16)
                    *p++ = '+';
                else
                    *p++ = '-';
                sprintf(p, "%d", node->right->right->value);
                cpu9900_2op("mov","r0",temp);
                break;
            }
            cpu9900_node_generate(node->left, 0);
            cpu9900_2op("mov","r0","r1");
            cpu9900_node_generate(node->right, 0);
            cpu9900_2op("mov","r1","*r0");
            break;
        default:    /* Every other node, all remaining are 16-bit operations */
            /* Optimization of address plus/minus constant */
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
                        cpu9900_2op("mov", "r0", temp);
                        break;
                    }
                }
            }
            if (node->type == N_PLUS16) {
                if (node->left->type == N_ADDR) {
                    cpu9900_node_generate(node->right, 0);
                    node_get_label(node->left, 0);
                    cpu9900_2op("ai","r0",temp);
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
                    sprintf(temp, "%d", c);
                    cpu9900_2op("ai","r0",temp);
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
                    sprintf(temp, "-%d", c);
                    cpu9900_2op("ai","r0",temp);
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
                    char *mnemonic;
                    
                    // TODO: we probably need to differentiate immediates...?
                    if (node->type == N_OR16) {
                        mnemonic = "ori";
                    } else if (node->type == N_AND16) {
                        mnemonic = "andi";
                    } else /*if (node->type == N_XOR16)*/ {
                        mnemonic = "xor";
                    }
                    if (node->left != explore)
                        cpu9900_node_generate(node->left, 0);
                    else
                        cpu9900_node_generate(node->right, 0);
                    if ((node->type == N_OR16 || node->type == N_XOR16) && value == 0x00) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && value == 0xffff) {
                        /* Nothing to do :) */
                    } else if (node->type == N_AND16 && value == 0x0000) {
                        cpu9900_1op("clr", "r0");
                    } else if (node->type == N_OR16 && value == 0xffff) {
                        cpu9900_1op("seto", "r0");
                    } else {
                        sprintf(temp, "%d", value);
                        if (node->type == N_XOR16) {
                            // there's no immediate xor
                            cpu9900_2op("li","r1",temp);
                            cpu9900_2op("xor","r1","r0");
                        } else {
                            cpu9900_2op(mnemonic, "r0", temp);
                        }
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
                    if (node->left != explore)
                        node = node->left;
                    else
                        node = node->right;
                    
                    if (c == 0) {
                        cpu9900_1op("clr", "r0");
                    } else if (c == 1) {
                        // nothing to do
                    } else {
                        cpu9900_node_generate(node, 0);
                        int cnt = 0;
                        while (c>1) {
                            ++cnt;
                            c/=2;
                        }
                        sprintf(temp,"%d",cnt);
                        cpu9900_2op("sla","r0",temp);
                    }
                    break;
                }
            }
            if (node->type == N_DIV16) {
                if (node->right->type == N_NUM16 && (node->right->value == 2 || node->right->value == 4 || node->right->value == 8)) {
                    int c;
                    
                    cpu9900_node_generate(node->left, 0);
                    c = node->right->value;
                    int cnt = 0;
                    while (c>1) {
                        ++cnt;
                        c/=2;
                    }
                    sprintf(temp,"%d",cnt);
                    cpu9900_2op("srl","r0",temp);
                    break;
                }
            }
            if (node->type == N_LESSEQUAL16 || node->type == N_GREATER16) {
                cpu9900_node_generate(node->right, 0);
                cpu9900_2op("mov","r0","r1");           // stack
                cpu9900_node_generate(node->left, 0);   
                cpu9900_2op("mov","r0","r2");           // temp
            } else {
                cpu9900_node_generate(node->left, 0);
                cpu9900_2op("mov","r0","r1");           // stack
                cpu9900_node_generate(node->right, 0);
                cpu9900_2op("mov","r0","r2");           // temp
            }
            if (node->type == N_OR16) {
                cpu9900_2op("soc","r2","r1");
                cpu9900_2op("mov","r1","r0");   // normalize and test for zero
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_XOR16) {
                cpu9900_2op("xor","r2","r1");
                cpu9900_2op("mov","r1","r0");   // normalize and test for zero
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_AND16) {
                cpu9900_1op("inv","r2");
                cpu9900_2op("szc","r2","r1");
                cpu9900_2op("mov","r1","r0");   // normalize and test for zero
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_EQUAL16) {
                cpu9900_2op("c","r2","r1");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jeq", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jeq", temp);
                    cpu9900_1op("clr", "r0");
                    cpu9900_1op("jmp", "$+4");
                    cpu9900_label(temp);
                    cpu9900_1op("seto", "r0");
                    cpu9900_empty();
                }
            } else if (node->type == N_NOTEQUAL16) {
                cpu9900_2op("c","r2","r1");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp);
                    cpu9900_1op("clr", "r0");
                    cpu9900_1op("jmp", "$+4");
                    cpu9900_label(temp);
                    cpu9900_1op("seto", "r0");
                    cpu9900_empty();
                }
            } else if (node->type == N_LESS16 || node->type == N_GREATER16) {
                cpu9900_2op("c","r1","r2");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jl", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jl", temp);
                    cpu9900_1op("clr", "r0");
                    cpu9900_1op("jmp", "$+4");
                    cpu9900_label(temp);
                    cpu9900_1op("seto", "r0");
                    cpu9900_empty();
                }
            } else if (node->type == N_LESSEQUAL16 || node->type == N_GREATEREQUAL16) {
                cpu9900_2op("c","r1","r2");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jhe", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jhe", temp);
                    cpu9900_1op("clr", "r0");
                    cpu9900_1op("jmp", "$+4");
                    cpu9900_label(temp);
                    cpu9900_1op("seto", "r0");
                    cpu9900_empty();
                }
            } else if (node->type == N_PLUS16) {
                // TODO: wonder if we can optimize add 2 and add 1 to register? (inc, inct)
                cpu9900_2op("a","r2","r1");
                cpu9900_2op("mov","r1","r0");
            } else if (node->type == N_MINUS16) {
                // TODO: wonder if we can optimize minus 2 and minus 1 to register? (dec, dect)
                cpu9900_noop("; TODO: check order of subtraction");
                cpu9900_2op("s","r2","r1");
                cpu9900_2op("mov","r1","r0");
            } else if (node->type == N_MUL16) {
                cpu9900_2op("mpy","r1","r2");   // r1 * r2 => r2_r3 (32 bit)
                cpu9900_2op("mov","r3","r0");
            } else if (node->type == N_DIV16) {
                cpu9900_noop("; TODO: check order of division - assume r1/r2");
                cpu9900_1op("clr","r0");
                cpu9900_2op("div","r2","r0");   // r0_r1 / r2 => r0, rem r1
            } else if (node->type == N_MOD16) {
                cpu9900_noop("; TODO: check order of mod - assume r1%r2");
                cpu9900_1op("clr","r0");
                cpu9900_2op("div","r2","r0");   // r0_r1 / r2 => r0, rem r1
                cpu9900_2op("mov","r1","r0");   // get remainder
            } else if (node->type == N_DIV16S) {
                cpu9900_noop("; TODO: check order of division - assume r1/r2");
                cpu9900_1op("bl","@JSR");
                cpu9900_1op("data", "_div16s");
            } else if (node->type == N_MOD16S) {
                cpu9900_noop("; TODO: check order of mod - assume r1%r2");
                cpu9900_1op("bl","@JSR");
                cpu9900_1op("data", "_mod16s");
            }
            break;
    }
}
