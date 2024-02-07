#include "label.h"
#include <stdio.h>

int Ltop = -1;
int Lbegin;
int Lexit;
int Lelse;
int Lendif;
int Ltemp;
int Lfirst;
int Lsecond;
LabelHandler Lhandler;


void initLhandler() {
    Lhandler.Lcounter = 0;
}

int getLabel() {
    printf("\nGET LABEL = %d\n", Lhandler.Lcounter);
    return Lhandler.Lcounter++;
}


// IF THEN ELSE -> 4 labels (2 boolean check + 2)
// IF THEN -> 3 labels (2 boolean check + 1)
// LOOP -> 
void pushLabel(int type) {
    printf("\nPUSH LABEL = %d\n", Lhandler.Lcounter);
    Lhandler.Lstack[++Ltop].number = Lhandler.Lcounter++;
    Lhandler.Lstack[Ltop].Ltype = type;
}

void popLabel(int lab) {
    for (int i = 1; i <= lab; i++) {
        // Lhandler.Lstack[Ltop--];
        Ltop--;
    }
}

int getElse() {
    for (int i = Ltop; i >= 0; i--) {
        if (Lhandler.Lstack[i].Ltype == COND_ELSE) return Lhandler.Lstack[i].number;
    }
}

int getEndIf() {
    for (int i = Ltop; i >= 0; i--) {
        if (Lhandler.Lstack[i].Ltype == COND_END) return Lhandler.Lstack[i].number;
    }
}

int getLoopBegin() {
    for (int i = Ltop; i >= 0; i--) {
        if (Lhandler.Lstack[i].Ltype == LOOP_BEGIN) return Lhandler.Lstack[i].number;
    }
}

int getLoopEnd() {
    for (int i = Ltop; i >= 0; i--) {
        if (Lhandler.Lstack[i].Ltype == LOOP_END) return Lhandler.Lstack[i].number;
    }
}

int getLTemp() {
    for (int i = Ltop; i >= 0; i++) {
        if (Lhandler.Lstack[i].Ltype == LOOP_BEGIN || Lhandler.Lstack[i].Ltype == COND_END) {
            return Lhandler.Lstack[i].number;
        }
    }
}