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

/*
 ** Constant for node_get_label to give us labels with '@' prefix
 */
#define ADDRESS 4

/*
 ** If enabled, replaced code from emit_line will be commented out in the assembler output
 */
/*#define DEBUGPEEP*/

/*
 ** Some tracking for peepholes
 */
static char cpu9900_line[MAX_LINE_SIZE] = "";
static char cpu9900_lastline[MAX_LINE_SIZE] = "";
static char cpu9900_lastline2[MAX_LINE_SIZE] = "";
static char cpu9900_lastline3[MAX_LINE_SIZE] = "";
static char cpu9900_lastline4[MAX_LINE_SIZE] = "";
static char last_r0_load[MAX_LINE_SIZE] = "";
static size_t pushpos = 0;
static size_t loadr0pos = 0;
static size_t lastclr = 0;
static size_t movtor0 = 0;
static char op1[128], op2[128], op3[128], op4[128];
static char s1[128], s2[128], s3[128], s4[128], s5[128], s6[128], s7[128], s8[128];

static void cpu9900_emit_line(void);
static int getargument(char *src, char *dest, int start);

// set to a unique string that will never match
void nomatch(char *src)
{
    static int nomatch = 0;
    
    sprintf(src,"nomatch%d", ++nomatch);
}

// parse a string to extract one assembly argument
int getargument(char *src, char *dest, int start)
{
    char *p = src;
    
    src += start;
    
    if (strlen(src) > 127) {
        nomatch(dest);
        return 0;
    }
    
    while (*src != '\0' && *src <= ' ')
        ++src;
    
    while (*src > ' ' && *src <= 'z' && *src != ',')
        *dest++ = *src++;
    
    *dest = '\0';
    
    return src - p;
}

/*
 ** Returns the character AFTER the comma
 */
int skipcomma(char *src, int start)
{
    char *p = src;
    
    src += start;
    while (*src != '\0' && *src != ',')
        ++src;
    if (*src == ',')
        ++src; /* skip past */
    return src - p;
}

/*
 ** Break up a string into opcode, arg1, arg2.
 ** Do not pass comments to this function.
 */
void parseline(char *buf, char *op, char *s1, char *s2)
{
    int p = 0;
    
    while (buf[p] != '\0' && buf[p] <= ' ')
        ++p;
    
    if (buf[p] == ';' || buf[p]=='*' || buf[p] == '\0') {
        /* Comment line */
        nomatch(op);
        nomatch(s1);
        nomatch(s2);
    } else if (buf[0] > ' ') {
        /*
         ** label - we don't generate lines with both label and opcode
         ** but we'll copy the label so it looks like an opcode
         */
        getargument(buf, op, p);
        nomatch(s1);
        nomatch(s2);
    } else {
        p = getargument(buf, op, p);    /* get opcode */
        p = getargument(buf, s1, p);    /* first arg */
        p = skipcomma(buf, p);
        p = getargument(buf, s2, p);    /* second arg */
    }
}

/*
 ** Return true if a load loads r0
 */
int loadsr0(char *op, char *s1, char *s2)
{
    if ( ((0 == strcmp(op,"li")) && (0 == strcmp(s1,"r0"))) ||
         ((0 == strncmp(op,"mov",3)) && (0 == strcmp(s2,"r0"))) ||
         ((0 == strcmp(op,"clr")) && (0 == strcmp(s1,"r0"))) ||
         ((0 == strcmp(op,"seto")) && (0 == strcmp(s1,"r0"))) ) {
         return 1;
    } else {
        return 0;
    }
}

