/*
** Z80 assembler output routines for CVBasic (headers)
**
** by Oscar Toledo G.
**
** Creation date: Jul/31/2024. Separated from CVBasic.c
*/

extern void z80_dump(void);
extern void z80_label(char *);
extern void z80_empty(void);
extern void z80_noop(char *);
extern void z80_1op(char *, char *);
extern void z80_2op(char *, char *, char *);
