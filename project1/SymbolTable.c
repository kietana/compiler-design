#include "SymbolTable.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int hash (char *name) {
    int hashValue = 0;
    for (int i = 0; i < strlen(name); i++) {
        hashValue += name[i];
    }
    return hashValue % MAX_TABLE_SIZE;
}

void create() {
    symbolTable.counter = 0;
    for (int i = 0; i < MAX_TABLE_SIZE; i++) {
        symbolTable.table[i] = NULL;
        symbolTable.order[i] = 0;
    }
}

int lookup(char* name) {
    int index = hash(name);
    for (int i = 0; i < MAX_TABLE_SIZE; i++) {
        int try = (i + index) % MAX_TABLE_SIZE;
        if (symbolTable.table[try] != NULL && strcmp(symbolTable.table[try]->idName, name) == 0) {
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
            if (symbolTable.table[try] == NULL) { 
                symbolTable.table[try] = symPtr;
                symbolTable.order[symbolTable.counter++] = try;
                return try;
            }
        }
    }
    return -1;
}

void dump() {
    for (int i = 0; i < MAX_TABLE_SIZE; i++) {
        if (symbolTable.table[symbolTable.order[i]] != NULL) {
            printf("%d: %s\n", symbolTable.order[i], symbolTable.table[symbolTable.order[i]]->idName);
        }
    }
}