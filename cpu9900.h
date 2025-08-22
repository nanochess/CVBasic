/*
** 9900 assembler output routines for CVBasic (headers)
**
** by Tursi, based on cpu6502.h by Oscar Toledo G.
**
** Creation date: Aug/20/2024. Separated from CVBasic.c
*/

#define REG_0    0x01
#define REG_1    0x02
#define REG_2    0x04
#define REG_3    0x08
#define REG_4    0x10
#define REG_5    0x20
#define REG_6    0x40
#define REG_7    0x80

#define REG_ALL  (REG_0 | REG_1 | REG_2 | REG_3 | REG_4 | REG_5 | REG_6 | REG_7)

extern void cpu9900_dump(void);
extern void cpu9900_label(char *);
extern void cpu9900_empty(void);
extern void cpu9900_noop(char *);
extern void cpu9900_1op(char *, char *);
extern void cpu9900_2op(char *, char *, char *);

extern void cpu9900_node_label(struct node *);
extern void cpu9900_node_generate(struct node *, int);