// Final emit phase. Some peephole optimizations can be placed here
// TODO: the roll-back and rewrite approach this uses can cause
// BASIC source lines to be discarded in the assembly output. No
// practical effect but could be occasionally annoying.
void cpu9900_emit_line(void)
{
    // xdt99 doesn't like '#' in labels, it has meaning, so map it to _
    char buf[MAX_LINE_SIZE];
    char *p = buf;

    strncpy(buf, cpu9900_line, MAX_LINE_SIZE);
    buf[MAX_LINE_SIZE-1]='\0';
    while (p != NULL) {
        p = strchr(p, '#');
        if (NULL != p) {
            *p = '_';
        }
    }

    // We check both 0 and 1 because some lines are "; comment" and some are "\t; comment"
    if ((buf[0] != ';')&&(buf[1] != ';')) {
        parseline(buf, op1, s1, s2);
        parseline(cpu9900_lastline, op2, s3, s4);
        parseline(cpu9900_lastline2, op3, s5, s6);
        parseline(cpu9900_lastline3, op4, s7, s8);
        // note: lastline4 is only for recovery from a stack pop, we don't need to parse it
        
        // there's some simple things we can check for
        
        // Replace immediate operations for select cases
        if ((0 == strcmp(op1,"li")) && (s1[0] == 'r') && (0 == strcmp(s2,"0"))) {
            sprintf(buf, "\tclr %s\n", s1);
            fflush(output);
            lastclr = ftell(output);
        } else if ((0 == strcmp(op1,"ai")) && (0 == strcmp(s1,"r0")) && (0 == strcmp(s2,"0"))) {
#ifdef DEBUGPEEP
            fprintf(output, "\t;PEEP: don't add zero\n");
            fprintf(output, "\t;ai r0,0\n");    // doesn't count as a line anymore
#endif
            return;
        } else if ((0 == strcmp(op1,"ai")) && (0 == strcmp(s1,"r0")) && (0 == strcmp(s2,"1"))) {
            strcpy(buf, "\tinc r0\n");
        } else if ((0 == strcmp(op1,"ai")) && (0 == strcmp(s1,"r0")) && (0 == strcmp(s2,"2"))) {
            strcpy(buf, "\tinct r0\n");
        } else if ((0 == strcmp(op1,"ai")) && (0 == strcmp(s1,"r0")) && (0 == strcmp(s2,"-1"))) {
            strcpy(buf, "\tdec r0\n");
        } else if ((0 == strcmp(op1,"ai")) && (0 == strcmp(s1,"r0")) && (0 == strcmp(s2,"-2"))) {
            strcpy(buf, "\tdect r0\n");
        }
    
        // remove second half of mov a,b / mov b,a, which happens a lot
        // all bets are off if there is a label, but try to catch comments
        // are last two both movs?
        if ((0 == strncmp(op1, "mov", 3)) && (0 == strncmp(op2, "mov", 3))) {
            // yes, are they both the same size?
            if (op1[3] == op2[3]) {
                // yes. see if they are using the same source and dest (in either order)
                if (
                    ((0 == strcmp(s1,s3)) || (0 == strcmp(s1, s4))) &&
                    ((0 == strcmp(s2,s3)) || (0 == strcmp(s2, s4)))
                   ) {
#ifdef DEBUGPEEP                   
                   // drop this one
                   fprintf(output, "\t;PEEP: skip second step of mov a,b / mov b,a\n");
                   fprintf(output, "\t;%s", &buf[2]);
#endif 
                   return;
                }
            }
        }
        
        // check for mov[b] xxx,r0 / clr r1 / c[b] r1,r0 - the mov[b] is enough
        if ((0 == strncmp(op3,"mov",3)) && (0 == strcmp(op2,"clr")) && (op1[0] == 'c')
           && (0 == strcmp(s2,s6)) && (0 == strcmp(s1,s3)) && (op3[3] == op1[1])) {
            // all three opcodes match, the registers compared match, and byte/word matches
            // We can drop the clr and compare
            fseek(output, lastclr, SEEK_SET);
#ifdef DEBUGPEEP
            fprintf(output, "\t;PEEP: skip clr and compare for zero test after move\n");
            fprintf(output, "\t;%s %s\n",op2,s3);
            fprintf(output, "\t;%s %s,%s\n",op1,s1,s2);
#endif
            // remove one line from history
            strcpy(cpu9900_lastline, cpu9900_lastline2);
            strcpy(cpu9900_lastline2, cpu9900_lastline3);
            strcpy(cpu9900_lastline3, cpu9900_lastline4);
            strcpy(cpu9900_lastline4, "");
            return;
        }
        
        // look for push/pop - happens sometimes, mostly around immediates due to the
        // simplified process handling I coded. But it's an easy fix. We remember where
        // we saw the dect r10 which might indicate the start of the sequence. If it completes,
        // we back up and rewrite those lines as comments to show what we removed
        // We have both r1 and r0 sequences
        if ((0 == strcmp(op1,"dect")) && (0 == strcmp(s1,"r10"))) {
            fflush(output);
            pushpos = ftell(output);
        } else if ( ((0 == strcmp(op3,"dect")) && (0 == strcmp(s5,"r10"))) && 
                    ((0 == strcmp(op2,"mov")) && (0 == strcmp(s3,"r1")) && (0 == strcmp(s4,"*r10"))) &&
                    ((0 == strcmp(op1,"mov")) && (0 == strcmp(s1,"*r10+")) && (0 == strcmp(s2,"r1"))) ) {
            fflush(output);
            fseek(output, pushpos, SEEK_SET);
            // update history - we should have JUST enough for the largest pattern
            strcpy(cpu9900_lastline, cpu9900_lastline3);
            strcpy(cpu9900_lastline2, cpu9900_lastline4);
            strcpy(cpu9900_lastline3, "");
            strcpy(cpu9900_lastline4, "");
#ifdef DEBUGPEEP
            fprintf(output, "\t;PEEP: skip push/pop r1\n");
            fprintf(output, "\t;dect r10\n\t;mov r1,*r10\n\t;mov *r10+,r1\n");
#endif
            return;
        } else if ( ((0 == strcmp(op3,"dect")) && (0 == strcmp(s5,"r10"))) && 
                    ((0 == strcmp(op2,"mov")) && (0 == strcmp(s3,"r0")) && (0 == strcmp(s4,"*r10"))) &&
                    ((0 == strcmp(op1,"mov")) && (0 == strcmp(s1,"*r10+")) && (0 == strcmp(s2,"r0"))) ) {
            fflush(output);
            fseek(output, pushpos, SEEK_SET);
            // update history - we should have JUST enough for the largest pattern
            strcpy(cpu9900_lastline, cpu9900_lastline3);
            strcpy(cpu9900_lastline2, cpu9900_lastline4);
            strcpy(cpu9900_lastline3, "");
            strcpy(cpu9900_lastline4, "");
#ifdef DEBUGPEEP            
            fprintf(output, "\t;PEEP: skip push/pop r0\n");
            fprintf(output, "\t;ect r10\n\t;ov r0,*r10\n\t;ov *r10+,r0\n");
#endif
            return;
        }
        
        // similar case, but push/pop to different regs - only seen r0->r1 so I'll just code for that
        if ( ((0 == strcmp(op3,"dect")) && (0 == strcmp(s5,"r10"))) && 
                    ((0 == strcmp(op2,"mov")) && (0 == strcmp(s3,"r0")) && (0 == strcmp(s4,"*r10"))) &&
                    ((0 == strcmp(op1,"mov")) && (0 == strcmp(s1,"*r10+")) && (0 == strcmp(s2,"r1"))) ) {
            fflush(output);
            fseek(output, pushpos, SEEK_SET);
            // update history - we should have JUST enough for the largest pattern
            strcpy(cpu9900_lastline, cpu9900_lastline3);
            strcpy(cpu9900_lastline2, cpu9900_lastline4);
            strcpy(cpu9900_lastline3, "");
            strcpy(cpu9900_lastline4, "");
#ifdef DEBUGPEEP
            fprintf(output, "\t;PEEP: simplify push r0/pop r1\n");
            fprintf(output, "\t;ect r10\n\t;ov r0,*r10\n\t;ov *r10+,r1\n");
#endif
            strcpy(buf,"\tmov r0,r1\n");
        }        

        // check for repeated absolute loads. Doesn't happen very often, but the savings is worth it
        // first check - labels cancels all bets. We can try to get smarter with the registers like
        // the other ports later...
        if (buf[0] > ' ') {
            strcpy(last_r0_load,"");
        } else {
            // is r0 the target?
            if (0 == strcmp(s2,"r0")) {
                // is the source the same as remembered?
                if ((0 == strcmp(s1,last_r0_load)) && (last_r0_load[0] != '\0')) {
                    // then never mind this one
#ifdef DEBUGPEEP
                    fprintf(output, "\t;PEEP: skip repeated r0 load\n");
                    fprintf(output, "\t;%s", &buf[2]);
#endif
                    return;
                } else if (s1[0] == '@') {
                    // remember only addressed loads without offset
                    if (NULL != strchr(s1,'(')) {
                        strcpy(last_r0_load, "");
                    } else {
                        strcpy(last_r0_load, s1);
                    }
                } else {
                    strcpy(last_r0_load, "");
                }
            } else {
                // also check for ai
                if (0 == strcmp(op1,"ai") && (0 == strcmp(s1,"r0"))) {
                    strcpy(last_r0_load, "");
                }
                // and bl - all bets are off
                if (0 == strcmp(op1,"bl")) {
                    strcpy(last_r0_load, "");
                }
            }
        }
        
        // optimize loading a value into r0 then moving it into another register (r1 or r2)
        // we can check for li, mov, clr or seto
        if (loadsr0(op1, s1, s2)) {
             fflush(output);
             loadr0pos = ftell(output);
        } else if (loadsr0(op2, s3, s4)) {
            if ((0 == strncmp(op1,"mov",3)) && (0 == strcmp(s1,"r0")) && (s2[0] == 'r') && (s2[1] != '0')) {
                // change the last line to load r'X' (s2)
                fseek(output, loadr0pos, SEEK_SET);
#ifdef DEBUGPEEP
                char tmp[MAX_LINE_SIZE];
                char old = cpu9900_lastline[1];
                strcpy(tmp, buf);
                cpu9900_lastline[0]=';';
                tmp[0] = ';';
                fprintf(output, "\t;PEEP: simplify load r0 / mov r0,rx\n");
                fprintf(output, "\t%s\t%s", cpu9900_lastline, tmp);
                cpu9900_lastline[1]=old;
#endif
                // remove one line from history
                strcpy(cpu9900_lastline, cpu9900_lastline2);
                strcpy(cpu9900_lastline2, cpu9900_lastline3);
                strcpy(cpu9900_lastline3, cpu9900_lastline4);
                strcpy(cpu9900_lastline4, "");
                
                if (0 == strncmp(op2,"mov",3)) {
                    sprintf(buf, "\t%s %s,%s\n", op2, s3, s2);
                } else {
                    if (s4[0] == '\0') {
                        sprintf(buf, "\t%s %s\n", op2, s2);
                    } else {
                        sprintf(buf, "\t%s %s,%s\n", op2, s2, s4);
                    }
                }
            }
        }
        
        // check for mov rx,r0 / sla r0,8 / movb r0,rx (reduce 16 bit to 8 bit) - we can sla directly
        if ((0 == strcmp(op1,"mov")) && (s1[0]=='r') && (0 == strcmp(s2,"r0"))) {
            fflush(output);
            movtor0 = ftell(output);
        } else if ((0 == strcmp(op1,"movb")) && (0 == strcmp(op2,"sla")) && (0 == strcmp(op3,"mov")) 
            && (0 == strcmp(s5,s2)) && (0 == strcmp(s6,"r0")) && (0 == strcmp(s3,"r0"))
            && (0 == strcmp(s4,"8")) && (0 == strcmp(s1,"r0"))) {
            // roll back and replace the first mov with the sla
            fseek(output, movtor0, SEEK_SET);
#ifdef DEBUGPEEP
            fprintf(output,"\t;PEEP: simplify demotion from 16 bit to 8 bit\n");
            fprintf(output,"\t;%s %s,%s\n", op3,s5,s6);
            fprintf(output,"\t;%s %s,%s\n", op2,s3,s4);
            fprintf(output,"\t;%s %s,%s\n", op1,s1,s2);
#endif
            // remove one line from history
            strcpy(cpu9900_lastline, cpu9900_lastline2);
            strcpy(cpu9900_lastline2, cpu9900_lastline3);
            strcpy(cpu9900_lastline3, cpu9900_lastline4);
            strcpy(cpu9900_lastline4, "");
            // new line
            sprintf(buf,"\tsla %s,8\n", s2);
        }
        
        // specifically test for clr r0, then mov to an address (not movb!), we can then clear directly
        if ((0 == strcmp(op2,"clr")) && (0 == strcmp(s3,"r0")) && 
            (0 == strcmp(op1,"mov")) && (0 == strcmp(s1,"r0")) && (s2[0] == '@')) {
            fseek(output, loadr0pos, SEEK_SET);

#ifdef DEBUGPEEP
            char tmp[MAX_LINE_SIZE];
            char old = cpu9900_lastline[1];
            strcpy(tmp, buf);
            cpu9900_lastline[1]=';';
            tmp[1] = ';';
            fprintf(output, "\t;PEEP: simplify clr r0 / mov r0,@xxx\n");
            fprintf(output, "%s%s", cpu9900_lastline, tmp);
#endif
            
            // remove one line from history
            strcpy(cpu9900_lastline, cpu9900_lastline2);
            strcpy(cpu9900_lastline2, cpu9900_lastline3);
            strcpy(cpu9900_lastline3, cpu9900_lastline4);
            strcpy(cpu9900_lastline4, "");

            sprintf(buf, "\tclr %s\n", s2);
        }
        
        // specifically test for mov or movb to r0, them mov or movb to an address - we can move directly
        if ((0 == strncmp(op2,"mov",3)) && (0 == strcmp(s4,"r0")) && 
            (0 == strncmp(op1,"mov",3)) && (0 == strcmp(s1,"r0")) && (s2[0] == '@')) {
            fseek(output, loadr0pos, SEEK_SET);

#ifdef DEBUGPEEP
            char tmp[MAX_LINE_SIZE];
            char old = cpu9900_lastline[1];
            strcpy(tmp, buf);
            cpu9900_lastline[1]=';';
            tmp[1] = ';';
            fprintf(output, "\t;PEEP: simplify mov xxx,r0 / mov r0,@xxx\n");
            fprintf(output, "%s%s", cpu9900_lastline, tmp);
#endif

            // remove one line from history
            strcpy(cpu9900_lastline, cpu9900_lastline2);
            strcpy(cpu9900_lastline2, cpu9900_lastline3);
            strcpy(cpu9900_lastline3, cpu9900_lastline4);
            strcpy(cpu9900_lastline4, "");

            sprintf(buf, "\t%s %s,%s\n", op1, s3, s2);
        }
        
        // check for mov @x,r0, inc r0, mov r0,@x - inc, inct, dec, dect
        if ((0 == strcmp(op3,"mov")) && (s5[0] == '@') && (0 == strcmp(s6,"r0")) &&
            ((0 == strncmp(op2,"inc",3))||(0 == strncmp(op2,"dec",3))) && (0 == strcmp(s3,"r0")) &&
            (0 == strcmp(op1,"mov")) && (0 == strcmp(s1,"r0")) && (s2[0] == '@') &&
            (0 == strcmp(s5,s2))) {
            // that was a lot, but it looks good!
            fseek(output, loadr0pos, SEEK_SET);

#ifdef DEBUGPEEP
            char tmp[MAX_LINE_SIZE];
            cpu9900_lastline2[1]=';';
            cpu9900_lastline[1]=';';
            strcpy(tmp, buf);
            tmp[1]=';';
            fprintf(output, "\t;PEEP: simplify mov @x,r0 / inc r0 / mov r0,@x (all forms)\n");
            fprintf(output,"%s%s%s", cpu9900_lastline2, cpu9900_lastline, tmp);
#endif

            // remove two lines from history
            strcpy(cpu9900_lastline, cpu9900_lastline3);
            strcpy(cpu9900_lastline2, cpu9900_lastline4);
            strcpy(cpu9900_lastline3, "");
            strcpy(cpu9900_lastline4, "");

            sprintf(buf,"\t%s %s\n", op2, s2);
        }
        
        // 4 step sequence: mov[b] @x,r0 / li r1,>xx00 / a[b] r1,r0 / mov[b] r0,@x -> li r1,>xx00 / a[b] r1,@x
        // I don't think we'd ever generate it using s[b]...
        if ((0 == strncmp(op4,"mov",3)) && (s7[0] == '@') && (0 == strcmp(s8,"r0")) &&
            (0 == strcmp(op3,"li")) && (0 == strcmp(s5,"r1")) &&
            ((0 == strcmp(op2,"a"))||(0 == strcmp(op2,"ab"))||(0 == strcmp(op2,"s"))||(0 == strcmp(op2,"sb"))) && (0 == strcmp(s3,"r1")) && (0 == strcmp(s4,"r0")) &&
            (0 == strncmp(op1,"mov",3)) && (0 == strcmp(s1,"r0")) && (s2[0] == '@') &&
            (0 == strcmp(op4,op1)) && (0 == strcmp(s7,s2)) ) {
            fseek(output, loadr0pos, SEEK_SET);

#ifdef DEBUGPEEP
            char tmp[MAX_LINE_SIZE];
            cpu9900_lastline3[1]=';';
            cpu9900_lastline2[1]=';';
            cpu9900_lastline[1]=';';
            strcpy(tmp, buf);
            tmp[1]=';';
            fprintf(output, "\t;PEEP: simplify mov @x,r0 / li r1,>xxxx / a r1,r0 / mov r0,@x\n");
            fprintf(output,"%s%s%s%s", cpu9900_lastline3, cpu9900_lastline2, cpu9900_lastline, tmp);
#endif

            // remove three lines from history, but shift it so we can inject one too,
            // cause we want to write two lines. TODO: there may be further optimization
            // opportunity, but this will do for now...
            strcpy(cpu9900_lastline, "");
            strcpy(cpu9900_lastline2, cpu9900_lastline4);
            strcpy(cpu9900_lastline3, "");
            strcpy(cpu9900_lastline4, "");

            sprintf(cpu9900_lastline,"\tli r1,%s\n", s6);
            fprintf(output, "%s", cpu9900_lastline);
            
            sprintf(buf,"\t%s r1,%s\n", op2, s2);
        }

        // rotate the line buffer
        strcpy(cpu9900_lastline4, cpu9900_lastline3);
        strcpy(cpu9900_lastline3, cpu9900_lastline2);
        strcpy(cpu9900_lastline2, cpu9900_lastline);
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
    /*
     ** Maybe in the future we can pass an arg to tell cpu9900_node_generate which
     ** reg to generate for instead of always r0? That would make better code...
     */

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
            cpu9900_1op("neg", "r0");
            break;
        case N_NOT8:    /* Complement 8-bit value */
        case N_NOT16:   /* Complement 16-bit value */
            cpu9900_node_generate(node->left, 0);
            cpu9900_1op("inv", "r0");
            break;
        case N_ABS16:   /* Get absolute 16-bit value */
            cpu9900_node_generate(node->left, 0);
            cpu9900_1op("abs", "r0");
            break;
        case N_SGN16:   /* Get sign of 16-bit value */
            cpu9900_node_generate(node->left, 0);
            cpu9900_1op("bl", "@JSR");
            cpu9900_1op("data", "_sgn16");
            break;
        case N_POS:     /* Get screen cursor position in r0 (AAYY) */
            cpu9900_2op("mov", "@cursor", "r0");
            break;
        case N_EXTEND8S:    /* Extend 8-bit signed value to 16-bit */
            cpu9900_node_generate(node->left, 0);
            cpu9900_2op("sra", "r0", "8");
            break;
        case N_EXTEND8: /* Extend 8-bit value to 16-bit */
            cpu9900_node_generate(node->left, 0);
            cpu9900_2op("srl", "r0", "8");
            break;
        case N_REDUCE16:    /* Reduce 16-bit value to 8-bit */
            cpu9900_node_generate(node->left, 0);
            cpu9900_2op("sla", "r0", "8");
            break;
        case N_READ8:   /* Read 8-bit value from read_pointer */
            cpu9900_2op("mov", "@read_pointer", "r1");
            cpu9900_2op("movb", "*r1", "r0");
            cpu9900_1op("inc", "@read_pointer");
            break;
        case N_READ16:  /* Read 16-bit value - warning, will not work as expected unaligned! */
            cpu9900_2op("mov", "@read_pointer", "r1");
            cpu9900_2op("mov", "*r1","r0");
            cpu9900_1op("inct", "@read_pointer");
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
            sprintf(temp, "%d   ; %d*256", node->value * 256, node->value);
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
                
                node_get_label(node->left->left, ADDRESS);        /* Address */
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
            /* So presumably here we are reading from something loaded into r0 */
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
                
                /* Power of 2 multiply */
                cpu9900_node_generate(node->left, 0);
                c = node->right->value;
                cnt = 0;
                while (c > 1) {
                    ++cnt;
                    c /= 2;
                }
                cpu9900_2op("andi", "r0", ">ff00"); /* Avoid trash bits 7-0 getting into */
                sprintf(temp, "%d", cnt);
                cpu9900_2op("sla", "r0", temp);
                break;
            }
            if (node->type == N_DIV8 && node->right->type == N_NUM8 && is_power_of_two(node->right->value)) {
                int c, cnt;
                
                /* Power of 2 divide */
                cpu9900_node_generate(node->left, 0);
                c = node->right->value;
                cnt = 0;
                while (c > 1) {
                    ++cnt;
                    c /= 2;
                }
                sprintf(temp, "%d", cnt);
                cpu9900_2op("srl", "r0", temp);
                break;
            }
            if (node->type == N_LESSEQUAL8 || node->type == N_GREATER8) {
                if (node->left->type == N_NUM8) {
                    int c;
                    
                    c = node->left->value & 0xff;
                    cpu9900_node_generate(node->right, 0);
                    sprintf(temp, "%d   ; %d*256", c*256, c);
                    cpu9900_2op("li", "r1", temp);
                    strcpy(temp, "r1");
                } else if (node->left->type == N_LOAD8) {
                    cpu9900_node_generate(node->right, 0);
                    node_get_label(node->left, ADDRESS);
                } else {
                    cpu9900_node_generate(node->left, 0);
                    cpu9900_1op("dect", "r10");
                    cpu9900_2op("mov", "r0", "*r10");
                    cpu9900_node_generate(node->right, 0);
                    cpu9900_2op("mov", "*r10+", "r1");
                    strcpy(temp, "r1");
                }
            } else if (node->type != N_XOR8 && node->type != N_AND8 && node->right->type == N_LOAD8) {
                /*
                 ** Not optimizable:
                 ** o XOR instruction doesn't have an 8-bit mode.
                 ** o To make AND it is required to invert the source operand (i.e. alter the variable)
                 */
                cpu9900_node_generate(node->left, 0);
                node_get_label(node->right, ADDRESS);
            } else if (node->right->type == N_NUM8) {
                int c;
                
                c = node->right->value & 0xff;
                cpu9900_node_generate(node->left, 0);
                sprintf(temp, "%d   ; %d*256", c*256, c);
                cpu9900_2op("li", "r1", temp);
                strcpy(temp, "r1");
            } else {
                cpu9900_node_generate(node->right, 0);
                cpu9900_1op("dect", "r10");
                cpu9900_2op("mov", "r0", "*r10");
                cpu9900_node_generate(node->left, 0);
                cpu9900_2op("mov", "*r10+", "r1");
                strcpy(temp, "r1");
            }
            if (node->type == N_OR8) {
                cpu9900_2op("socb", temp, "r0");
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
                cpu9900_1op("inv", temp);
                cpu9900_2op("szcb", temp, "r0");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_EQUAL8) {
                cpu9900_2op("cb", temp, "r0");
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
            } else if (node->type == N_NOTEQUAL8) {
                cpu9900_2op("cb", temp, "r0");
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
            } else if (node->type == N_LESS8 || node->type == N_GREATER8) {
                cpu9900_2op("cb", "r0", temp);
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
            } else if (node->type == N_LESSEQUAL8 || node->type == N_GREATEREQUAL8) {
                cpu9900_2op("cb", "r0", temp);
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
                cpu9900_2op("ab", temp, "r0");
            } else if (node->type == N_MINUS8) {
                cpu9900_2op("sb", temp, "r0");
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
                        int cnt;
                        
                        cpu9900_node_generate(node, 0);
                        cnt = 0;
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
                    int cnt;
                    int c;
                    
                    cpu9900_node_generate(node->left, 0);
                    c = node->right->value;
                    cnt = 0;
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
                cpu9900_noop(";unclear - node->type == N_LESSEQUAL16 || node->type == N_GREATER16");
                cpu9900_node_generate(node->left, 0);   
                cpu9900_1op("dect","r10");
                cpu9900_2op("mov","r0","*r10");
                cpu9900_node_generate(node->right, 0);
            } else {
                cpu9900_node_generate(node->right, 0);
                cpu9900_1op("dect","r10");
                cpu9900_2op("mov","r0","*r10");
                cpu9900_node_generate(node->left, 0);
            }
            if (node->type == N_OR16) {
                cpu9900_2op("mov","*r10+","r1");
                cpu9900_2op("soc","r1","r0");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_XOR16) {
                cpu9900_2op("mov","*r10+","r1");
                cpu9900_2op("xor","r1","r0");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_AND16) {
                cpu9900_2op("mov","*r10+","r1");
                cpu9900_1op("inv","r1");
                cpu9900_2op("szc","r1","r0");
                if (decision) {
                    optimized = 1;
                    sprintf(temp, "@" INTERNAL_PREFIX "%d", decision);
                    sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                    cpu9900_1op("jne", temp + 100);
                    cpu9900_1op("b", temp);
                    cpu9900_label(temp + 100);
                }
            } else if (node->type == N_EQUAL16) {
                cpu9900_2op("mov","*r10+","r1");
                cpu9900_2op("c","r0","r1");
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
                cpu9900_2op("mov","*r10+","r1");
                cpu9900_2op("c","r0","r1");
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
                cpu9900_2op("mov","*r10+","r1");
                cpu9900_2op("c","r0","r1");
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
                cpu9900_2op("mov","*r10+","r1");
                cpu9900_noop("; TODO check order of compare2");
                cpu9900_2op("c","r0","r1");
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
                cpu9900_2op("mov","*r10+","r1");
                cpu9900_2op("a","r1","r0");
            } else if (node->type == N_MINUS16) {
                cpu9900_2op("mov","*r10+","r1");
                cpu9900_2op("s","r1","r0");
            } else if (node->type == N_MUL16) {
                cpu9900_2op("mov","*r10+","r1");
                cpu9900_2op("mpy","r0","r1");   // r0 * r1 => r1_r2 (32 bit)
                cpu9900_2op("mov","r2","r0");
            } else if (node->type == N_DIV16) {
                cpu9900_2op("mov","r0","r1");
                cpu9900_2op("mov","*r10+","r2");
                cpu9900_1op("clr","r0");
                cpu9900_2op("div","r2","r0");   // r0_r1 / r2 => r0, rem r1
            } else if (node->type == N_MOD16) {
                cpu9900_2op("mov","r0","r1");
                cpu9900_2op("mov","*r10+","r2");
                cpu9900_1op("clr","r0");
                cpu9900_2op("div","r2","r0");   // r0_r1 / r2 => r0, rem r1
                cpu9900_2op("mov","r1","r0");   // get remainder
            } else if (node->type == N_DIV16S) {
                cpu9900_noop("; TODO: check order of division - assume r0/r2");
                cpu9900_2op("mov","r0","r1");
                cpu9900_2op("mov","*r10+","r2");
                cpu9900_1op("bl","@JSR");
                cpu9900_1op("data", "_div16s");
            } else if (node->type == N_MOD16S) {
                cpu9900_noop("; TODO: check order of mod - assume r0%r2");
                cpu9900_2op("mov","r0","r1");
                cpu9900_2op("mov","*r10+","r2");
                cpu9900_1op("bl","@JSR");
                cpu9900_1op("data", "_mod16s");
            }
            break;
    }
}
