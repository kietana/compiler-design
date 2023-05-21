#include "symboltable.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int tabTop = -1;

/* Symbol table implementation */

void init(){
    SymbolTable* newTab = create();
    pushTab(newTab);
}

SymbolTable* create() {
    SymbolTable* tab = malloc(sizeof(SymbolTable));
    for (int i = 0; i < MAX_TABLE_SIZE; i++) {
        tab->table[i] = NULL;
    }
    return tab;
}

/* Only lookup in a certain table */
int lookup(char* name, SymbolTable* tab) {        
    for (int i = 0; i < MAX_TABLE_SIZE; i++) {
        if (tab->table[i] != NULL && strcmp(tab->table[i]->idName, name) == 0) {
            return i;
        }
    }
    return -1;
}

/*Insert always at the top most symbol table in the stack*/
int insert(Symbol* symPtr) {                    
    for (int i = 0; i < MAX_TABLE_SIZE; i++) {
        if (stack[tabTop]->table[i] == NULL) { 
            stack[tabTop]->table[i] = symPtr;
            return i;
        }
    }
    return -1;
}

/* Printing symbol table */
void dump(SymbolTable* tab) {
    printf("%-15s %-15s %-15s %-15s %-15s %-15s\n", "INDEX", "ID_NAME", "TYPE", "CATEGORY", "HAS_VALUE", "VALUE");
    for (int i = 0; i < MAX_TABLE_SIZE; i++) {
        if (tab->table[i] != NULL) {
            printf("%-15d %-15s %-15d %-15d %-15d ", i, tab->table[i]->idName, tab->table[i]->type, tab->table[i]->category, tab->table[i]->hasValue);
            if (tab->table[i]->type == TYPE_INT) {
                printf("%-15d\n", tab->table[i]->symbolVal.iValue);
            }
            else if (tab->table[i]->type == TYPE_BOOL) {
                printf("%-15d\n", tab->table[i]->symbolVal.bValue);
            }
            else if (tab->table[i]->type == TYPE_REAL) {
                printf("%-15f\n", tab->table[i]->symbolVal.fValue);
            }
            else {
                printf("%-15s\n", tab->table[i]->symbolVal.sValue);
            }
        }
    }

    // Free table after print
    freeSymbolTable(tab);
}

void freeSymbolTable(SymbolTable* tab) {
    if (tab == NULL) return;

    // Traverse the symbol table to free Symbol
    for (int i = 0; i < MAX_TABLE_SIZE; i++) {
        if (tab->table[i] != NULL) {
            free(tab->table[i]);
            tab->table[i] = NULL;
        }
    }

    // Free the symbol table itself
    free(tab);
}

/* Handle symbol table stack */

int isTabFull() {
    return tabTop == MAX_TABLE_SIZE - 1;
}

int isTabEmpty() {
	return tabTop == -1;
}

void pushTab(SymbolTable* tab) {
    // printf("\nPushing symbol table to stack\n");
	if (isTabFull()) return;
	stack[++tabTop] = tab;
}

void popTab() {
    // printf("\n{Popping symbol table to stack\n");
	if (isTabEmpty()) return;
    freeSymbolTable(stack[tabTop]);
	stack[tabTop--] = NULL;
}