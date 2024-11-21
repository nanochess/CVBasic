/*
 ** CVBasic
 **
 ** by Oscar Toledo G.
 **
 ** © Copyright 2024 Óscar Toledo G.
 ** https://nanochess.org/
 **
 ** Creation date: Feb/27/2024.
 ** Revision date: Feb/28/2024. Implemented WHILE/WEND, DO/LOOP, FOR/NEXT, and EXIT.
 ** Revision date: Feb/29/2024. Implemented controller support. Added arrays, SOUND,
 **                             RESTORE/READ/DATA. Added small local optimization.
 ** Revision date: Aug/23/2024. Added TI-99/4A.
  */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#include "cvbasic.h"
#include "node.h"
#include "driver.h"
#include "cpuz80.h"
#include "cpu6502.h"
#include "cpu9900.h"

#ifdef ASM_LIBRARY_PATH
#define DEFAULT_ASM_LIBRARY_PATH ASM_LIBRARY_PATH
#else
#define DEFAULT_ASM_LIBRARY_PATH ""
#endif

#define VERSION "v0.8.0 Nov/12/2024"

#define TEMPORARY_ASSEMBLER "cvbasic_temporary.asm"

#define FALSE           0
#define TRUE            1

/*
 ** Supported platforms.
 */
static enum {
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
    TOTAL_TARGETS
} machine;

enum cpu_target target;

/*
 ** Base information about each platform.
 */
static struct console {
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
    enum cpu_target target;
} consoles[TOTAL_TARGETS] = {
    /*  RAM   STACK    Size  VDP R   VDP W  PSG */
    {"colecovision","",     "Standard Colecovision (1K RAM)",
        "Colecovision",
        0x7000, 0x7400, 0x0400,  0xbe,   0xbe, 0xff, CPU_Z80},
    {"sg1000",  "",         "Sega SG-1000/SC-3000 (1K RAM)",
        "Sega SG-1000/SC-3000",
        0xc000, 0xc400, 0x0400,  0xbe,   0xbe, 0x7f, CPU_Z80},
    {"msx",     "-ram16",   "MSX (8K RAM), use -ram16 for 16K of RAM",
        "MSX",
        0xe000, 0xf380, 0x1380,  0x98,   0x98, 0,    CPU_Z80},
    {"sgm",     "",         "Colecovision with Opcode's Super Game Module",
        "Colecovision with SGM",
        0x7c00, 0x8000, 0x5c00,  0xbe,   0xbe, 0xff, CPU_Z80}, /* Note: Real RAM at 0x2000 */
    {"svi",     "",         "Spectravideo SVI-318/328 (16K of RAM)",
        "Spectravideo SVI-318/328",
        0xc000, 0xf000, 0x3000,  0x80,   0x84, 0,    CPU_Z80},
    {"sord",    "",         "Sord M5 (1K RAM)",
        "Sord M5",
        0x7080, 0x7080, 0x0380,  0x10,   0x10, 0x20, CPU_Z80},
    {"memotech","-cpm",     "Memotech MTX (64K RAM), generates .run files, use -cpm for .com files",
        "Memotech MTX",
        0,      0xa000, 0,       0x01,   0x01, 0x06, CPU_Z80},
    {"creativision","-rom16","Vtech Creativision (Dick Smith's Wizzard/Laser 2001), 6502+1K RAM.",
        "Creativision/Wizzard",
        0x0050, 0x017f, 0x0400,  0,      0,    0,    CPU_6502},
    {"pencil",  "",         "Soundic/Hanimex Pencil II (2K RAM)",
        "Soundic Pencil II",
        0x7000, 0x7800, 0x0800,  0xbe,   0xbe, 0xff, CPU_Z80},
    {"einstein","",         "Tatung Einstein, generates .com files",
        "Tatung Einstein",
        0,      0xa000, 0,       0x08,   0x08, 0,    CPU_Z80},
    {"pv2000",  "",         "Casio PV-2000",
        "Casio PV-2000",
        0x7600, 0x8000, 0x0a00,0x4000, 0x4000, 0x40, CPU_Z80},
    {"ti994a",  "",         "Texas Instruments TI-99/4A (32K RAM). Support by tursilion",
        "TI-99/4A (support by tursilion)",
        0x2080, 0x4000, 0x1f80, 0x8800, 0x8c00,0xff, CPU_9900},
    {"nabu",    "-cpm",     "NABU PC (64K RAM)",
        "Nabu PC",
        0,      0xe000, 0,       0xa0,   0xa0, 0,    CPU_Z80},
};

static int err_code;

static char library_path[4096] = DEFAULT_ASM_LIBRARY_PATH;
static char path[4096];

static int last_is_return;
static int music_used;
static int compression_used;
static int bank_switching;
static int bank_rom_size;
static int bank_current;

static char current_file[MAX_LINE_SIZE];
static int current_line;
static FILE *input;
FILE *output;           /* Used by Z80.c */

static int line_pos;
static int line_size;
static int line_start;
static char line[MAX_LINE_SIZE];

int next_local = 1;

static int option_explicit;
static int option_warnings;

static enum lexical_component {
    C_END, C_NAME,
    C_STRING, C_LABEL, C_NUM,
    C_ASSIGN,
    C_EQUAL, C_NOTEQUAL, C_LESS, C_LESSEQUAL, C_GREATER, C_GREATEREQUAL,
    C_PLUS, C_MINUS, C_MUL, C_DIV, C_MOD,
    C_LPAREN, C_RPAREN, C_COLON, C_PERIOD, C_COMMA,
    C_ERR} lex;
static int value;
static char global_label[MAX_LINE_SIZE];
static char name[MAX_LINE_SIZE];
static int name_size;
static char assigned[MAX_LINE_SIZE];

char temp[MAX_LINE_SIZE];

static struct label *label_hash[HASH_PRIME];

static struct label *array_hash[HASH_PRIME];

static struct label *inside_proc;
static struct label *frame_drive;

struct signedness {
    struct signedness *next;
    int sign;
    char name[1];
};

struct constant {
    struct constant *next;
    int value;
    char name[1];
};

static struct signedness *signed_hash[HASH_PRIME];

static struct constant *constant_hash[HASH_PRIME];

static struct label *function_hash[HASH_PRIME];

struct macro {
    struct macro *next;
    int total_arguments;
    int in_use;
    struct macro_def *definition;
    int length;
    int max_length;
    char name[1];
};

struct macro_arg {
    struct macro_def *definition;
    int length;
    int max_length;
};

struct macro_def {
    enum lexical_component lex;
    int value;
    char *name;
};

static struct macro *macro_hash[HASH_PRIME];

static struct macro_arg accumulated;

int replace_macro(void);
struct node *process_usr(int);

int optimized;

struct node *evaluate_level_0(int *);
struct node *evaluate_level_1(int *);
struct node *evaluate_level_2(int *);
struct node *evaluate_level_3(int *);
struct node *evaluate_level_4(int *);
struct node *evaluate_level_5(int *);
struct node *evaluate_level_6(int *);
struct node *evaluate_level_7(int *);

/*
** Representation for a loop
*/
struct loop {
    struct loop *next;
    enum {NESTED_FOR, NESTED_WHILE, NESTED_IF, NESTED_DO, NESTED_DO_LOOP, NESTED_SELECT} type;
    struct node *step;
    struct node *final;
    int label_loop;     /* Main label, in C this would be destination for 'continue' */
    int label_exit;     /* Exit label, in C this would be destination for 'break' */
    char var[1];
};

static struct loop *loops;

static unsigned char bitmap[32];
static int bitmap_byte;

/*
 ** Prototypes
 */
void emit_error(char *);
void emit_warning(char *);
void bank_finish(void);

int label_hash_value(char *);
struct label *function_search(char *);
struct label *function_add(char *);
struct signedness *signed_search(char *);
struct signedness *signed_add(char *);
struct constant *constant_search(char *);
struct constant *constant_add(char *);
struct label *label_search(char *);
struct label *label_add(char *);
struct label *array_search(char *);
struct label *array_add(char *);
struct macro *macro_search(char *);
struct macro *macro_add(char *);

int lex_skip_spaces(void);
int lex_sneak_peek(void);
void get_lex(void);

void check_for_explicit(char *);
int extend_types(struct node **, int, struct node **, int);
int mix_types(struct node **, int, struct node **, int);
struct node *evaluate_save_expression(int, int);
int evaluate_expression(int, int, int);
void accumulated_push(enum lexical_component, int, char *);
void compile_assignment(int);
void compile_statement(int);
void compile_basic(void);

/*
 ** Emit an error
 */
void emit_error(char *string)
{
    fprintf(stderr, "ERROR: %s at line %d (%s)\n", string, current_line, current_file);
    err_code = 1;
}

/*
 ** Emit a warning
 */
void emit_warning(char *string)
{
    if (!option_warnings)
        return;
    fprintf(stderr, "Warning: %s at line %d (%s)\n", string, current_line, current_file);
}

/*
 ** Finish a bank
 */
void bank_finish(void)
{
    if (machine == SG1000) {
        if (bank_current == 0) {
            fprintf(output, "BANK_0_FREE:\tEQU $3fff-$\n");
            fprintf(output, "\tTIMES $3fff-$ DB $ff\n");
        } else {
            fprintf(output, "BANK_%d_FREE:\tEQU $7fff-$\n", bank_current);
            fprintf(output, "\tTIMES $7fff-$ DB $ff\n");
        }
        fprintf(output, "\tDB $%02x\n", bank_current);
    } else if (machine == MSX) {
        if (bank_current == 0) {
            fprintf(output, "BANK_0_FREE:\tEQU $7fff-$\n");
            fprintf(output, "\tTIMES $7fff-$ DB $ff\n");
        } else {
            fprintf(output, "BANK_%d_FREE:\tEQU $bfff-$\n", bank_current);
            fprintf(output, "\tTIMES $bfff-$ DB $ff\n");
        }
        fprintf(output, "\tDB $%02x\n", bank_current);
    } else if (machine == TI994A) {
        if (bank_current == 0) {
            // bank 0 is copied to RAM so is 24k
            fprintf(output, "BANK_0_FREE:\tEQU >fffe-$\n");
            fprintf(output, "\t.rept >fffe-$\n");
            fprintf(output, "\tbyte 255\n");
            fprintf(output, "\t.endr\n");
        } else {
            // other banks are only 8k
            fprintf(output, "BANK_%d_FREE:\tEQU >7ffe-$\n", bank_current);
            fprintf(output, "\t.rept >7ffe-$\n");
            fprintf(output, "\tbyte 255\n");
            fprintf(output, "\t.endr\n");
        }
        // output the bank switch address so it doesn't need to be calculated later
        fprintf(output, "\tdata >%04x\n", (bank_current+2)*2+0x6000);
    } else {
        int c;
        
        if (bank_current == 0) {
            fprintf(output, "BANK_0_FREE:\tEQU $bfbf-$\n");
            fprintf(output, "\tTIMES $bfbf-$ DB $ff\n");
        } else {
            fprintf(output, "BANK_%d_FREE:\tEQU $ffbf-$\n", bank_current);
            fprintf(output, "\tTIMES $ffbf-$ DB $ff\n");
        }
        c = (bank_current - 1) & 0x3f;
        if (bank_rom_size == 128)
            c |= 0xf8;
        else if (bank_rom_size == 256)
            c |= 0xf0;
        else if (bank_rom_size == 512)
            c |= 0xe0;
        else if (bank_rom_size == 1024)
            c |= 0xc0;
        fprintf(output, "\tDB $%02x\n", c);
        fprintf(output, "\tTIMES $40 DB $ff\n");
    }
}

/*
 ** Calculate a hash value for a name
 */
int label_hash_value(char *name)
{
    unsigned int value;
    
    value = 0;
    while (*name) {
        value *= 11;    /* Another prime number */
        value += (unsigned int) *name++;
    }
    return value % HASH_PRIME;
}

/*
 ** Search for a function
 */
struct label *function_search(char *name)
{
    struct label *explore;
    
    explore = function_hash[label_hash_value(name)];
    while (explore != NULL) {
        if (strcmp(explore->name, name) == 0)
            return explore;
        explore = explore->next;
    }
    return NULL;
}

/*
 ** Add a constant
 */
struct label *function_add(char *name)
{
    struct label **previous;
    struct label *new_one;
    
    new_one = malloc(sizeof(struct label) + strlen(name));
    if (new_one == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    new_one->used = 0;
    new_one->length = 0;
    strcpy(new_one->name, name);
    previous = &function_hash[label_hash_value(name)];
    new_one->next = *previous;
    *previous = new_one;
    return new_one;
}

/*
 ** Search for a name with defined signedness
 */
struct signedness *signed_search(char *name)
{
    struct signedness *explore;
    
    explore = signed_hash[label_hash_value(name)];
    while (explore != NULL) {
        if (strcmp(explore->name, name) == 0)
            return explore;
        explore = explore->next;
    }
    return NULL;
}

/*
 ** Add a name with defined signedness
 */
struct signedness *signed_add(char *name)
{
    struct signedness **previous;
    struct signedness *new_one;
    
    new_one = malloc(sizeof(struct signedness) + strlen(name));
    if (new_one == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    new_one->sign = 0;
    strcpy(new_one->name, name);
    previous = &signed_hash[label_hash_value(name)];
    new_one->next = *previous;
    *previous = new_one;
    return new_one;
}

/*
 ** Search for a constant
 */
struct constant *constant_search(char *name)
{
    struct constant *explore;
    
    explore = constant_hash[label_hash_value(name)];
    while (explore != NULL) {
        if (strcmp(explore->name, name) == 0)
            return explore;
        explore = explore->next;
    }
    return NULL;
}

/*
 ** Add a constant
 */
struct constant *constant_add(char *name)
{
    struct constant **previous;
    struct constant *new_one;
    
    new_one = malloc(sizeof(struct constant) + strlen(name));
    if (new_one == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    new_one->value = 0;
    strcpy(new_one->name, name);
    previous = &constant_hash[label_hash_value(name)];
    new_one->next = *previous;
    *previous = new_one;
    return new_one;
}

/*
 ** Search for a label
 */
struct label *label_search(char *name)
{
    struct label *explore;
    
    explore = label_hash[label_hash_value(name)];
    while (explore != NULL) {
        if (strcmp(explore->name, name) == 0)
            return explore;
        explore = explore->next;
    }
    return NULL;
}

/*
 ** Add a label
 */
struct label *label_add(char *name)
{
    struct label **previous;
    struct label *new_one;
    
    new_one = malloc(sizeof(struct label) + strlen(name));
    if (new_one == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    new_one->used = 0;
    strcpy(new_one->name, name);
    previous = &label_hash[label_hash_value(name)];
    new_one->length = 0;
    new_one->next = *previous;
    *previous = new_one;
    return new_one;
}

/*
 ** Search for an array
 */
struct label *array_search(char *name)
{
    struct label *explore;
    
    explore = array_hash[label_hash_value(name)];
    while (explore != NULL) {
        if (strcmp(explore->name, name) == 0)
            return explore;
        explore = explore->next;
    }
    return NULL;
}

/*
 ** Add an array
 */
struct label *array_add(char *name)
{
    struct label **previous;
    struct label *new_one;
    
    new_one = malloc(sizeof(struct label) + strlen(name));
    if (new_one == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    new_one->used = 0;
    strcpy(new_one->name, name);
    previous = &array_hash[label_hash_value(name)];
    new_one->next = *previous;
    *previous = new_one;
    return new_one;
}

/*
 ** Search for a macro
 */
struct macro *macro_search(char *name)
{
    struct macro *explore;
    
    explore = macro_hash[label_hash_value(name)];
    while (explore != NULL) {
        if (strcmp(explore->name, name) == 0)
            return explore;
        explore = explore->next;
    }
    return NULL;
}

/*
 ** Add a macro
 */
struct macro *macro_add(char *name)
{
    struct macro **previous;
    struct macro *new_one;
    
    new_one = malloc(sizeof(struct macro) + strlen(name));
    if (new_one == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    new_one->total_arguments = 0;
    new_one->in_use = 0;
    new_one->definition = NULL;
    new_one->length = 0;
    new_one->max_length = 0;
    strcpy(new_one->name, name);
    previous = &macro_hash[label_hash_value(name)];
    new_one->next = *previous;
    *previous = new_one;
    return new_one;
}

/*
 ** Avoid spaces
 */
int lex_skip_spaces(void) {
    int something = 0;
    
    if (line_pos == 0)
        something = 1;
    while (line_pos < line_size && isspace(line[line_pos])) {
        line_pos++;
        something = 1;
    }
    return something;
}

/*
 ** Sneak-peek to next character
 */
int lex_sneak_peek(void) {
    if (accumulated.length > 0) {
        if (accumulated.definition[accumulated.length - 1].lex == C_LPAREN)
            return '(';
        return 0;
    }
    lex_skip_spaces();
    if (line_pos == line_size)
        return '\0';
    return toupper(line[line_pos]);
}

/*
 ** Gets another lexical component
 ** Output:
 **  lex = lexical component
 **  name = identifier or string
 **  value = value
 */
void get_lex(void) {
    int spaces;
    char *p;

    if (accumulated.length > 0) {
        --accumulated.length;
        lex = accumulated.definition[accumulated.length].lex;
        strcpy(name, accumulated.definition[accumulated.length].name);
        value = accumulated.definition[accumulated.length].value;
        free(accumulated.definition[accumulated.length].name);
        return;
    }
    name[0] = '\0';
    spaces = lex_skip_spaces();
    if (line_pos == line_size) {
        lex = C_END;
        return;
    }
    if (isalpha(line[line_pos]) ||
        line[line_pos] == '#' ||
        (spaces && line[line_pos] == '.') ||
        (line_pos > 0 && line[line_pos - 1] == ',' && line[line_pos] == '.') ||
        (line_pos > 0 && line[line_pos - 1] == ':' && line[line_pos] == '.')) {  /* Name, label or local label */
        if (line[line_pos] == '.') {
            strcpy(name, global_label);
            p = name + strlen(name);
            value = 1;
        } else {
            name[0] = '\0';
            p = name;
            value = 0;
        }
        *p++ = toupper(line[line_pos]);
        line_pos++;
        while (line_pos < line_size
               && (isalnum(line[line_pos]) || line[line_pos] == '_' || line[line_pos] == '#')) {
            if (p - name < MAX_LINE_SIZE - 1)
                *p++ = toupper(line[line_pos]);
            line_pos++;
        }
        *p = '\0';
        name_size = (int) (p - name);
        if (line_pos < line_size && line[line_pos] == ':' && line_start
            && strcmp(name, "RETURN") != 0 && strcmp(name, "CLS") != 0 && strcmp(name, "WAIT") != 0
            && strcmp(name, "RESTORE") != 0 && strcmp(name, "WEND") != 0
            && strcmp(name, "DO") != 0 && strcmp(name, "NEXT") != 0) {
            lex = C_LABEL;
            line_pos++;
        } else {
            lex = C_NAME;
        }
        line_start = 0;
        return;
    }
    if (isdigit(line[line_pos])) {  /* Decimal number */
        value = 0;
        while (line_pos < line_size && isdigit(line[line_pos]))
            value = (value * 10) + line[line_pos++] - '0';
        if (line[line_pos] == '.') {
            line_pos++;
            strcpy(name, "1");
        }
        lex = C_NUM;
        line_start = 0;
        return;
    }
    if (line[line_pos] == '$' && line_pos + 1 < line_size
        && isxdigit(line[line_pos + 1])) {  /* Hexadecimal number */
        value = 0;
        line_pos++;
        while (line_pos < line_size && isxdigit(line[line_pos])) {
            int temp;
            
            temp = toupper(line[line_pos]) - '0';
            if (temp > 9)
                temp -= 7;
            value = (value << 4) | temp;
            line_pos++;
        }
        if (line[line_pos] == '.') {
            line_pos++;
            strcpy(name, "1");
        }
        lex = C_NUM;
        line_start = 0;
        return;
    }
    if (line[line_pos] == '&' && line_pos + 1 < line_size
        && (line[line_pos + 1] == '0' || line[line_pos + 1] == '1')) {  /* Binary number */
        value = 0;
        line_pos++;
        while (line_pos < line_size && (line[line_pos] == '0' || line[line_pos] == '1')) {
            value = (value << 1) | (line[line_pos] & 1);
            line_pos++;
        }
        if (line[line_pos] == '.') {
            line_pos++;
            strcpy(name, "1");
        }
        lex = C_NUM;
        line_start = 0;
        return;
    }
    if (line[line_pos] == '"') {  /* String */
        line_pos++;
        p = name;
        while (line_pos < line_size && line[line_pos] != '"') {
            int c;
            int digits;
            
            if (line[line_pos] == '\\') {
                line_pos++;
                if (line_pos < line_size && (line[line_pos] == '"' || line[line_pos] == '\\')) {
                    c = line[line_pos++];
                } else {
                    c = 0;
                    digits = 0;
                    while (line_pos < line_size && isdigit(line[line_pos])) {
                        c = c * 10 + (line[line_pos] - '0');
                        line_pos++;
                        if (++digits == 3)
                            break;
                    }
                    if (c < 0)
                        c = 0;
                    if (c > 255)
                        c = 255;
                }
            } else {
                c = line[line_pos++];
            }
            if (p - name < MAX_LINE_SIZE - 1)
                *p++ = c;
        }
        *p = '\0';
        name_size = (int) (p - name);
        if (line_pos < line_size && line[line_pos] == '"') {
            line_pos++;
        } else {
            emit_error("unfinished string");
        }
        lex = C_STRING;
        line_start = 0;
        return;
    }
    line_start = 0;
    switch (line[line_pos]) {
        case '=':
            line_pos++;
            lex = C_EQUAL;
            break;
        case '+':
            line_pos++;
            lex = C_PLUS;
            break;
        case '-':
            line_pos++;
            lex = C_MINUS;
            break;
        case '(':
            line_pos++;
            lex = C_LPAREN;
            break;
        case ')':
            line_pos++;
            lex = C_RPAREN;
            break;
        case '<':
            line_pos++;
            lex = C_LESS;
            if (line[line_pos] == '=') {
                line_pos++;
                lex = C_LESSEQUAL;
            } else if (line[line_pos] == '>') {
                line_pos++;
                lex = C_NOTEQUAL;
            }
            break;
        case '>':
            line_pos++;
            lex = C_GREATER;
            if (line[line_pos] == '=') {
                line_pos++;
                lex = C_GREATEREQUAL;
            }
            break;
        case '*':
            line_pos++;
            lex = C_MUL;
            break;
        case '/':
            line_pos++;
            lex = C_DIV;
            break;
        case '%':
            line_pos++;
            lex = C_MOD;
            break;
        case ':':
            line_pos++;
            lex = C_COLON;
            break;
        case '.':
            line_pos++;
            lex = C_PERIOD;
            break;
        case ',':
            line_pos++;
            lex = C_COMMA;
            break;
        case '\'':
            line_pos = line_size;
            lex = C_END;
            break;
        default:
            line_pos++;
            lex = C_ERR;
            break;
    }
}

/*
 ** Check if explicit declaration is needed
 */
void check_for_explicit(char *name) {
    if (!option_explicit)
        return;
    sprintf(temp, "variable '%s' not defined previously", name);
    emit_error(temp);
}

/*
 ** Extend types
 **
 ** The signed flag propagates.
 */
int extend_types(struct node **node1, int type1, struct node **node2, int type2)
{
    int final_type;
    
    final_type = TYPE_16;   /* Promote to 16-bit */
    if ((type1 & MAIN_TYPE) == TYPE_8) {
        if (type1 & TYPE_SIGNED) {
            *node1 = node_create(N_EXTEND8S, 0, *node1, NULL);
        } else {
            *node1 = node_create(N_EXTEND8, 0, *node1, NULL);
        }
    }
    if (type1 & TYPE_SIGNED)
        final_type |= TYPE_SIGNED;
    if ((type2 & MAIN_TYPE) == TYPE_8) {
        if (type2 & TYPE_SIGNED) {
            *node2 = node_create(N_EXTEND8S, 0, *node2, NULL);
        } else {
            *node2 = node_create(N_EXTEND8, 0, *node2, NULL);
        }
    }
    if (type2 & TYPE_SIGNED)
        final_type |= TYPE_SIGNED;
    return final_type;
}

/*
 ** Mix types
 **
 ** The signed flag propagates.
 */
int mix_types(struct node **node1, int type1, struct node **node2, int type2)
{
    int c;
    
    c = (type1 & TYPE_SIGNED) | (type2 & TYPE_SIGNED);
    if ((type1 & MAIN_TYPE) == TYPE_8 && (type2 & MAIN_TYPE) == TYPE_8)   /* Both are 8-bit */
        return TYPE_8 | c;
    if ((type1 & MAIN_TYPE) == TYPE_16 && (type2 & MAIN_TYPE) == TYPE_16)   /* Both are 16-bit */
        return TYPE_16 | c;
    return extend_types(node1, type1, node2, type2);
}

/*
 ** Evaluates an expression for later usage.
 ** Result in A or HL.
 ** Doesn't need to propagate signed flag because the expression result is used immediately.
 */
struct node *evaluate_save_expression(int cast, int to_type)
{
    struct node *tree;
    int type;
    
