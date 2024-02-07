#ifndef LABEL_H
#define LABEL_H
#define MAX_LABEL_STACK 256

enum LabelType {
    LOOP_BEGIN = 1,
    LOOP_END,
    COND_END,
    COND_ELSE
};

typedef struct 
{
    int number;
    int Ltype;
} Label;


typedef struct
{
    int Lcounter;
    Label Lstack[MAX_LABEL_STACK];
} LabelHandler;

extern int Ltop;
extern int Lbegin;
extern int Lexit;
extern int Lelse;
extern int Lendif;
extern int Ltemp;
extern int Lfirst;
extern int Lsecond;

void initLhandler();
int getLabel();
void pushLabel(int type);
void popLabel(int lab);
int getElse();
int getEndIf();
int getLoopBegin();
int getLoopEnd();
int getLTemp();

#endif