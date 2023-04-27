#include "SymbolTable.h"

int hash (char *name) {
    int hashValue = 0;
    for (int i = 0; i < strlen(name); i++) {
        hashValue += name[i];
    }
    return hashValue % MAX_TABLE_SIZE;
}

void create() {
    for (int i = 0; i < MAX_TABLE_SIZE; i++) {
        SymbolTable[i] = NULL;
    }
}

int lookup(char* name) {
    int index = hash(name);
    for (int i = 0; i < MAX_TABLE_SIZE; i++) {
        int try = (i + index) % MAX_TABLE_SIZE;
        if (SymbolTable[try] != NULL && strcmp(SymbolTable[try]->idName, name) == 0) {
            return try;
        }
    }
    return -1;
}

int insert(char* name) {
    Symbol* symPtr = (Symbol*) malloc (sizeof(Symbol));
    if (symPtr == NULL) return -1;
    strcpy(symPtr->idName, name);
    int index = hash(name);
    if (lookup(name) == -1) {
        for (int i = 0; i < MAX_TABLE_SIZE; i++) {
            int try = (i + index) % MAX_TABLE_SIZE;
            if (SymbolTable[try] == NULL) { 
                SymbolTable[try] = symPtr;
                // printf("\n\nInserted %s at %d\n\n", name, try);
                return try;
            }
        }
    }
    return -1;
}

void dump() {
    for (int i = 0; i < MAX_TABLE_SIZE; i++) {
        if (SymbolTable[i] != NULL) {
            printf("%d: %s\n", i, SymbolTable[i]->idName);
        }
        // else {
        //     printf("%d: %s\n", i, "NULL");
        // }
    }
}