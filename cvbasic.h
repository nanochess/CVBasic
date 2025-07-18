/*
 ** CVBasic - Global definitions
 ** by Oscar Toledo G.
 **
 ** © Copyright 2024 Óscar Toledo G.
 ** https://nanochess.org/
 **
 ** Creation date: Jun/21/2024.
 */

#define CONST_PREFIX    "const_"
#define ARRAY_PREFIX    "array_"
#define LABEL_PREFIX    "cvb_"
#define INTERNAL_PREFIX "cv"

#define MAX_LINE_SIZE    1024

/*
 ** Supported platforms.
 */
enum supported_machine {
    COLECOVISION,
    SG1000,
    MSX,
    COLECOVISION_SGM,
    SVI,
    SORD,
    MEMOTECH,
    CREATIVISION,
    PENCIL,
    EINSTEIN,
    PV2000,
    TI994A,
    NABU,
    SMS,
    NES,
    TOTAL_TARGETS
};

extern enum supported_machine machine;

/*
 ** Supported target CPUs
 */
enum cpu_target {
    CPU_Z80,
    CPU_6502,
    CPU_9900
};

extern enum cpu_target target;

/*
 ** Information about supported machines
 */
struct console {
    char *name;         /* Machine name */
    char *options;      /* Options */
    char *description;  /* Description (for usage guide) */
    char *canonical;    /* Canonical name */
    int base_ram;       /* Where the RAM starts */
    int stack;          /* Where the stack will start */
    int memory_size;    /* Memory available */
    int vdp_port_write; /* VDP port for writing */
    int vdp_port_read;  /* VDP port for reading (needed for SVI-318/328, sigh) */
    int psg_port;       /* PSG port (SN76489) */
    int int_pin;        /* Indicates if it uses the INT pin for video frame interrupt */
    enum cpu_target target;
};

extern struct console consoles[TOTAL_TARGETS];

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
#define LABEL_USED              0x10
#define LABEL_DEFINED           0x20
#define LABEL_CALLED_BY_GOTO    0x40
#define LABEL_CALLED_BY_GOSUB   0x80
#define LABEL_IS_PROCEDURE      0x100
#define LABEL_IS_VARIABLE       0x200
#define LABEL_IS_ARRAY          0x400

#define LABEL_VAR_READ          0x0800
#define LABEL_VAR_WRITE         0x1000
#define LABEL_VAR_ACCESS        (LABEL_VAR_READ | LABEL_VAR_WRITE)

extern void emit_error(char *);
