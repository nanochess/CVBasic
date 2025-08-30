/*
** 6502 assembler output routines for CVBasic (headers)
**
** by Oscar Toledo G.
**
** Creation date: Aug/04/2024. Separated from CVBasic.c
*/

#define REG_ACC   1
#define REG_X     2
#define REG_Y     4
#define REG_TEMP  8

extern void cpu6502_dump(void);
extern void cpu6502_label(char *);
extern void cpu6502_empty(void);
extern void cpu6502_noop(char *);
extern void cpu6502_1op(char *, char *);

extern void cpu6502_node_label(struct node *);
extern void cpu6502_node_generate(struct node *, int);
