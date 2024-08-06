/*
** Driver for CVBasic's backends (headers)
**
** by Oscar Toledo G.
**
** Creation date: Aug/04/2024. Separated from CVBasic.c
*/

extern void generic_dump(void);
extern void generic_write_8(char *);
extern void generic_write_16(char *);
extern void generic_test_8(void);
extern void generic_test_16(void);
extern void generic_label(char *);
extern void generic_call(char *);
extern void generic_return(void);
extern void generic_jump(char *);
extern void generic_jump_zero(char *);