    optimized = 0;
    tree = evaluate_level_0(&type);
    if (cast != 0) {
        if (to_type == TYPE_8 && (type & MAIN_TYPE) == TYPE_16) {
            tree = node_create(N_REDUCE16, 0, tree, NULL);
            type = TYPE_8;
        } else if (to_type == TYPE_16 && (type & MAIN_TYPE) == TYPE_8) {
            tree = node_create((type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, tree, NULL);
            type = TYPE_16;
        }
    }
    node_label(tree);
/*    node_visual(tree); */  /* Debugging */
    return tree;
}

int evaluate_expression(int cast, int to_type, int label)
{
    struct node *tree;
    int type;
    
    optimized = 0;
    tree = evaluate_level_0(&type);
    if (cast != 0) {
        if (to_type == TYPE_8 && (type & MAIN_TYPE) == TYPE_16) {
            tree = node_create(N_REDUCE16, 0, tree, NULL);
            type = TYPE_8;
        } else if (to_type == TYPE_16 && (type & MAIN_TYPE) == TYPE_8) {
            tree = node_create((type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, tree, NULL);
            type = TYPE_16;
        }
    }
    if (label != 0) {   /* Decision with 8-bit AND */
        if (tree->type == N_AND16 && tree->right->type == N_NUM16
            && (tree->right->value & ~0xff) == 0 && tree->left->type == N_LOAD16) {
            tree->left->type = N_LOAD8;
            tree->right->type = N_NUM8;
            tree->type = N_AND8;
            type = TYPE_8;
        }
    }
    if (label != 0 && (tree->type == N_NUM8 || tree->type == N_NUM16)) {
        if (tree->value == 0) {
            sprintf(temp, INTERNAL_PREFIX "%d", label);
            generic_jump(temp);     /* Jump over */
        } else {
            /* No code generated :) */
        }
        node_delete(tree);
        return type;
    }
    
    if (cast == 2)
        return type;
    node_label(tree);
    /*    node_visual(tree); */ /* Debugging */
    node_generate(tree, label);
    node_delete(tree);
    if (label != 0 && !optimized) {
        if ((type & MAIN_TYPE) == TYPE_8) {
            generic_test_8();
        } else {
            generic_test_16();
        }
        sprintf(temp, INTERNAL_PREFIX "%d", label);
        generic_jump_zero(temp);
    }
    return type;
}

/*
 ** Expression evaluation level 0 (OR)
 */
struct node *evaluate_level_0(int *type)
{
    struct node *left;
    struct node *right;
    int type2;
    
    left = evaluate_level_1(type);
    while (1) {
        if (lex == C_NAME && strcmp(name, "OR") == 0) {
            get_lex();
            right = evaluate_level_1(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_OR8, 0, left, right);
            else
                left = node_create(N_OR16, 0, left, right);
        } else {
            break;
        }
    }
    return left;
}

/*
 ** Expression evaluation level 1 (XOR)
 */
struct node *evaluate_level_1(int *type)
{
    struct node *left;
    struct node *right;
    int type2;
    
    left = evaluate_level_2(type);
    while (1) {
        if (lex == C_NAME && strcmp(name, "XOR") == 0) {
            get_lex();
            right = evaluate_level_2(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_XOR8, 0, left, right);
            else
                left = node_create(N_XOR16, 0, left, right);
        } else {
            break;
        }
    }
    return left;
}

/*
 ** Expression evaluation level 2 (AND)
 */
struct node *evaluate_level_2(int *type)
{
    struct node *left;
    struct node *right;
    int type2;
    
    left = evaluate_level_3(type);
    while (1) {
        if (lex == C_NAME && strcmp(name, "AND") == 0) {
            get_lex();
            right = evaluate_level_3(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_AND8, 0, left, right);
            else
                left = node_create(N_AND16, 0, left, right);
        } else {
            break;
        }
    }
    return left;
}

/*
 ** Expression evaluation level 3 (= <> < <= > >=)
 */
struct node *evaluate_level_3(int *type)
{
    struct node *left;
    struct node *right;
    int type2;
    enum node_type operation8;
    enum node_type operation16;
    enum node_type operation8s;
    enum node_type operation16s;

    left = evaluate_level_4(type);
    while (1) {
        if (lex == C_EQUAL) {
            operation8 = N_EQUAL8;
            operation16 = N_EQUAL16;
            operation8s = N_EQUAL8;
            operation16s = N_EQUAL16;
        } else if (lex == C_NOTEQUAL) {
            operation8 = N_NOTEQUAL8;
            operation16 = N_NOTEQUAL16;
            operation8s = N_NOTEQUAL8;
            operation16s = N_NOTEQUAL16;
        } else if (lex == C_LESS) {
            operation8 = N_LESS8;
            operation16 = N_LESS16;
            operation8s = N_LESS8S;
            operation16s = N_LESS16S;
        } else if (lex == C_LESSEQUAL) {
            operation8 = N_LESSEQUAL8;
            operation16 = N_LESSEQUAL16;
            operation8s = N_LESSEQUAL8S;
            operation16s = N_LESSEQUAL16S;
        } else if (lex == C_GREATER) {
            operation8 = N_GREATER8;
            operation16 = N_GREATER16;
            operation8s = N_GREATER8S;
            operation16s = N_GREATER16S;
        } else if (lex == C_GREATEREQUAL) {
            operation8 = N_GREATEREQUAL8;
            operation16 = N_GREATEREQUAL16;
            operation8s = N_GREATEREQUAL8S;
            operation16s = N_GREATEREQUAL16S;
        } else {
            break;
        }
        get_lex();
        right = evaluate_level_4(&type2);
        *type = mix_types(&left, *type, &right, type2);
        if ((*type & MAIN_TYPE) == TYPE_8)
            left = node_create(*type & TYPE_SIGNED ? operation8s : operation8, 0, left, right);
        else
            left = node_create(*type & TYPE_SIGNED ? operation16s : operation16, 0, left, right);
        *type = TYPE_8;
    }
    return left;
}

/*
 ** Expression evaluation level 4 (+ - )
 */
struct node *evaluate_level_4(int *type)
{
    struct node *left;
    struct node *right;
    int type2;
    
    left = evaluate_level_5(type);
    while (1) {
        if (lex == C_PLUS) {
            get_lex();
            right = evaluate_level_5(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_PLUS8, 0, left, right);
            else
                left = node_create(N_PLUS16, 0, left, right);
        } else if (lex == C_MINUS) {
            get_lex();
            right = evaluate_level_5(&type2);
            *type = mix_types(&left, *type, &right, type2);
            if ((*type & MAIN_TYPE) == TYPE_8)
                left = node_create(N_MINUS8, 0, left, right);
            else
                left = node_create(N_MINUS16, 0, left, right);
        } else {
            break;
        }
    }
    return left;
}

/*
 ** Expression evaluation level 5 (* / %)
 */
struct node *evaluate_level_5(int *type)
{
    struct node *left;
    struct node *right;
    int type2;
    
    left = evaluate_level_6(type);
    while (1) {
        if (lex == C_MUL) {
            get_lex();
            right = evaluate_level_6(&type2);
            *type = extend_types(&left, *type, &right, type2);
            left = node_create(N_MUL16, 0, left, right);
        } else if (lex == C_DIV) {
            get_lex();
            right = evaluate_level_6(&type2);
            *type = extend_types(&left, *type, &right, type2);
            if (*type & TYPE_SIGNED)
                left = node_create(N_DIV16S, 0, left, right);
            else
                left = node_create(N_DIV16, 0, left, right);
        } else if (lex == C_MOD) {
            get_lex();
            right = evaluate_level_6(&type2);
            *type = extend_types(&left, *type, &right, type2);
            if (*type & TYPE_SIGNED)
                left = node_create(N_MOD16S, 0, left, right);
            else
                left = node_create(N_MOD16, 0, left, right);
        } else {
            break;
        }
    }
    return left;
}

/*
 ** Expression evaluation level 6 (- NOT)
 */
struct node *evaluate_level_6(int *type)
{
    struct node *left;
    
    if (lex == C_MINUS) {
        get_lex();
        
        left = evaluate_level_7(type);
        if ((*type & MAIN_TYPE) == TYPE_8)
            left = node_create(N_NEG8, 0, left, NULL);
        else
            left = node_create(N_NEG16, 0, left, NULL);
    } else if (lex == C_NAME && strcmp(name, "NOT") == 0) {
        get_lex();
        
        left = evaluate_level_7(type);
        if ((*type & MAIN_TYPE) == TYPE_8)
            left = node_create(N_NOT8, 0, left, NULL);
        else
            left = node_create(N_NOT16, 0, left, NULL);
    } else {
        left = evaluate_level_7(type);
    }
    return left;
}

/*
 ** Expression evaluation level 7 (parenthesis, variables, and values)
 */
struct node *evaluate_level_7(int *type)
{
    struct node *tree;
    struct label *label;
    struct constant *constant;
    struct signedness *sign;
    
    if (lex == C_LPAREN) {
        get_lex();
        tree = evaluate_level_0(type);
        if (lex != C_RPAREN)
            emit_error("missing right parenthesis");
        else
            get_lex();
        return tree;
    }
    if (lex == C_STRING) {
        int temp;
        
        if (name_size == 0) {
            emit_error("empty string");
            temp = 0;
        } else {
            temp = name[0] & 0xff;
        }
        get_lex();
        *type = TYPE_8;
        return node_create(N_NUM8, temp, NULL, NULL);
    }
    if (lex == C_NAME) {
        if (strcmp(name, "INP") == 0) {
            get_lex();
            if (lex != C_LPAREN) {
                emit_error("missing left parenthesis in INP");
            }
            get_lex();
            tree = evaluate_level_0(type);
            if ((*type & MAIN_TYPE) == TYPE_8)
                tree = node_create((*type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, tree, NULL);
            tree = node_create(N_INP, 0, tree, NULL);
            if (lex != C_RPAREN) {
                emit_error("missing right parenthesis in INP");
            }
            get_lex();
            *type = TYPE_8;
            if ((machine == CREATIVISION)||(machine == TI994A))
                emit_warning("Ignoring INP (not supported in Creativision or TI994A)");
            return tree;
        }
        if (strcmp(name, "PEEK") == 0) {
            get_lex();
            if (lex != C_LPAREN) {
                emit_error("missing left parenthesis in PEEK");
            }
            get_lex();
            tree = evaluate_level_0(type);
            if ((*type & MAIN_TYPE) == TYPE_8)
                tree = node_create((*type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, tree, NULL);
            tree = node_create(N_PEEK8, 0, tree, NULL);
            if (lex != C_RPAREN) {
                emit_error("missing right parenthesis in PEEK");
            }
            get_lex();
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "VPEEK") == 0) {
            get_lex();
            if (lex != C_LPAREN) {
                emit_error("missing left parenthesis in VPEEK");
            }
            get_lex();
            tree = evaluate_level_0(type);
            if ((*type & MAIN_TYPE) == TYPE_8)
                tree = node_create((*type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, tree, NULL);
            tree = node_create(N_VPEEK, 0, tree, NULL);
            if (lex != C_RPAREN) {
                emit_error("missing right parenthesis in VPEEK");
            }
            get_lex();
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "ABS") == 0) {
            get_lex();
            if (lex != C_LPAREN)
                emit_error("missing left parenthesis in ABS");
            get_lex();
            tree = evaluate_level_0(type);
            if ((*type & MAIN_TYPE) == TYPE_8)
                tree = node_create((*type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, tree, NULL);
            tree = node_create(N_ABS16, 0, tree, NULL);
            if (lex != C_RPAREN) {
                emit_error("missing right parenthesis in ABS");
            }
            get_lex();
            *type = TYPE_16;    /* It is unsigned now */
            return tree;
        }
        if (strcmp(name, "SGN") == 0) {
            get_lex();
            if (lex != C_LPAREN)
                emit_error("missing left parenthesis in SGN");
            get_lex();
            tree = evaluate_level_0(type);
            if ((*type & MAIN_TYPE) == TYPE_8)
                tree = node_create((*type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, tree, NULL);
            tree = node_create(N_SGN16, 0, tree, NULL);
            if (lex != C_RPAREN) {
                emit_error("missing right parenthesis in SGN");
            }
            get_lex();
            *type = TYPE_16 | TYPE_SIGNED;
            return tree;
        }
        if (strcmp(name, "CONT") == 0) {
            get_lex();
            if (lex == C_PERIOD) {
                get_lex();
                if (lex != C_NAME) {
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    emit_error("CONT syntax error");
                } else if (strcmp(name, "UP") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_OR8, 0, tree, node_create(N_JOY2, 0, NULL, NULL));
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 1, NULL, NULL));
                } else if (strcmp(name, "RIGHT") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_OR8, 0, tree, node_create(N_JOY2, 0, NULL, NULL));
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 2, NULL, NULL));
                } else if (strcmp(name, "DOWN") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_OR8, 0, tree, node_create(N_JOY2, 0, NULL, NULL));
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 4, NULL, NULL));
                } else if (strcmp(name, "LEFT") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_OR8, 0, tree, node_create(N_JOY2, 0, NULL, NULL));
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 8, NULL, NULL));
                } else if (strcmp(name, "BUTTON") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_OR8, 0, tree, node_create(N_JOY2, 0, NULL, NULL));
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 0x40, NULL, NULL));
                } else if (strcmp(name, "BUTTON2") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_OR8, 0, tree, node_create(N_JOY2, 0, NULL, NULL));
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 0x80, NULL, NULL));
                } else if (strcmp(name, "KEY") == 0) {
                    get_lex();
                    tree = node_create(N_KEY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_KEY2, 0, NULL, NULL));
                } else {
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    emit_error("Wrong field for CONT");
                }
            } else {
                tree = node_create(N_JOY1, 0, NULL, NULL);
                tree = node_create(N_OR8, 0, tree, node_create(N_JOY2, 0, NULL, NULL));
            }
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "CONT1") == 0) {
            get_lex();
            if (lex == C_PERIOD) {
                get_lex();
                if (lex != C_NAME) {
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    emit_error("CONT1 syntax error");
                } else if (strcmp(name, "UP") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 1, NULL, NULL));
                } else if (strcmp(name, "RIGHT") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 2, NULL, NULL));
                } else if (strcmp(name, "DOWN") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 4, NULL, NULL));
                } else if (strcmp(name, "LEFT") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 8, NULL, NULL));
                } else if (strcmp(name, "BUTTON") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 0x40, NULL, NULL));
                } else if (strcmp(name, "BUTTON2") == 0) {
                    get_lex();
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 0x80, NULL, NULL));
                } else if (strcmp(name, "KEY") == 0) {
                    get_lex();
                    tree = node_create(N_KEY1, 0, NULL, NULL);
                } else {
                    emit_error("Wrong field for CONT1");
                    tree = node_create(N_JOY1, 0, NULL, NULL);
                }
            } else {
                tree = node_create(N_JOY1, 0, NULL, NULL);
            }
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "CONT2") == 0) {
            get_lex();
            if (lex == C_PERIOD) {
                get_lex();
                if (lex != C_NAME) {
                    emit_error("CONT2 syntax error");
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                } else if (strcmp(name, "UP") == 0) {
                    get_lex();
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 1, NULL, NULL));
                } else if (strcmp(name, "RIGHT") == 0) {
                    get_lex();
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 2, NULL, NULL));
                } else if (strcmp(name, "DOWN") == 0) {
                    get_lex();
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 4, NULL, NULL));
                } else if (strcmp(name, "LEFT") == 0) {
                    get_lex();
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 8, NULL, NULL));
                } else if (strcmp(name, "BUTTON") == 0) {
                    get_lex();
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 0x40, NULL, NULL));
                } else if (strcmp(name, "BUTTON2") == 0) {
                    get_lex();
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                    tree = node_create(N_AND8, 0, tree, node_create(N_NUM8, 0x80, NULL, NULL));
                } else if (strcmp(name, "KEY") == 0) {
                    get_lex();
                    tree = node_create(N_KEY2, 0, NULL, NULL);
                } else {
                    emit_error("Wrong field for CONT2");
                    tree = node_create(N_JOY2, 0, NULL, NULL);
                }
            } else {
                tree = node_create(N_JOY2, 0, NULL, NULL);
            }
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "RANDOM") == 0) {
            get_lex();
            if (lex == C_LPAREN) {
                get_lex();
                tree = evaluate_level_0(type);
                if ((*type & MAIN_TYPE) == TYPE_8)
                    tree = node_create(N_EXTEND8, 0, tree, NULL);
                tree = node_create(N_MOD16, 0, node_create(N_RANDOM, 0, NULL, NULL), tree);
                if (lex != C_RPAREN) {
                    emit_error("missing right parenthesis in RANDOM");
                }
                get_lex();
            } else {
                tree = node_create(N_RANDOM, 0, NULL, NULL);
            }
            *type = TYPE_16;
            return tree;
        }
        if (strcmp(name, "FRAME") == 0) {
            get_lex();
            tree = node_create(N_FRAME, 0, NULL, NULL);
            *type = TYPE_16;
            return tree;
        }
        if (strcmp(name, "MUSIC") == 0) {
            get_lex();
            if (lex != C_PERIOD) {
                emit_error("missing period in MUSIC");
            } else {
                get_lex();
            }
            if (lex != C_NAME || strcmp(name, "PLAYING") != 0) {
                emit_error("only allowed MUSIC.PLAYING");
            } else {
                get_lex();
            }
            tree = node_create(N_MUSIC, 0, NULL, NULL);
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "VDP") == 0) {
            get_lex();
            if (lex != C_PERIOD) {
                emit_error("missing period in VDP");
            } else {
                get_lex();
            }
            if (lex != C_NAME || strcmp(name, "STATUS") != 0) {
                emit_error("only allowed VDP.STATUS");
            } else {
                get_lex();
            }
            tree = node_create(N_VDPSTATUS, 0, NULL, NULL);
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "NTSC") == 0) {
            get_lex();
            tree = node_create(N_NTSC, 0, NULL, NULL);
            *type = TYPE_8;
            return tree;
        }
        if (strcmp(name, "USR") == 0) {  /* Call to function written in assembler */
            get_lex();
            tree = process_usr(0);
            *type = TYPE_16;
            return tree;
        }
        if (strcmp(name, "VARPTR") == 0) {  /* Access to variable/array/label address */
            *type = TYPE_16;
            get_lex();
            if (lex != C_NAME) {
                emit_error("missing variable name for VARPTR");
                return node_create(N_NUM16, 0, NULL, NULL);
            }
            if (lex_sneak_peek() == '(') {  /* Indexed access */
                int type2;
                struct node *addr;

                label = array_search(name);
                if (label != NULL) {    /* Found array */
                } else {
                    label = label_search(name);
                    if (label != NULL) {
                        if (label->used & LABEL_IS_VARIABLE) {
                            emit_error("using array but not defined");
                        }
                    } else {
                        label = label_add(name);
                    }
                }
                get_lex();
                if (lex != C_LPAREN)
                    emit_error("missing left parenthesis in array access");
                else
                    get_lex();
                tree = evaluate_level_0(&type2);
                if (lex != C_RPAREN)
                    emit_error("missing right parenthesis in array access");
                else
                    get_lex();
                addr = node_create(N_ADDR, 0, NULL, NULL);
                addr->label = label;
                if ((type2 & MAIN_TYPE) == TYPE_8)
                    tree = node_create(N_EXTEND8, 0, tree, NULL);
                if (label->name[0] == '#') {
                    tree = node_create(N_MUL16, 0, tree,
                                       node_create(N_NUM16, 2, NULL, NULL));
                }
                return node_create(N_PLUS16, 0, addr, tree);
            }
            constant = constant_search(name);
            if (constant != NULL) {
                emit_error("constants doesn't have address for VARPTR");
                get_lex();
                return node_create(N_NUM16, 0, NULL, NULL);
            }
            label = label_search(name);
            if (label != NULL && (label->used & LABEL_IS_VARIABLE) == 0) {
                char buffer[MAX_LINE_SIZE];
                
                sprintf(buffer, "variable name '%s' already defined with other purpose", name);
                emit_error(buffer);
                label = NULL;
            }
            if (label == NULL) {
                check_for_explicit(name);
                label = label_add(name);
                if (name[0] == '#')
                    label->used = TYPE_16;
                else
                    label->used = TYPE_8;
                label->used |= LABEL_IS_VARIABLE;
            }
            get_lex();
            tree = node_create(N_ADDR, 0, NULL, NULL);
            tree->label = label;
            return tree;
        }
        if (strcmp(name, "LEN") == 0) { /* Access to string length */
            int c;
            
            get_lex();
            if (lex != C_LPAREN)
                emit_error("missing left parenthesis in LEN");
            else
                get_lex();
            if (lex != C_STRING) {
                c = 0;
                emit_error("missing string inside LEN");
            } else {
                c = name_size;
                get_lex();
            }
            if (lex != C_RPAREN)
                emit_error("missing right parenthesis in LEN");
            else
                get_lex();
            return node_create(N_NUM16, c, NULL, NULL);
        }
        if (strcmp(name, "POS") == 0) { /* Access to current screen position */
            int type2;
            
            get_lex();
            if (lex != C_LPAREN)
                emit_error("missing left parenthesis in POS");
            else
                get_lex();
            tree = evaluate_level_0(&type2);
            node_delete(tree);
            if (lex != C_RPAREN)
                emit_error("missing right parenthesis in POS");
            else
                get_lex();
            *type = TYPE_16;
            return node_create(N_MINUS16, 0, node_create(N_POS, 0, NULL, NULL), node_create(N_NUM16, 0x1800, NULL, NULL));
        }
        if (macro_search(name) != NULL) {  /* Function (macro) */
            if (replace_macro())
                return node_create(N_NUM8, 0, NULL, NULL);
            return evaluate_level_0(type);
        }
        if (lex_sneak_peek() == '(') {  /* Indexed access */
            int type2;
            struct node *addr;
            struct signedness *sign;
            
            if (name[0] == '#')
                *type = TYPE_16;
            else
                *type = TYPE_8;
            sign = signed_search(name);
            if (sign != NULL && sign->sign == 1)
                *type |= TYPE_SIGNED;
            label = array_search(name);
            if (label != NULL) {    /* Found array */
            } else {
                label = label_search(name);
                if (label != NULL) {
                    if (label->used & LABEL_IS_VARIABLE) {
                        emit_error("using array but not defined");
                    }
                } else {
                    label = label_add(name);
                }
            }
            get_lex();
            if (lex != C_LPAREN)
                emit_error("missing left parenthesis in array access");
            else
                get_lex();
            tree = evaluate_level_0(&type2);
            if (lex != C_RPAREN)
                emit_error("missing right parenthesis in array access");
            else
                get_lex();
            addr = node_create(N_ADDR, 0, NULL, NULL);
            addr->label = label;
            if ((type2 & MAIN_TYPE) == TYPE_8) {
                tree = node_create(N_EXTEND8, 0, tree, NULL);
            }
            if ((*type & MAIN_TYPE) == TYPE_16) {
                tree = node_create(N_MUL16, 0, tree,
                                   node_create(N_NUM16, 2, NULL, NULL));
            }
            tree = node_create(*type == TYPE_16 ? N_PEEK16 : N_PEEK8, 0,
                               node_create(N_PLUS16, 0, addr, tree), NULL);
            return tree;
        }
        constant = constant_search(name);
        if (constant != NULL) {
            get_lex();
            if (constant->name[0] == '#') {
                *type = TYPE_16;
                return node_create(N_NUM16, constant->value & 0xffff, NULL, NULL);
            }
            *type = TYPE_8;
            return node_create(N_NUM8, constant->value & 0xff, NULL, NULL);
        }
        sign = signed_search(name);
        if (sign != NULL && sign->sign == 1)
            *type = TYPE_SIGNED;
        else
            *type = 0;
        label = label_search(name);
        if (label != NULL && (label->used & LABEL_IS_VARIABLE) == 0) {
            char buffer[MAX_LINE_SIZE];
            
            sprintf(buffer, "variable name '%s' already defined with other purpose", name);
            emit_error(buffer);
            label = NULL;
        }
        if (label == NULL) {
            check_for_explicit(name);
            label = label_add(name);
            if (name[0] == '#')
                label->used = TYPE_16;
            else
                label->used = TYPE_8;
            label->used |= LABEL_IS_VARIABLE;
        }
        label->used |= LABEL_VAR_READ;
        *type |= label->used & MAIN_TYPE;
        get_lex();
        if ((*type & MAIN_TYPE) == TYPE_8)
            tree = node_create(N_LOAD8, 0, NULL, NULL);
        else
            tree = node_create(N_LOAD16, 0, NULL, NULL);
        tree->label = label;
        return tree;
    }
    if (lex == C_NUM) {
        int temp;
        
        temp = value;
        if (name[0] == '1') {
            get_lex();
            *type = TYPE_8;
            return node_create(N_NUM8, temp & 0xff, NULL, NULL);
        }
        get_lex();
        *type = TYPE_16;
        return node_create(N_NUM16, temp & 0xffff, NULL, NULL);
    }
    emit_error("bad syntax por expression");
    *type = TYPE_16;
    return node_create(N_NUM16, 0, NULL, NULL);
}

