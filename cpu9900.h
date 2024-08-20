/*
** 9900 assembler output routines for CVBasic (headers)
**
** by Tursi, based on cpu6502.h by Oscar Toledo G.
**
** Creation date: Aug/20/2024. Separated from CVBasic.c
*/

extern void cpu9900_dump(void);
extern void cpu9900_label(char *);
extern void cpu9900_empty(void);
extern void cpu9900_noop(char *);
extern void cpu9900_1op(char *, char *);
extern void cpu9900_2op(char *, char *, char *);

extern void cpu9900_node_label(struct node *);
extern void cpu9900_node_generate(struct node *, int);
