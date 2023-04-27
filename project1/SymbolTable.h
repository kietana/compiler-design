#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H
#define MAX_LINE_LENG 256
#define MAX_TABLE_SIZE 257

typedef struct {
    char idName[MAX_LINE_LENG];  // name of the identifier
} Symbol;

typedef struct {
    Symbol* table[MAX_TABLE_SIZE]; // array of pointers to Symbol
    int order[MAX_TABLE_SIZE]; // store the position in table array
    int counter; // keep track of current index of order array
} SymbolTable;

SymbolTable symbolTable;

int hash (char *name);
void create();
int lookup(char* name);
int insert(char* name);
void dump();

#endif