/*
** Z80 assembler output routines for CVBasic (headers)
**
** by Oscar Toledo G.
**
** Creation date: Jul/31/2024. Separated from CVBasic.c
*/

extern void cpuz80_dump(void);
extern void cpuz80_label(char *);
extern void cpuz80_empty(void);
extern void cpuz80_noop(char *);
extern void cpuz80_1op(char *, char *);
extern void cpuz80_2op(char *, char *, char *);

extern void cpuz80_node_label(struct node *);
extern void cpuz80_node_generate(struct node *, int);
