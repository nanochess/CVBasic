/*
** Z80 assembler output routines for CVBasic (headers)
**
** by Oscar Toledo G.
**
** Creation date: Jul/31/2024. Separated from CVBasic.c
*/

#define REG_A   0x01
#define REG_F   0x02
#define REG_B   0x04
#define REG_C   0x08
#define REG_D   0x10
#define REG_E   0x20
#define REG_H   0x40
#define REG_L   0x80

#define REG_AF  (REG_A | REG_F)
#define REG_BC  (REG_B | REG_C)
#define REG_DE  (REG_D | REG_E)
#define REG_HL  (REG_H | REG_L)

extern void cpuz80_dump(void);
extern void cpuz80_label(char *);
extern void cpuz80_empty(void);
extern void cpuz80_noop(char *);
extern void cpuz80_1op(char *, char *);
extern void cpuz80_2op(char *, char *, char *);

extern void cpuz80_node_label(struct node *);
extern void cpuz80_node_generate(struct node *, int);
