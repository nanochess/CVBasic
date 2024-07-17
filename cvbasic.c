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
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#include "cvbasic.h"
#include "node.h"

#define VERSION "v0.5.1 Jun/23/2024"

#define TEMPORARY_ASSEMBLER "cvbasic_temporary.asm"

#define FALSE           0
#define TRUE            1

/*
 ** Supported platforms.
 */
static enum {
    COLECOVISION, SG1000, MSX, COLECOVISION_SGM, SVI,
} machine;

/*
 ** Base information about each platform.
 */
static struct console {
    int base_ram;       /* Where the RAM starts */
    int stack;          /* Where the stack will start */
    int memory_size;    /* Memory available */
    int vdp_port_write; /* VDP port for writing */
    int vdp_port_read;  /* VDP port for reading (needed for SVI-318/328, sigh) */
} consoles[5] = {
    /*  RAM     STACK    Size  VDP R   VDP W */
    {0x7000, 0x7400,  1024,  0xbe,   0xbe},
    {0xc000, 0xc400,  1024,  0xbe,   0xbe},
    {0xe000, 0xf000,  4096,  0x98,   0x98},
    {0x7c00, 0x8000, 23552,  0xbe,   0xbe},
    {0xc000, 0xf000, 12288,  0x80,   0x84},
};

static int err_code;

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
static FILE *output;

static int line_pos;
static int line_size;
static int line_start;
static char line[MAX_LINE_SIZE];

static int next_local = 1;

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
    int type;           /* 0=FOR, 1=WHILE, 2=IF, 3=DO WHILE/UNTIL LOOP, 4=DO LOOP WHILE/UNTIL */
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

void z80_label(char *);
void z80_empty(void);
void z80_noop(char *);
void z80_1op(char *, char *);
void z80_2op(char *, char *, char *);

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

static char z80_a_content[MAX_LINE_SIZE];
static char z80_hl_content[MAX_LINE_SIZE];
static int z80_flag_z_valid;

/*
 ** Emit a Z80 label
 */
void z80_label(char *label)
{
    fprintf(output, "%s:\n", label);
    z80_a_content[0] = '\0';
    z80_hl_content[0] = '\0';
    z80_flag_z_valid = 0;
}

/*
 ** Reset A register (technically a null label)
 */
void z80_empty(void)
{
    z80_a_content[0] = '\0';
    z80_flag_z_valid = 0;
}

/*
 ** Emit a Z80 instruction with no operand
 */
void z80_noop(char *mnemonic)
{
    fprintf(output, "\t%s\n", mnemonic);
    z80_a_content[0] = '\0';
    z80_hl_content[0] = '\0';
    z80_flag_z_valid = 0;
}

/*
 ** Emit a Z80 instruction with a single operand
 */
void z80_1op(char *mnemonic, char *operand)
{
    /*
     ** Optimize zero in register A
     */
    if (strcmp(mnemonic, "SUB") == 0) {
        if (strcmp(operand, "A") == 0) {
            if (strcmp(z80_a_content, "0") == 0)
                return;
        }
    }
    
    /*
     ** Important note: AND A is used for the sole purpose of
     ** make sure A is zero.
     **
     ** It is used OR A for clearing the carry flag for SBC HL,DE
     */
    if (strcmp(mnemonic, "AND") == 0) {
        if (strcmp(operand, "A") == 0) {
            if (z80_flag_z_valid)
                return;
        }
    }

    fprintf(output, "\t%s %s\n", mnemonic, operand);
    
    if (strcmp(mnemonic, "PUSH") == 0) {
        /* No affected registers */
    } else if (strcmp(mnemonic, "CP") == 0) {
        /* No affected registers */
        z80_flag_z_valid = 0;
    } else if (strcmp(mnemonic, "POP") == 0) {
        if (strcmp(operand, "AF") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 0;
        } else if (strcmp(operand, "HL") == 0) {
            z80_hl_content[0] = '\0';
        }
    } else if (strcmp(mnemonic, "CALL") == 0 ||
               strcmp(mnemonic, "JP") == 0) {
        z80_a_content[0] = '\0';
        z80_hl_content[0] = '\0';
        z80_flag_z_valid = 0;
    } else if (strcmp(mnemonic, "SUB") == 0) {
        if (strcmp(operand, "A") == 0)
            strcpy(z80_a_content, "0");
        else
            z80_a_content[0] = '\0';
        z80_flag_z_valid = 1;
    } else if (strcmp(mnemonic, "OR") == 0 ||
               strcmp(mnemonic, "XOR") == 0 ||
               strcmp(mnemonic, "AND") == 0) {
        z80_a_content[0] = '\0';
        z80_flag_z_valid = 1;
    } else if (strcmp(mnemonic, "SRL") == 0) {
        if (strcmp(operand, "H") == 0)
            z80_hl_content[0] = '\0';
        else if (strcmp(operand, "A") == 0)
            z80_flag_z_valid = 1;
    } else if (strcmp(mnemonic, "RR") == 0) {
        if (strcmp(operand, "L") == 0)
            z80_hl_content[0] = '\0';
        z80_flag_z_valid = 0;
    } else if (strcmp(mnemonic, "INC") == 0) {
        if (strcmp(operand, "H") == 0 ||
            strcmp(operand, "L") == 0 ||
            strcmp(operand, "HL") == 0) {
            z80_hl_content[0] = '\0';
            z80_flag_z_valid = 0;
        } else if (strcmp(operand, "A") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 1;
        } else if (strcmp(operand, "(HL)") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 0;
        }
    } else if (strcmp(mnemonic, "DEC") == 0) {
        if (strcmp(operand, "H") == 0 ||
            strcmp(operand, "L") == 0 ||
            strcmp(operand, "HL") == 0) {
            z80_hl_content[0] = '\0';
            z80_flag_z_valid = 0;
        } else if (strcmp(operand, "A") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 1;
        } else if (strcmp(operand, "(HL)") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 0;
        }
    } else if (strcmp(mnemonic, "DW") == 0 || strcmp(mnemonic, "ORG") == 0 || strcmp(mnemonic, "FORG") == 0) {
        /* Nothing to do */
    } else {
        fprintf(stderr, "z80_1op: not found mnemonic %s\n", mnemonic);
    }
}