/*
** Process call to assembly language
*/
struct node *process_usr(int is_call)
{
    struct node *tree;
    struct node *list;
    struct node *last_list;
    int c;
    struct label *function;
    int type2;
    
    if (lex != C_NAME) {
        if (is_call)
            emit_error("missing function name in CALL");
        else
            emit_error("missing function name in USR");
    }
    function = function_search(name);
    if (function == NULL)
        function = function_add(name);
    get_lex();
    tree = NULL;
    list = NULL;
    last_list = NULL;
    c = 0;
    if (lex == C_LPAREN) {
        get_lex();
        while (1) {
            tree = evaluate_level_0(&type2);
            if ((type2 & MAIN_TYPE) == TYPE_8)
                tree = node_create((type2 & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, tree, NULL);
            tree = node_create(N_COMMA, 0, tree, NULL);
            if (list == NULL) {
                list = tree;
            } else {
                last_list->right = tree;
            }
            last_list = tree;
            c++;
            if (lex != C_COMMA)
                break;
            get_lex();
        }
        if (lex == C_RPAREN)
            get_lex();
        else
            emit_error("missing right parenthesis");
    }
    if (c > 1 && target != CPU_Z80)
        emit_error("more than one argument for USR (non-Z80 target)");
    else if (c > 5 && target == CPU_Z80)
        emit_error("more than five arguments for USR (Z80 target)");
    tree = node_create(N_USR, c, list, NULL);
    tree->label = function;
    return tree;
}

/*
 ** Push into the lexical analyzer buffer
 */
void accumulated_push(enum lexical_component lex, int value, char *name)
{
    if (accumulated.length >= accumulated.max_length) {
        accumulated.definition = realloc(accumulated.definition, (accumulated.max_length + 1) * 2 * sizeof(struct macro_def));
        if (accumulated.definition == NULL) {
            emit_error("out of memory in accumulated_push");
            exit(1);
        }
        accumulated.max_length = (accumulated.max_length + 1) * 2;
    }
    accumulated.definition[accumulated.length].lex = lex;
    accumulated.definition[accumulated.length].value = value;
    accumulated.definition[accumulated.length].name = malloc(strlen(name) + 1);
    if (accumulated.definition[accumulated.length].name == NULL) {
        emit_error("out of memory in accumulated_push");
        exit(1);
    }
    strcpy(accumulated.definition[accumulated.length].name, name);
    accumulated.length++;
}

/*
** Replace a macro
*/
int replace_macro(void)
{
    struct macro *macro;
    char function[MAX_LINE_SIZE];
    int total_arguments;
    int c;
    int d;
    int level;
    struct macro_arg *argument;
    
    strcpy(function, name);
    macro = macro_search(function);
    get_lex();
    if (macro->in_use) {
        emit_error("Recursion in FN name");
        return 1;
    }
    macro->in_use = 1;
    total_arguments = macro->total_arguments;
    if (total_arguments > 0) {
        argument = calloc(total_arguments, sizeof(struct macro_arg));
        if (argument == NULL) {
            emit_error("out of memory in call to FN");
            return 1;
        }
        if (lex != C_LPAREN) {
            emit_error("missing left parenthesis in call to FN");
            return 1;
        }
        get_lex();
        c = 0;
        level = 0;
        while (c < total_arguments) {
            while (1) {
                if (level == 0 && (lex == C_RPAREN || lex == C_COMMA))
                    break;
                if (lex == C_END)   /* Avoid possibility of being stuck */
                    break;
                if (lex == C_LPAREN)
                    level++;
                if (lex == C_RPAREN)
                    level--;
                if (argument[c].length >= argument[c].max_length) {
                    argument[c].definition = realloc(argument[c].definition, (argument[c].max_length + 1) * 2 * sizeof(struct macro_def));
                    if (argument[c].definition == NULL) {
                        emit_error("out of memory in call to FN");
                        return 1;
                    }
                    argument[c].max_length = (argument[c].max_length + 1) * 2;
                }
                argument[c].definition[argument[c].length].lex = lex;
                argument[c].definition[argument[c].length].value = value;
                argument[c].definition[argument[c].length].name = malloc(strlen(name) + 1);
                if (argument[c].definition[argument[c].length].name == NULL) {
                    emit_error("out of memory in call to FN");
                    return 1;
                }
                strcpy(argument[c].definition[argument[c].length].name, name);
                argument[c].length++;
                get_lex();
            }
            if (lex == C_COMMA && c + 1 < total_arguments) {
                get_lex();
                c++;
                continue;
            }
            if (lex == C_RPAREN && c + 1 == total_arguments) {
                get_lex();
                break;
            }
            emit_error("syntax error in call to FN");
            break;
        }
    } else {
        argument = NULL;
    }
    accumulated_push(lex, value, name); /* The actual one for later */
    
    /*
     ** Push macro into lexical analyzer
     */
    for (c = macro->length - 1; c >= 0; c--) {
        if (macro->definition[c].lex == C_ERR) {
            struct macro_arg *arg;
            
            arg = &argument[macro->definition[c].value];
            for (d = arg->length - 1; d >= 0; d--) {
                accumulated_push(arg->definition[d].lex, arg->definition[d].value, arg->definition[d].name);
            }
        } else {
            accumulated_push(macro->definition[c].lex, macro->definition[c].value, macro->definition[c].name);
        }
    }
    for (c = 0; c < total_arguments; c++)
        free(argument[c].definition);
    c = --accumulated.length;
    lex = accumulated.definition[c].lex;
    value = accumulated.definition[c].value;
    strcpy(name, accumulated.definition[c].name);
    free(accumulated.definition[c].name);
    macro->in_use = 0;
    return 0;
}

/*
 ** Compile an assignment
 */
void compile_assignment(int is_read)
{
    struct node *tree;
    struct node *var;
    int type;
    int type2;
    struct label *label;
    struct signedness *sign;
    
    if (lex != C_NAME) {
        emit_error("name required for assignment");
        return;
    }
    if (lex_sneak_peek() == '(') {  /* Indexed access */
        int type2;
        struct node *addr;
        
        if (name[0] == '#')
            type2 = TYPE_16;
        else
            type2 = TYPE_8;
        sign = signed_search(name);
        if (sign != NULL && sign->sign == 1)
            type2 |= TYPE_SIGNED;
        label = array_search(name);
        if (label == NULL) {    /* Found array */
            emit_error("using array without previous DIM, autoassigning DIM(10)");
            label = array_add(name);
            label->length = 10;
        }
        get_lex();
        if (lex != C_LPAREN)
            emit_error("missing left parenthesis in array access");
        else
            get_lex();
        tree = evaluate_level_0(&type);
        if (lex != C_RPAREN)
            emit_error("missing right parenthesis in array access");
        else
            get_lex();
        addr = node_create(N_ADDR, 0, NULL, NULL);
        addr->label = label;
        if ((type & MAIN_TYPE) == TYPE_8)
            tree = node_create(N_EXTEND8, 0, tree, NULL);
        if ((type2 & MAIN_TYPE) == TYPE_16) {
            tree = node_create(N_MUL16, 0, tree,
                               node_create(N_NUM16, 2, NULL, NULL));
        }
        addr = node_create(N_PLUS16, 0, addr, tree);
        if (is_read) {
            tree = node_create(is_read == 1 ? N_READ16 : N_READ8, 0, NULL, NULL);
            type = is_read == 1 ? TYPE_16 : TYPE_8;
        } else {
            if (lex != C_EQUAL) {
                emit_error("required '=' for assignment");
                return;
            }
            get_lex();
            tree = evaluate_level_0(&type);
        }
        if ((type2 & MAIN_TYPE) == TYPE_16 && (type & MAIN_TYPE) == TYPE_8)
            tree = node_create((type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, tree, NULL);
        else if ((type2 & MAIN_TYPE) == TYPE_8 && (type & MAIN_TYPE) == TYPE_16)
            tree = node_create(N_REDUCE16, 0, tree, NULL);
        if ((type2 & MAIN_TYPE) == TYPE_16)
            tree = node_create(N_ASSIGN16, 0, tree, addr);
        else if ((type2 & MAIN_TYPE) == TYPE_8)
            tree = node_create(N_ASSIGN8, 0, tree, addr);
        tree->label = label;
        node_label(tree);
/*        node_visual(tree); */ /* @@@ debugging */
        node_generate(tree, 0);
        node_delete(tree);
        return;
    }
    strcpy(assigned, name);
    sign = signed_search(name);
    if (sign != NULL && sign->sign == 1)
        type2 = TYPE_SIGNED;
    else
        type2 = 0;
    label = label_search(name);
    if (label != NULL && (label->used & LABEL_IS_VARIABLE) == 0) {
        char buffer[MAX_LINE_SIZE];
        
        sprintf(buffer, "variable name '%s' already defined with other purpose", name);
        emit_error(buffer);
        label = NULL;
    }
    if (label == NULL) {
        check_for_explicit(name);
        label = label_add(name);
        if (name[0] == '#')
            label->used = TYPE_16;
        else
            label->used = TYPE_8;
        label->used |= LABEL_IS_VARIABLE;
    }
    label->used |= LABEL_VAR_WRITE;
    type2 |= label->used & MAIN_TYPE;
    get_lex();
    if (is_read) {
        tree = node_create(is_read == 1 ? N_READ16 : N_READ8, 0, NULL, NULL);
        type = is_read == 1 ? TYPE_16 : TYPE_8;
    } else {
        if (lex != C_EQUAL) {
            emit_error("required '=' for assignment");
            return;
        }
        get_lex();
        tree = evaluate_level_0(&type);
    }
    if ((type2 & MAIN_TYPE) == TYPE_16 && (type & MAIN_TYPE) == TYPE_8)
        tree = node_create((type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, tree, NULL);
    else if ((type2 & MAIN_TYPE) == TYPE_8 && (type & MAIN_TYPE) == TYPE_16)
        tree = node_create(N_REDUCE16, 0, tree, NULL);
    var = node_create(N_ADDR, 0, NULL, NULL);
    var->label = label_search(label->name);
    tree = node_create((type2 & MAIN_TYPE) == TYPE_8 ? N_ASSIGN8 : N_ASSIGN16, 0, tree, var);
    node_label(tree);
    node_generate(tree, 0);
    node_delete(tree);
}

/*
 ** Compile a statement
 */
void compile_statement(int check_for_else)
{
    struct label *label;
    int type;
    
    while (1) {
        if (lex == C_NAME) {
            last_is_return = 0;
            if (strcmp(name, "GOTO") == 0) {
                get_lex();
                if (lex != C_NAME) {
                    emit_error("bad syntax for GOTO");
                } else {
                    label = label_search(name);
                    if (label == NULL) {
                        label = label_add(name);
                    }
                    label->used |= LABEL_USED;
                    label->used |= LABEL_CALLED_BY_GOTO;
                    strcpy(temp, LABEL_PREFIX);
                    strcat(temp, name);
                    generic_jump(temp);
                    get_lex();
                }
            } else if (strcmp(name, "GOSUB") == 0) {
                get_lex();
                if (lex != C_NAME) {
                    emit_error("bad syntax for GOSUB");
                } else {
                    label = label_search(name);
                    if (label == NULL) {
                        label = label_add(name);
                    }
                    label->used |= LABEL_USED;
                    label->used |= LABEL_CALLED_BY_GOSUB;
                    strcpy(temp, LABEL_PREFIX);
                    strcat(temp, name);
                    generic_call(temp);
                    get_lex();
                }
            } else if (strcmp(name, "RETURN") == 0) {
                get_lex();
                generic_return();
                last_is_return = 1;
            } else if (strcmp(name, "IF") == 0) {
                int type;
                int label;
                int there_is_else;
                int label2;
                struct loop *new_loop;
                int block;
                
                get_lex();
                label = next_local++;
                type = evaluate_expression(0, 0, label);
                if (lex == C_NAME && strcmp(name, "GOTO") == 0) {
                    compile_statement(FALSE);
                    block = 0;
                } else if (lex != C_NAME || strcmp(name, "THEN") != 0) {
                    emit_error("missing THEN in IF");
                    block = 0;
                } else {
                    get_lex();
                    if (lex == C_END) {
                        block = 1;
                        new_loop = malloc(sizeof(struct loop));
                        if (new_loop == NULL) {
                            fprintf(stderr, "out of memory\n");
                            exit(1);
                        }
                        new_loop->type = NESTED_IF;
                        new_loop->step = NULL;
                        new_loop->final = NULL;
                        new_loop->var[0] = 0;
                        new_loop->label_loop = label;
                        new_loop->label_exit = 0;
                        new_loop->next = loops;
                        loops = new_loop;
                    } else {
                        compile_statement(TRUE);
                        block = 0;
                    }
                }
                if (block) {
                    last_is_return = 0;
                    break;
                }
                if (lex == C_NAME && strcmp(name, "ELSE") == 0) {
                    there_is_else = 1;
                    get_lex();
                    label2 = next_local++;
                    sprintf(temp, INTERNAL_PREFIX "%d", label2);
                    generic_jump(temp);
                } else {
                    there_is_else = 0;
                    label2 = 0;
                }
                sprintf(temp, INTERNAL_PREFIX "%d", label);
                generic_label(temp);
                if (there_is_else) {
                    compile_statement(TRUE);
                    sprintf(temp, INTERNAL_PREFIX "%d", label2);
                    generic_label(temp);
                }
                last_is_return = 0;
            } else if (strcmp(name, "ELSEIF") == 0) {
                int type;
                
                get_lex();
                if (loops == NULL) {
                    emit_error("ELSEIF without IF");
                } else if (loops->type != NESTED_IF || loops->label_loop == 0) {
                    emit_error("bad nested ELSEIF");
                } else {
                    if (loops->var[0] != 1) {
                        loops->label_exit = next_local++;
                        loops->var[0] = 1;
                    }
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                    generic_jump(temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                    generic_label(temp);
                    loops->label_loop = next_local++;
                    type = evaluate_expression(0, 0, loops->label_loop);
                    if (lex == C_NAME && strcmp(name, "GOTO") == 0) {
                        compile_statement(FALSE);
                    } else if (lex != C_NAME || strcmp(name, "THEN") != 0) {
                        emit_error("missing THEN in ELSEIF");
                    } else {
                        get_lex();
                    }
                }
                if (lex == C_END)
                    break;
                continue;
            } else if (strcmp(name, "ELSE") == 0) {
                if (check_for_else)
                    break;
                get_lex();
                if (loops == NULL) {
                    emit_error("ELSE without IF");
                } else if (loops->type != NESTED_IF) {
                    emit_error("bad nested ELSE");
                } else if (loops->label_loop == 0) {
                    emit_error("more than one ELSE");
                } else {
                    if (loops->var[0] != 1) {
                        loops->label_exit = next_local++;
                        loops->var[0] = 1;
                    }
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                    generic_jump(temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                    generic_label(temp);
                    loops->label_loop = 0;
                }
                if (lex == C_END)
                    break;
                continue;
            } else if (strcmp(name, "END") == 0) {
                struct loop *popping;
                
                get_lex();
                if (lex == C_NAME && strcmp(name, "IF") == 0) {
                    get_lex();
                    if (loops == NULL || loops->type != NESTED_IF) {
                        emit_error("Bad nested END IF");
                    } else {
                        if (loops->var[0] == 1) {
                            sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                            generic_label(temp);
                        }
                        if (loops->label_loop != 0) {
                            sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                            generic_label(temp);
                        }
                        popping = loops;
                        loops = loops->next;
                        free(popping);
                    }
                } else if (lex == C_NAME && strcmp(name, "SELECT") == 0) {
                    get_lex();
                    if (loops == NULL || loops->type != NESTED_SELECT) {
                        emit_error("Bad nested END SELECT");
                    } else {
                        if (loops->label_loop != 0) {
                            sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                            generic_label(temp);
                        }
                        sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                        generic_label(temp);
                        popping = loops;
                        loops = loops->next;
                        free(popping);
                    }
                } else {
                    emit_error("wrong END");
                }
            } else if (strcmp(name, "FOR") == 0) {
                struct label *label;
                struct loop *new_loop;
                int label_loop;
                struct node *final = NULL;
                struct node *step = NULL;
                struct node *var;
                int positive;
                int type;
                int step_value;
                int type_var;
                enum node_type comparison;
                struct signedness *sign;
                
                get_lex();
                compile_assignment(0);
                
                /* Avoid unnecessary warnings */
                label = label_search(assigned);
                if (label != NULL && (label->used & LABEL_IS_VARIABLE) != 0)
                    label->used |= LABEL_VAR_READ;
                
                new_loop = malloc(sizeof(struct loop) + strlen(assigned) + 1);
                if (new_loop == NULL) {
                    fprintf(stderr, "Out of memory\n");
                    exit(1);
                }
                strcpy(new_loop->var, assigned);
                if (assigned[0] == '#')
                    type_var = TYPE_16;
                else
                    type_var = TYPE_8;
                sign = signed_search(assigned);
                if (sign != NULL && sign->sign == 1)
                    type_var |= TYPE_SIGNED;
                label_loop = next_local++;
                sprintf(temp, INTERNAL_PREFIX "%d", label_loop);
                generic_label(temp);
                if (lex != C_NAME || strcmp(name, "TO") != 0) {
                    emit_error("missing TO in FOR");
                } else {
                    get_lex();
                    final = evaluate_level_0(&type);
                    if ((type_var & MAIN_TYPE) == TYPE_16 && (type & MAIN_TYPE) == TYPE_8)
                        final = node_create((type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, final, NULL);
                    else if ((type_var & MAIN_TYPE) == TYPE_8 && (type & MAIN_TYPE) == TYPE_16)
                        final = node_create(N_REDUCE16, 0, final, NULL);
                    positive = 1;
                    var = node_create((type_var & MAIN_TYPE) == TYPE_16 ? N_LOAD16 : N_LOAD8, 0, NULL, NULL);
                    var->label = label_search(new_loop->var);
                    if (lex == C_NAME && strcmp(name, "STEP") == 0) {
                        get_lex();
                        if (lex == C_MINUS) {
                            get_lex();
                            step = evaluate_level_0(&type);
                            if ((type_var & MAIN_TYPE) == TYPE_16 && (type & MAIN_TYPE) == TYPE_8)
                                step = node_create((type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, step, NULL);
                            else if ((type_var & MAIN_TYPE) == TYPE_8 && (type & MAIN_TYPE) == TYPE_16)
                                step = node_create(N_REDUCE16, 0, step, NULL);
                            step = node_create((type_var & MAIN_TYPE) == TYPE_16 ? N_MINUS16 : N_MINUS8, 0,
                                            var, step);
                            positive = 0;
                        } else {
                            step = evaluate_level_0(&type);
                            if ((type_var & MAIN_TYPE) == TYPE_16 && (type & MAIN_TYPE) == TYPE_8)
                                step = node_create((type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, step, NULL);
                            else if ((type_var & MAIN_TYPE) == TYPE_8 && (type & MAIN_TYPE) == TYPE_16)
                                step = node_create(N_REDUCE16, 0, step, NULL);
                            step = node_create((type_var & MAIN_TYPE) == TYPE_16 ? N_PLUS16 : N_PLUS8, 0, var, step);
                        }
                    } else {
                        step_value = 1;
                        step = node_create((type_var & MAIN_TYPE) == TYPE_16 ? N_NUM16 : N_NUM8, 1, NULL, NULL);
                        step = node_create((type_var & MAIN_TYPE) == TYPE_16 ? N_PLUS16 : N_PLUS8, 0, var, step);
                    }
                    var = node_create(N_ADDR, 0, NULL, NULL);
                    var->label = label_search(new_loop->var);
                    step = node_create((type_var & MAIN_TYPE) == TYPE_16 ? N_ASSIGN16 : N_ASSIGN8, 0, step, var);
                    var = node_create((type_var & MAIN_TYPE) == TYPE_16 ? N_LOAD16 : N_LOAD8, 0, NULL, NULL);
                    var->label = label_search(new_loop->var);
                    if ((type_var & MAIN_TYPE) == TYPE_16) {
                        if (type_var & TYPE_SIGNED)
                            comparison = positive ? N_GREATER16S : N_LESS16S;
                        else
                            comparison = positive ? N_GREATER16 : N_LESS16;
                    } else {
                        if (type_var & TYPE_SIGNED)
                            comparison = positive ? N_GREATER8S : N_LESS8S;
                        else
                            comparison = positive ? N_GREATER8 : N_LESS8;
                    }
                    final = node_create(comparison, 0, var, final);
                }
                new_loop->type = NESTED_FOR;
                new_loop->step = step;
                new_loop->final = final;
                new_loop->label_loop = label_loop;
                new_loop->label_exit = 0;
                new_loop->next = loops;
                loops = new_loop;
            } else if (strcmp(name, "NEXT") == 0) {
                struct loop *popping;
                
                get_lex();
                if (loops == NULL) {
                    emit_error("NEXT without FOR");
                } else {
                    struct node *final = loops->final;
                    struct node *step = loops->step;
                    int label_loop = loops->label_loop;
                    int label_exit = loops->label_exit;
                    
                    if (loops->type != NESTED_FOR) {
                        emit_error("bad nested NEXT");
                        if (lex == C_NAME)
                            get_lex();
                    } else {
                        if (lex == C_NAME) {
                            if (strcmp(name, loops->var) != 0)
                                emit_error("bad nested NEXT");
                            get_lex();
                        }
                        node_label(step);
                        node_generate(step, 0);
                        if (final != NULL) {
                            optimized = 0;
                            node_label(final);
                            node_generate(final, label_loop);
                            if (!optimized) {
                                generic_test_8();
                                sprintf(temp, INTERNAL_PREFIX "%d", label_loop);
                                generic_jump_zero(temp);
                            }
                            node_delete(final);
                        }
                        node_delete(step);
                        if (label_exit != 0) {
                            sprintf(temp, INTERNAL_PREFIX "%d", label_exit);
                            generic_label(temp);
                        }
                        popping = loops;
                        loops = loops->next;
                        free(popping);
                    }
                }
            } else if (strcmp(name, "WHILE") == 0) {
                int label_loop;
                int label_exit;
                int type;
                struct loop *new_loop;
                
                get_lex();
                label_loop = next_local++;
                label_exit = next_local++;
                sprintf(temp, INTERNAL_PREFIX "%d", label_loop);
                generic_label(temp);
                type = evaluate_expression(0, 0, label_exit);
                new_loop = malloc(sizeof(struct loop));
                if (new_loop == NULL) {
                    fprintf(stderr, "Out of memory\n");
                    exit(1);
                }
                new_loop->type = NESTED_WHILE;
                new_loop->step = NULL;
                new_loop->final = NULL;
                new_loop->var[0] = '\0';
                new_loop->label_loop = label_loop;
                new_loop->label_exit = label_exit;
                new_loop->next = loops;
                loops = new_loop;
            } else if (strcmp(name, "WEND") == 0) {
                struct loop *popping;
                
                get_lex();
                if (loops == NULL) {
                    emit_error("WEND without WHILE");
                } else if (loops->type != NESTED_WHILE) {
                    emit_error("bad nested WEND");
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                    generic_jump(temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                    generic_label(temp);
                    popping = loops;
                    loops = loops->next;
                    free(popping);
                }
            } else if (strcmp(name, "DO") == 0) {
                int label_loop;
                int label_exit;
                int type;
                struct loop *new_loop;
                
                get_lex();
                label_loop = next_local++;
                label_exit = next_local++;
                sprintf(temp, INTERNAL_PREFIX "%d", label_loop);
                generic_label(temp);
                new_loop = malloc(sizeof(struct loop));
                if (new_loop == NULL) {
                    fprintf(stderr, "Out of memory\n");
                    exit(1);
                }
                if (lex == C_NAME && strcmp(name, "WHILE") == 0) {
                    get_lex();
                    type = evaluate_expression(0, 0, label_exit);
                    new_loop->var[0] = '1'; /* Uses exit label */
                    new_loop->type = NESTED_DO;     /* Condition at top */
                } else if (lex == C_NAME && strcmp(name, "UNTIL") == 0) {
                    int label_temp = next_local++;
                    
                    get_lex();
                    type = evaluate_expression(0, 0, label_temp);
                    /* Let optimizer to solve this =P */
                    sprintf(temp, INTERNAL_PREFIX "%d", label_exit);
                    generic_jump(temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", label_temp);
                    generic_label(temp);
                    new_loop->var[0] = '1'; /* Uses exit label */
                    new_loop->type = NESTED_DO;  /* Condition at top */
                } else {
                    new_loop->var[0] = '\0'; /* Doesn't use exit label (yet) */
                    new_loop->type = NESTED_DO_LOOP;  /* Condition at bottom */
                }
                new_loop->step = NULL;
                new_loop->final = NULL;
                new_loop->label_loop = label_loop;
                new_loop->label_exit = label_exit;
                new_loop->next = loops;
                loops = new_loop;
            } else if (strcmp(name, "LOOP") == 0) {
                struct loop *popping;
                
                get_lex();
                if (loops == NULL) {
                    emit_error("LOOP without DO");
                } else if (loops->type == NESTED_DO) {
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                    generic_jump(temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                    generic_label(temp);
                    popping = loops;
                    loops = loops->next;
                    free(popping);
                } else if (loops->type == NESTED_DO_LOOP) {
                    int type;
                    
                    if (lex == C_NAME && strcmp(name, "WHILE") == 0) {
                        int label_temp = next_local++;
                        
                        get_lex();
                        type = evaluate_expression(0, 0, label_temp);
                        /* Let optimizer to solve this =P */
                        sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                        generic_jump(temp);
                        sprintf(temp, INTERNAL_PREFIX "%d", label_temp);
                        generic_label(temp);
                    } else if (lex == C_NAME && strcmp(name, "UNTIL") == 0) {
                        get_lex();
                        type = evaluate_expression(0, 0, loops->label_loop);
                    } else {
                        emit_error("LOOP without condition");
                    }
                    if (loops->var[0] == '1') {  /* Uses exit label? */
                        sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                        generic_label(temp);
                    }
                    popping = loops;
                    loops = loops->next;
                    free(popping);
                } else {
                    emit_error("bad nested LOOP");
                }
            } else if (strcmp(name, "SELECT") == 0) {
                int label_loop;
                int label_exit;
                int type;
                struct loop *new_loop;
                struct node *tree;
                
                get_lex();
                label_exit = next_local++;
                new_loop = malloc(sizeof(struct loop));
                if (new_loop == NULL) {
                    fprintf(stderr, "Out of memory\n");
                    exit(1);
                }
                new_loop->type = NESTED_SELECT;
                if (lex == C_NAME && strcmp(name, "CASE") == 0) {
                    get_lex();
                    
                    optimized = 0;
                    tree = evaluate_level_0(&type);
                    if (type & TYPE_SIGNED) {
                        if ((type & MAIN_TYPE) == TYPE_8)
                            tree = node_create(N_XOR8, 0, tree, node_create(N_NUM8, 0x80, NULL, NULL));
                        else
                            tree = node_create(N_XOR16, 0, tree, node_create(N_NUM16, 0x8000, NULL, NULL));
                    }
                    node_label(tree);
                    /*    node_visual(tree); */ /* Debugging */
                    node_generate(tree, 0);
                    node_delete(tree);
                    new_loop->var[0] = type & (MAIN_TYPE | TYPE_SIGNED); /* Type of data */
                } else {
                    emit_error("missing CASE after SELECT");
                    new_loop->var[0] = TYPE_8;
                }
                new_loop->step = NULL;
                new_loop->final = NULL;
                new_loop->label_loop = 0;
                new_loop->label_exit = label_exit;
                new_loop->next = loops;
                loops = new_loop;
            } else if (strcmp(name, "CASE") == 0) {
                get_lex();
                if (loops == NULL || loops->type != NESTED_SELECT) {
                    emit_error("CASE without SELECT CASE");
                } else {
                    if (loops->label_loop != 0) {
                        sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                        generic_jump(temp);
                        sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                        generic_label(temp);
                    }
                    if (lex == C_NAME && strcmp(name, "ELSE") == 0) {
                        get_lex();
                        if (loops->label_loop == 0) {
                            emit_error("More than one CASE ELSE");
                        } else {
                            loops->label_loop = 0;
                        }
                    } else {
                        struct node *tree;
                        int type;
                        int min;
                        int max;
                        
                        optimized = 0;
                        tree = evaluate_level_0(&type);
                        if ((loops->var[0] & MAIN_TYPE) == TYPE_8 && (type & MAIN_TYPE) == TYPE_16) {
                            tree = node_create(N_REDUCE16, 0, tree, NULL);
                            type = TYPE_8;
                        } else if ((loops->var[0] & MAIN_TYPE) == TYPE_16 && (type & MAIN_TYPE) == TYPE_8) {
                            tree = node_create((type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, tree, NULL);
                            type = TYPE_16;
                        }
                        if (tree->type != N_NUM8 && tree->type != N_NUM16) {
                            emit_error("Not a constant expression in CASE");
                            min = 0;
                        } else {
                            min = tree->value;
                        }
                        node_delete(tree);
                        if (lex == C_NAME && strcmp(name, "TO") == 0) {
                            get_lex();
                            optimized = 0;
                            tree = evaluate_level_0(&type);
                            if (loops->var[0] == TYPE_8 && (type & MAIN_TYPE) == TYPE_16) {
                                tree = node_create(N_REDUCE16, 0, tree, NULL);
                                type = TYPE_8;
                            } else if (loops->var[0] == TYPE_16 && (type & MAIN_TYPE) == TYPE_8) {
                                tree = node_create((type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, tree, NULL);
                                type = TYPE_16;
                            }
                            if (tree->type != N_NUM8 && tree->type != N_NUM16) {
                                emit_error("Not a constant expression in CASE TO");
                            } else {
                                max = tree->value;
                            }
                            node_delete(tree);
                        } else {
                            max = min;
                        }
                        if (loops->var[0] == (TYPE_8 | TYPE_SIGNED)) {
                            min ^= 0x80;
                            max ^= 0x80;
                        } else if (loops->var[0] == (TYPE_16 | TYPE_SIGNED)) {
                            min ^= 0x8000;
                            max ^= 0x8000;
                        }
                        if (min > max) {
                            emit_error("Maximum range of CASE is lesser than minimum");
                        }
                        loops->label_loop = next_local++;
                        sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                        if (type == TYPE_8)
                            generic_comparison_8bit(min, max, temp);
                        else
                            generic_comparison_16bit(min, max, temp);
                    }
                }
            } else if (strcmp(name, "EXIT") == 0) {
                struct loop *loop_explorer;
                
                get_lex();
                
                /* Avoid IF blocks */
                loop_explorer = loops;
                while (loop_explorer != NULL) {
                    if (loop_explorer->type != NESTED_IF)
                        break;
                    loop_explorer = loop_explorer->next;
                }
                if (loops == NULL || loop_explorer == NULL) {
                    emit_error("nowhere to EXIT");
                } else {
                    if (lex != C_NAME) {
                        emit_error("missing type of EXIT, WHILE/FOR/DO");
                    } else if (strcmp(name, "FOR") == 0) {
                        get_lex();
                        if (loop_explorer->type != NESTED_FOR) {
                            emit_error("EXIT FOR without FOR");
                        } else {
                            if (loop_explorer->label_exit == 0)
                                loop_explorer->label_exit = next_local++;
                            sprintf(temp, INTERNAL_PREFIX "%d", loop_explorer->label_exit);
                            generic_jump(temp);
                        }
                    } else if (strcmp(name, "WHILE") == 0) {
                        get_lex();
                        if (loop_explorer->type != NESTED_WHILE) {
                            emit_error("EXIT WHILE without WHILE");
                        } else {
                            sprintf(temp, INTERNAL_PREFIX "%d", loop_explorer->label_exit);
                            generic_jump(temp);
                        }
                    } else if (strcmp(name, "DO") == 0) {
                        get_lex();
                        if (loop_explorer->type != NESTED_DO && loop_explorer->type != NESTED_DO_LOOP) {
                            emit_error("EXIT DO without DO");
                        } else {
                            loop_explorer->var[0] = '1';
                            sprintf(temp, INTERNAL_PREFIX "%d", loop_explorer->label_exit);
                            generic_jump(temp);
                        }
                    } else if (strcmp(name, "SELECT") == 0) {
                        get_lex();
                        if (loop_explorer->type != NESTED_SELECT) {
                            emit_error("EXIT SELECT without SELECT");
                        } else {
                            sprintf(temp, INTERNAL_PREFIX "%d", loop_explorer->label_exit);
                            generic_jump(temp);
                        }
                    } else {
                        emit_error("only supported EXIT WHILE/FOR/DO/SELECT");
                        get_lex();
                    }
                }
            } else if (strcmp(name, "POKE") == 0) {
                struct node *address;
                struct node *value;
                
                get_lex();
                address = evaluate_save_expression(1, TYPE_16);
                if (lex == C_COMMA)
                    get_lex();
                else
                    emit_error("missing comma in POKE");
                value = evaluate_save_expression(1, TYPE_8);
                if (target == CPU_6502) {
                    node_generate(value, 0);
                    cpu6502_noop("PHA");
                    node_generate(address, 0);
                    cpu6502_1op("STA", "temp");
                    cpu6502_1op("STY", "temp+1");
                    cpu6502_noop("PLA");
                    cpu6502_1op("LDY", "#0");
                    cpu6502_1op("STA", "(temp),Y");
                } else if (target == CPU_9900) {
                    node_generate(value, 0);
                    cpu9900_1op("dect", "r10");
                    cpu9900_2op("mov", "r0", "*r10");
                    node_generate(address, 0);
                    cpu9900_2op("mov", "*r10+", "r1");
                    cpu9900_2op("movb","r1","*r0");
                } else {
                    if ((value->regs & REG_HL) == 0) {
                        node_generate(address, 0);
                        node_generate(value, 0);
                    } else if ((address->regs & REG_A) == 0) {
                        node_generate(value, 0);
                        node_generate(address, 0);
                    } else {
                        node_generate(address, 0);
                        cpuz80_1op("PUSH", "HL");
                        node_generate(value, 0);
                        cpuz80_1op("POP", "HL");
                    }
                    cpuz80_2op("LD", "(HL)", "A");
                }
                node_delete(address);
                node_delete(value);
            } else if (strcmp(name, "VPOKE") == 0) {
                struct node *address;
                struct node *value;
                
                get_lex();
                address = evaluate_save_expression(1, TYPE_16);
                if (lex == C_COMMA)
                    get_lex();
                else
                    emit_error("missing comma in VPOKE");
                value = evaluate_save_expression(1, TYPE_8);
                if (target == CPU_6502) {
                    node_generate(value, 0);
                    cpu6502_noop("PHA");
                    node_generate(address, 0);
                    cpu6502_1op("STA", "temp");
                    cpu6502_1op("STY", "temp+1");
                    cpu6502_noop("PLA");
                    cpu6502_noop("TAX");
                    cpu6502_1op("LDA", "temp");
                    cpu6502_noop("SEI");
                    cpu6502_1op("JSR", "WRTVRM");
                    cpu6502_noop("CLI");
                } else if (target == CPU_9900) {
                    node_generate(value, 0);
                    cpu9900_1op("dect", "r10");
                    cpu9900_2op("mov", "r0", "*r10");
                    node_generate(address, 0);
                    cpu9900_2op("mov", "*r10+", "r2");
                    cpu9900_1op("limi","0");
                    cpu9900_1op("bl","@JSR");
                    cpu9900_1op("data", "WRTVRM");
                    cpu9900_1op("limi","2");
                } else {
                    if ((value->regs & REG_HL) == 0) {
                        node_generate(address, 0);
                        node_generate(value, 0);
                    } else if ((address->regs & REG_A) == 0) {
                        node_generate(value, 0);
                        node_generate(address, 0);
                    } else {
                        node_generate(address, 0);
                        cpuz80_1op("PUSH", "HL");
                        node_generate(value, 0);
                        cpuz80_1op("POP", "HL");
                    }
                    cpuz80_1op("CALL", "NMI_OFF");
                    cpuz80_1op("CALL", "WRTVRM");
                    cpuz80_1op("CALL", "NMI_ON");
                }
                node_delete(address);
                node_delete(value);
            } else if (strcmp(name, "REM") == 0) {
                line_pos = line_size;
                get_lex();
            } else if (strcmp(name, "CLS") == 0) {
                get_lex();
                generic_call("cls");
            } else if (strcmp(name, "WAIT") == 0) {
                get_lex();
                if (machine == SORD || machine == CREATIVISION || machine == EINSTEIN || machine == TI994A)
                    generic_call("wait");
                else
                    cpuz80_noop("HALT");
            } else if (strcmp(name, "RESTORE") == 0) {
                get_lex();
                if (lex != C_NAME) {
                    emit_error("bad syntax for RESTORE");
                } else {
                    label = label_search(name);
                    if (label == NULL) {
                        label = label_add(name);
                    }
                    if (target == CPU_6502) {
                        sprintf(temp, "#" LABEL_PREFIX "%s", name);
                        cpu6502_1op("LDA", temp);
                        strcat(temp, ">>8");
                        cpu6502_1op("LDY", temp);
                        cpu6502_1op("STA", "read_pointer");
                        cpu6502_1op("STY", "read_pointer+1");
                    } else if (target == CPU_9900) {
                        sprintf(temp, LABEL_PREFIX "%s", name);
                        cpu9900_2op("li", "r0", temp);
                        cpu9900_2op("mov", "r0", "@read_pointer");
                    } else {
                        sprintf(temp, LABEL_PREFIX "%s", name);
                        cpuz80_2op("LD", "HL", temp);
                        cpuz80_2op("LD", "(read_pointer)", "HL");
                    }
                    get_lex();
                }
            } else if (strcmp(name, "READ") == 0) {
                int c;
                
                get_lex();
                if (lex == C_NAME && strcmp(name, "BYTE") == 0) {
                    get_lex();
                    c = 2;
                } else {
                    c = 1;
                }
                while (1) {
                    compile_assignment(c);
                    if (lex != C_COMMA)
                        break;
                    get_lex();
                }
            } else if (strcmp(name, "DATA") == 0) {
                struct node *tree;
                int c = 0;

                generic_dump();
                get_lex();
                if (lex == C_NAME && strcmp(name, "BYTE") == 0) {
                    int d;
                    
                    get_lex();
                    while (1) {
                        if (lex == C_STRING) {
                            for (d = 0; d < name_size; d++) {
                                if (c == 0) {
                                    if (target == CPU_9900) {
                                        fprintf(output, "\tbyte ");
                                    } else {
                                        fprintf(output, "\tDB ");
                                    }
                                } else {
                                    fprintf(output, ",");
                                }
                                if (target == CPU_9900) {
                                    fprintf(output, ">%02x", name[d] & 0xff);
                                } else {
                                    fprintf(output, "$%02x", name[d] & 0xff);
                                }
                                if (c == 7) {
                                    fprintf(output, "\n");
                                    c = 0;
                                } else {
                                    c++;
                                }
                            }
                            get_lex();
                        } else {
                            tree = evaluate_level_0(&type);
                            if (tree->type != N_NUM8 && tree->type != N_NUM16) {
                                emit_error("not a constant expression in CONST");
                            } else {
                                value = tree->value;
                            }
                            node_delete(tree);
                            tree = NULL;
                            if (c == 0) {
                                if (target == CPU_9900) {
                                    fprintf(output, "\tbyte ");
                                } else {
                                    fprintf(output, "\tDB ");
                                }
                            } else {
                                fprintf(output, ",");
                            }
                            if (target == CPU_9900) {
                                fprintf(output, ">%02x", value & 0xff);
                            } else {
                                fprintf(output, "$%02x", value & 0xff);
                            }
                            if (c == 7) {
                                fprintf(output, "\n");
                                c = 0;
                            } else {
                                c++;
                            }
                        }
                        if (lex != C_COMMA)
                            break;
                        get_lex();
                    }
                    if (c) {
                        fprintf(output, "\n");
                    }
                } else {
                    while (1) {
                        if (lex == C_NAME && strcmp(name, "VARPTR") == 0) {  /* Access to variable/array/label address */
                            int type2;
                            
                            get_lex();
                            if (lex != C_NAME) {
                                emit_error("missing variable name for VARPTR");
                            } else {
                                if (lex_sneak_peek() == '(') {  /* Indexed access */
                                    struct node *tree;
                                    int index;
                                    struct label *label;
                                    
                                    label = array_search(name);
                                    if (label != NULL) {    /* Found array */
                                    } else {
                                        label = label_search(name);
                                        if (label != NULL) {
                                            if (label->used & LABEL_IS_VARIABLE) {
                                                emit_error("using array but not defined");
                                            }
                                        } else {
                                            label = label_add(name);
                                        }
                                    }
                                    get_lex();
                                    if (lex != C_LPAREN)
                                        emit_error("missing left parenthesis in array access");
                                    else
                                        get_lex();
                                    tree = evaluate_level_0(&type2);
                                    if (tree->type != N_NUM8 && tree->type != N_NUM16) {
                                        index = 0;
                                        emit_error("not a constant expression in array access");
                                    } else {
                                        index = tree->value;
                                    }
                                    if (lex != C_RPAREN)
                                        emit_error("missing right parenthesis in array access");
                                    else
                                        get_lex();
                                    if (c == 0) {
                                        if (target == CPU_9900) {
                                            fprintf(output, "\tdata ");
                                        } else {
                                            fprintf(output, "\tDW ");
                                        }
                                    } else {
                                        fprintf(output, ",");
                                    }
                                    strcpy(assigned, label->name);
                                    if (target == CPU_9900) {
                                        char *p = assigned;
                                        
                                        while (*p) {
                                            if (*p == '#')
                                                *p = '_';
                                            p++;
                                        }
                                    }
                                    fprintf(output, "%s%s+%d", label->length ? ARRAY_PREFIX : LABEL_PREFIX, assigned, label->name[0] == '#' ? index * 2 : index);
                                    if (c == 7) {
                                        fprintf(output, "\n");
                                        c = 0;
                                    } else {
                                        c++;
                                    }
                                    node_delete(tree);
                                    tree = NULL;
                                } else {
                                    if (constant_search(name) != NULL) {
                                        emit_error("constants doesn't have address for VARPTR");
                                        get_lex();
                                    } else {
                                        label = label_search(name);
                                        if (label != NULL && (label->used & LABEL_IS_VARIABLE) == 0) {
                                            char buffer[MAX_LINE_SIZE];
                                            
                                            sprintf(buffer, "variable name '%s' already defined with other purpose", name);
                                            emit_error(buffer);
                                            label = NULL;
                                        }
                                        if (label == NULL) {
                                            check_for_explicit(name);
                                            label = label_add(name);
                                            if (name[0] == '#')
                                                label->used = TYPE_16;
                                            else
                                                label->used = TYPE_8;
                                            label->used |= LABEL_IS_VARIABLE;
                                        }
                                        get_lex();
                                        if (c == 0) {
                                            if (target == CPU_9900) {
                                                fprintf(output, "\tdata ");
                                            } else {
                                                fprintf(output, "\tDW ");
                                            }
                                        } else {
                                            fprintf(output, ",");
                                        }
                                        strcpy(assigned, label->name);
                                        if (target == CPU_9900) {
                                            char *p = assigned;
                                            
                                            while (*p) {
                                                if (*p == '#')
                                                    *p = '_';
                                                p++;
                                            }
                                        }
                                        fprintf(output, "%s%s", LABEL_PREFIX, assigned);
                                        if (c == 7) {
                                            fprintf(output, "\n");
                                            c = 0;
                                        } else {
                                            c++;
                                        }
                                    }
                                }
                            }
                        } else {
                            tree = evaluate_level_0(&type);
                            if (tree->type != N_NUM8 && tree->type != N_NUM16) {
                                emit_error("not a constant expression in CONST");
                            } else {
                                value = tree->value;
                            }
                            node_delete(tree);
                            tree = NULL;
                            if (c == 0) {
                                if (target == CPU_9900) {
                                    fprintf(output, "\tdata ");
                                } else {
                                    fprintf(output, "\tDW ");
                                }
                            } else {
                                fprintf(output, ",");
                            }
                            if (target == CPU_9900) {
                                fprintf(output, ">%04x", value & 0xffff);
                            } else {
                                fprintf(output, "$%04x", value & 0xffff);
                            }
                            if (c == 7) {
                                fprintf(output, "\n");
                                c = 0;
                            } else {
                                c++;
                            }
                        }
                        if (lex != C_COMMA)
                            break;
                        get_lex();
                    }
                    if (c) {
                        fprintf(output, "\n");
                    }
                }
            } else if (strcmp(name, "OUT") == 0) {
                struct node *port;
                struct node *value;
                
                get_lex();
                port = evaluate_save_expression(1, TYPE_8);
                if (lex == C_COMMA)
                    get_lex();
                else
                    emit_error("missing comma in OUT");
                value = evaluate_save_expression(1, TYPE_8);
                if (target == CPU_6502) {
                    emit_warning("Ignoring OUT (not supported in target)");
                } else if (target == CPU_9900) {
                    /*
                     ** We don't have ports (though we could map this to CRU)
                     ** however, since it seems OUT is the CVBasic way to directly
                     ** access the sound chip, we'll check for OUT $FF and map that
                     ** over.
                     */
                    if (port->type == N_NUM8 && port->value == 0xff) {
                        node_generate(value, 0);
                        cpu9900_2op("movb", "r0", "@SOUND");
                    } else {
                        emit_warning("OUT to 0xff for audio is the only supported use.");
                    }
                } else {
                    node_generate(port, 0);
                    cpuz80_2op("LD", "C", "A");
                    if ((value->regs & REG_C) == 0) {
                        node_generate(value, 0);
                    } else {
                        cpuz80_1op("PUSH", "BC");
                        node_generate(value, 0);
                        cpuz80_1op("POP", "BC");
                    }
                    cpuz80_2op("OUT", "(C)", "A");
                }
                node_delete(port);
                node_delete(value);
            } else if (strcmp(name, "PRINT") == 0) {
                int label;
                int label2;
                int c;
                int start;
                int cursor_value;
                int cursor_pos;
                struct node *tree;
                
                get_lex();
                start = 1;
                cursor_value = 0;
                cursor_pos = 0;
                if (lex == C_NAME && strcmp(name, "AT") == 0) {
                    get_lex();
                    tree = evaluate_save_expression(1, TYPE_16);
                    if (target == CPU_6502) {
                        if (tree->type == N_NUM16) {
                            cursor_value = 2;
                            cursor_pos = tree->value;
                        } else {
                            node_generate(tree, 0);
                            cursor_value = 1;
                        }
                    } else if (target == CPU_9900) {
                        node_generate(tree, 0);
                        cpu9900_2op("mov", "r0", "@cursor");
                    } else {
                        node_generate(tree, 0);
                        cpuz80_2op("LD", "(cursor)", "HL");
                    }
                    start = 0;
                }
                while (1) {
                    if (!start) {
                        if (lex != C_COMMA) {
                            if (target == CPU_6502) {
                                if (cursor_value) {
                                    if (cursor_value == 2) {
                                        sprintf(temp, "#%d", cursor_pos & 0xff);
                                        cpu6502_1op("LDA", temp);
                                        sprintf(temp, "#%d", cursor_pos >> 8);
                                        cpu6502_1op("LDY", temp);
                                    }
                                    cpu6502_1op("STA", "cursor");
                                    cpu6502_1op("STY", "cursor+1");
                                }
                            }
                            break;
                        }
                        get_lex();
                    }
                    start = 0;
                    if (lex == C_STRING) {
                        if (name_size) {
                            if (target == CPU_6502) {
                                if (cursor_value) {
                                    if (cursor_value == 2) {
                                        generic_call("print_string_cursor_constant");
                                        generic_dump();
                                        fprintf(output, "\tDB $%02x,$%02x,$%02x\n", cursor_pos & 0xff, (cursor_pos >> 8) & 0xff, name_size);
                                    } else {
                                        generic_call("print_string_cursor");
                                        generic_dump();
                                        fprintf(output, "\tDB $%02x\n", name_size);
                                    }
                                } else {
                                    generic_call("print_string");
                                    generic_dump();
                                    fprintf(output, "\tDB $%02x\n", name_size);
                                }
                            } else if (target == CPU_9900) {
                                label = next_local++;
                                label2 = next_local++;
                                sprintf(temp, INTERNAL_PREFIX "%d", label);
                                cpu9900_2op("li","r2",temp);
                                sprintf(temp, "%d", name_size);
                                cpu9900_2op("li","r3",temp);    /* yes, as 16 bit */
                                generic_call("print_string");
                                sprintf(temp, INTERNAL_PREFIX "%d", label2);
                                generic_jump(temp);
                                sprintf(temp, INTERNAL_PREFIX "%d", label);
                                generic_label(temp);
                                generic_dump();
                            } else {
                                label = next_local++;
                                label2 = next_local++;
                                sprintf(temp, INTERNAL_PREFIX "%d", label);
                                cpuz80_2op("LD", "HL", temp);
                                sprintf(temp, "%d", name_size);
                                cpuz80_2op("LD", "A", temp);
                                generic_call("print_string");
                                sprintf(temp, INTERNAL_PREFIX "%d", label2);
                                generic_jump(temp);
                                sprintf(temp, INTERNAL_PREFIX "%d", label);
                                generic_label(temp);
                                generic_dump();
                            }
                            for (c = 0; c < name_size; c++) {
                                if ((c & 7) == 0) {
                                    if (target == CPU_9900) {
                                        fprintf(output, "\tbyte ");
                                    } else {
                                        fprintf(output, "\tDB ");
                                    }
                                }
                                if (target == CPU_9900) {
                                    fprintf(output, ">%02x", name[c] & 0xff);
                                } else {
                                    fprintf(output, "$%02x", name[c] & 0xff);
                                }
                                if ((c & 7) == 7 || c + 1 == name_size) {
                                    fprintf(output, "\n");
                                } else {
                                    fprintf(output, ",");
                                }
                            }

                            if (target == CPU_9900) {
                                fprintf(output, "\teven\n");
                                sprintf(temp, INTERNAL_PREFIX "%d", label2);
                                generic_label(temp);
                            }

                            if (target == CPU_Z80) {
                                sprintf(temp, INTERNAL_PREFIX "%d", label2);
                                generic_label(temp);
                            }
                        } else {
                            if (target == CPU_6502) {
                                if (cursor_value) {
                                    if (cursor_value == 2) {
                                        sprintf(temp, "#%d", cursor_pos & 0xff);
                                        cpu6502_1op("LDA", temp);
                                        sprintf(temp, "#%d", cursor_pos >> 8);
                                        cpu6502_1op("LDY", temp);
                                    }
                                    cpu6502_1op("STA", "cursor");
                                    cpu6502_1op("STY", "cursor+1");
                                }
                            }
                        }
                        get_lex();
                    } else if (lex == C_LESS || lex == C_NOTEQUAL) {
                        int format = 0;
                        int size = 1;
                        
                        if (target == CPU_6502) {
                            if (cursor_value) {
                                if (cursor_value == 2) {
                                    sprintf(temp, "#%d", cursor_pos & 0xff);
                                    cpu6502_1op("LDA", temp);
                                    sprintf(temp, "#%d", cursor_pos >> 8);
                                    cpu6502_1op("LDY", temp);
                                }
                                cpu6502_1op("STA", "cursor");
                                cpu6502_1op("STY", "cursor+1");
                            }
                        }
                        if (lex == C_NOTEQUAL) {    /* IntyBASIC compatibility */
                            get_lex();
                        } else {
                            get_lex();
                            if (lex == C_PERIOD) {
                                get_lex();
                                format = 1;
                                if (lex != C_NUM) {
                                    emit_error("missing size for number");
                                } else {
                                    size = value;
                                    get_lex();
                                }
                            } else if (lex == C_NUM) {
                                format = 2;
                                if (lex != C_NUM) {
                                    emit_error("missing size for number");
                                } else {
                                    size = value;
                                    get_lex();
                                }
                            }
                            if (lex == C_GREATER)
                                get_lex();
                            else
                                emit_error("missing > in PRINT for number");
                        }
                        if (size < 1)
                            size = 1;
                        if (size > 5)
                            size = 5;
                        type = evaluate_expression(1, TYPE_16, 0);
                        if (target == CPU_6502) {
                            if (format == 0) {
                                cpu6502_1op("JSR", "print_number");
                            } else if (format == 1) {
                                cpu6502_noop("SEI");
                                cpu6502_1op("LDX", "#2");
                                cpu6502_1op("STX", "temp");
                                cpu6502_1op("LDX", "#32");
                                cpu6502_1op("STX", "temp+1");
                                sprintf(temp, "print_number%d", size);
                                cpu6502_1op("JSR", temp);
                            } else if (format == 2) {
                                cpu6502_noop("SEI");
                                cpu6502_1op("LDX", "#2");
                                cpu6502_1op("STX", "temp");
                                cpu6502_1op("LDX", "#48");
                                cpu6502_1op("STX", "temp+1");
                                sprintf(temp, "print_number%d", size);
                                cpu6502_1op("JSR", temp);
                            }
                        } else if (target == CPU_9900) {
                            cpu9900_2op("mov", "r0", "r3");
                            if (format == 0) {
                                cpu9900_1op("bl", "@JSR");
                                cpu9900_1op("data", "print_number");
                            } else if (format == 1) {
                                cpu9900_1op("limi","0");        /* print_number will turn it back on */
                                cpu9900_2op("li", "r5", ">0220");
                                sprintf(temp, "print_number%d", size);
                                cpu9900_1op("bl", "@JSR");
                                cpu9900_1op("data", temp);
                            } else if (format == 2) {
                                cpu9900_1op("limi","0");        /* print_number will turn it back on */
                                cpu9900_2op("li", "r5", ">0230");
                                sprintf(temp, "print_number%d", size);
                                cpu9900_1op("bl", "@JSR");
                                cpu9900_1op("data", temp);
                            }
                        } else {
                            if (format == 0) {
                                cpuz80_1op("CALL", "print_number");
                            } else if (format == 1) {
                                cpuz80_1op("CALL", "nmi_off");
                                cpuz80_2op("LD", "BC", "$0220");
                                sprintf(temp, "print_number%d", size);
                                cpuz80_1op("CALL", temp);
                            } else if (format == 2) {
                                cpuz80_1op("CALL", "nmi_off");
                                cpuz80_2op("LD", "BC", "$0230");
                                sprintf(temp, "print_number%d", size);
                                cpuz80_1op("CALL", temp);
                            }
                        }
                    } else {
                        if (target == CPU_6502) {
                            if (cursor_value) {
                                if (cursor_value == 2) {
                                    sprintf(temp, "#%d", cursor_pos & 0xff);
                                    cpu6502_1op("LDA", temp);
                                    sprintf(temp, "#%d", cursor_pos >> 8);
                                    cpu6502_1op("LDY", temp);
                                }
                                cpu6502_1op("STA", "cursor");
                                cpu6502_1op("STY", "cursor+1");
                            }
                        }
                        type = evaluate_expression(1, TYPE_16, 0);
                        if (target == CPU_9900) {
                            cpu9900_2op("mov", "r0", "r3");
                        }
                        generic_call("print_number");
                    }
                    cursor_value = 0;
                }
            } else if (strcmp(name, "DEFINE") == 0) {
                int pletter = 0;
                int vram_read = 0;
                
                get_lex();
                if (lex != C_NAME) {
                    emit_error("syntax error in DEFINE");
                } else if (strcmp(name, "SPRITE") == 0) {
                    get_lex();
                    if (lex == C_NAME && strcmp(name, "PLETTER") == 0) {
                        pletter = 1;
                        get_lex();
                    }
                    if (pletter) {
                        type = evaluate_expression(1, TYPE_16, 0);
                        if (target == CPU_6502) {
                            cpu6502_1op("ASL", "A");
                            cpu6502_1op("ASL", "A");
                            cpu6502_1op("LDY", "#7");
                            cpu6502_1op("STY", "pointer+1");
                            cpu6502_1op("ASL", "A");
                            cpu6502_1op("ROL", "pointer+1");
                            cpu6502_1op("ASL", "A");
                            cpu6502_1op("ROL", "pointer+1");
                            cpu6502_1op("ASL", "A");
                            cpu6502_1op("ROL", "pointer+1");
                            cpu6502_1op("STA", "pointer");
                        } else if (target == CPU_9900) {
                            cpu9900_2op("mov","r0","r4");
                            cpu9900_2op("sla","r4","5");
                            cpu9900_2op("ai","r4",">3800");
                        } else {
                            cpuz80_2op("ADD", "HL", "HL");
                            cpuz80_2op("ADD", "HL", "HL");
                            cpuz80_2op("LD", "H", "$07");
                            cpuz80_2op("ADD", "HL", "HL");
                            cpuz80_2op("ADD", "HL", "HL");
                            cpuz80_2op("ADD", "HL", "HL");
                            cpuz80_2op("EX", "DE", "HL");
                        }
                        if (lex == C_COMMA)
                            get_lex();
                        else
                            emit_error("missing comma in DEFINE");
                        type = evaluate_expression(2, TYPE_8, 0);
                        if (lex == C_COMMA)
                            get_lex();
                        else
                            emit_error("missing comma in DEFINE");
                        if (lex != C_NAME) {
                            emit_error("missing label in DEFINE");
                        } else {
                            if (target == CPU_6502) {
                                strcpy(temp, "#" LABEL_PREFIX);
                                strcat(temp, name);
                                cpu6502_1op("LDA", temp);
                                strcat(temp, ">>8");
                                cpu6502_1op("LDY", temp);
                                cpu6502_1op("STA", "temp");
                                cpu6502_1op("STY", "temp+1");
                            } else if (target == CPU_9900) {
                                strcpy(temp, LABEL_PREFIX);
                                strcat(temp, name);
                                cpu9900_2op("li", "r2", temp);
                                cpu9900_2op("mov","r4","r1");
                            } else {
                                strcpy(temp, LABEL_PREFIX);
                                strcat(temp, name);
                                cpuz80_2op("LD", "HL", temp);
                            }
                            get_lex();
                        }
                        generic_call("unpack");
                        compression_used = 1;
                    } else {
                        struct node *length;
                        struct node *source = NULL;
                        
                        type = evaluate_expression(1, TYPE_16, 0);  /* char number */
                        if (target == CPU_6502) {
                            cpu6502_1op("STA", "pointer");
                        } else if (target == CPU_9900) {
                            cpu9900_2op("mov","r0","r4");
                        } else {
                            cpuz80_1op("PUSH", "HL");
                        }
                        if (lex == C_COMMA)
                            get_lex();
                        else
                            emit_error("missing comma in DEFINE");
                        length = evaluate_save_expression(1, TYPE_8);   /* count */
                        if (lex == C_COMMA)
                            get_lex();
                        else
                            emit_error("missing comma in DEFINE");
                        if (lex != C_NAME) {
                            emit_error("missing label in DEFINE");
                        } else if (strcmp(name, "VARPTR") == 0) {
                            source = evaluate_save_expression(1, TYPE_16);  /* CPU address (variable) */
                            node_generate(length, 0);
                            if (target == CPU_6502) {
                                cpu6502_noop("PHA");
                                node_generate(source, 0);
                                cpu6502_1op("STA", "temp");
                                cpu6502_1op("STY", "temp+1");
                                cpu6502_noop("PLA");
                            } else if (target == CPU_9900) {
                                cpu9900_2op("mov","r0","r5");
                                node_generate(source, 0);
                            } else {
                                if ((source->regs & REG_A) != 0)
                                    cpuz80_1op("PUSH", "AF");
                                node_generate(source, 0);
                                if ((source->regs & REG_A) != 0)
                                    cpuz80_1op("POP", "AF");
                            }
                        } else {
                            node_generate(length, 0);   /* CPU address (immediate) */
                            if (target == CPU_6502) {
                                cpu6502_noop("PHA");
                                strcpy(temp, "#" LABEL_PREFIX);
                                strcat(temp, name);
                                cpu6502_1op("LDA", temp);
                                cpu6502_1op("STA", "temp");
                                strcat(temp, ">>8");
                                cpu6502_1op("LDA", temp);
                                cpu6502_1op("STA", "temp+1");
                                cpu6502_noop("PLA");
                            } else if (target == CPU_9900) {
                                cpu9900_2op("mov","r0","r5");
                                strcpy(temp, LABEL_PREFIX);
                                strcat(temp, name);
                                cpu9900_2op("li","r0",temp);
                            } else {
                                strcpy(temp, LABEL_PREFIX);
                                strcat(temp, name);
                                cpuz80_2op("LD", "HL", temp);
                            }
                            get_lex();
                        }
                        generic_call("define_sprite");
                        node_delete(length);
                        node_delete(source);
                    }
                } else if (strcmp(name, "CHAR") == 0 || strcmp(name, "COLOR") == 0) {
                    int color;
                    struct node *length;
                    struct node *source = NULL;
                    
                    if (strcmp(name, "COLOR") == 0)
                        color = 1;
                    else
                        color = 0;
                    get_lex();
                    if (lex == C_NAME && strcmp(name, "PLETTER") == 0) {
                        pletter = 1;
                        get_lex();
                    }
                    type = evaluate_expression(1, TYPE_16, 0);
                    if (target == CPU_6502) {
                        cpu6502_1op("STA", "pointer");
                    } else if (target == CPU_9900) {
                        /* char in r4, data in r0, count in r5 */
                        cpu9900_2op("mov","r0","r4");
                    } else {
                        cpuz80_1op("PUSH", "HL");
                    }
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in DEFINE");
                    length = evaluate_save_expression(1, TYPE_8);
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in DEFINE");
                    if (lex != C_NAME) {
                        emit_error("missing label in DEFINE");
                    } else if (!pletter && strcmp(name, "VARPTR") == 0) {
                        source = evaluate_save_expression(1, TYPE_16);
                        node_generate(length, 0);
                        if (target == CPU_6502) {
                            cpu6502_noop("PHA");
                            node_generate(source, 0);
                            cpu6502_1op("STA", "temp");
                            cpu6502_1op("STY", "temp+1");
                            cpu6502_noop("PLA");
                        } else if (target == CPU_9900) {
                            /* char in r4, data in r0, count in r5 */
                            cpu9900_2op("mov","r0","r5");
                            node_generate(source, 0);
                        } else {
                            if ((source->regs & REG_A) != 0)
                                cpuz80_1op("PUSH", "AF");
                            node_generate(source, 0);
                            if ((source->regs & REG_A) != 0)
                                cpuz80_1op("POP", "AF");
                        }
                    } else {
                        node_generate(length, 0);
                        if (target == CPU_6502) {
                            cpu6502_noop("PHA");
                            strcpy(temp, "#" LABEL_PREFIX);
                            strcat(temp, name);
                            cpu6502_1op("LDA", temp);
                            cpu6502_1op("STA", "temp");
                            strcat(temp, ">>8");
                            cpu6502_1op("LDA", temp);
                            cpu6502_1op("STA", "temp+1");
                            cpu6502_noop("PLA");
                        } else if (target == CPU_9900) {
                            /* char in r4, data in r0, count in r5 */
                            cpu9900_2op("mov","r0","r5");
                            strcpy(temp, LABEL_PREFIX);
                            strcat(temp, name);
                            cpu9900_2op("li","r0",temp);
                        } else {
                            strcpy(temp, LABEL_PREFIX);
                            strcat(temp, name);
                            cpuz80_2op("LD", "HL", temp);
                        }
                        get_lex();
                    }
                    if (pletter) {
                        generic_call(color ? "define_color_unpack" : "define_char_unpack");
                        compression_used = 1;
                    } else {
                        generic_call(color ? "define_color" : "define_char");
                    }
                    node_delete(length);
                    node_delete(source);
                } else if (strcmp(name, "VRAM") == 0) {
                    struct node *source;
                    struct node *target2;
                    struct node *length;
                    
                    get_lex();
                    if (lex == C_NAME && strcmp(name, "PLETTER") == 0) {
                        pletter = 1;
                        get_lex();
                    } else if (lex == C_NAME && strcmp(name, "READ") == 0) {
                        vram_read = 1;
                        get_lex();
                    }
                    target2 = evaluate_save_expression(1, TYPE_16);
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in DEFINE");
                    length = evaluate_save_expression(1, TYPE_16);
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in DEFINE");
                    if (lex != C_NAME) {
                        emit_error("missing label in DEFINE");
                        source = NULL;
                    } else if (!pletter && strcmp(name, "VARPTR") == 0) {
                        source = evaluate_save_expression(1, TYPE_16);
                        if (target == CPU_6502) {
                            node_generate(target2, 0);
                            cpu6502_1op("STA", "pointer");
                            cpu6502_1op("STY", "pointer+1");
                            node_generate(length, 0);
                            cpu6502_noop("PHA");
                            cpu6502_noop("TYA");
                            cpu6502_noop("PHA");
                            node_generate(source, 0);
                            cpu6502_1op("STA", "temp");
                            cpu6502_1op("STY", "temp+1");
                            cpu6502_noop("PLA");
                            cpu6502_1op("STA", "temp2+1");
                            cpu6502_noop("PLA");
                            cpu6502_1op("STA", "temp2");
                        } else if (target == CPU_9900) {
                            node_generate(target2, 0);
                            cpu9900_2op("mov","r0","r4");   /* save it off, cause we need it at the end in r0 */
                            node_generate(length, 0);
                            cpu9900_2op("mov","r0","r5");
                            node_generate(source, 0);
                        } else {
                            node_generate(length, 0);
                            if (((target2->regs | source->regs) & REG_BC) == 0) {
                                cpuz80_2op("LD", "B", "H");
                                cpuz80_2op("LD", "C", "L");
                            } else {
                                cpuz80_1op("PUSH", "HL");
                            }
                            node_generate(target2, 0);
                            if ((source->regs & REG_DE) == 0) {
                                cpuz80_2op("EX", "DE", "HL");
                                node_generate(source, 0);
                            } else {
                                cpuz80_1op("PUSH", "HL");
                                node_generate(source, 0);
                                cpuz80_1op("POP", "DE");
                            }
                            if (((target2->regs | source->regs) & REG_BC) != 0)
                                cpuz80_1op("POP", "BC");
                        }
                    } else {
                        source = NULL;
                        if (target == CPU_6502) {
                            if (!pletter) {
                                node_generate(length, 0);
                                cpu6502_noop("PHA");
                                cpu6502_noop("TYA");
                                cpu6502_noop("PHA");
                            }
                        } else if (target == CPU_9900) {
                            if (!pletter) {
                                node_generate(length, 0);
                                cpu9900_2op("mov","r0","r5");
                            }
                        } else {
                            if (!pletter) {
                                node_generate(length, 0);
                                if ((target2->regs & REG_BC) == 0) {
                                    cpuz80_2op("LD", "B", "H");
                                    cpuz80_2op("LD", "C", "L");
                                } else {
                                    cpuz80_1op("PUSH", "HL");
                                }
                            }
                        }
                        node_generate(target2, 0);
                        if (target == CPU_6502) {
                            cpu6502_1op("STA", "pointer");
                            cpu6502_1op("STY", "pointer+1");
                            strcpy(temp, "#" LABEL_PREFIX);
                            strcat(temp, name);
                            cpu6502_1op("LDA", temp);
                            strcat(temp, ">>8");
                            cpu6502_1op("LDY", temp);
                            cpu6502_1op("STA", "temp");
                            cpu6502_1op("STY", "temp+1");
                            if (!pletter) {
                                cpu6502_noop("PLA");
                                cpu6502_1op("STA", "temp2+1");
                                cpu6502_noop("PLA");
                                cpu6502_1op("STA", "temp2");
                            }
                        } else if (target == CPU_9900) {
                            cpu9900_2op("mov","r0","r4");
                            strcpy(temp, LABEL_PREFIX);
                            strcat(temp, name);
                            cpu9900_2op("li","r0",temp);
                        } else {
                            cpuz80_2op("EX", "DE", "HL");
                            strcpy(temp, LABEL_PREFIX);
                            strcat(temp, name);
                            cpuz80_2op("LD", "HL", temp);
                            if (!pletter) {
                                if ((target2->regs & REG_BC) != 0)
                                    cpuz80_1op("POP", "BC");
                            }
                        }
                        get_lex();
                    }
                    if (pletter) {
                        if (target == CPU_9900) {
                            cpu9900_2op("mov","r0","r2");
                            cpu9900_2op("mov","r4","r1");
                        }
                        generic_call("unpack");
                        compression_used = 1;
                    } else {
                        if (target == CPU_6502) {
                            cpu6502_noop("SEI");
                        } else if (target == CPU_9900) {
                            cpu9900_2op("mov","r0","r2");
                            cpu9900_2op("mov","r5","r3");
                            cpu9900_2op("mov","r4","r0");
                            cpu9900_1op("limi","0");
                        } else {
                            cpuz80_1op("CALL", "nmi_off");
                        }
                        if (vram_read) {
                            generic_call("LDIRMV");
                        } else {
                            generic_call("LDIRVM");
                        }
                        if (target == CPU_6502)
                            cpu6502_noop("CLI");
                        else if (target == CPU_9900)
                            cpu9900_1op("limi","2");
                        else
                            cpuz80_1op("CALL", "nmi_on");
                    }
                    node_delete(length);
                    node_delete(target2);
                    node_delete(source);
                } else {
                    emit_error("syntax error in DEFINE");
                }
            } else if (strcmp(name, "SPRITE") == 0) {
                get_lex();
                if (lex == C_NAME && strcmp(name, "FLICKER") == 0) {
                    get_lex();
                    if (lex == C_NAME && strcmp(name, "ON") == 0) {
                        if (target == CPU_6502) {
                            cpu6502_1op("LDA", "mode");
                            cpu6502_1op("AND", "#251");
                            cpu6502_1op("STA", "mode");
                        } else if (target == CPU_9900) {
                            cpu9900_2op("li", "r0", ">0400");
                            cpu9900_2op("szcb", "r0", "@mode");
                        } else {
                            cpuz80_2op("LD", "HL", "mode");
                            cpuz80_2op("RES", "2", "(HL)");
                        }
                        get_lex();
                    } else if (lex == C_NAME && strcmp(name, "OFF") == 0) {
                        if (target == CPU_6502) {
                            cpu6502_1op("LDA", "mode");
                            cpu6502_1op("ORA", "#4");
                            cpu6502_1op("STA", "mode");
                        } else if (target == CPU_9900) {
                            cpu9900_2op("li", "r0", ">0400");
                            cpu9900_2op("socb", "r0", "@mode");
                        } else {
                            cpuz80_2op("LD", "HL", "mode");
                            cpuz80_2op("SET", "2", "(HL)");
                        }
                        get_lex();
                    } else {
                        emit_error("only allowed SPRITE FLICKER ON/OFF");
                    }
                } else {
                    type = evaluate_expression(1, TYPE_8, 0);
                    if (target == CPU_6502)
                        cpu6502_noop("PHA");
                    else if (target == CPU_9900)
                        cpu9900_2op("mov","r0","r4");
                    else
                        cpuz80_1op("PUSH", "AF");
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in SPRITE");
                    type = evaluate_expression(1, TYPE_8, 0);
                    if (target == CPU_6502)
                        cpu6502_1op("STA", "sprite_data");
                    else if (target == CPU_9900)
                        cpu9900_2op("movb","r0","r5");
                    else
                        cpuz80_1op("PUSH", "AF");
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in SPRITE");
                    type = evaluate_expression(1, TYPE_8, 0);
                    if (target == CPU_6502)
                        cpu6502_1op("STA", "sprite_data+1");
                    else if (target == CPU_9900)
                        cpu9900_2op("movb","r0","r6");
                    else
                        cpuz80_1op("PUSH", "AF");
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in SPRITE");
                    type = evaluate_expression(1, TYPE_8, 0);
                    if (target == CPU_6502)
                        cpu6502_1op("STA", "sprite_data+2");
                    else if (target == CPU_9900)
                        cpu9900_2op("movb","r0","r7");
                    else
                        cpuz80_1op("PUSH", "AF");
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in SPRITE");
                    type = evaluate_expression(1, TYPE_8, 0);
                    if (target == CPU_6502) {
                        cpu6502_1op("STA", "sprite_data+3");
                        cpu6502_noop("PLA");
                    }
                    generic_call("update_sprite");
                }
            } else if (strcmp(name, "BITMAP") == 0) {
                generic_dump();
                get_lex();
                if (lex != C_STRING || (name_size != 8 && name_size != 16)) {
                    emit_error("syntax error in BITMAP");
                } else if (name_size == 16) {   /* Sprites */
                    int c;
                    
                    value = 0;
                    for (c = 0; c < 16; c++) {
                        if (name[c] != 0x30 && name[c] != 0x5f   /* 0 and _ */
                            && name[c] != 0x20 && name[c] != 0x2e)  /* space and . */
                            value |= 0x8000 >> c;
                    }
                    get_lex();
                    bitmap[bitmap_byte] = value >> 8;
                    bitmap[bitmap_byte + 16] = value;
                    bitmap_byte++;
                    if (bitmap_byte >= 16) {
                        bitmap_byte = 0;
                        for (c = 0; c < 32; c += 8) {
                            if (target == CPU_9900) {
                                sprintf(temp, "\tbyte >%02x,>%02x,>%02x,>%02x,>%02x,>%02x,>%02x,>%02x\n",
                                        bitmap[c], bitmap[c + 1], bitmap[c + 2], bitmap[c + 3],
                                        bitmap[c + 4], bitmap[c + 5], bitmap[c + 6], bitmap[c + 7]);
                            } else {
                                sprintf(temp, "\tDB $%02x,$%02x,$%02x,$%02x,$%02x,$%02x,$%02x,$%02x\n",
                                        bitmap[c], bitmap[c + 1], bitmap[c + 2], bitmap[c + 3],
                                        bitmap[c + 4], bitmap[c + 5], bitmap[c + 6], bitmap[c + 7]);
                            }
                            fprintf(output, "%s", temp);
                        }
                    }
                    
                } else {
                    int c;
                    
                    value = 0;
                    for (c = 0; c < 8; c++) {
                        if (name[c] != 0x30 && name[c] != 0x5f   /* 0 and _ */
                            && name[c] != 0x20 && name[c] != 0x2e)  /* space and . */
                            value |= 0x80 >> c;
                    }
                    get_lex();
                    bitmap[bitmap_byte] = value;
                    bitmap_byte++;
                    if (bitmap_byte >= 8) {
                        bitmap_byte = 0;
                        c = 0;
                        if (target == CPU_9900) {
                            sprintf(temp, "\tbyte >%02x,>%02x,>%02x,>%02x,>%02x,>%02x,>%02x,>%02x\n",
                                    bitmap[c], bitmap[c + 1], bitmap[c + 2], bitmap[c + 3],
                                    bitmap[c + 4], bitmap[c + 5], bitmap[c + 6], bitmap[c + 7]);
                        } else {
                            sprintf(temp, "\tDB $%02x,$%02x,$%02x,$%02x,$%02x,$%02x,$%02x,$%02x\n",
                                    bitmap[c], bitmap[c + 1], bitmap[c + 2], bitmap[c + 3],
                                    bitmap[c + 4], bitmap[c + 5], bitmap[c + 6], bitmap[c + 7]);
                        }
                        fprintf(output, "%s", temp);
                    }
                }
            } else if (strcmp(name, "BORDER") == 0) {
                int type;
                
                get_lex();
                type = evaluate_expression(1, TYPE_8, 0);
                if (target == CPU_6502) {
                    cpu6502_1op("LDX", "#7");
                    cpu6502_noop("SEI");
                    cpu6502_1op("JSR", "WRTVDP");
                    cpu6502_noop("CLI");
                } else if (target == CPU_9900) {
                    /* this is just a lot faster inline than jumping through hoops... */
                    cpu9900_2op("srl","r0","8");
                    cpu9900_2op("ori","r0",">8700");
                    cpu9900_1op("swpb","r0");
                    cpu9900_1op("limi","0");
                    cpu9900_2op("movb","r0","@VDPWADR");
                    cpu9900_1op("swpb","r0");
                    cpu9900_2op("movb","r0","@VDPWADR");
                    cpu9900_1op("limi","2");
                } else {
                    cpuz80_2op("LD", "B", "A");
                    cpuz80_2op("LD", "C", "7");
                    cpuz80_1op("CALL", "nmi_off");
                    cpuz80_1op("CALL", "WRTVDP");
                    cpuz80_1op("CALL", "nmi_on");
                }
            } else if (strcmp(name, "SIGNED") == 0) {
                struct signedness *c;
                
                get_lex();
                while (1) {
                    if (lex != C_NAME) {
                        emit_error("missing name in SIGNED");
                        break;
                    }
                    c = signed_search(name);
                    if (c != NULL) {
                        emit_error("variable already SIGNED/UNSIGNED");
                    } else {
                        c = signed_add(name);
                    }
                    c->sign = 1;
                    get_lex();
                    if (lex != C_COMMA)
                        break;
                    get_lex();
                }
            } else if (strcmp(name, "UNSIGNED") == 0) {
                struct signedness *c;

                get_lex();
                while (1) {
                    if (lex != C_NAME) {
                        emit_error("missing name in UNSIGNED");
                        break;
                    }
                    c = signed_search(name);
                    if (c != NULL) {
                        emit_error("variable already SIGNED/UNSIGNED");
                    } else {
                        c = signed_add(name);
                    }
                    c->sign = 2;
                    get_lex();
                    if (lex != C_COMMA)
                        break;
                    get_lex();
                }
            } else if (strcmp(name, "CONST") == 0) {
                struct constant *c;
                
                get_lex();
                if (lex != C_NAME) {
                    emit_error("name required for constant assignment");
                    return;
                }
                c = constant_search(name);
                if (c != NULL) {
                    emit_error("constant redefined");
                } else {
                    c = constant_add(name);
                }
                strcpy(assigned, name);;
                get_lex();
                if (lex != C_EQUAL) {
                    emit_error("required '=' for constant assignment");
                } else {
                    struct node *tree;
                    int type;
                    
                    get_lex();
                    tree = evaluate_level_0(&type);
                    if (tree->type != N_NUM8 && tree->type != N_NUM16) {
                        emit_error("not a constant expression in CONST");
                    } else {
                        c->value = tree->value;
                    }
                    if (target == CPU_Z80 || target == CPU_6502) {
                        sprintf(temp, CONST_PREFIX "%s:\tequ $%04x", assigned, c->value);
                        fprintf(output, "%s\n", temp);
                    } else if (target == CPU_9900) {
                        sprintf(temp, CONST_PREFIX "%s\tequ >%04x", assigned, c->value);
                        cpu9900_label(temp);    // Hack
                    }
                    node_delete(tree);
                    tree = NULL;
                }
            } else if (strcmp(name, "DIM") == 0) {
                char array[MAX_LINE_SIZE];
                struct label *new_array;
                struct node *tree;
                int type;
                int c;
                
                while (1) {
                    get_lex();
                    if (lex != C_NAME) {
                        emit_error("missing name in DIM");
                        break;
                    }
                    strcpy(array, name);
                    get_lex();
                    if (lex == C_LPAREN) {
                        get_lex();
                        tree = evaluate_level_0(&type);
                        if (tree->type != N_NUM8 && tree->type != N_NUM16) {
                            emit_error("not a constant expression in DIM");
                            break;
                        }
                        c = tree->value;
                        node_delete(tree);
                        if (lex != C_RPAREN) {
                            emit_error("missing right parenthesis in DIM");
                        } else {
                            get_lex();
                        }
                        new_array = array_search(array);
                        if (new_array != NULL) {
                            emit_error("array already defined");
                        } else {
                            new_array = array_add(array);
                            new_array->length = c;
                        }
                    } else {
                        label = label_add(array);
                        if (array[0] == '#')
                            label->used = TYPE_16;
                        else
                            label->used = TYPE_8;
                        label->used |= LABEL_IS_VARIABLE;
                    }
                    if (lex != C_COMMA)
                        break;
                }
            } else if (strcmp(name, "MODE") == 0) {
                get_lex();
                if (lex != C_NUM || (value != 0 && value != 1 && value != 2)) {
                    emit_error("bad syntax for MODE");
                    break;
                }
                get_lex();
                if (value == 0)
                    generic_call("mode_0");
                if (value == 1)
                    generic_call("mode_1");
                if (value == 2)
                    generic_call("mode_2");
            } else if (strcmp(name, "SCREEN") == 0) {  /* Copy screen */
                struct label *array;
                
                get_lex();
                if (lex != C_NAME) {
                    emit_error("bad syntax for SCREEN");
                    break;
                }
                if (strcmp(name, "ENABLE") == 0) {
                    get_lex();
                    generic_call("ENASCR");
                } else if (strcmp(name, "DISABLE") == 0) {
                    get_lex();
                    generic_call("DISSCR");
                } else {
                    array = array_search(name);
                    if (array != NULL) {
                        strcpy(assigned, ARRAY_PREFIX);
                        strcat(assigned, name);
                    } else {
                        array = label_search(name);
                        if (array == NULL) {
                            array = label_add(name);
                        }
                        array->used |= LABEL_USED;
                        strcpy(assigned, LABEL_PREFIX);
                        strcat(assigned, name);
                    }
                    get_lex();
                    if (lex == C_COMMA) {  /* There is a second argument? */
                        struct node *final;
                        struct node *addr;
                        int type;
                        
                        get_lex();
                        addr = node_create(N_ADDR, 0, NULL, NULL);
                        addr->label = array;
                        final = evaluate_level_0(&type);    /* Source */
                        if ((type & MAIN_TYPE) == TYPE_8)
                            final = node_create((type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, final, NULL);
                        final = node_create(N_PLUS16, 0, addr, final);
                        node_label(final);
                        node_generate(final, 0);
                        node_delete(final);
                        if (target == CPU_6502) {
                            cpu6502_noop("PHA");
                            cpu6502_noop("TYA");
                            cpu6502_noop("PHA");
                        } else if (target == CPU_9900) {
                            cpu9900_2op("mov","r0","r9");
                        } else {
                            cpuz80_1op("PUSH", "HL");
                        }
                        if (lex != C_COMMA) {
                            emit_error("missing comma after second parameter in SCREEN");
                            break;
                        }
                        get_lex();
                        final = evaluate_level_0(&type);    /* Target */
                        if ((type & MAIN_TYPE) == TYPE_8)
                            final = node_create((type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, final, NULL);
                        final = node_create(N_PLUS16, 0, node_create(N_NUM16, 0x1800, NULL, NULL), final);
                        node_label(final);
                        node_generate(final, 0);
                        node_delete(final);
                        if (target == CPU_6502) {
                            cpu6502_1op("STA", "pointer");
                            cpu6502_1op("STY", "pointer+1");
                        } else if (target == CPU_9900) {
                            cpu9900_2op("mov","r0","r8");
                        } else {
                            cpuz80_1op("PUSH", "HL");
                        }
                        if (lex != C_COMMA) {
                            emit_error("missing comma after third parameter in SCREEN");
                            break;
                        }
                        get_lex();
                        final = evaluate_level_0(&type);    /* Width */
                        if ((type & MAIN_TYPE) == TYPE_16)
                            final = node_create(N_REDUCE16, 0, final, NULL);
                        node_label(final);
                        node_generate(final, 0);
                        node_delete(final);
                        if (target == CPU_6502) {
                            cpu6502_noop("PHA");
                        } else if (target == CPU_9900) {
                            cpu9900_2op("mov","r0","r6");
                        } else {
                            cpuz80_1op("PUSH", "AF");
                        }
                        if (lex != C_COMMA) {
                            emit_error("missing comma after fourth parameter in SCREEN");
                            break;
                        }
                        get_lex();
                        final = evaluate_level_0(&type);    /* Height */
                        if ((type & MAIN_TYPE) == TYPE_16)
                            final = node_create(N_REDUCE16, 0, final, NULL);
                        node_label(final);
                        node_generate(final, 0);
                        node_delete(final);
                        if (lex == C_COMMA) {   /* Sixth argument for SCREEN (stride width) */
                            if (target == CPU_6502) {
                                cpu6502_noop("PHA");
                            } else if (target == CPU_9900) {
                                cpu9900_2op("mov","r0","r4");
                            } else {
                                cpuz80_1op("PUSH", "AF");
                            }
                            get_lex();
                            final = evaluate_level_0(&type);
                            if (target == CPU_6502) {
                                if ((type & MAIN_TYPE) == TYPE_8)
                                    final = node_create(N_EXTEND8, 0, final, NULL);
                            } else {
                                if ((type & MAIN_TYPE) == TYPE_16)
                                    final = node_create(N_REDUCE16, 0, final, NULL);
                            }
                            node_label(final);
                            node_generate(final, 0);
                            node_delete(final);
                            if (target == CPU_6502) {
                                cpu6502_noop("TAX");
                                cpu6502_noop("PLA");
                                cpu6502_1op("STA", "temp2+1");
                                cpu6502_noop("PLA");
                                cpu6502_1op("STA", "temp2");
                            } else if (target == CPU_9900) {
                                cpu9900_2op("mov","r0","r5");
                            }
                        } else {
                            if (target == CPU_6502) {
                                cpu6502_1op("STA", "temp2+1");
                                cpu6502_noop("PLA");
                                cpu6502_1op("STA", "temp2");
                                cpu6502_noop("TAX");    /* Copy previous width... */
                                cpu6502_1op("LDY", "#0");   /* ...as stride width */
                            } else if (target == CPU_9900) {
                                cpu9900_2op("mov","r0","r4");
                                cpu9900_2op("mov","r6","r5");   /* copy width as stride width */
                            } else {
                                cpuz80_2op("LD", "B", "A");
                                cpuz80_1op("POP", "AF");   /* Extract previous width */
                                cpuz80_1op("PUSH", "AF");  /* Save width */
                                cpuz80_1op("PUSH", "BC");  /* Save height */
                            }
                        }
                        if (target == CPU_6502) {
                            cpu6502_noop("PLA");
                            cpu6502_1op("STA","temp+1");
                            cpu6502_noop("PLA");
                            cpu6502_1op("STA","temp");
                        }   /* 9900 already covered */
                        generic_call("CPYBLK");
                    } else {
                        if (target == CPU_6502) {
                            sprintf(temp, "#%s", assigned);
                            cpu6502_1op("LDA", temp);
                            strcat(temp, ">>8");
                            cpu6502_1op("LDY", temp);
                            cpu6502_1op("STA", "temp");
                            cpu6502_1op("STY", "temp+1");
                            cpu6502_1op("LDA", "#0");
                            cpu6502_1op("LDY", "#3");
                            cpu6502_1op("STA", "temp2");
                            cpu6502_1op("STY", "temp2+1");
                            cpu6502_1op("LDA", "#0");
                            cpu6502_1op("LDY", "#24");
                            cpu6502_1op("STA", "pointer");
                            cpu6502_1op("STY", "pointer+1");
                            cpu6502_noop("SEI");
                            cpu6502_1op("JSR", "LDIRVM");
                            cpu6502_noop("CLI");
                        } else if (target == CPU_9900) {
                            cpu9900_2op("li","r0",">1800");
                            cpu9900_2op("li","r2",assigned);
                            cpu9900_2op("li","r3",">0300");
                            cpu9900_1op("limi","0");
                            cpu9900_1op("bl","@jsr");
                            cpu9900_1op("data","LDIRVM");
                            cpu9900_1op("limi","2");
                        } else {
                            cpuz80_2op("LD", "HL", assigned);
                            cpuz80_2op("LD", "DE", "$1800");
                            cpuz80_2op("LD", "BC", "$0300");
                            cpuz80_1op("CALL", "nmi_off");
                            cpuz80_1op("CALL", "LDIRVM");
                            cpuz80_1op("CALL", "nmi_on");
                        }
                    }
                }
            } else if (strcmp(name, "PLAY") == 0) {
                int c;
                
                get_lex();
                if (lex != C_NAME) {
                    emit_error("bad syntax for PLAY");
                    break;
                }
                music_used = 1;
                if (strcmp(name, "OFF") == 0) {
                    get_lex();
                    if (target == CPU_6502) {
                        cpu6502_1op("LDA", "#music_silence");
                        cpu6502_1op("LDY", "#music_silence>>8");
                    } else if (target == CPU_9900) {
                        cpu9900_2op("li", "r0", "music_silence");
                    } else {
                        cpuz80_2op("LD", "HL", "music_silence");
                    }
                    generic_call("music_play");
                } else if (strcmp(name, "NONE") == 0) {
                    get_lex();
                    if (target == CPU_6502) {
                        cpu6502_1op("LDA", "#0");
                        cpu6502_1op("STA", "music_mode");
                    } else if (target == CPU_9900) {
                        cpu9900_1op("clr", "r0");
                        cpu9900_2op("movb", "r0", "@music_mode");
                    } else {
                        cpuz80_1op("XOR", "A");
                        cpuz80_2op("LD", "(music_mode)", "A");
                    }
                } else if (strcmp(name, "SIMPLE") == 0) {
                    get_lex();
                    c = 3;
                    if (lex == C_NAME && strcmp(name, "NO") == 0) {
                        get_lex();
                        if (lex == C_NAME && strcmp(name, "DRUMS") == 0) {
                            get_lex();
                            c = 2;
                        } else {
                            emit_error("only allowed PLAY SIMPLE NO DRUMS");
                        }
                    }
                    if (target == CPU_6502) {
                        sprintf(temp, "#%d", c);
                        cpu6502_1op("LDA", temp);
                        cpu6502_1op("STA", "music_mode");
                    } else if (target == CPU_9900) {
                        sprintf(temp, "%d   ; %d*256", c*256, c);
                        cpu9900_2op("li", "r0", temp);
                        cpu9900_2op("movb", "r0", "@music_mode");
                    } else {
                        sprintf(temp, "%d", c);
                        cpuz80_2op("LD", "A", temp);
                        cpuz80_2op("LD", "(music_mode)", "A");
                    }
                } else if (strcmp(name, "FULL") == 0) {
                    get_lex();
                    c = 5;
                    if (lex == C_NAME && strcmp(name, "NO") == 0) {
                        get_lex();
                        if (lex == C_NAME && strcmp(name, "DRUMS") == 0) {
                            get_lex();
                            c = 4;
                        } else {
                            emit_error("only allowed PLAY FULL NO DRUMS");
                        }
                    }
                    if (target == CPU_6502) {
                        sprintf(temp, "#%d", c);
                        cpu6502_1op("LDA", temp);
                        cpu6502_1op("STA", "music_mode");
                    } else if (target == CPU_9900) {
                        sprintf(temp, "%d   ; %d*256", c*256, c);
                        cpu9900_2op("li", "r0", temp);
                        cpu9900_2op("movb", "r0", "@music_mode");
                    } else {
                        sprintf(temp, "%d", c);
                        cpuz80_2op("LD", "A", temp);
                        cpuz80_2op("LD", "(music_mode)", "A");
                    }
                } else {
                    struct label *label;
                    
                    label = label_search(name);
                    if (label == NULL) {
                        label = label_add(name);
                    }
                    label->used |= LABEL_USED;
                    if (target == CPU_6502) {
                        strcpy(temp, "#" LABEL_PREFIX);
                        strcat(temp, name);
                        cpu6502_1op("LDA", temp);
                        strcat(temp, ">>8");
                        cpu6502_1op("LDY", temp);
                    } else if (target == CPU_9900) {
                        strcpy(temp, LABEL_PREFIX);
                        strcat(temp, name);
                        cpu9900_2op("li", "r0", temp);
                    } else {
                        strcpy(temp, LABEL_PREFIX);
                        strcat(temp, name);
                        cpuz80_2op("LD", "HL", temp);
                    }
                    generic_call("music_play");
                    get_lex();
                }
            } else if (strcmp(name, "MUSIC") == 0) {
                int arg;
                static int previous[4];
                unsigned int notes;
                int note;
                int c;
                int label;
                
                generic_dump();
                get_lex();
                label = 0;
                notes = 0;
                arg = 0;
                while (1) {
                    if (lex != C_NAME && lex != C_MINUS) {
                        emit_error("bad syntax for MUSIC");
                        break;
                    }
                    if (lex == C_MINUS) {
                        /* Nothing to do */
                    } else if (arg == 0 && strcmp(name, "REPEAT") == 0) {
                        get_lex();
                        notes = 0xfd;
                        break;
                    } else if (arg == 0 && strcmp(name, "STOP") == 0) {
                        get_lex();
                        notes = 0xfe;
                        break;
                    } else if (arg == 3) {
                        if (name[0] != 'M' || name[1] < '1' || name[1] > '3') {
                            emit_error("bad syntax for drum in MUSIC");
                            break;
                        }
                        notes |= (name[1] - '0') << ((arg & 3) * 8);
                    } else if (strcmp(name, "S") == 0) {
                        notes |= 0x3f << ((arg & 3) * 8);
                    } else {
                        notes |= previous[arg] << ((arg & 3) * 8);
                        c = 0;
                        switch (name[c++]) {
                            case 'C': note = 0; break;
                            case 'D': note = 2; break;
                            case 'E': note = 4; break;
                            case 'F': note = 5; break;
                            case 'G': note = 7; break;
                            case 'A': note = 9; break;
                            case 'B': note = 11; break;
                            default:
                                note = 0;
                                emit_error("bad syntax for note in MUSIC");
                                break;
                        }
                        switch (name[c++]) {
                            case '2': note += 0 * 12; break;
                            case '3': note += 1 * 12; break;
                            case '4': note += 2 * 12; break;
                            case '5': note += 3 * 12; break;
                            case '6': note += 4 * 12; break;
                            case '7': if (note == 0) { note += 5 * 12; break; }
                            default:
                                emit_error("bad syntax for note in MUSIC");
                                break;
                        }
                        note++;
                        if (name[c] == '#') {
                            note++;
                            c++;
                        }
                        if (name[c] == 'W') {
                            previous[arg] = 0x00;
                            notes &= ~(0xc0 << ((arg & 3) * 8));
                            notes |= previous[arg] << ((arg & 3) * 8);
                        } else if (name[c] == 'X') {
                            previous[arg] = 0x40;
                            notes &= ~(0xc0 << ((arg & 3) * 8));
                            notes |= previous[arg] << ((arg & 3) * 8);
                        } else if (name[c] == 'Y') {
                            previous[arg] = 0x80;
                            notes &= ~(0xc0 << ((arg & 3) * 8));
                            notes |= previous[arg] << ((arg & 3) * 8);
                        } else if (name[c] == 'Z') {
                            previous[arg] = 0xc0;
                            notes &= ~(0xc0 << ((arg & 3) * 8));
                            notes |= previous[arg] << ((arg & 3) * 8);
                        }
                        notes |= note << ((arg & 3) * 8);
                    }
                    get_lex();
                    arg++;
                    if (lex != C_COMMA)
                        break;
                    if (arg == 4) {
                        emit_error("too many arguments for MUSIC");
                        break;
                    }
                    get_lex();
                }
                if (target == CPU_9900) {
                    fprintf(output, "\tbyte >%02x,>%02x,>%02x,>%02x\n", notes & 0xff, (notes >> 8) & 0xff, (notes >> 16) & 0xff, (notes >> 24) & 0xff);
                } else {
                    fprintf(output, "\tdb $%02x,$%02x,$%02x,$%02x\n", notes & 0xff, (notes >> 8) & 0xff, (notes >> 16) & 0xff, (notes >> 24) & 0xff);
                }
            } else if (strcmp(name, "ON") == 0) {
                struct label *label;
                int table;
                int c;
                int max_value;
                int gosub;
                int fast;
                struct label *options[256];
                int new_label;
                int type;
                
                get_lex();
                if (lex == C_NAME && strcmp(name, "FRAME") == 0) {  /* Frame-driven games */
                    get_lex();
                    if (lex != C_NAME || strcmp(name, "GOSUB") != 0) {
                        emit_error("Bad syntax for ON FRAME GOSUB");
                    }
                    get_lex();
                    if (lex != C_NAME) {
                        emit_error("Missing label for ON FRAME GOSUB");
                    }
                    if (frame_drive != NULL) {
                        emit_error("More than one ON FRAME GOSUB");
                    }
                    label = label_search(name);
                    if (label == NULL) {
                        label = label_add(name);
                    }
                    label->used |= LABEL_USED;
                    label->used |= LABEL_CALLED_BY_GOSUB;
                    frame_drive = label;
                    get_lex();
                } else {
                    type = evaluate_expression(0, 0, 0);
                    fast = 0;
                    if (lex == C_NAME && strcmp(name, "FAST") == 0) {
                        get_lex();
                        fast = 1;
                    }
                    gosub = 0;
                    if (lex != C_NAME || (strcmp(name, "GOTO") != 0 && strcmp(name, "GOSUB") != 0)) {
                        emit_error("required GOTO or GOSUB after ON");
                    } else if (strcmp(name, "GOTO") == 0) {
                        get_lex();
                    } else if (strcmp(name, "GOSUB") == 0) {
                        get_lex();
                        gosub = 1;
                    }
                    max_value = 0;
                    while (1) {
                        if (max_value == sizeof(options) / sizeof(struct label *)) {
                            emit_error("too many options for ON statement");
                            max_value--;
                        }
                        if (lex == C_NAME) {
                            label = label_search(name);
                            if (label == NULL) {
                                label = label_add(name);
                            }
                            label->used |= LABEL_USED;
                            if (gosub != 0) {
                                label->used |= LABEL_CALLED_BY_GOSUB;
                            } else {
                                label->used |= LABEL_CALLED_BY_GOTO;
                            }
                            options[max_value++] = label;
                            get_lex();
                        } else {
                            options[max_value++] = NULL;
                        }
                        if (lex != C_COMMA)
                            break;
                        get_lex();
                    }
                    table = next_local++;
                    new_label = next_local++;
                    if (fast == 0) {
                        if (target == CPU_6502) {
                            if ((type & MAIN_TYPE) == TYPE_8) {
                                cpu6502_1op("STA", "temp");
                                cpu6502_1op("LDY", "#0");
                                cpu6502_1op("STY", "temp+1");
                                sprintf(temp, "#%d", max_value);
                                cpu6502_1op("CMP", temp);
                            } else {
                                cpu6502_1op("STA", "temp");
                                cpu6502_1op("STY", "temp+1");
                                sprintf(temp, "#%d", max_value);
                                cpu6502_1op("LDA", "temp");
                                cpu6502_noop("SEC");
                                cpu6502_1op("SBC", temp);
                                cpu6502_1op("LDA", "temp+1");
                                strcat(temp, ">>8");
                                cpu6502_1op("SBC", temp);
                            }
                            sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                            cpu6502_1op("BCS.L", temp);
                        } else if (target == CPU_9900) {
                            if ((type & MAIN_TYPE) == TYPE_8) {
                                sprintf(temp, "%d   ; %d*256", max_value*256, max_value);
                                cpu9900_2op("ci", "r0", temp);
                            } else {
                                sprintf(temp, "%d", max_value);
                                cpu9900_2op("ci", "r0", temp);
                            }
                            sprintf(temp, "@" INTERNAL_PREFIX "%d", new_label);
                            sprintf(temp + 100, INTERNAL_PREFIX "%d", next_local++);
                            cpu9900_1op("jl", temp + 100);
                            cpu9900_1op("b", temp);
                            cpu9900_label(temp + 100);
                        } else {
                            if ((type & MAIN_TYPE) == TYPE_8) {
                                sprintf(temp, "%d", max_value);
                                cpuz80_1op("CP", temp);
                            } else {
                                sprintf(temp, "%d", max_value);
                                cpuz80_2op("LD", "DE", temp);
                                cpuz80_1op("OR", "A");
                                cpuz80_2op("SBC", "HL", "DE");
                                cpuz80_2op("ADD", "HL", "DE");
                            }
                            sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                            cpuz80_2op("JP", "NC", temp);
                        }
                    }
                    if (gosub) {
                        if (target == CPU_6502) {
                            sprintf(temp, "#(" INTERNAL_PREFIX "%d-1)>>8", new_label);
                            cpu6502_1op("LDA", temp);
                            cpu6502_noop("PHA");
                            sprintf(temp, "#" INTERNAL_PREFIX "%d-1", new_label);
                            cpu6502_1op("LDA", temp);
                            cpu6502_noop("PHA");
                        } else if (target == CPU_9900) {
                            sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                            cpu9900_2op("li", "r1", temp);
                            cpu9900_1op("dect", "r10");   /* stack manipulation */
                            cpu9900_2op("mov", "r1", "*r10");
                        } else {
                            sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                            cpuz80_2op("LD", "DE", temp);
                            cpuz80_1op("PUSH", "DE");
                        }
                    }
                    if (target == CPU_6502) {
                        cpu6502_1op("LDA", "temp");
                        cpu6502_1op("ASL", "A");
                        cpu6502_1op("ROL", "temp+1");
                        cpu6502_noop("CLC");
                        sprintf(temp, "#" INTERNAL_PREFIX "%d", table);
                        cpu6502_1op("ADC", temp);
                        cpu6502_1op("STA", "temp");
                        cpu6502_1op("LDA", "temp+1");
                        strcat(temp, ">>8");
                        cpu6502_1op("ADC", temp);
                        cpu6502_1op("STA", "temp+1");
                        cpu6502_1op("LDY", "#0");
                        cpu6502_1op("LDA", "(temp),Y");
                        cpu6502_1op("STA", "temp2");
                        cpu6502_noop("INY");
                        cpu6502_1op("LDA", "(temp),Y");
                        cpu6502_1op("STA", "temp2+1");
                        cpu6502_1op("JMP", "(temp2)");
                    } else if (target == CPU_9900) {
                        if ((type & MAIN_TYPE) == TYPE_8) {
                            cpu9900_2op("srl", "r0", "8");
                        }
                        cpu9900_2op("sla", "r0", "1");
                        cpu9900_2op("mov", "r0", "r1");
                        sprintf(temp, "@" INTERNAL_PREFIX "%d(r1)", table);
                        cpu9900_2op("mov", temp, "r0");
                        cpu9900_1op("b", "*r0");
                    } else {
                        if ((type & MAIN_TYPE) == TYPE_8) {
                            cpuz80_2op("LD", "L", "A");
                            if (type & TYPE_SIGNED) {
                                cpuz80_noop("RLA");
                                cpuz80_2op("SBC", "A", "A");
                                cpuz80_2op("LD", "H", "A");
                            } else {
                                cpuz80_2op("LD", "H", "0");
                            }
                        }
                        cpuz80_2op("ADD", "HL", "HL");
                        sprintf(temp, INTERNAL_PREFIX "%d", table);
                        cpuz80_2op("LD", "DE", temp);
                        cpuz80_2op("ADD", "HL", "DE");
                        cpuz80_2op("LD", "A", "(HL)");
                        cpuz80_1op("INC", "HL");
                        cpuz80_2op("LD", "H", "(HL)");
                        cpuz80_2op("LD", "L", "A");
                        cpuz80_1op("JP", "(HL)");
                    }
                    sprintf(temp, INTERNAL_PREFIX "%d", table);
                    generic_label(temp);
                    for (c = 0; c < max_value; c++) {
                        if (options[c] != NULL) {
                            sprintf(temp, LABEL_PREFIX "%s", options[c]->name);
                        } else {
                            sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                        }
                        if (target == CPU_6502)
                            cpu6502_1op("DW", temp);
                        else if (target == CPU_9900)
                            cpu9900_1op("data", temp);
                        else
                            cpuz80_1op("DW", temp);
                    }
                    sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                    generic_label(temp);
                }
            } else if (strcmp(name, "SOUND") == 0) {
                get_lex();
                if (lex != C_NUM) {
                    emit_error("syntax error in SOUND");
                } else {
                    if (value < 3 && (machine == MSX || machine == SVI || machine == EINSTEIN || machine == NABU))
                        emit_warning("using SOUND 0-3 with AY-3-8910 target");
                    else if (value >= 5 && machine != MSX && machine != COLECOVISION_SGM && machine != SVI && machine != SORD && machine != MEMOTECH)
                        emit_warning("using SOUND 5-9 with SN76489 target");
                    switch (value) {
                        case 0:
                            get_lex();
                            if (lex != C_COMMA) {
                                emit_error("missing comma in sound");
                            } else {
                                get_lex();
                            }
                            if (lex != C_COMMA) {
                                type = evaluate_expression(1, TYPE_16, 0);
                                if (target == CPU_6502) {
                                    cpu6502_1op("LDX", "#128");
                                } else if (target == CPU_9900) {
                                    cpu9900_2op("li", "r2", ">8000");
                                } else {
                                    cpuz80_2op("LD", "A", "$80");
                                }
                                generic_call("sn76489_freq");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                if (target == CPU_6502) {
                                    cpu6502_1op("LDX", "#144");
                                } else if (target == CPU_9900) {
                                    cpu9900_2op("li", "r2", ">9000");
                                } else {
                                    cpuz80_2op("LD", "B", "$90");
                                }
                                generic_call("sn76489_vol");
                            }
                            break;
                        case 1:
                            get_lex();
                            if (lex != C_COMMA) {
                                emit_error("missing comma in sound");
                            } else {
                                get_lex();
                            }
                            if (lex != C_COMMA) {
                                type = evaluate_expression(1, TYPE_16, 0);
                                if (target == CPU_6502) {
                                    cpu6502_1op("LDX", "#160");
                                } else if (target == CPU_9900) {
                                    cpu9900_2op("li", "r2", ">a000");
                                } else {
                                    cpuz80_2op("LD", "A", "$a0");
                                }
                                generic_call("sn76489_freq");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                if (target == CPU_6502) {
                                    cpu6502_1op("LDX", "#176");
                                } else if (target == CPU_9900) {
                                    cpu9900_2op("li", "r2", ">b000");
                                } else {
                                    cpuz80_2op("LD", "B", "$b0");
                                }
                                generic_call("sn76489_vol");
                            }
                            break;
                        case 2:
                            get_lex();
                            if (lex != C_COMMA) {
                                emit_error("missing comma in sound");
                            } else {
                                get_lex();
                            }
                            if (lex != C_COMMA) {
                                type = evaluate_expression(1, TYPE_16, 0);
                                if (target == CPU_6502) {
                                    cpu6502_1op("LDX", "#192");
                                } else if (target == CPU_9900) {
                                    cpu9900_2op("li", "r2", ">c000");
                                } else {
                                    cpuz80_2op("LD", "A", "$c0");
                                }
                                generic_call("sn76489_freq");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                if (target == CPU_6502) {
                                    cpu6502_1op("LDX", "#208");
                                } else if (target == CPU_9900) {
                                    cpu9900_2op("li", "r2", ">d000");
                                } else {
                                    cpuz80_2op("LD", "B", "$d0");
                                }
                                generic_call("sn76489_vol");
                            }
                            break;
                        case 3:
                            get_lex();
                            if (lex != C_COMMA) {
                                emit_error("missing comma in sound");
                            } else {
                                get_lex();
                            }
                            if (lex != C_COMMA) {
                                type = evaluate_expression(1, TYPE_8, 0);
                                generic_call("sn76489_control");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                if (target == CPU_6502) {
                                    cpu6502_1op("LDX", "#240");
                                } else if (target == CPU_9900) {
                                    cpu9900_2op("li", "r2", ">f000");
                                } else {
                                    cpuz80_2op("LD", "B", "$f0");
                                }
                                generic_call("sn76489_vol");
                            }
                            break;
                        case 5:
                            get_lex();
                            if (lex != C_COMMA) {
                                emit_error("missing comma in sound");
                            } else {
                                get_lex();
                            }
                            if (lex != C_COMMA) {
                                type = evaluate_expression(1, TYPE_16, 0);
                                if (target == CPU_6502) {
                                    /* Nothing to do */
                                } else if (target == CPU_9900) {
                                    /* Nothing to do - could consider SID Blaster... */
                                } else {
                                    cpuz80_2op("LD", "A", "$00");
                                    cpuz80_1op("CALL", "ay3_freq");
                                }
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                if (target == CPU_6502) {
                                    /* Nothing to do */
                                } else if (target == CPU_9900) {
                                    /* Nothing to do - could consider SID Blaster... */
                                } else {
                                    cpuz80_2op("LD", "B", "$08");
                                    cpuz80_1op("CALL", "ay3_reg");
                                }
                            }
                            break;
                        case 6:
                            get_lex();
                            if (lex != C_COMMA) {
                                emit_error("missing comma in sound");
                            } else {
                                get_lex();
                            }
                            if (lex != C_COMMA) {
                                type = evaluate_expression(1, TYPE_16, 0);
                                if (target == CPU_6502) {
                                    /* Nothing to do */
                                } else if (target == CPU_9900) {
                                    /* Nothing to do - could consider SID Blaster... */
                                } else {
                                    cpuz80_2op("LD", "A", "$02");
                                    cpuz80_1op("CALL", "ay3_freq");
                                }
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                if (target == CPU_6502) {
                                    /* Nothing to do */
                                } else if (target == CPU_9900) {
                                    /* Nothing to do - could consider SID Blaster... */
                                } else {
                                    cpuz80_2op("LD", "B", "$09");
                                    cpuz80_1op("CALL", "ay3_reg");
                                }
                            }
                            break;
                        case 7:
                            get_lex();
                            if (lex != C_COMMA) {
                                emit_error("missing comma in sound");
                            } else {
                                get_lex();
                            }
                            if (lex != C_COMMA) {
                                type = evaluate_expression(1, TYPE_16, 0);
                                if (target == CPU_6502) {
                                    /* Nothing to do */
                                } else if (target == CPU_9900) {
                                    /* Nothing to do - could consider SID Blaster... */
                                } else {
                                    cpuz80_2op("LD", "A", "$04");
                                    cpuz80_1op("CALL", "ay3_freq");
                                }
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                if (target == CPU_6502) {
                                    /* Nothing to do */
                                } else if (target == CPU_9900) {
                                    /* Nothing to do - could consider SID Blaster... */
                                } else {
                                    cpuz80_2op("LD", "B", "$0a");
                                    cpuz80_1op("CALL", "ay3_reg");
                                }
                            }
                            break;
                        case 8:
                            get_lex();
                            if (lex != C_COMMA) {
                                emit_error("missing comma in sound");
                            } else {
                                get_lex();
                            }
                            if (lex != C_COMMA) {
                                type = evaluate_expression(1, TYPE_16, 0);
                                if (target == CPU_6502) {
                                    /* Nothing to do */
                                } else if (target == CPU_9900) {
                                    /* Nothing to do */
                                } else {
                                    cpuz80_2op("LD", "A", "$0b");
                                    cpuz80_1op("CALL", "ay3_freq");
                                }
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                if (target == CPU_6502) {
                                    /* Nothing to do */
                                } else if (target == CPU_9900) {
                                    /* Nothing to do */
                                } else {
                                    cpuz80_2op("LD", "B", "$0d");
                                    cpuz80_1op("CALL", "ay3_reg");
                                }
                            }
                            break;
                        case 9:
                            get_lex();
                            if (lex != C_COMMA) {
                                emit_error("missing comma in sound");
                            } else {
                                get_lex();
                            }
                            if (lex != C_COMMA) {
                                type = evaluate_expression(1, TYPE_8, 0);
                                if (target == CPU_6502) {
                                    /* Nothing to do */
                                } else if (target == CPU_9900) {
                                    /* Nothing to do */
                                } else {
                                    cpuz80_2op("LD", "B", "$06");
                                    cpuz80_1op("CALL", "ay3_reg");
                                }
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                if (target == CPU_6502) {
                                    /* Nothing to do */
                                } else if (target == CPU_9900) {
                                    /* Nothing to do */
                                } else {
                                    cpuz80_1op("AND", "$3f");
                                    if (machine == EINSTEIN || machine == NABU) {
                                        cpuz80_1op("OR", "$40");
                                    } else {
                                        /* Protect these MSX machines! */
                                        cpuz80_1op("OR", "$80");
                                    }
                                    cpuz80_2op("LD", "B", "$07");
                                    cpuz80_1op("CALL", "ay3_reg");
                                }
                            }
                            break;
                    }
                }
            } else if (strcmp(name, "CALL") == 0) {        /* Call assembly language */
                struct node *tree;
                
                get_lex();
                tree = process_usr(1);
                node_label(tree);
                node_generate(tree, 0);
                node_delete(tree);
            } else if (strcmp(name, "ASM") == 0) {  /* ASM statement for inserting assembly code */
                int c;
                
                generic_dump();
                c = line_pos;
                while (c < line_size && isspace(line[c]))
                    c++;
                while (c < line_size && !isspace(line[c]))
                    c++;
                if (line[c - 1] == ':')
                    lex_skip_spaces();
                if (target == CPU_9900) {
                    /* check for and remap INCBIN */
                    if (strncmp(&line[line_pos]," INCBIN", 7) == 0) {
                        memcpy(&line[line_pos],"  bcopy", 7);
                    }
                }
                fprintf(output, "%s\n", &line[line_pos]);
                line_pos = line_size;
                get_lex();
            } else if (strcmp(name, "DEF") == 0) {     /* Function definition (macro in CVBasic) */
                char function[MAX_LINE_SIZE];
                int total_arguments;
                char *arguments[32];
                struct macro *macro;
                int c;
                
                get_lex();
                if (lex != C_NAME || strcmp(name, "FN") != 0) {
                    emit_error("syntax error for DEF FN");
                } else {
                    get_lex();
                    if (lex != C_NAME) {
                        emit_error("missing function name for DEF FN");
                    } else if (macro_search(name) != NULL) {
                        emit_error("DEF FN name already defined");
                    } else {
                        strcpy(function, name);
                        get_lex();
                        total_arguments = 0;
                        if (lex == C_LPAREN) {
                            get_lex();
                            while (1) {
                                if (lex != C_NAME) {
                                    emit_error("syntax error in argument list for DEF FN");
                                    break;
                                }
                                if (total_arguments == 32) {
                                    emit_error("More than 32 arguments in DEF FN");
                                    break;
                                }
                                arguments[total_arguments] = malloc(strlen(name) + 1);
                                if (arguments[total_arguments] == NULL) {
                                    emit_error("Out of memory in DEF FN");
                                    break;
                                }
                                strcpy(arguments[total_arguments], name);
                                total_arguments++;
                                get_lex();
                                if (lex == C_COMMA) {
                                    get_lex();
                                } else if (lex == C_RPAREN) {
                                    get_lex();
                                    break;
                                } else {
                                    emit_error("syntax error in argument list for DEF FN");
                                    break;
                                }
                            }
                        }
                        macro = macro_add(function);
                        macro->total_arguments = total_arguments;
                        if (lex != C_EQUAL) {
                            emit_error("missing = in DEF FN");
                        } else {
                            get_lex();
                            while (lex != C_END) {
                                if (lex == C_ERR) {
                                    emit_error("bad syntax inside DEF FN replacement text");
                                    break;
                                }
                                if (lex == C_NAME) {
                                    for (c = 0; c < total_arguments; c++) {
                                        if (strcmp(arguments[c], name) == 0)
                                            break;
                                    }
                                    if (c < total_arguments) {
                                        lex = C_ERR;
                                        value = c;
                                        name[0] = '\0';
                                    }
                                }
                                if (macro->length >= macro->max_length) {
                                    macro->definition = realloc(macro->definition, (macro->max_length + 1) * 2 * sizeof(struct macro_def));
                                    if (macro->definition == NULL) {
                                        emit_error("Out of memory in DEF FN");
                                        break;
                                    }
                                    macro->max_length = (macro->max_length + 1) * 2;
                                }
                                macro->definition[macro->length].lex = lex;
                                macro->definition[macro->length].value = value;
                                macro->definition[macro->length].name = malloc(strlen(name) + 1);
                                if (macro->definition[macro->length].name == NULL) {
                                    emit_error("Out of memory in DEF FN");
                                    break;
                                }
                                strcpy(macro->definition[macro->length].name, name);
                                macro->length++;
                                get_lex();
                            }
                        }
                    }
                }
            } else if (strcmp(name, "OPTION") == 0) {
                get_lex();
                if (lex != C_NAME) {
                    emit_error("required name after OPTION");
                } else if (strcmp(name, "EXPLICIT") == 0) {
                    get_lex();
                    if (lex == C_NAME && strcmp(name, "ON") == 0) {
                        get_lex();
                        option_explicit = 1;
                    } else if (lex == C_NAME && strcmp(name, "OFF") == 0) {
                        get_lex();
                        option_explicit = 0;
                    } else {
                        option_explicit = 1;
                    }
                } else if (strcmp(name, "WARNINGS") == 0) {
                    get_lex();
                    if (lex == C_NAME && strcmp(name, "ON") == 0) {
                        get_lex();
                        option_warnings = 1;
                    } else if (lex == C_NAME && strcmp(name, "OFF") == 0) {
                        get_lex();
                        option_warnings = 0;
                    } else {
                        emit_error("missing ON/OFF in OPTION WARNINGS");
                    }
                } else {
                    emit_error("non-recognized OPTION");
                }
            } else if (strcmp(name, "BANK") == 0) {
                get_lex();
                if (lex == C_NAME && strcmp(name, "ROM") == 0) {
                    get_lex();
                    if (lex != C_NUM) {
                        emit_error("Bad syntax for BANK ROM");
                    } else if (value != 128 && value != 256 && value != 512 && value != 1024) {
                        // TODO: TI can do 2MB as it stands, and 32MB with the scheme. But leaving at 1MB for now.
                        emit_error("BANK ROM not 128, 256, 512 or 1024");
                        get_lex();
                    } else if (bank_switching != 0) {
                        emit_error("BANK ROM used twice");
                        get_lex();
                    } else {
                        if (machine == SVI || machine == SORD || machine == MEMOTECH || machine == CREATIVISION || machine == EINSTEIN || machine == PV2000) {
                            emit_error("Bank-switching not supported with current platform");
                        } else {
                            bank_switching = 1;
                            bank_rom_size = value;
                            bank_current = 0;
                        }
                        get_lex();
                    }
                } else if (lex == C_NAME && strcmp(name, "SELECT") == 0) {
                    int c;
                    struct node *tree;
                    int type;
                    
                    get_lex();
                    tree = evaluate_level_0(&type);
                    if (tree->type != N_NUM8 && tree->type != N_NUM16) {
                        emit_error("not a constant expression in BANK SELECT");
                        break;
                    }
                    c = tree->value;
                    node_delete(tree);
                    if (bank_switching == 0) {
                        emit_error("Using BANK SELECT without BANK ROM");
                    } else {
                        if (machine == TI994A) {
                            // the TI needs to use 8k banks, so our masks are different
                            c+=2;   // reserving 3 banks (0,1,2) for 'fixed' space

                            if (bank_rom_size == 128)
                                c &= 0x0f;
                            else if (bank_rom_size == 256)
                                c &= 0x1f;
                            else if (bank_rom_size == 512)
                                c &= 0x3f;
                            else
                                c &= 0x7f;
                            
                            c = 0x6000+(c*2);   // ROM address to poke
                            sprintf(temp, "@>%x", c);
                            cpu9900_1op("clr", temp);
                        } else {
                            if (machine == COLECOVISION || machine == COLECOVISION_SGM)
                                c--;
                            if (bank_rom_size == 128)
                                c &= 0x07;
                            else if (bank_rom_size == 256)
                                c &= 0x0f;
                            else if (bank_rom_size == 512)
                                c &= 0x1f;
                            else
                                c &= 0x3f;
                            if (machine == SG1000) {
                                sprintf(temp, "%d", c & 0x3f);
                                cpuz80_2op("LD", "A", temp);
                                cpuz80_2op("LD", "($fffe)", "A");
                            } else if (machine == MSX) {
                                sprintf(temp, "%d", c & 0x3f);
                                cpuz80_2op("LD", "A", temp);
                                cpuz80_2op("LD", "($7000)", "A");
                            } else {
                                if (bank_rom_size == 128)
                                    c |= 0xfff8;
                                else if (bank_rom_size == 256)
                                    c |= 0xfff0;
                                else if (bank_rom_size == 512)
                                    c |= 0xffe0;
                                else
                                    c |= 0xffc0;
                                sprintf(temp, "($%04x)", c);
                                cpuz80_2op("LD", "A", temp);
                            }
                        }
                    }
                } else {
                    int c;
                    int d;
                    struct node *tree;
                    int type;

                    tree = evaluate_level_0(&type);
                    if (tree->type != N_NUM8 && tree->type != N_NUM16) {
                        emit_error("not a constant expression in BANK SELECT");
                        break;
                    }
                    c = tree->value;
                    node_delete(tree);
                    if (bank_switching == 0) {
                        emit_error("Using BANK without BANK ROM");
                    } else {
                        d = c;
                        if (machine == TI994A) {
                            // the TI needs to use 8k banks, so our masks are different
                            c+=2;   // reserving 3 banks (0,1,2) for 'fixed' space

                            if (bank_rom_size == 128)
                                c &= 0x0f;
                            else if (bank_rom_size == 256)
                                c &= 0x1f;
                            else if (bank_rom_size == 512)
                                c &= 0x3f;
                            else
                                c &= 0x7f;
                            bank_finish();
                            
                            sprintf(temp, "%d", c);
                            cpu9900_1op("bank", temp);
                            cpu9900_empty();
                        } else {
                            if (machine == COLECOVISION || machine == COLECOVISION_SGM)
                                c--;
                            if (machine == TI994A)
                                c+=2;   // reserving 3 banks (0,1,2) for 'fixed' space
                            if (bank_rom_size == 128)
                                c &= 0x07;
                            else if (bank_rom_size == 256)
                                c &= 0x0f;
                            else if (bank_rom_size == 512)
                                c &= 0x1f;
                            else
                                c &= 0x3f;
                            bank_finish();
                            sprintf(temp, "$%05x", c << 14);
                            cpuz80_1op("FORG", temp);
                            if (machine == SG1000) {
                                cpuz80_1op("ORG", "$4000");
                            } else if (machine == MSX) {
                                cpuz80_1op("ORG", "$8000");
                            } else {
                                cpuz80_1op("ORG", "$c000");
                            }
                            cpuz80_empty();
                        }
                        bank_current = d;
                    }
                }
            } else if (strcmp(name, "VDP") == 0 && lex_sneak_peek() == '(') {   /* VDP pseudo-array */
                int vdp_reg;
                
                get_lex();
                if (lex != C_LPAREN)
                    emit_error("Missing left parenthesis in VDP");
                else
                    get_lex();
                if (lex != C_NUM) {
                    emit_error("Not a constant in VDP");
                } else {
                    vdp_reg = value;
                    get_lex();
                }
                if (lex != C_RPAREN)
                    emit_error("Missing right parenthesis in VDP");
                else
                    get_lex();
                if (lex != C_EQUAL)
                    emit_error("Missing equal sign in VDP");
                else
                    get_lex();
                type = evaluate_expression(1, TYPE_8, 0);
                if (target == CPU_6502) {
                    sprintf(temp, "#%d", vdp_reg);
                    cpu6502_1op("LDX", temp);
                    cpu6502_noop("SEI");
                    cpu6502_1op("JSR", "WRTVDP");
                    cpu6502_noop("CLI");
                } else if (target == CPU_9900) {
                    /* Simpler to do inline */
                    sprintf(temp, "%d   ; %d*256+0x8000", vdp_reg*256+0x8000, vdp_reg);
                    cpu9900_2op("li", "r1", temp);
                    cpu9900_2op("movb", "r0", "@VDPWADR");
                    cpu9900_2op("movb", "r1", "@VDPWADR");
                    /*
                     ** only timing critical in scratchpad with register indirect addressing,
                     ** even then probably safe on the 99/4A
                     */
                } else {
                    cpuz80_2op("LD", "B", "A");
                    sprintf(temp, "%d", vdp_reg);
                    cpuz80_2op("LD", "C", temp);
                    cpuz80_1op("CALL", "nmi_off");
                    cpuz80_1op("CALL", "WRTVDP");
                    cpuz80_1op("CALL", "nmi_on");
                }
            } else if (macro_search(name) != NULL) {  /* Function (macro) */
                if (!replace_macro()) {
                    compile_statement(check_for_else);
                    return;
                }
            } else {
                compile_assignment(0);
            }
        } else {
            last_is_return = 0;
            emit_error("syntax error in statement");
        }
        if (lex != C_COLON)
            break;
        get_lex();
    }
}

/*
 ** Compile a source code file.
 */
void compile_basic(void)
{
    struct label *label;
    int label_exists;
    char *p;

    current_line = 0;
    while (fgets(line, sizeof(line) - 1, input)) {
        current_line++;

        line_size = (int) strlen(line);
        if (line_size > 0 && line[line_size - 1] == '\n')
            line[--line_size] = '\0';
        if (line_size > 0 && line[line_size - 1] == '\r')
            line[--line_size] = '\0';

        generic_dump();
        fprintf(output, "\t; %s\n", line);
        
        line_start = 1;
        line_pos = 0;
        label_exists = 0;
        label = NULL;
        get_lex();
        if (lex == C_LABEL) {
            if (value == 0)
                strcpy(global_label, name);
            label = label_search(name);
            if (label != NULL) {
                if (label->used & LABEL_DEFINED) {
                    char buffer[MAX_LINE_SIZE];
                    
                    sprintf(buffer, "already defined '%s' label", name);
                    emit_error(buffer);
                }
            } else {
                label = label_add(name);
            }
            label->used |= LABEL_DEFINED;
            strcpy(temp, LABEL_PREFIX);
            strcat(temp, name);
            generic_label(temp);
            get_lex();
            label_exists = 1;
        }
        if (lex == C_NAME) {
            if (strcmp(name, "PROCEDURE") == 0) {
                if (!label_exists)
                    emit_error("PROCEDURE without label in same line");
                else
                    label->used |= LABEL_IS_PROCEDURE;
                if (inside_proc)
                    emit_error("starting PROCEDURE without ENDing previous PROCEDURE");
                get_lex();
                inside_proc = label;
                last_is_return = 0;
            } else if (strcmp(name, "END") == 0 && lex_sneak_peek() != 'I' && lex_sneak_peek() != 'S') {  /* END (and not END IF) */
                if (!inside_proc)
                    emit_warning("END without PROCEDURE");
                else if (loops != NULL)
                    emit_error("Ending PROCEDURE with control block still open");
                get_lex();
                if (!last_is_return)
                    generic_return();
                inside_proc = NULL;
                last_is_return = 0;
            } else if (strcmp(name, "INCLUDE") == 0) {
                int quotes;
                FILE *old_input = input;
                int old_line = current_line;
                char old_file[MAX_LINE_SIZE];

                strcpy(old_file, current_file);
                while (line_pos < line_size && isspace(line[line_pos]))
                    line_pos++;
                
                /* Separate filename, admit use of quotes */
                if (line_pos < line_size && line[line_pos] == '"') {
                    quotes = 1;
                    line_pos++;
                } else {
                    quotes = 0;
                }
                p = &path[0];
                while (p < &path[4095] && line_pos < line_size) {
                    if (quotes && line[line_pos] == '"')
                        break;
                    *p++ = line[line_pos++];
                }
                if (quotes) {
                    if (line_pos >= line_size || line[line_pos] != '"')
                        emit_error("missing quotes in INCLUDE");
                    else
                        line_pos++;
                } else {
                    while (p > &path[0] && isspace(*(p - 1)))
                        p--;
                }
                *p = '\0';
                strcpy(current_file, path);
                input = fopen(path, "r");
                if (input == NULL) {
                    emit_error("INCLUDE not successful");
                } else {
                    compile_basic();
                    fclose(input);
                }
                input = old_input;
                current_line = old_line;
                strcpy(current_file, old_file);
                lex = C_END;
            } else {
                compile_statement(FALSE);
            }
        }
        if (lex != C_END)
            emit_error("Extra characters");
    }
    generic_dump();
}

/*
 ** Process variables
 */
int process_variables(void)
{
    struct label *label;
    int c;
    int bytes_used;
    int size;
    int address;
    
    if (machine == CREATIVISION || machine == TI994A)
        address = consoles[machine].base_ram;
    bytes_used = 0;
    for (c = 0; c < HASH_PRIME; c++) {
        label = label_hash[c];
        while (label != NULL) {
            if ((label->used & (LABEL_CALLED_BY_GOTO & LABEL_IS_PROCEDURE)) == (LABEL_CALLED_BY_GOTO | LABEL_IS_PROCEDURE)) {
                fprintf(stderr, "Error: PROCEDURE '%s' jumped in by GOTO\n", label->name);
                err_code = 1;
            }
            if ((label->used & (LABEL_CALLED_BY_GOSUB & LABEL_IS_PROCEDURE)) == LABEL_CALLED_BY_GOSUB) {
                fprintf(stderr, "Error: Common label '%s' jumped in by GOSUB\n", label->name);
                err_code = 1;
            }
            if (label->used & LABEL_IS_VARIABLE) {
                if (target == CPU_6502) {
                    if ((label->used & MAIN_TYPE) == TYPE_8) {
                        if (address < 0x0200 && address + 1 > 0x0140)
                            address = 0x0200;
                        sprintf(temp, "%s%s:\tequ $%04x", LABEL_PREFIX, label->name, address);
                        address++;
                        bytes_used++;
                    } else {
                        if (address < 0x0200 && address + 2 > 0x0140)
                            address = 0x0200;
                        sprintf(temp, "%s%s:\tequ $%04x", LABEL_PREFIX, label->name, address);
                        address += 2;
                        bytes_used += 2;
                    }
                    fprintf(output, "%s\n", temp);
                } else if (target == CPU_9900) {
                    /* using the cpu9900_xxop() functions to get the character remapping */
                    if ((label->used & MAIN_TYPE) == TYPE_16 && (bytes_used & 1) != 0) {
                        cpu9900_noop("even");
                        ++bytes_used;
                    }
                    
                    strcpy(temp, LABEL_PREFIX);
                    strcat(temp, label->name);
                    strcat(temp, ":");
                    cpu9900_label(temp);
                    if ((label->used & MAIN_TYPE) == TYPE_8) {
                        cpu9900_1op("bss", "1");
                        bytes_used++;
                    } else {
                        cpu9900_1op("bss", "2");
                        bytes_used += 2;
                    }
                } else {
                    strcpy(temp, LABEL_PREFIX);
                    strcat(temp, label->name);
                    strcat(temp, ":\t");
                    if ((label->used & MAIN_TYPE) == TYPE_8) {
                        strcat(temp, "rb 1");
                        bytes_used++;
                    } else {
                        strcat(temp, "rb 2");
                        bytes_used += 2;
                    }
                    fprintf(output, "%s\n", temp);
                }
                
                /* Warns of variables only read or only written */
                if ((label->used & LABEL_VAR_ACCESS) == LABEL_VAR_READ) {
                    if (option_warnings)
                        fprintf(stderr, "Warning: variable '%s' read but never assigned\n", label->name);
                }
                if ((label->used & LABEL_VAR_ACCESS) == LABEL_VAR_WRITE) {
                    if (option_warnings)
                        fprintf(stderr, "Warning: variable '%s' assigned but never read\n", label->name);
                }
                
            }
            label = label->next;
        }
    }
    for (c = 0; c < HASH_PRIME; c++) {
        label = array_hash[c];
        while (label != NULL) {
            if (label->name[0] == '#')
                size = 2;
            else
                size = 1;
            size *= label->length;
            if (target == CPU_6502) {
                if (address < 0x0200 && address + size > 0x0140)
                    address = 0x0200;
                sprintf(temp, ARRAY_PREFIX "%s:\tequ $%04x", label->name, address);
                address += size;
                fprintf(output, "%s\n", temp);
            } else if (target == CPU_9900) {
                if ((bytes_used & 1) != 0) {
                    cpu9900_noop("even");
                    ++bytes_used;
                }
                
                strcpy(temp, ARRAY_PREFIX);
                strcat(temp, label->name);
                strcat(temp, ":");
                cpu9900_label(temp);

                sprintf(temp, "%d", size);
                cpu9900_1op("bss", temp);
                address += size;
            } else {
                sprintf(temp, ARRAY_PREFIX "%s:\trb %d", label->name, size);
                fprintf(output, "%s\n", temp);
            }
            bytes_used += size;
            label = label->next;
        }
    }
    fprintf(output, "ram_end:\n");
    return bytes_used;
}

/*
 ** Main program
 */
int main(int argc, char *argv[])
{
    struct label *label;
    FILE *prologue;
    int c;
    int size;
    char *p;
    char *p1;
    int bytes_used;
    int available_bytes;
    time_t actual;
    struct tm *date;
    int extra_ram;
    int small_rom;
    int cpm_option;
    int pencil;
    char hex;
    
    actual = time(0);
    date = localtime(&actual);

    fprintf(stderr, "\nCVBasic compiler " VERSION "\n");
    fprintf(stderr, "(c) 2024 Oscar Toledo G. https://nanochess.org/\n\n");
    
    if (argc < 3) {
        fprintf(stderr, "Usage:\n");
        fprintf(stderr, "\n");
        machine = COLECOVISION;
        while (machine < TOTAL_TARGETS) {
            if (machine == COLECOVISION)
                fprintf(stderr, "    cvbasic input.bas output.asm [library_path]\n");
            else
                fprintf(stderr, "    cvbasic --%s input.bas output.asm [library_path]\n", consoles[machine].name);
            if (consoles[machine].options[0])
                fprintf(stderr, "    cvbasic --%s %s input.bas output.asm [library_path]\n", consoles[machine].name, consoles[machine].options);
            fprintf(stderr, "        %s\n",
                    consoles[machine].description);
            machine++;
        }
        fprintf(stderr, "\n");
        fprintf(stderr, "    By default, it will generate assembler files for Colecovision.\n");
        fprintf(stderr, "    The library_path argument is optional so you can provide a\n");
        fprintf(stderr, "    path where the prologue and epilogue files are available.\n");
#ifdef ASM_LIBRARY_PATH
        fprintf(stderr, "    Default: '" DEFAULT_ASM_LIBRARY_PATH "'\n");
#endif
        fprintf(stderr, "\n");
        fprintf(stderr, "    It will return a zero error code if compilation was\n");
        fprintf(stderr, "    successful, or non-zero otherwise.\n\n");
        fprintf(stderr, "Many thanks to Albert, abeker, aotta, artrag, atari2600land,\n");
        fprintf(stderr, "carlsson, chalkyw64, CrazyBoss, drfloyd, gemintronic, Jess Ragan,\n");
        fprintf(stderr, "Kamshaft, Kiwi, MADrigal, pixelboy, SiRioKD, Tarzilla,\n");
        fprintf(stderr, "Tony Cruise, tursilion, visrealm, wavemotion, and youki.\n");
        fprintf(stderr, "\n");
        exit(1);
    }
    
    /*
     ** Select target machine.
     */
    c = 1;
    if (argv[c][0] == '-' && argv[c][1] == '-') {
        machine = COLECOVISION;
        while (machine < TOTAL_TARGETS) {
            p = &argv[c][2];
            p1 = consoles[machine].name;
            while (*p && tolower(*p) == tolower(*p1)) {
                p++;
                p1++;
            }
            if (*p == '\0' && *p1 == '\0')  /* Exact match */
                break;
            machine++;
        }
        if (machine == TOTAL_TARGETS) {
            fprintf(stderr, "Unknown target: %s\n", argv[c]);
            exit(1);
        }
        target = consoles[machine].target;
        c++;
    } else {
        machine = COLECOVISION;
        target = CPU_Z80;
    }
    if (machine == PENCIL) {
        machine = COLECOVISION;
        target = CPU_Z80;
        pencil = 1;
    } else {
        pencil = 0;
    }
    
    /*
     ** Extra options.
     */
    extra_ram = 0;
    if (argv[c][0] == '-' && tolower(argv[c][1]) == 'r' && tolower(argv[c][2] == 'a') &&
        tolower(argv[c][3] == 'm') && argv[c][4] == '1' && argv[c][5] == '6' &&
        argv[c][6] == '\0') {
        c++;
        if (machine == MSX) {
            extra_ram = 8192;
        } else {
            fprintf(stderr, "-ram16 option only applies to MSX.\n");
            exit(2);
        }
    }
    cpm_option = 0;
    if (machine == EINSTEIN)
        cpm_option = 1;     /* Forced */
    if (argv[c][0] == '-' && tolower(argv[c][1]) == 'c' && tolower(argv[c][2] == 'p') &&
        tolower(argv[c][3] == 'm') && argv[c][4] == '\0') {
        c++;
        if (machine == MEMOTECH || machine == NABU) {
            cpm_option = 1;
        } else {
            fprintf(stderr, "-cpm option only applies to Memotech or NABU.\n");
            exit(2);
        }
    }
    small_rom = 0;
    if (argv[c][0] == '-' && tolower(argv[c][1]) == 'r' && tolower(argv[c][2] == 'o') &&
        tolower(argv[c][3] == 'm') && argv[c][4] == '1' && argv[c][5] == '6' &&
        argv[c][6] == '\0') {
        c++;
        if (machine == CREATIVISION) {
            small_rom = 1;
        } else {
            fprintf(stderr, "-rom16 option only applies to Creativision.\n");
            exit(2);
        }
    }
    strcpy(current_file, argv[c]);
    err_code = 0;
    input = fopen(current_file, "r");
    if (input == NULL) {
        fprintf(stderr, "Couldn't open '%s' source file.\n", current_file);
        exit(2);
    }
    c++;

    output = fopen(TEMPORARY_ASSEMBLER, "w");
    if (output == NULL) {
        fprintf(stderr, "Couldn't open '%s' temporary file.\n", TEMPORARY_ASSEMBLER);
        exit(2);
    }
    bank_switching = 0;
    option_explicit = 0;
    option_warnings = 1;
    inside_proc = NULL;
    frame_drive = NULL;
    compile_basic();
    if (loops != NULL)
        emit_error("End of source with control block still open");
    else if (inside_proc) {
        emit_warning("End of source without ending PROCEDURE");
        if (!last_is_return)
            generic_return();
        inside_proc = 0;
        last_is_return = 0;
    }
    if (bank_switching)
        bank_finish();
    fclose(input);
    fclose(output);
    
    output = fopen(argv[c], "w");
    if (output == NULL) {
        fprintf(stderr, "Couldn't open '%s' output file.\n", argv[2]);
        exit(2);
    }
    c++;
    
    if (c < argc) {
        strcpy(library_path, argv[c]);
        c++;
	}
#ifdef _WIN32
	if (strlen(library_path) > 0 && library_path[strlen(library_path) - 1] != '\\')
		strcat(library_path, "\\");
#else
	if (strlen(library_path) > 0 && library_path[strlen(library_path) - 1] != '/')
		strcat(library_path, "/");
#endif
    
    hex = '$';
    if (target == CPU_9900) {
        /* Texas Instruments is a free spirit... */
        hex = '>';
    }
    
    fprintf(output, "\t; CVBasic compiler " VERSION "\n");
    fprintf(output, "\t; Command: ");
    for (c = 0; c < argc; c++) {
        char *b;
        
        b = strchr(argv[c], ' ');
        if (b != NULL)
            fprintf(output, "\"%s\" ", argv[c]);
        else
            fprintf(output, "%s ", argv[c]);
    }
    fprintf(output, "\n");
    
    fprintf(output, "\t; Created: %s\n", asctime(date));
    fprintf(output, "COLECO:\tequ %d\n",
            (machine == COLECOVISION || machine == COLECOVISION_SGM) ? 1 : 0);
    fprintf(output, "SG1000:\tequ %d\n", (machine == SG1000) ? 1 : 0);
    fprintf(output, "MSX:\tequ %d\n", (machine == MSX) ? 1 : 0);
    fprintf(output, "SGM:\tequ %d\n", (machine == COLECOVISION_SGM) ? 1 : 0);
    fprintf(output, "SVI:\tequ %d\n", (machine == SVI) ? 1 : 0);
    fprintf(output, "SORD:\tequ %d\n", (machine == SORD) ? 1 : 0);
    fprintf(output, "MEMOTECH:\tequ %d\n", (machine == MEMOTECH) ? 1 : 0);
    fprintf(output, "EINSTEIN:\tequ %d\n", (machine == EINSTEIN) ? 1 : 0);
    fprintf(output, "CPM:\tequ %d\n", cpm_option);
    fprintf(output, "PENCIL:\tequ %d\n", pencil);
    fprintf(output, "PV2000:\tequ %d\n", (machine == PV2000) ? 1 : 0);
    fprintf(output, "TI99:\tequ %d\n", (machine == TI994A) ? 1 : 0);
    fprintf(output, "NABU:\tequ %d\n", (machine == NABU) ? 1 : 0);
    fprintf(output, "\n");
    fprintf(output, "CVBASIC_MUSIC_PLAYER:\tequ %d\n", music_used);
    fprintf(output, "CVBASIC_COMPRESSION:\tequ %d\n", compression_used);
    fprintf(output, "CVBASIC_BANK_SWITCHING:\tequ %d\n", bank_switching);
    fprintf(output, "\n");
    fprintf(output, "BASE_RAM:\tequ %c%04x\t; Base of RAM\n", hex, consoles[machine].base_ram - extra_ram);
    if ((machine == MEMOTECH || machine == EINSTEIN) && cpm_option != 0)
        fprintf(output, "STACK:\tequ %c%04x\t; Base stack pointer\n", hex, 0xe000);
    else
        fprintf(output, "STACK:\tequ %C%04x\t; Base stack pointer\n", hex, consoles[machine].stack);
    fprintf(output, "VDP:\tequ %c%02x\t; VDP port (write)\n", hex, consoles[machine].vdp_port_write);
    fprintf(output, "VDPR:\tequ %c%02x\t; VDP port (read)\n", hex, consoles[machine].vdp_port_read);
    if (machine != TI994A) {
        fprintf(output, "PSG:\tequ %c%02x\t; PSG port (write)\n", hex, consoles[machine].psg_port);
    }
    if (machine == CREATIVISION) {
        fprintf(output, "SMALL_ROM:\tequ %d\n", small_rom);
    }

    fprintf(output, "\n");
    if (bank_switching) {
        if (machine == COLECOVISION || machine == COLECOVISION_SGM) {
            fprintf(output, "\tforg $%05x\n", bank_rom_size * 0x0400 - 0x4000);
        } else if (machine == TI994A) {
            /* nothing to output here - it's all in the prologue */
        } else {
            fprintf(output, "\tforg $00000\n");
        }
    }
    strcpy(path, library_path);
    if (target == CPU_6502)
        strcat(path, "cvbasic_6502_prologue.asm");
    else if (target == CPU_9900)
        strcat(path, "cvbasic_9900_prologue.asm");
    else
        strcat(path, "cvbasic_prologue.asm");
    prologue = fopen(path, "r");
    if (prologue == NULL) {
        fprintf(stderr, "Unable to open '%s'.\n", path);
        exit(2);
    }
    while (fgets(line, sizeof(line) - 1, prologue)) {
        p = line;
        while (*p && isspace(*p))
            p++;
        if (memcmp(p, ";CVBASIC MARK DON'T CHANGE", 26) == 0) {  /* Location to replace */
            if (frame_drive != NULL) {
                if (target == CPU_6502)
                    fprintf(output, "\tJSR " LABEL_PREFIX "%s\n", frame_drive->name);
                else if (target == CPU_9900) {
                    /* To call compiled code, we need the stack pointer and we need to jsr it */
                    fprintf(output, "\tmov @>8314,r10\n");
                    fprintf(output, "\tbl @jsr\n");
                    strcpy(assigned, frame_drive->name);
                    if (target == CPU_9900) {
                        char *p = assigned;
                        
                        while (*p) {
                            if (*p == '#')
                                *p = '_';
                            p++;
                        }
                    }
                    fprintf(output, "\tdata " LABEL_PREFIX "%s\n", assigned);
                }
                else
                    fprintf(output, "\tCALL " LABEL_PREFIX "%s\n", frame_drive->name);
            }
        } else {
            fputs(line, output);
        }
    }
    fclose(prologue);
    
    if (target == CPU_6502) {
        bytes_used = process_variables();
    }
    
    input = fopen(TEMPORARY_ASSEMBLER, "r");
    if (input == NULL) {
        fprintf(stderr, "Unable to reopen '%s'.\n", TEMPORARY_ASSEMBLER);
        exit(2);
    }
    while (fgets(line, sizeof(line) - 1, input)) {
        fputs(line, output);
    }
    fclose(input);
    remove(TEMPORARY_ASSEMBLER);
    
    strcpy(path, library_path);
    if (target == CPU_6502)
        strcat(path, "cvbasic_6502_epilogue.asm");
    else if (target == CPU_9900)
        strcat(path, "cvbasic_9900_epilogue.asm");
    else
        strcat(path, "cvbasic_epilogue.asm");
    prologue = fopen(path, "r");
    if (prologue == NULL) {
        fprintf(stderr, "Unable to open '%s'.\n", path);
        exit(2);
    }
    while (fgets(line, sizeof(line) - 1, prologue)) {
        fputs(line, output);
    }
    fclose(prologue);
    
    if (target == CPU_Z80 || target == CPU_9900) {
        bytes_used = process_variables();
    }
    fclose(output);
    if (machine == MEMOTECH || machine == EINSTEIN || machine == NABU) {
        fprintf(stderr, "%d RAM bytes used for variables.\n", bytes_used);
    } else {
        available_bytes = consoles[machine].memory_size + extra_ram;
        if (machine == SORD)    /* Because stack is set apart */
            available_bytes -= (music_used ? 33 : 0) + 146;
        else if (machine != COLECOVISION_SGM)
            available_bytes -= 64 +                    /* Stack requirements */
            (music_used ? 33 : 0) +     /* Music player requirements */
            146;                    /* Support variables */
        if (bytes_used > available_bytes) {
            fprintf(stderr, "ERROR: ");
            err_code = 1;
        }
        fprintf(stderr, "%d RAM bytes used of %d bytes available.\n", bytes_used, available_bytes);
    }
    fprintf(stderr, "Compilation finished for %s.\n\n", consoles[machine].canonical);
    exit(err_code);
}

