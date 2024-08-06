/*
 ** CVBasic - Global definitions
 ** by Oscar Toledo G.
 **
 ** © Copyright 2024 Óscar Toledo G.
 ** https://nanochess.org/
 **
 ** Creation date: Jun/21/2024.
 */

#define ARRAY_PREFIX    "array_"
#define LABEL_PREFIX    "cvb_"
#define INTERNAL_PREFIX "cv"

#define MAX_LINE_SIZE    1024

enum cpu_target {
    CPU_Z80,
    CPU_6502,
};

extern enum cpu_target target;
extern char temp[MAX_LINE_SIZE];
extern int optimized;
extern FILE *output;
extern int next_local;

#define HASH_PRIME    1103    /* A prime number */

struct label {
    struct label *next;
    int used;
    int length;         /* For arrays */
    char name[1];
};

/*
 ** These flags are used to keep types when evaluating expressions, but also
 ** for variables (TYPE_SIGNED isn't keep in variables or arrays, instead in
 ** a separate signedness definition table).
 */
#define MAIN_TYPE       0x03
#define TYPE_8          0x00
#define TYPE_16         0x01
#define TYPE_SIGNED     0x04

/*
 ** These flags are used in labels
 */
#define LABEL_USED      0x10
#define LABEL_DEFINED   0x20
#define LABEL_CALLED_BY_GOTO    0x40
#define LABEL_CALLED_BY_GOSUB   0x80
#define LABEL_IS_PROCEDURE  0x100
#define LABEL_IS_VARIABLE   0x200
#define LABEL_IS_ARRAY      0x400

#define LABEL_VAR_READ  0x0800
#define LABEL_VAR_WRITE 0x1000
#define LABEL_VAR_ACCESS (LABEL_VAR_READ | LABEL_VAR_WRITE)

extern void emit_error(char *);
