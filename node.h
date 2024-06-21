/*
 ** CVBasic - Header for expression nodes
 **
 ** by Oscar Toledo G.
 **
 ** © Copyright 2024 Óscar Toledo G.
 ** https://nanochess.org/
 **
 ** Creation date: Jun/21/2024.
 */

enum node_type {
    N_OR8, N_OR16,
    N_XOR8, N_XOR16,
    N_AND8, N_AND16,
    
    N_EQUAL8, N_EQUAL16, N_NOTEQUAL8, N_NOTEQUAL16,
    N_LESS8, N_LESS16, N_LESSEQUAL8, N_LESSEQUAL16,
    N_GREATER8, N_GREATER16, N_GREATEREQUAL8, N_GREATEREQUAL16,
    N_LESS8S, N_LESS16S, N_LESSEQUAL8S, N_LESSEQUAL16S,
    N_GREATER8S, N_GREATER16S, N_GREATEREQUAL8S, N_GREATEREQUAL16S,
    
    N_PLUS8, N_PLUS16, N_MINUS8, N_MINUS16,
    N_MUL8, N_MUL16, N_DIV16, N_DIV16S, N_MOD16, N_MOD16S,
    N_NEG8, N_NEG16, N_NOT8, N_NOT16,
    N_EXTEND8, N_EXTEND8S, N_REDUCE16,
    N_LOAD8, N_LOAD16,
    N_ASSIGN8, N_ASSIGN16,
    N_READ8, N_READ16,
    N_NUM8, N_NUM16,
    N_PEEK8, N_PEEK16, N_VPEEK, N_INP, N_ABS16, N_SGN16,
    N_JOY1, N_JOY2, N_KEY1, N_KEY2,
    N_RANDOM, N_FRAME, N_MUSIC, N_NTSC, N_POS,
    N_ADDR,
    N_USR,
};

struct node {
    enum node_type type;
    int value;
    struct node *left;
    struct node *right;
    struct label *label;
    int x;
};

extern void node_visual(struct node *);
extern struct node *node_create(enum node_type, int, struct node *, struct node *);
extern void node_generate(struct node *, int);
extern void node_delete(struct node *);