/*
 ** Emit a Z80 instruction with two operands
 */
void z80_2op(char *mnemonic, char *operand1, char *operand2)
{
    
    /*
     ** Optimize constant expressions (both constants and access to memory variables)
     */
    if (strcmp(mnemonic, "LD") == 0) {
        if (strcmp(operand1, "A") == 0) {
            if (strcmp(operand2, z80_a_content) == 0)
                return;
            if (strcmp(operand2, z80_hl_content) == 0)
                operand2 = "L";
        } else if (strcmp(operand1, "HL") == 0) {
            if (strcmp(operand2, z80_hl_content) == 0)
                return;
        }
    }
    
    fprintf(output, "\t%s %s,%s\n", mnemonic, operand1, operand2);
    
    if (strcmp(mnemonic, "JP") == 0 ||
        strcmp(mnemonic, "JR") == 0 ||
        strcmp(mnemonic, "OUT") == 0 ||
        strcmp(mnemonic, "RES") == 0 ||
        strcmp(mnemonic, "SET") == 0) {
        /* No affected registers or flags */
    } else if (strcmp(mnemonic, "EX") == 0) {
        z80_hl_content[0] = '\0';
    } else if (strcmp(mnemonic, "IN") == 0) {
        z80_a_content[0] = '\0';
        z80_flag_z_valid = 0;
    } else if (strcmp(mnemonic, "ADD") == 0 || strcmp(mnemonic, "SBC") == 0) {
        if (strcmp(operand1, "A") == 0) {
            z80_a_content[0] = '\0';
            z80_flag_z_valid = 1;
        } else {
            z80_hl_content[0] = '\0';
            z80_flag_z_valid = 0;
        }
    } else if (strcmp(mnemonic, "LD") == 0) {
        if (strcmp(operand1, "A") == 0)  /* Read value into accumulator */
            z80_flag_z_valid = 0;       /* Z status isn't valid */
        if (strcmp(operand1, "L") == 0 || strcmp(operand1, "H") == 0)
            z80_hl_content[0] = '\0';
        if (strcmp(operand1, "HL") == 0)
            strcpy(z80_hl_content, operand2);
        else if (strcmp(operand2, "HL") == 0)
            strcpy(z80_hl_content, operand1);
        if (strcmp(operand1, "A") == 0 && strcmp(operand2, "(HL)") == 0) {
            z80_a_content[0] = '\0';
        } else if (strcmp(operand1, "(HL)") == 0 && strcmp(operand2, "A") == 0) {
            /* A keeps its value */
        } else if (strcmp(operand1, "A") == 0) {
            if (isdigit(operand2[0]) || operand2[0] == '(')
                strcpy(z80_a_content, operand2);
            else
                z80_a_content[0] = '\0';
        } else if (strcmp(operand2, "A") == 0 && operand1[0] == '(') {
            strcpy(z80_a_content, operand1);
        }
    } else {
        fprintf(stderr, "z80_2op: not found mnemonic %s\n", mnemonic);
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
            z80_1op("JP", temp);    /* Jump over */
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
            z80_1op("OR", "A");
        } else {
            z80_2op("LD", "A", "H");
            z80_1op("OR", "L");
        }
        sprintf(temp, INTERNAL_PREFIX "%d", label);
        z80_2op("JP", "Z", temp);
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
            if (lex_sneak_peek() == '(') {  // Indexed access
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
        if (strcmp(name, "POS") == 0) { // Access to current screen position
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
        if (macro_search(name) != NULL) {  // Function (macro)
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
    if (lex == C_LPAREN) {
        get_lex();
        tree = evaluate_level_0(&type2);
        if ((type2 & MAIN_TYPE) == TYPE_8)
            tree = node_create((type2 & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, tree, NULL);
        if (lex == C_RPAREN)
            get_lex();
        else
            emit_error("missing right parenthesis");
    }
    tree = node_create(N_USR, 0, tree, NULL);
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
                if (lex == C_END)   // Avoid possibility of being stuck
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
    node_label(tree);
    node_generate(tree, 0);
    node_delete(tree);
    strcpy(temp, "(" LABEL_PREFIX);
    strcat(temp, label->name);
    strcat(temp, ")");
    if ((type2 & MAIN_TYPE) == TYPE_8) {
        z80_2op("LD", temp, "A");
    } else {
        z80_2op("LD", temp, "HL");
    }
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
                    z80_1op("JP", temp);
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
                    z80_1op("CALL", temp);
                    get_lex();
                }
            } else if (strcmp(name, "RETURN") == 0) {
                get_lex();
                z80_noop("RET");
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
                        new_loop->type = 2;
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
                    z80_1op("JP", temp);
                } else {
                    there_is_else = 0;
                    label2 = 0;
                }
                sprintf(temp, INTERNAL_PREFIX "%d", label);
                z80_label(temp);
                if (there_is_else) {
                    compile_statement(TRUE);
                    sprintf(temp, INTERNAL_PREFIX "%d", label2);
                    z80_label(temp);
                }
                last_is_return = 0;
            } else if (strcmp(name, "ELSEIF") == 0) {
                int type;
                
                get_lex();
                if (loops == NULL) {
                    emit_error("ELSEIF without IF");
                } else if (loops->type != 2 || loops->label_loop == 0) {
                    emit_error("bad nested ELSEIF");
                } else {
                    if (loops->var[0] != 1) {
                        loops->label_exit = next_local++;
                        loops->var[0] = 1;
                    }
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                    z80_1op("JP", temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                    z80_label(temp);
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
                } else if (loops->type != 2) {
                    emit_error("bad nested ELSE");
                } else if (loops->label_loop == 0) {
                    emit_error("more than one ELSE");
                } else {
                    if (loops->var[0] != 1) {
                        loops->label_exit = next_local++;
                        loops->var[0] = 1;
                    }
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                    z80_1op("JP", temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                    z80_label(temp);
                    loops->label_loop = 0;
                }
                if (lex == C_END)
                    break;
                continue;
            } else if (strcmp(name, "END") == 0) {
                struct loop *popping;
                
                get_lex();
                if (lex != C_NAME || strcmp(name, "IF") != 0) {
                    emit_error("wrong END");
                } else {
                    get_lex();
                    if (loops == NULL || loops->type != 2) {
                        emit_error("Bad nested END IF");
                    } else {
                        if (loops->var[0] == 1) {
                            sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                            z80_label(temp);
                        }
                        if (loops->label_loop != 0) {
                            sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                            z80_label(temp);
                        }
                        popping = loops;
                        loops = loops->next;
                        free(popping);
                    }
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
                sign = signed_search(name);
                if (sign != NULL && sign->sign == 1)
                    type_var |= TYPE_SIGNED;
                label_loop = next_local++;
                sprintf(temp, INTERNAL_PREFIX "%d", label_loop);
                z80_label(temp);
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
                            step = node_create(type_var == TYPE_16 ? N_MINUS16 : N_MINUS8, 0,
                                            var, step);
                            positive = 0;
                        } else {
                            step = evaluate_level_0(&type);
                            if ((type_var & MAIN_TYPE) == TYPE_16 && (type & MAIN_TYPE) == TYPE_8)
                                step = node_create((type & TYPE_SIGNED) ? N_EXTEND8S : N_EXTEND8, 0, step, NULL);
                            else if ((type_var & MAIN_TYPE) == TYPE_8 && (type & MAIN_TYPE) == TYPE_16)
                                step = node_create(N_REDUCE16, 0, step, NULL);
                            step = node_create(type_var == TYPE_16 ? N_PLUS16 : N_PLUS8, 0, var, step);
                        }
                    } else {
                        step_value = 1;
                        step = node_create((type_var & MAIN_TYPE) == TYPE_16 ? N_NUM16 : N_NUM8, 1, NULL, NULL);
                        step = node_create((type_var & MAIN_TYPE) == TYPE_16 ? N_PLUS16 : N_PLUS8, 0, var, step);
                    }
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
                new_loop->type = 0;
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
                    
                    if (loops->type != 0) {
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
                        sprintf(temp, "(" LABEL_PREFIX "%s" ")", loops->var);
                        if (loops->var[0] == '#') {
                            z80_2op("LD", temp, "HL");
                        } else {
                            z80_2op("LD", temp, "A");
                        }
                        if (final != NULL) {
                            optimized = 0;
                            node_label(final);
                            node_generate(final, label_loop);
                            if (!optimized) {
                                z80_1op("OR", "A");
                                sprintf(temp, INTERNAL_PREFIX "%d", label_loop);
                                z80_2op("JP", "Z", temp);
                            }
                            node_delete(final);
                        }
                        node_delete(step);
                        if (label_exit != 0) {
                            sprintf(temp, INTERNAL_PREFIX "%d", label_exit);
                            z80_label(temp);
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
                z80_label(temp);
                type = evaluate_expression(0, 0, label_exit);
                new_loop = malloc(sizeof(struct loop));
                if (new_loop == NULL) {
                    fprintf(stderr, "Out of memory\n");
                    exit(1);
                }
                new_loop->type = 1;
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
                } else if (loops->type != 1) {
                    emit_error("bad nested WEND");
                } else {
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                    z80_1op("JP", temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                    z80_label(temp);
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
                z80_label(temp);
                new_loop = malloc(sizeof(struct loop));
                if (new_loop == NULL) {
                    fprintf(stderr, "Out of memory\n");
                    exit(1);
                }
                if (lex == C_NAME && strcmp(name, "WHILE") == 0) {
                    get_lex();
                    type = evaluate_expression(0, 0, label_exit);
                    new_loop->var[0] = '1'; /* Uses exit label */
                    new_loop->type = 3;     /* Condition at top */
                } else if (lex == C_NAME && strcmp(name, "UNTIL") == 0) {
                    int label_temp = next_local++;
                    
                    get_lex();
                    type = evaluate_expression(0, 0, label_temp);
                    /* Let optimizer to solve this =P */
                    sprintf(temp, INTERNAL_PREFIX "%d", label_exit);
                    z80_1op("JP", temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", label_temp);
                    z80_label(temp);
                    new_loop->var[0] = '1'; /* Uses exit label */
                    new_loop->type = 3;  /* Condition at top */
                } else {
                    new_loop->var[0] = '\0'; /* Doesn't use exit label (yet) */
                    new_loop->type = 4;  /* Condition at bottom */
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
                } else if (loops->type == 3) {
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                    z80_1op("JP", temp);
                    sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                    z80_label(temp);
                    popping = loops;
                    loops = loops->next;
                    free(popping);
                } else if (loops->type == 4) {
                    int type;
                    
                    if (lex == C_NAME && strcmp(name, "WHILE") == 0) {
                        int label_temp = next_local++;
                        
                        get_lex();
                        type = evaluate_expression(0, 0, label_temp);
                        /* Let optimizer to solve this =P */
                        sprintf(temp, INTERNAL_PREFIX "%d", loops->label_loop);
                        z80_1op("JP", temp);
                        sprintf(temp, INTERNAL_PREFIX "%d", label_temp);
                        z80_label(temp);
                    } else if (lex == C_NAME && strcmp(name, "UNTIL") == 0) {
                        get_lex();
                        type = evaluate_expression(0, 0, loops->label_loop);
                    } else {
                        emit_error("LOOP without condition");
                    }
                    if (loops->var[0] == '1') {  /* Uses exit label? */
                        sprintf(temp, INTERNAL_PREFIX "%d", loops->label_exit);
                        z80_label(temp);
                    }
                    popping = loops;
                    loops = loops->next;
                    free(popping);
                } else {
                    emit_error("bad nested LOOP");
                }
            } else if (strcmp(name, "EXIT") == 0) {
                struct loop *loop_explorer;
                
                get_lex();
                
                /* Avoid IF blocks */
                loop_explorer = loops;
                while (loop_explorer != NULL) {
                    if (loop_explorer->type != 2)
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
                        if (loop_explorer->type != 0) {
                            emit_error("EXIT FOR without FOR");
                        } else {
                            if (loop_explorer->label_exit == 0)
                                loop_explorer->label_exit = next_local++;
                            sprintf(temp, INTERNAL_PREFIX "%d", loop_explorer->label_exit);
                            z80_1op("JP", temp);
                        }
                    } else if (strcmp(name, "WHILE") == 0) {
                        get_lex();
                        if (loop_explorer->type != 1) {
                            emit_error("EXIT WHILE without WHILE");
                        } else {
                            sprintf(temp, INTERNAL_PREFIX "%d", loop_explorer->label_exit);
                            z80_1op("JP", temp);
                        }
                    } else if (strcmp(name, "DO") == 0) {
                        get_lex();
                        if (loop_explorer->type != 3 && loop_explorer->type != 4) {
                            emit_error("EXIT DO without DO");
                        } else {
                            loop_explorer->var[0] = '1';
                            sprintf(temp, INTERNAL_PREFIX "%d", loop_explorer->label_exit);
                            z80_1op("JP", temp);
                        }
                    } else {
                        emit_error("only supported EXIT WHILE/FOR/DO");
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
                if ((value->regs & REG_HL) == 0) {
                    node_generate(address, 0);
                    node_generate(value, 0);
                } else if ((address->regs & REG_A) == 0) {
                    node_generate(value, 0);
                    node_generate(address, 0);
                } else {
                    node_generate(address, 0);
                    z80_1op("PUSH", "HL");
                    node_generate(value, 0);
                    z80_1op("POP", "HL");
                }
                z80_2op("LD", "(HL)", "A");
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
                if ((value->regs & REG_HL) == 0) {
                    node_generate(address, 0);
                    node_generate(value, 0);
                } else if ((address->regs & REG_A) == 0) {
                    node_generate(value, 0);
                    node_generate(address, 0);
                } else {
                    node_generate(address, 0);
                    z80_1op("PUSH", "HL");
                    node_generate(value, 0);
                    z80_1op("POP", "HL");
                }
                z80_1op("CALL", "NMI_OFF");
                z80_1op("CALL", "WRTVRM");
                z80_1op("CALL", "NMI_ON");
                node_delete(address);
                node_delete(value);
            } else if (strcmp(name, "REM") == 0) {
                line_pos = line_size;
                get_lex();
            } else if (strcmp(name, "CLS") == 0) {
                get_lex();
                z80_1op("CALL", "cls");
            } else if (strcmp(name, "WAIT") == 0) {
                get_lex();
                z80_noop("HALT");
            } else if (strcmp(name, "RESTORE") == 0) {
                get_lex();
                if (lex != C_NAME) {
                    emit_error("bad syntax for RESTORE");
                } else {
                    label = label_search(name);
                    if (label == NULL) {
                        label = label_add(name);
                    }
                    sprintf(temp, LABEL_PREFIX "%s", name);
                    z80_2op("LD", "HL", temp);
                    z80_2op("LD", "(read_pointer)", "HL");
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

                get_lex();
                if (lex == C_NAME && strcmp(name, "BYTE") == 0) {
                    int d;
                    
                    get_lex();
                    while (1) {
                        if (lex == C_STRING) {
                            for (d = 0; d < name_size; d++) {
                                if (c == 0) {
                                    fprintf(output, "\tDB ");
                                } else {
                                    fprintf(output, ",");
                                }
                                fprintf(output, "$%02x", name[d] & 0xff);
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
                                fprintf(output, "\tDB ");
                            } else {
                                fprintf(output, ",");
                            }
                            fprintf(output, "$%02x", value & 0xff);
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
                                if (lex_sneak_peek() == '(') {  // Indexed access
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
                                        fprintf(output, "\tDW ");
                                    } else {
                                        fprintf(output, ",");
                                    }
                                    fprintf(output, "%s%s+%d", label->length ? ARRAY_PREFIX : LABEL_PREFIX, label->name, label->name[0] == '#' ? index * 2 : index);
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
                                            fprintf(output, "\tDW ");
                                        } else {
                                            fprintf(output, ",");
                                        }
                                        fprintf(output, "%s%s", LABEL_PREFIX, label->name);
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
                                fprintf(output, "\tDW ");
                            } else {
                                fprintf(output, ",");
                            }
                            fprintf(output, "$%04x", value & 0xffff);
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
                node_generate(port, 0);
                z80_2op("LD", "C", "A");
                if ((value->regs & REG_C) == 0) {
                    node_generate(value, 0);
                } else {
                    z80_1op("PUSH", "BC");
                    node_generate(value, 0);
                    z80_1op("POP", "BC");
                }
                z80_2op("OUT", "(C)", "A");
                node_delete(port);
                node_delete(value);
            } else if (strcmp(name, "PRINT") == 0) {
                int label;
                int label2;
                int c;
                int start;
                
                get_lex();
                start = 1;
                if (lex == C_NAME && strcmp(name, "AT") == 0) {
                    get_lex();
                    type = evaluate_expression(1, TYPE_16, 0);
                    z80_2op("LD", "(cursor)", "HL");
                    start = 0;
                }
                while (1) {
                    if (!start) {
                        if (lex != C_COMMA)
                            break;
                        get_lex();
                    }
                    start = 0;
                    if (lex == C_STRING) {
                        if (name_size) {
                            label = next_local++;
                            label2 = next_local++;
                            sprintf(temp, INTERNAL_PREFIX "%d", label);
                            z80_2op("LD", "HL", temp);
                            sprintf(temp, "%d", name_size);
                            z80_2op("LD", "A", temp);
                            z80_1op("CALL", "print_string");
                            sprintf(temp, INTERNAL_PREFIX "%d", label2);
                            z80_1op("JP", temp);
                            sprintf(temp, INTERNAL_PREFIX "%d", label);
                            z80_label(temp);
                            for (c = 0; c < name_size; c++) {
                                if ((c & 7) == 0) {
                                    fprintf(output, "\tDB ");
                                }
                                fprintf(output, "$%02x", name[c] & 0xff);
                                if ((c & 7) == 7 || c + 1 == name_size) {
                                    fprintf(output, "\n");
                                } else {
                                    fprintf(output, ",");
                                }
                            }
                            sprintf(temp, INTERNAL_PREFIX "%d", label2);
                            z80_label(temp);
                        }
                        get_lex();
                    } else if (lex == C_LESS || lex == C_NOTEQUAL) {
                        int format = 0;
                        int size = 1;
                        
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
                        if (format == 0) {
                            z80_1op("CALL", "print_number");
                        } else if (format == 1) {
                            z80_1op("CALL", "nmi_off");
                            z80_2op("LD", "BC", "$0220");
                            sprintf(temp, "print_number%d", size);
                            z80_1op("CALL", temp);
                        } else if (format == 2) {
                            z80_1op("CALL", "nmi_off");
                            z80_2op("LD", "BC", "$0230");
                            sprintf(temp, "print_number%d", size);
                            z80_1op("CALL", temp);
                        }
                    } else {
                        type = evaluate_expression(1, TYPE_16, 0);
                        z80_1op("CALL", "print_number");
                    }
                }
            } else if (strcmp(name, "DEFINE") == 0) {
                int pletter = 0;
                
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
                        z80_2op("ADD", "HL", "HL");
                        z80_2op("ADD", "HL", "HL");
                        z80_2op("LD", "H", "$07");
                        z80_2op("ADD", "HL", "HL");
                        z80_2op("ADD", "HL", "HL");
                        z80_2op("ADD", "HL", "HL");
                        z80_2op("EX", "DE", "HL");
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
                            strcpy(temp, LABEL_PREFIX);
                            strcat(temp, name);
                            z80_2op("LD", "HL", temp);
                            get_lex();
                        }
                        z80_1op("CALL", "unpack");
                        compression_used = 1;
                    } else {
                        struct node *length;
                        struct node *source = NULL;
                        
                        type = evaluate_expression(1, TYPE_16, 0);
                        z80_1op("PUSH", "HL");
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
                        } else if (strcmp(name, "VARPTR") == 0) {
                            source = evaluate_save_expression(1, TYPE_16);
                            node_generate(length, 0);
                            if ((source->regs & REG_A) != 0)
                                z80_1op("PUSH", "AF");
                            node_generate(source, 0);
                            if ((source->regs & REG_A) != 0)
                                z80_1op("POP", "AF");
                        } else {
                            node_generate(length, 0);
                            strcpy(temp, LABEL_PREFIX);
                            strcat(temp, name);
                            z80_2op("LD", "HL", temp);
                            get_lex();
                        }
                        z80_1op("CALL", "define_sprite");
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
                    z80_1op("PUSH", "HL");
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
                        if ((source->regs & REG_A) != 0)
                            z80_1op("PUSH", "AF");
                        node_generate(source, 0);
                        if ((source->regs & REG_A) != 0)
                            z80_1op("POP", "AF");
                    } else {
                        node_generate(length, 0);
                        strcpy(temp, LABEL_PREFIX);
                        strcat(temp, name);
                        z80_2op("LD", "HL", temp);
                        get_lex();
                    }
                    if (pletter) {
                        z80_1op("CALL", color ? "define_color_unpack" : "define_char_unpack");
                        compression_used = 1;
                    } else {
                        z80_1op("CALL", color ? "define_color" : "define_char");
                    }
                    node_delete(length);
                    node_delete(source);
                } else if (strcmp(name, "VRAM") == 0) {
                    struct node *source;
                    struct node *target;
                    struct node *length;
                    
                    get_lex();
                    if (lex == C_NAME && strcmp(name, "PLETTER") == 0) {
                        pletter = 1;
                        get_lex();
                    }
                    target = evaluate_save_expression(1, TYPE_16);
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
                        node_generate(length, 0);
                        if (((target->regs | source->regs) & REG_BC) == 0) {
                            z80_2op("LD", "B", "H");
                            z80_2op("LD", "C", "L");
                        } else {
                            z80_1op("PUSH", "HL");
                        }
                        node_generate(target, 0);
                        if ((source->regs & REG_DE) == 0) {
                            z80_2op("EX", "DE", "HL");
                            node_generate(source, 0);
                        } else {
                            z80_1op("PUSH", "HL");
                            node_generate(source, 0);
                            z80_1op("POP", "DE");
                        }
                        if (((target->regs | source->regs) & REG_BC) != 0)
                            z80_1op("POP", "BC");
                    } else {
                        source = NULL;
                        if (!pletter) {
                            node_generate(length, 0);
                            if ((target->regs & REG_BC) == 0) {
                                z80_2op("LD", "B", "H");
                                z80_2op("LD", "C", "L");
                            } else {
                                z80_1op("PUSH", "HL");
                            }
                        }
                        node_generate(target, 0);
                        z80_2op("EX", "DE", "HL");
                        strcpy(temp, LABEL_PREFIX);
                        strcat(temp, name);
                        z80_2op("LD", "HL", temp);
                        if (!pletter) {
                            if ((target->regs & REG_BC) != 0)
                                z80_1op("POP", "BC");
                        }
                        get_lex();
                    }
                    if (pletter) {
                        z80_1op("CALL", "unpack");
                        compression_used = 1;
                    } else {
                        z80_1op("CALL", "nmi_off");
                        z80_1op("CALL", "LDIRVM");
                        z80_1op("CALL", "nmi_on");
                    }
                    node_delete(length);
                    node_delete(target);
                    node_delete(source);
                } else {
                    emit_error("syntax error in DEFINE");
                }
            } else if (strcmp(name, "SPRITE") == 0) {
                get_lex();
                if (lex == C_NAME && strcmp(name, "FLICKER") == 0) {
                    get_lex();
                    if (lex == C_NAME && strcmp(name, "ON") == 0) {
                        z80_2op("LD", "HL", "mode");
                        z80_2op("RES", "2", "(HL)");
                        get_lex();
                    } else if (lex == C_NAME && strcmp(name, "OFF") == 0) {
                        z80_2op("LD", "HL", "mode");
                        z80_2op("SET", "2", "(HL)");
                        get_lex();
                    } else {
                        emit_error("only allowed SPRITE FLICKER ON/OFF");
                    }
                } else {
                    type = evaluate_expression(1, TYPE_8, 0);
                    z80_1op("PUSH", "AF");
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in SPRITE");
                    type = evaluate_expression(1, TYPE_8, 0);
                    z80_1op("PUSH", "AF");
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in SPRITE");
                    type = evaluate_expression(1, TYPE_8, 0);
                    z80_1op("PUSH", "AF");
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in SPRITE");
                    type = evaluate_expression(1, TYPE_8, 0);
                    z80_1op("PUSH", "AF");
                    if (lex == C_COMMA)
                        get_lex();
                    else
                        emit_error("missing comma in SPRITE");
                    type = evaluate_expression(1, TYPE_8, 0);
                    z80_1op("CALL", "update_sprite");
                }
            } else if (strcmp(name, "BITMAP") == 0) {
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
                            sprintf(temp, "\tDB $%02x,$%02x,$%02x,$%02x,$%02x,$%02x,$%02x,$%02x\n",
                                    bitmap[c], bitmap[c + 1], bitmap[c + 2], bitmap[c + 3],
                                    bitmap[c + 4], bitmap[c + 5], bitmap[c + 6], bitmap[c + 7]);
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
                        sprintf(temp, "\tDB $%02x,$%02x,$%02x,$%02x,$%02x,$%02x,$%02x,$%02x\n",
                                bitmap[c], bitmap[c + 1], bitmap[c + 2], bitmap[c + 3],
                                bitmap[c + 4], bitmap[c + 5], bitmap[c + 6], bitmap[c + 7]);
                        fprintf(output, "%s", temp);
                    }
                }
            } else if (strcmp(name, "BORDER") == 0) {
                int type;
                
                get_lex();
                type = evaluate_expression(1, TYPE_8, 0);
                z80_2op("LD", "B", "A");
                z80_2op("LD", "C", "7");
                z80_1op("CALL", "nmi_off");
                z80_1op("CALL", "WRTVDP");
                z80_1op("CALL", "nmi_on");
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
                    z80_1op("CALL", "mode_0");
                if (value == 1)
                    z80_1op("CALL", "mode_1");
                if (value == 2)
                    z80_1op("CALL", "mode_2");
            } else if (strcmp(name, "SCREEN") == 0) {  /* Copy screen */
                struct label *array;
                
                get_lex();
                if (lex != C_NAME) {
                    emit_error("bad syntax for SCREEN");
                    break;
                }
                if (strcmp(name, "ENABLE") == 0) {
                    get_lex();
                    z80_1op("CALL", "ENASCR");
                } else if (strcmp(name, "DISABLE") == 0) {
                    get_lex();
                    z80_1op("CALL", "DISSCR");
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
                        z80_1op("PUSH", "HL");
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
                        z80_1op("PUSH", "HL");
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
                        z80_1op("PUSH", "AF");
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
                            z80_1op("PUSH", "AF");
                            get_lex();
                            final = evaluate_level_0(&type);
                            if ((type & MAIN_TYPE) == TYPE_16)
                                final = node_create(N_REDUCE16, 0, final, NULL);
                            node_label(final);
                            node_generate(final, 0);
                            node_delete(final);
                            z80_1op("CALL", "CPYBLK");
                        } else {
                            z80_2op("LD", "B", "A");
                            z80_1op("POP", "AF");   /* Extract previous width */
                            z80_1op("PUSH", "AF");  /* Save width */
                            z80_1op("PUSH", "BC");  /* Save height */
                            z80_1op("CALL", "CPYBLK");
                        }
                    } else {
                        z80_2op("LD", "HL", assigned);
                        z80_2op("LD", "DE", "$1800");
                        z80_2op("LD", "BC", "$0300");
                        z80_1op("CALL", "nmi_off");
                        z80_1op("CALL", "LDIRVM");
                        z80_1op("CALL", "nmi_on");
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
                    z80_2op("LD", "HL", "music_silence");
                    z80_1op("CALL", "music_play");
                } else if (strcmp(name, "NONE") == 0) {
                    get_lex();
                    z80_1op("XOR", "A");
                    z80_2op("LD", "(music_mode)", "A");
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
                    sprintf(temp, "%d", c);
                    z80_2op("LD", "A", temp);
                    z80_2op("LD", "(music_mode)", "A");
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
                    sprintf(temp, "%d", c);
                    z80_2op("LD", "A", temp);
                    z80_2op("LD", "(music_mode)", "A");
                } else {
                    struct label *label;
                    
                    label = label_search(name);
                    if (label == NULL) {
                        label = label_add(name);
                    }
                    label->used |= LABEL_USED;
                    strcpy(temp, LABEL_PREFIX);
                    strcat(temp, name);
                    z80_2op("LD", "HL", temp);
                    z80_1op("CALL", "music_play");
                    get_lex();
                }
            } else if (strcmp(name, "MUSIC") == 0) {
                int arg;
                static int previous[4];
                unsigned int notes;
                int note;
                int c;
                int label;
                
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
                fprintf(output, "\tdb $%02x,$%02x,$%02x,$%02x\n", notes & 0xff, (notes >> 8) & 0xff, (notes >> 16) & 0xff, (notes >> 24) & 0xff);
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
                        if ((type & MAIN_TYPE) == TYPE_8) {
                            sprintf(temp, "%d", max_value);
                            z80_1op("CP", temp);
                        } else {
                            sprintf(temp, "%d", max_value);
                            z80_2op("LD", "DE", temp);
                            z80_1op("OR", "A");
                            z80_2op("SBC", "HL", "DE");
                            z80_2op("ADD", "HL", "DE");
                        }
                        sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                        z80_2op("JP", "NC", temp);
                    }
                    if (gosub) {
                        sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                        z80_2op("LD", "DE", temp);
                        z80_1op("PUSH", "DE");
                    }
                    if ((type & MAIN_TYPE) == TYPE_8) {
                        z80_2op("LD", "L", "A");
                        if (type & TYPE_SIGNED) {
                            z80_noop("RLA");
                            z80_2op("SBC", "A", "A");
                            z80_2op("LD", "H", "A");
                        } else {
                            z80_2op("LD", "H", "0");
                        }
                    }
                    z80_2op("ADD", "HL", "HL");
                    sprintf(temp, INTERNAL_PREFIX "%d", table);
                    z80_2op("LD", "DE", temp);
                    z80_2op("ADD", "HL", "DE");
                    z80_2op("LD", "A", "(HL)");
                    z80_1op("INC", "HL");
                    z80_2op("LD", "H", "(HL)");
                    z80_2op("LD", "L", "A");
                    z80_1op("JP", "(HL)");
                    sprintf(temp, INTERNAL_PREFIX "%d", table);
                    z80_label(temp);
                    for (c = 0; c < max_value; c++) {
                        if (options[c] != NULL) {
                            sprintf(temp, LABEL_PREFIX "%s", options[c]->name);
                        } else {
                            sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                        }
                        z80_1op("DW", temp);
                    }
                    sprintf(temp, INTERNAL_PREFIX "%d", new_label);
                    z80_label(temp);
                }
            } else if (strcmp(name, "SOUND") == 0) {
                get_lex();
                if (lex != C_NUM) {
                    emit_error("syntax error in SOUND");
                } else {
                    if (value < 3 && (machine == MSX || machine == SVI))
                        emit_warning("using SOUND 0-3 with MSX/SVI target");
                    else if (value >= 5 && machine != MSX && machine != COLECOVISION_SGM && machine != SVI)
                        emit_warning("using SOUND 5-9 with non-MSX/SVI/SGM target");
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
                                z80_2op("LD", "A", "$80");
                                z80_1op("CALL", "sn76489_freq");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_2op("LD", "B", "$90");
                                z80_1op("CALL", "sn76489_vol");
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
                                z80_2op("LD", "A", "$a0");
                                z80_1op("CALL", "sn76489_freq");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_2op("LD", "B", "$b0");
                                z80_1op("CALL", "sn76489_vol");
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
                                z80_2op("LD", "A", "$c0");
                                z80_1op("CALL", "sn76489_freq");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_2op("LD", "B", "$d0");
                                z80_1op("CALL", "sn76489_vol");
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
                                z80_1op("CALL", "sn76489_control");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_2op("LD", "B", "$f0");
                                z80_1op("CALL", "sn76489_vol");
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
                                z80_2op("LD", "A", "$00");
                                z80_1op("CALL", "ay3_freq");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_2op("LD", "B", "$08");
                                z80_1op("CALL", "ay3_reg");
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
                                z80_2op("LD", "A", "$02");
                                z80_1op("CALL", "ay3_freq");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_2op("LD", "B", "$09");
                                z80_1op("CALL", "ay3_reg");
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
                                z80_2op("LD", "A", "$04");
                                z80_1op("CALL", "ay3_freq");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_2op("LD", "B", "$0a");
                                z80_1op("CALL", "ay3_reg");
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
                                z80_2op("LD", "A", "$0b");
                                z80_1op("CALL", "ay3_freq");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_2op("LD", "B", "$0d");
                                z80_1op("CALL", "ay3_reg");
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
                                z80_2op("LD", "B", "$06");
                                z80_1op("CALL", "ay3_reg");
                            }
                            if (lex == C_COMMA) {
                                get_lex();
                                type = evaluate_expression(1, TYPE_8, 0);
                                z80_2op("LD", "B", "$07");
                                z80_1op("CALL", "ay3_reg");
                            }
                            break;
                    }
                }
            } else if (strcmp(name, "CALL") == 0) {        // Call assembly language
                struct node *tree;
                
                get_lex();
                tree = process_usr(1);
                node_label(tree);
                node_generate(tree, 0);
                node_delete(tree);
            } else if (strcmp(name, "ASM") == 0) {  /* ASM statement for inserting assembly code */
                int c;
                
                c = line_pos;
                while (c < line_size && isspace(line[c]))
                    c++;
                while (c < line_size && !isspace(line[c]))
                    c++;
                if (line[c - 1] == ':')
                    lex_skip_spaces();
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
                        emit_error("BANK ROM not 128, 256, 512 or 1024");
                        get_lex();
                    } else if (bank_switching != 0) {
                        emit_error("BANK ROM used twice");
                        get_lex();
                    } else {
                        if (machine == SVI) {
                            emit_error("Bank-switching not supported with SVI");
                        }
                        bank_switching = 1;
                        bank_rom_size = value;
                        bank_current = 0;
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
                    if (bank_switching == 0)
                        emit_error("Using BANK SELECT without BANK ROM");
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
                        z80_2op("LD", "A", temp);
                        z80_2op("LD", "($fffe)", "A");
                    } else if (machine == MSX) {
                        sprintf(temp, "%d", c & 0x3f);
                        z80_2op("LD", "A", temp);
                        z80_2op("LD", "($7000)", "A");
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
                        z80_2op("LD", "A", temp);
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
                    if (bank_switching == 0)
                        emit_error("Using BANK without BANK ROM");
                    d = c;
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
                    bank_finish();
                    sprintf(temp, "$%05x", c << 14);
                    z80_1op("FORG", temp);
                    if (machine == SG1000) {
                        z80_1op("ORG", "$4000");
                    } else if (machine == MSX) {
                        z80_1op("ORG", "$8000");
                    } else {
                        z80_1op("ORG", "$c000");
                    }
                    bank_current = d;
                    z80_empty();
                }
            } else if (macro_search(name) != NULL) {  // Function (macro)
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
            z80_label(temp);
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
            } else if (strcmp(name, "END") == 0 && lex_sneak_peek() != 'I') {  /* END (and not END IF) */
                if (!inside_proc)
                    emit_warning("END without PROCEDURE");
                else if (loops != NULL)
                    emit_error("Ending PROCEDURE with control block still open");
                get_lex();
                if (!last_is_return)
                    z80_noop("RET");
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
    int bytes_used;
    int available_bytes;
    time_t actual;
    struct tm *date;
    
    actual = time(0);
    date = localtime(&actual);

    fprintf(stderr, "\nCVBasic compiler " VERSION "\n");
    fprintf(stderr, "(c) 2024 Oscar Toledo G. https://nanochess.org/\n\n");
    
    if (argc < 3) {
        fprintf(stderr, "Usage:\n");
        fprintf(stderr, "\n");
        fprintf(stderr, "    cvbasic input.bas output.asm\n");
        fprintf(stderr, "    cvbasic --sgm input.bas output.asm\n");
        fprintf(stderr, "    cvbasic --sg1000 input.bas output.asm\n");
        fprintf(stderr, "    cvbasic --msx input.bas output.asm\n");
        fprintf(stderr, "    cvbasic --svi input.bas output.asm\n");
        fprintf(stderr, "\n");
        fprintf(stderr, "    By default, it will create assembler files for Colecovision.\n");
        fprintf(stderr, "    The options allow to compile for Sega SG-1000, MSX,\n");
        fprintf(stderr, "    SVI-328, and the Super Game Module for Colecovision.\n");
        fprintf(stderr, "\n");
        fprintf(stderr, "    It will return a zero error code if compilation was\n");
        fprintf(stderr, "    successful, or non-zero otherwise.\n\n");
        fprintf(stderr, "Many thanks to Albert, abeker, aotta, artrag, atari2600land,\n");
        fprintf(stderr, "carlsson, CrazyBoss, drfloyd, gemintronic, Jess Ragan,\n");
        fprintf(stderr, "Kamshaft, Kiwi, pixelboy, SiRioKD, Tarzilla, Tony Cruise,\n");
        fprintf(stderr, "and youki.\n");
        fprintf(stderr, "\n");
        exit(1);
    }
    c = 1;
    if (argv[c][0] == '-' && argv[c][1] == '-' && tolower(argv[c][2]) == 's' && tolower(argv[c][3]) == 'g' && memcmp(&argv[c][4], "1000", 5) == 0) {
        machine = SG1000;
        c++;
    } else if(argv[c][0] == '-' && argv[c][1] == '-' && tolower(argv[c][2]) == 'm' && tolower(argv[c][3]) == 's' && tolower(argv[c][4]) == 'x' && argv[c][5] == '\0') {
        machine = MSX;
        c++;
    } else if(argv[c][0] == '-' && argv[c][1] == '-' && tolower(argv[c][2]) == 's' && tolower(argv[c][3]) == 'g' && tolower(argv[c][4]) == 'm' && argv[c][5] == '\0') {
        machine = COLECOVISION_SGM;
        c++;
    } else if(argv[c][0] == '-' && argv[c][1] == '-' && tolower(argv[c][2]) == 's' && tolower(argv[c][3]) == 'v' && tolower(argv[c][4]) == 'i' && argv[c][5] == '\0') {
        machine = SVI;
        c++;
    } else {
        machine = COLECOVISION;
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
            z80_noop("RET");
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
    fprintf(output, "\n");
    fprintf(output, "CVBASIC_MUSIC_PLAYER:\tequ %d\n", music_used);
    fprintf(output, "CVBASIC_COMPRESSION:\tequ %d\n", compression_used);
    fprintf(output, "CVBASIC_BANK_SWITCHING:\tequ %d\n", bank_switching);
    fprintf(output, "\n");
    fprintf(output, "BASE_RAM:\tequ $%04x\t; Base of RAM\n", consoles[machine].base_ram);
    fprintf(output, "STACK:\tequ $%04x\t; Base stack pointer\n", consoles[machine].stack);
    fprintf(output, "VDP:\tequ $%02x\t; VDP port (write)\n", consoles[machine].vdp_port_write);
    fprintf(output, "VDPR:\tequ $%02x\t; VDP port (read)\n", consoles[machine].vdp_port_read);
    fprintf(output, "\n");
    if (bank_switching) {
        if (machine == COLECOVISION || machine == COLECOVISION_SGM) {
            fprintf(output, "\tforg $%05x\n", bank_rom_size * 0x0400 - 0x4000);
        } else {
            fprintf(output, "\tforg $00000\n");
        }
    }
    prologue = fopen("cvbasic_prologue.asm", "r");
    if (prologue == NULL) {
        fprintf(stderr, "Unable to open cvbasic_prologue.asm.\n");
        exit(2);
    }
    while (fgets(line, sizeof(line) - 1, prologue)) {
        p = line;
        while (*p && isspace(*p))
            p++;
        if (memcmp(p, ";CVBASIC MARK DON'T CHANGE", 26) == 0) {  /* Location to replace */
            if (frame_drive != NULL) {
                fprintf(output, "\tCALL " LABEL_PREFIX "%s\n", frame_drive->name);
            }
        } else {
            fputs(line, output);
        }
    }
    fclose(prologue);
    
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
    
    prologue = fopen("cvbasic_epilogue.asm", "r");
    if (prologue == NULL) {
        fprintf(stderr, "Unable to open cvbasic_epilogue.asm.\n");
        exit(2);
    }
    while (fgets(line, sizeof(line) - 1, prologue)) {
        fputs(line, output);
    }
    fclose(prologue);
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
            sprintf(temp, ARRAY_PREFIX "%s:\trb %d", label->name, label->length * size);
            fprintf(output, "%s\n", temp);
            bytes_used += label->length * size;
            label = label->next;
        }
    }
    fclose(output);
    available_bytes = consoles[machine].memory_size;
    if (machine != COLECOVISION_SGM)
        available_bytes -= 64 +                    /* Stack requirements */
                    (music_used ? 33 : 0) +     /* Music player requirements */
                        146;                    /* Support variables */
    if (bytes_used > available_bytes) {
        fprintf(stderr, "ERROR: ");
        err_code = 1;
    }
    fprintf(stderr, "%d RAM bytes used of %d bytes available.\n", bytes_used, available_bytes);
    fprintf(stderr, "Compilation finished.\n\n");
    exit(err_code);
}

