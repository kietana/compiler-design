#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H
#define MAX_LINE_LENG 256
#define MAX_TABLE_SIZE 257

#include "union.h"

/* Symbol Table Part */

typedef struct {
    char idName[MAX_LINE_LENG];     // Name of the id
    enum types type;                // int, bool, real, string
    enum categories category;       // var, const, function, procedure
    union unionValue symbolVal;     // Store constant value
    int argCount;                   // Store number of argument a function have
    int indexLoc;                   // Local variable index in local variable array
} Symbol;

typedef struct {
    Symbol* table[MAX_TABLE_SIZE];  // Array of pointers to Symbol
    int idxCounter;
} SymbolTable;

void init();
SymbolTable* create();
int lookup(char* name, SymbolTable* tab);
int insert(Symbol*);
void dump(SymbolTable*);
void freeSymbolTable(SymbolTable* tab);


/* Symbol Table Stack */

SymbolTable* stack[MAX_LINE_LENG];  // Contain symbol tables for scope     
extern int tabTop;

int isTabFull();
int isTabEmpty();
void pushTab(SymbolTable* tab);
void popTab();

#endif