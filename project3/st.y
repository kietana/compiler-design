%{
#include "symboltable.h"
#include "label.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#define Trace(t)        printf(t)

void yyerror(char *msg);
int yylex();
extern FILE *yyin;

char filename[30];
char ext[30];
FILE* jasmFile;
int hold; // just var to hold any temporary value
%}

%union {
    char idName[256];           // id name NOT value
    int iVal;                   // int value
    float fVal;                 // float value
    int bVal;                   // bool value: 0 or 1
    char sVal[256];             // string value
    int t;                      // type
    struct info i;              // for non-terminal use
}

%token MOD ASSIGN LEQUAL GEQUAL AND OR NOT NOTEQUAL
%token ARRAY ST_BEGIN BOOL CHAR CONST DECREASING DEFAULT DO ELSE END EXIT FALSE FOR FUNCTION GET IF INT LOOP OF PUT PROCEDURE REAL RESULT RETURN SKIP STRING THEN TRUE VAR WHEN
%token <idName> ID
%token <iVal> INTVAL
%token <fVal> REALVAL
%token <bVal> BOOLVAL
%token <sVal> STRINGVAL

%type <t> type_dec
%type <i> literal_const const_exp bool_exp expression opt_actual_arg expression_list func_invoc array_ref

%left OR
%left AND
%left NOT
%left '<' LEQUAL '>' GEQUAL '=' NOTEQUAL
%left '+' '-'
%left '*' '/' MOD
%nonassoc UMINUS

%%

program:                {
                            fprintf(jasmFile, "class %s\n{\n", filename);
                        }
                        opt_decs 
                        {
                            fprintf(jasmFile, "\tmethod public static void main(java.lang.String[])\n");
                            fprintf(jasmFile, "\tmax_stack 15\n");
                            fprintf(jasmFile, "\tmax_locals 15\n\t{\n");
                        }
                        {
                            init();
                        }
                        opt_stmts
                        {
                            Trace("\nTRACE: program\n");
                            popTab();

                            fprintf(jasmFile, "\t\treturn\n\t}\n}");

                        };

 /* zero or more variable, constant, or function declarations */
opt_decs:               dec opt_decs
                        | /* No declaration */
                        ;

dec:                    var_dec | const_dec | func_dec;

opt_stmts:              stmt opt_stmts
                        | /* No statements */
                        ;

stmt:                   block | simple | conditional | loop | func_invoc;

 /* zero or more variable, or constant declarations and statements, NO function declaration */
opt_decs_stmts:         var_dec opt_decs_stmts
                        | const_dec opt_decs_stmts
                        | stmt opt_decs_stmts
                        | /* No declaration nor statement */
                        ;

literal_const:          INTVAL
                        {
                            $$.type = TYPE_INT;
                            $$.category = TYPE_CONST;
                            $$.ntValue.iValue = $1;
                        }
                        | REALVAL
                        {
                            $$.type = TYPE_REAL;
                            $$.category = TYPE_CONST;
                            $$.ntValue.fValue = $1;
                        }
                        | BOOLVAL
                        {
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_CONST;
                            $$.ntValue.bValue = $1;
                        }
                        | STRINGVAL
                        {
                            $$.type = TYPE_STRING;
                            $$.category = TYPE_CONST;
                            strcpy($$.ntValue.sValue, $1);
                        }
                        ;

type_dec:               INT { $$ = TYPE_INT; }
                        | REAL { $$ = TYPE_REAL; }
                        | STRING { $$ = TYPE_STRING; }
                        | BOOL { $$ = TYPE_BOOL; }
                        ;

const_dec:              CONST ID ':' type_dec ASSIGN const_exp
                        {
                            // Trace("\nTRACE: Constant declaration with type and expression\n");

                            if ($6.category != TYPE_CONST) {
                                yyerror("Invalid constant declaration: RHS must be a constant value");
                            }
                            else if ($4 != $6.type) {
                                yyerror("Invalid constant declaration: Type not match");
                            }
                            else if (lookup($2, stack[tabTop]) != -1) { /* Look up from the top most symbol table and found */
                                yyerror("Constant redefinition");
                            }
                            else {
                                Symbol* symPtr = (Symbol*) malloc (sizeof(Symbol));
                                strcpy(symPtr->idName, $2);
                                symPtr->type = $4;
                                symPtr->category = TYPE_CONST;
                                
                                if ($4 == TYPE_INT) symPtr->symbolVal.iValue = $6.ntValue.iValue;
                                else if ($4 == TYPE_REAL) symPtr->symbolVal.fValue = $6.ntValue.fValue;
                                else if ($4 == TYPE_BOOL) symPtr->symbolVal.bValue = $6.ntValue.bValue;
                                else if ($4 == TYPE_STRING) strcpy(symPtr->symbolVal.sValue, $6.ntValue.sValue);
                                
                                int index = insert(symPtr);
                            }

                        }
                        | CONST ID ASSIGN const_exp
                        {
                            // Trace("\nTRACE: Constant declaration with expression\n");

                            if (lookup($2, stack[tabTop]) != -1) {
                                yyerror("Constant redefinition");
                            }
                            else {
                                Symbol* symPtr = (Symbol*) malloc (sizeof(Symbol));
                                strcpy(symPtr->idName, $2);
                                symPtr->type = $4.type;
                                symPtr->category = TYPE_CONST;
                                
                                if ($4.type == TYPE_INT) symPtr->symbolVal.iValue = $4.ntValue.iValue;
                                else if ($4.type == TYPE_REAL) symPtr->symbolVal.fValue = $4.ntValue.fValue;
                                else if ($4.type == TYPE_BOOL) symPtr->symbolVal.bValue = $4.ntValue.bValue;
                                else if ($4.type == TYPE_STRING) strcpy(symPtr->symbolVal.sValue, $4.ntValue.sValue);
                                
                                int index = insert(symPtr);
                            }
                        }
                        ;

var_dec:                VAR ID ':' type_dec ASSIGN const_exp
                        {
                            // Trace("\nTRACE: Variable declaration with type and expression\n");

                            if ($6.category != TYPE_CONST) {
                                yyerror("Invalid variable declaration: RHS must be constant");
                            }
                            else if ($4 != $6.type) {
                                yyerror("Invalid variable declaration: Type not match");
                            }
                            else if (lookup($2, stack[tabTop]) != -1) {                     /* Found in the top most symbol table */
                                yyerror("Variable redefinition: already defined as a variable");
                            }
                            else {                                                          /* Create new variable */
                                Symbol* symPtr = (Symbol*) malloc (sizeof(Symbol));
                                strcpy(symPtr->idName, $2);
                                symPtr->type = $4;
                                symPtr->category = TYPE_VAR;
                                
                                int index = insert(symPtr);
                                if ($4 == TYPE_INT || $4 == TYPE_BOOL) {
                                    if (tabTop == 0) {  // global
                                        fprintf(jasmFile, "\tfield static int %s = %d\n", $2, $6.ntValue.iValue);
                                    }
                                    else {
                                        stack[tabTop]->table[index]->indexLoc = stack[tabTop]->idxCounter++;
                                        fprintf(jasmFile, "istore %d\n", stack[tabTop]->idxCounter);
                                    }
                                }
                            }
                        }
                        | VAR ID ASSIGN const_exp
                        {
                            // Trace("\nTRACE: Variable declaration with expression\n");

                            if ($4.category != TYPE_CONST) {
                                yyerror("Invalid variable declaration: RHS must be constant");
                            }
                            else if (lookup($2, stack[tabTop]) != -1) {
                                yyerror("Variable redefinition: already defined as a variable");
                            }
                            else {
                                Symbol* symPtr = (Symbol*) malloc (sizeof(Symbol));
                                strcpy(symPtr->idName, $2);
                                symPtr->type = $4.type;
                                symPtr->category = TYPE_VAR;

                                int index = insert(symPtr);

                                if (tabTop == 0) {
                                    fprintf(jasmFile, "\tfield static int %s = %d\n", $2, $4.ntValue.iValue);
                                }
                                else {
                                    stack[tabTop]->table[index]->indexLoc = stack[tabTop]->idxCounter++;
                                    fprintf(jasmFile, "istore %d\n", stack[tabTop]->idxCounter);
                                }
                            }
                        }
                        | VAR ID ':' type_dec
                        {
                            // Trace("\nTRACE: Variable declaration with type\n");

                            if (lookup($2, stack[tabTop]) != -1) {
                                yyerror("Variable redefinition: already defined as a variable");
                            }
                            else {
                                Symbol* symPtr = (Symbol*) malloc (sizeof(Symbol));
                                strcpy(symPtr->idName, $2);
                                symPtr->type = $4;
                                symPtr->category = TYPE_VAR;
                                
                                int index = insert(symPtr);
                                if ($4 == TYPE_INT || $4 == TYPE_BOOL) {
                                    if (tabTop == 0) {
                                        fprintf(jasmFile, "\tfield static int %s\n", $2);
                                    }
                                    else {
                                        stack[tabTop]->table[index]->indexLoc = stack[tabTop]->idxCounter++;
                                    }
                                }
                            }
                        }
                        | array_dec
                        ;

const_exp:              expression;

array_dec:              VAR ID ':' ARRAY INTVAL '.' '.' INTVAL OF type_dec
                        {

                            if ($5 < 0 || $8 < 0) {
                                yyerror("Array bound cannot be negative");
                            }
                            else if ($5 > $8) {
                                yyerror("Array lower bound must be less than upper bound");
                            }
                            else if (lookup($2, stack[tabTop]) != -1) {
                                yyerror("Array redefinition");
                            }
                            else {
                                Symbol* symPtr = (Symbol*) malloc (sizeof(Symbol));
                                strcpy(symPtr->idName, $2);
                                symPtr->type = $10;
                                symPtr->category = TYPE_VAR;
                                
                                int index = insert(symPtr);
                            }
                        }
                        ;

 /* Function declaration: return (FUNCTION) and no return (PROCEDURE) */
func_dec:               FUNCTION ID
                        {
                            // Trace("\nTRACE: Function declaration\n");

                            if (lookup($2, stack[tabTop]) != -1) {
                                yyerror("Function redefinition: name not unique");
                            }
                            if (lookup($2, stack[tabTop]) == -1) {
                                Symbol* symPtr = (Symbol*) malloc (sizeof(Symbol));
                                strcpy(symPtr->idName, $2);
                                symPtr->category = TYPE_FUNC;
                                    
                                int index = insert(symPtr);                 /* ID belongs to previous symbol table, so insert first then init() */
                            }

                            init();
                        }
                        '(' opt_formal_arg ')' ':' type_dec 
                        {
                            int index = lookup($2, stack[tabTop - 1]);
                            stack[tabTop - 1]->table[index]->type = $8;

                            // Code gen
                            int args = stack[tabTop - 1]->table[index]->argCount;
                            fprintf(jasmFile, "\tmethod public static int %s(", $2);
                            for (int i = 0; i < args ; i++){
                                if (i != args - 1) fprintf(jasmFile, "int, ");
                                else fprintf(jasmFile, "int)\n");
                            }
                            fprintf(jasmFile, "\tmax_stack 15\n");
                            fprintf(jasmFile, "\tmax_locals 15\n\t{\n");
                        }
                        opt_decs_stmts END ID
                        {
                            if (strcmp($2, $12) != 0) yyerror("Function name not match");
                            else {
                                int index = lookup($2, stack[tabTop - 1]);  /* Function index, because function name is not store in new scope, tabTop-1*/
                                stack[tabTop - 1]->table[index]->type = $8; /* Store function return type */
                            }

                            popTab();

                            // Code gen
                            fprintf(jasmFile, "\t\tireturn\n\t}\n");
                        }
                        | PROCEDURE ID
                        {
                            // Trace("\nTRACE: Procedure declaration\n");

                            if (lookup($2, stack[tabTop]) != -1) {
                                yyerror("Function redefinition: name not unique");
                            }
                            if (lookup($2, stack[tabTop]) == -1) {
                                Symbol* symPtr = (Symbol*) malloc (sizeof(Symbol));
                                strcpy(symPtr->idName, $2);
                                symPtr->category = TYPE_PROC;
                                
                                int index = insert(symPtr);
                            }

                            init();
                        }
                        '(' opt_formal_arg ')' 
                        {
                            // Code gen
                            int index = lookup($2, stack[tabTop - 1]);
                            int args = stack[tabTop - 1]->table[index]->argCount;
                            fprintf(jasmFile, "\tmethod public static void %s(", $2);
                            for (int i = 0; i < args ; i++){
                                if (i != args - 1) fprintf(jasmFile, "int, ");
                                else fprintf(jasmFile, "int)\n");
                            }
                            fprintf(jasmFile, "\tmax_stack 15\n");
                            fprintf(jasmFile, "\tmax_locals 15\n\t{\n");
                        }
                        opt_decs_stmts END ID
                        {
                            if (strcmp($2, $10) != 0) yyerror("Function name not match");
                            else {
                                int index = lookup($2, stack[tabTop]);
                                stack[tabTop - 1]->table[index]->type = NO_TYPE;
                            }

                            popTab();
                            // Code gen
                            fprintf(jasmFile, "\t\treturn\n\t}\n");
                        }
                        ;

opt_formal_arg:         arg_list
                        | /* No arguments */
                        ;

arg_list:               arg_dec ',' arg_list
                        | arg_dec
                        ;

arg_dec:                ID ':' type_dec
                        {

                            // Add number of args info to FUNCITON ID from prev symtoltable bcs arg_dec is alr entering new scope
                            int prevTab = tabTop - 1;
                            for (int i = 0; i < 256; i++) {
                                if (stack[prevTab]->table[i] == NULL) {
                                    stack[prevTab]->table[i - 1]->argCount++; // i - 1 is which index id is in the prev symbol table
                                    break;
                                }
                            }

                            int index = lookup($1, stack[tabTop]);
                            if (index != -1 && stack[tabTop]->table[index]->category == TYPE_FOR_ARG) {
                                yyerror("Formal argument redefinition");
                            }
                            else {
                                Symbol* symPtr = (Symbol*) malloc (sizeof(Symbol));
                                strcpy(symPtr->idName, $1);
                                symPtr->type = $3;
                                symPtr->category = TYPE_FOR_ARG;
                                symPtr->indexLoc = stack[tabTop]->idxCounter++;
                                
                                int index = insert(symPtr);
                            }
                        }
                        ;

 /* Statements, Invocations, and Expressions part */

 block:                 ST_BEGIN
                        {
                            init();
                        }
                        opt_decs_stmts END
                        {
                            popTab();
                        }
                        ;

 simple:                ID ASSIGN expression
                        {
                            // Trace("\nTRACE: id := expression\n");
                            /* Repeatedly look for symbols in current and before tables */
                            int foundInTab = -1;
                            int index;

                            for (int i = tabTop; i >= 0; i--) { 
                                index = lookup($1, stack[i]);
                                if (index != -1) {       // Found
                                    foundInTab = i;      // Found in this table
                                    break;
                                }
                            }

                            if (foundInTab == -1) yyerror("Undeclared identifier");
                            else if (stack[foundInTab]->table[index]->category == TYPE_CONST) {
                                yyerror("Cannot assign new value to constant");
                            }

                            // Code gen
                            if (foundInTab == 0) { // global
                                fprintf(jasmFile, "\t\tputstatic int %s.%s\n", filename, $1);
                            }
                            else {  // local
                                fprintf(jasmFile, "\t\tistore %d\n", stack[foundInTab]->table[index]->indexLoc);
                            }
                        }
                        | 
                        {
                            fprintf(jasmFile, "\t\tgetstatic java.io.PrintStream java.lang.System.out\n");
                        }
                        PUT expression
                        {
                            if ($3.type == TYPE_STRING) fprintf(jasmFile, "\t\tinvokevirtual void java.io.PrintStream.print(java.lang.String)\n");
                            else if ($3.type == TYPE_INT || $3.type == TYPE_BOOL) fprintf(jasmFile, "\t\tinvokevirtual void java.io.PrintStream.print(int)\n");
                         
                        }
                        | GET ID
                        | RESULT expression
                        | RETURN
                        | EXIT opt_exit_condition
                        | SKIP
                        {
                            fprintf(jasmFile, "\t\tgetstatic java.io.PrintStream java.lang.System.out\n");
                            fprintf(jasmFile, "\t\tinvokevirtual void java.io.PrintStream.println()\n");
                        }
                        ;

opt_exit_condition:     WHEN bool_exp
                        {
                            if ($2.type != TYPE_BOOL) yyerror("Exit condition not boolean type");
    
                            Lexit = getLoopEnd();
                            fprintf(jasmFile, "\t\tifne L%d\n", Lexit);
                        }
                        | /* No exit condition */
                        {

                        }
                        ;

bool_exp:               expression;

/* conditional:            IF bool_exp THEN
                        {
                            // Trace("\nTRACE: Conditional statement with else\n");

                            if ($2.type != TYPE_BOOL) yyerror("Condition inside bracket not boolean type");
                            init();

                            // Code gen
                            fprintf(jasmFile, "\t\tifeq L%d\n", label); // 2
                        }
                        opt_decs_stmts 
                        {
                            popTab();

                            // Code gen
                            fprintf(jasmFile, "\t\tgoto L%d\n", label + 1); // 3
                            fprintf(jasmFile, "\tL%d:\n", label); // 2
                        }
                        ELSE
                        {
                            init();
                        }
                        opt_decs_stmts END IF
                        {
                            popTab();

                            // Code gen
                            fprintf(jasmFile, "\tL%d:\n", label + 1); // 3 
                            label += 2;
                        }
                        | IF bool_exp THEN
                        {
                            // Trace("\nTRACE: Conditional statement w/o else\n");

                            if ($2.type != TYPE_BOOL) yyerror("Condition inside bracket not boolean type");
                            init();

                            // Code gen
                            fprintf(jasmFile, "\t\tifeq L%d\n", label);
                        }
                        opt_decs_stmts END IF
                        {
                            popTab();
                            // Code gen
                            fprintf(jasmFile, "\t\tgoto L%d\n", label);
                            fprintf(jasmFile, "\tL%d:\n", label);
                            label += 1;
                        }
                        ; */

conditional:            IF bool_exp THEN
                        {
                            // Trace("\nTRACE: Conditional statement with else\n");

                            if ($2.type != TYPE_BOOL) yyerror("Condition inside bracket not boolean type");
                            init();

                            // Code gen
                            pushLabel(COND_ELSE);
                            pushLabel(COND_END);
                            Lelse = getElse();

                            fprintf(jasmFile, "\t\tifeq L%d\n", Lelse);
                        }
                        opt_decs_stmts 
                        {
                            popTab();
                        }
                        opt_else END IF
                        {
                            // Code gen
                            popLabel(2);
                            // Ltemp = getLTemp();
                            // if (Ltop != -1) { // there is still another label from outer scope
                            //     fprintf(jasmFile, "\t\tgoto L%d\n", Ltemp);
                            // }
                        }
                        ;

opt_else:               ELSE
                        {
                            init();

                            // Code gen
                            Lelse = getElse();
                            Lendif = getEndIf();

                            fprintf(jasmFile, "\t\tgoto L%d\n", Lendif);
                            fprintf(jasmFile, "\tL%d:\n", Lelse);
                        }
                        opt_decs_stmts
                        {
                            popTab();
                            
                            // Code gen
                            Lendif = getEndIf();
                            fprintf(jasmFile, "\tL%d:\n", Lendif);

                        }
                        | /*No else*/
                        {

                            // Code gen
                            Lendif = getElse();
                            fprintf(jasmFile, "\tL%d:\n", Lendif);
                            
                        }
                        ;

loop:                   LOOP 
                        {
                            // Trace("\nTRACE: Forever loop\n");
                            init();

                            // Code gen
                            pushLabel(LOOP_BEGIN);
                            pushLabel(LOOP_END);
                            Lbegin = getLoopBegin();
                            fprintf(jasmFile, "\tL%d:\n", Lbegin);
                        }
                        opt_decs_stmts
                        {
                            Lbegin = getLoopBegin();
                            Lexit = getLoopEnd();
                            fprintf(jasmFile, "\t\tgoto L%d\n", Lbegin);
                            fprintf(jasmFile, "\tL%d:\n", Lexit);
                        }
                        END LOOP
                        {
                            popTab();

                            // Code gen
                            popLabel(2); // begin and exit label

                            // if (Ltop != -1) { // there is still another label from outer scope
                            //     Ltemp = getLTemp();
                            //     fprintf(jasmFile, "\t\thellogoto L%d\n", Ltemp);
                                
                            // }
                            
                        }
                        | FOR DECREASING 
                        {
                            // Trace("\nTRACE: Decreasing loop\n");
                            init();
                        }
                        ID
                        {
                            Symbol* symPtr = (Symbol*) malloc (sizeof(Symbol));
                            strcpy(symPtr->idName, $4);
                            symPtr->type = TYPE_INT;
                            symPtr->category = TYPE_VAR;
                            
                            int index = insert(symPtr);
                        }
                        ':' const_exp 
                        {
                            hold = stack[tabTop]->idxCounter++;
                            fprintf(jasmFile, "\t\tistore %d\n", hold);

                            pushLabel(LOOP_BEGIN);
                            pushLabel(LOOP_END);
                            Lbegin = getLoopBegin();

                            fprintf(jasmFile, "\tL%d:\n", Lbegin);
                            fprintf(jasmFile, "\t\tiload %d\n", hold);
                        }
                        '.' '.' const_exp
                        {
                            if ($7.category != TYPE_CONST || $11.category != TYPE_CONST) {
                                yyerror("Iteration inside bracket not constant");
                            }
                            else if ($7.type != TYPE_INT || $11.type != TYPE_INT) {
                                yyerror("Iteration inside bracket not integer type");
                            }
                            else if ($7.ntValue.iValue < $11.ntValue.iValue) {
                                yyerror("Iterator not decreasing");
                            }

                            // Code gen
                            Lexit = getLoopEnd();
                            Lfirst = getLabel(); // 0
                            Lsecond = getLabel(); // 1
                            
                            fprintf(jasmFile, "\t\tiadd\n");
                            fprintf(jasmFile, "\t\tifgt L%d\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_0\n");
                            fprintf(jasmFile, "\t\tgoto L%d\n", Lsecond);
                            fprintf(jasmFile, "\tL%d:\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_1\n");
                            fprintf(jasmFile, "\tL%d:\n", Lsecond);
                            fprintf(jasmFile, "\t\tifne L%d\n", Lexit);
                            fprintf(jasmFile, "\t\tiload %d\n", hold);
                            fprintf(jasmFile, "\t\tsipush 1\n");
                            fprintf(jasmFile, "\t\tisub\n");
                            fprintf(jasmFile, "\t\tistore %d\n", hold);
                        }
                        opt_decs_stmts END FOR
                        {
                            popTab();

                            // Code gen          
                            Lbegin = getLoopBegin();
                            Lexit = getLoopEnd();                  
                            fprintf(jasmFile, "\t\tgoto L%d\n", Lbegin);
                            fprintf(jasmFile, "\tL%d:\n", Lexit);
                        }
                        | FOR
                        {
                            // Trace("\nTRACE: Increasing loop\n");
                            init();
                        }
                        ID
                        {
                            Symbol* symPtr = (Symbol*) malloc (sizeof(Symbol));
                            strcpy(symPtr->idName, $3);
                            symPtr->type = TYPE_INT;
                            symPtr->category = TYPE_VAR;
                            
                            int index = insert(symPtr);
                        }
                        ':' const_exp
                        {
                            hold = stack[tabTop]->idxCounter++;
                            fprintf(jasmFile, "\t\tistore %d\n", hold);

                            pushLabel(LOOP_BEGIN);
                            pushLabel(LOOP_END);
                            Lbegin = getLoopBegin();

                            fprintf(jasmFile, "\tL%d:\n", Lbegin);
                            fprintf(jasmFile, "\t\tiload %d\n", hold);
                        }
                        '.' '.' const_exp 
                        {
                            if ($6.category != TYPE_CONST || $10.category != TYPE_CONST) {
                                yyerror("Iteration inside bracket not constant");
                            }
                            else if ($6.type != TYPE_INT || $10.type != TYPE_INT) {
                                yyerror("Iteration inside bracket not integer type");
                            }
                            else if ($6.ntValue.iValue > $10.ntValue.iValue) {
                                yyerror("Iterator not increasing");
                            }

                            // Code gen
                            Lexit = getLoopEnd();
                            Lfirst = getLabel(); // 0
                            Lsecond = getLabel(); // 1
                            
                            fprintf(jasmFile, "\t\tisub\n");
                            fprintf(jasmFile, "\t\tifgt L%d\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_0\n");
                            fprintf(jasmFile, "\t\tgoto L%d\n", Lsecond);
                            fprintf(jasmFile, "\tL%d:\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_1\n");
                            fprintf(jasmFile, "\tL%d:\n", Lsecond);
                            fprintf(jasmFile, "\t\tifne L%d\n", Lexit);
                            fprintf(jasmFile, "\t\tiload %d\n", hold);
                            fprintf(jasmFile, "\t\tsipush 1\n");
                            fprintf(jasmFile, "\t\tiadd\n");
                            fprintf(jasmFile, "\t\tistore %d\n", hold);
                        }
                        opt_decs_stmts END FOR
                        {   
                            
                            popTab();

                            // Code gen          
                            Lbegin = getLoopBegin();
                            Lexit = getLoopEnd();                  
                            fprintf(jasmFile, "\t\tgoto L%d\n", Lbegin);
                            fprintf(jasmFile, "\tL%d:\n", Lexit);
                        }
                        ;

func_invoc:             ID '(' opt_actual_arg ')'
                        {
                            // Trace("\nTRACE: Function invocation\n");
                            /* Repeatedly look for symbols in current and before tables */
                            int foundInTab = -1;
                            int index;
                            int isFunc = 0;
                            int args;

                            for (int i = tabTop; i >= 0; i--) { 
                                index = lookup($1, stack[i]);
                                if (index != -1) {  // Found
                                    foundInTab = i;      // Found in this table
                                    if (stack[foundInTab]->table[index]->category == TYPE_FUNC) isFunc = 1;
                                    args = stack[foundInTab]->table[index]->argCount;
                                    break;
                                }
                            }

                            if (foundInTab == -1) yyerror("Undeclared identifier");
                            else {
                                $$.type = stack[foundInTab]->table[index]->type;
                                $$.category = TYPE_VAR;
                            }
                            
                            // Code gen
                            if (isFunc) fprintf(jasmFile, "\t\tinvokestatic int %s.%s(", filename, $1);
                            else if (!isFunc) fprintf(jasmFile, "\t\tinvokestatic void %s.%s(", filename, $1);
                            
                            for (int i = 0; i < args ; i++){
                                if (i != args - 1) fprintf(jasmFile, "int, ");
                                else fprintf(jasmFile, "int)\n");
                            }
                        }
                        ;

opt_actual_arg:         expression_list
                        | /* No actual arguments */
                        ;

expression_list:        expression ',' expression_list
                        | expression
                        {
                            $$.type = $1.type;
                            $$.category = $1.category;
                        }
                        ;

array_ref:              ID '[' expression ']'
                        {
                            // Trace("\nTRACE: Array reference\n");
                            /* Repeatedly look for symbols in current and before tables */
                            int foundInTab = -1;
                            int index;

                            for (int i = tabTop; i >= 0; i--) { 
                                index = lookup($1, stack[i]);
                                if (index != -1) {       // Found
                                    foundInTab = i;      // Found in this table
                                    break;
                                }
                            }

                            if (foundInTab == -1) yyerror("Undeclared identifier");
                            else if ($3.type != TYPE_INT) yyerror("Array reference not integer type");
                            else if ($3.category != TYPE_CONST) yyerror("Array reference not constant");
                            else {
                                $$.type = stack[foundInTab]->table[index]->type;
                                $$.category = stack[foundInTab]->table[index]->category;
                            }
                        };

expression:             expression '+' expression
                        {
                            // Trace("\nTRACE: E+E\n");
                            if ($1.type == TYPE_STRING || $3.type == TYPE_STRING || $1.type == TYPE_BOOL || $3.type == TYPE_BOOL) {
                                yyerror("Addition not supported for this type");
                            }

                            else if ($1.category == TYPE_CONST && $3.category == TYPE_CONST) {
                                $$.category = TYPE_CONST;
                                if ($1.type == TYPE_INT && $3.type == TYPE_INT) {
                                    $$.type == TYPE_INT;
                                    $$.ntValue.iValue = $1.ntValue.iValue + $3.ntValue.iValue;
                                }
                                else if ($1.type == TYPE_REAL && $3.type == TYPE_INT) {
                                    $$.type == TYPE_REAL;
                                    $$.ntValue.fValue = $1.ntValue.fValue + $3.ntValue.iValue;
                                }
                                else if ($1.type == TYPE_INT && $3.type == TYPE_REAL){
                                    $$.type == TYPE_REAL;
                                    $$.ntValue.fValue = $1.ntValue.iValue + $3.ntValue.fValue;
                                }
                                else {
                                    $$.type == TYPE_REAL;
                                    $$.ntValue.fValue = $1.ntValue.fValue + $3.ntValue.fValue;
                                }
                            }

                            else $$.category = TYPE_VAR;

                            // Code gen
                            if ($1.type == TYPE_INT && $3.type == TYPE_INT) fprintf(jasmFile, "\t\tiadd\n");
                        }
                        | expression '-' expression
                        {
                            // Trace("\nTRACE: E-E\n");
                            if ($1.type == TYPE_STRING || $3.type == TYPE_STRING || $1.type == TYPE_BOOL || $3.type == TYPE_BOOL) {
                                yyerror("Substraction not supported for this type");
                            }

                            else if ($1.category == TYPE_CONST && $3.category == TYPE_CONST) {
                                $$.category = TYPE_CONST;
                                if ($1.type == TYPE_INT && $3.type == TYPE_INT) {
                                    $$.type == TYPE_INT;
                                    $$.ntValue.iValue = $1.ntValue.iValue - $3.ntValue.iValue;
                                }
                                else if ($1.type == TYPE_REAL && $3.type == TYPE_INT) {
                                    $$.type == TYPE_REAL;
                                    $$.ntValue.fValue = $1.ntValue.fValue - $3.ntValue.iValue;
                                }
                                else if ($1.type == TYPE_INT && $3.type == TYPE_REAL){
                                    $$.type == TYPE_REAL;
                                    $$.ntValue.fValue = $1.ntValue.iValue - $3.ntValue.fValue;
                                }
                                else {
                                    $$.type == TYPE_REAL;
                                    $$.ntValue.fValue = $1.ntValue.fValue - $3.ntValue.fValue;
                                }
                            }

                            else $$.category = TYPE_VAR;

                            // Code gen
                            if ($1.type == TYPE_INT && $3.type == TYPE_INT) fprintf(jasmFile, "\t\tisub\n");
                        }
                        | expression '*' expression
                        {
                            // Trace("\nTRACE: E*E\n");
                            if ($1.type == TYPE_STRING || $3.type == TYPE_STRING || $1.type == TYPE_BOOL || $3.type == TYPE_BOOL) {
                                yyerror("Multiplication not supported for this type");
                            }

                            else if ($1.category == TYPE_CONST && $3.category == TYPE_CONST) {
                                $$.category = TYPE_CONST;
                                if ($1.type == TYPE_INT && $3.type == TYPE_INT) {
                                    $$.type == TYPE_INT;
                                    $$.ntValue.iValue = $1.ntValue.iValue * $3.ntValue.iValue;
                                }
                                else if ($1.type == TYPE_REAL && $3.type == TYPE_INT) {
                                    $$.type == TYPE_REAL;
                                    $$.ntValue.fValue = $1.ntValue.fValue * $3.ntValue.iValue;
                                }
                                else if ($1.type == TYPE_INT && $3.type == TYPE_REAL){
                                    $$.type == TYPE_REAL;
                                    $$.ntValue.fValue = $1.ntValue.iValue * $3.ntValue.fValue;
                                }
                                else {
                                    $$.type == TYPE_REAL;
                                    $$.ntValue.fValue = $1.ntValue.fValue * $3.ntValue.fValue;
                                }
                            }

                            else $$.category = TYPE_VAR;

                            // Code gen
                            if ($1.type == TYPE_INT && $3.type == TYPE_INT) fprintf(jasmFile, "\t\timul\n");
                        }
                        | expression '/' expression
                        {
                            // Trace("\nTRACE: E/E\n");
                            if ($1.type == TYPE_STRING || $3.type == TYPE_STRING || $1.type == TYPE_BOOL || $3.type == TYPE_BOOL) {
                                yyerror("Division not supported for this type");
                            }

                            else if ($1.category == TYPE_CONST && $3.category == TYPE_CONST) {
                                    $$.category = TYPE_CONST;
                                    if ($1.type == TYPE_INT && $3.type == TYPE_INT) {
                                        $$.type == TYPE_INT;
                                        $$.ntValue.iValue = $1.ntValue.iValue / $3.ntValue.iValue;
                                    }
                                    else if ($1.type == TYPE_REAL && $3.type == TYPE_INT) {
                                        $$.type == TYPE_REAL;
                                        $$.ntValue.fValue = $1.ntValue.fValue / $3.ntValue.iValue;
                                    }
                                    else if ($1.type == TYPE_INT && $3.type == TYPE_REAL) {
                                        $$.type == TYPE_REAL;
                                        $$.ntValue.fValue = $1.ntValue.iValue / $3.ntValue.fValue;
                                    }
                                    else {
                                        $$.type == TYPE_REAL;
                                        $$.ntValue.fValue = $1.ntValue.fValue / $3.ntValue.fValue;
                                    }
                            }

                            else $$.category = TYPE_VAR;

                            // Code gen
                            if ($1.type == TYPE_INT && $3.type == TYPE_INT) fprintf(jasmFile, "\t\tidiv\n");

                        }
                        | expression MOD expression
                        {
                            // Trace("\nTRACE: EmodE\n");
                            if ($1.type == TYPE_STRING || $3.type == TYPE_STRING || $1.type == TYPE_BOOL || $3.type == TYPE_BOOL) {
                                yyerror("Modulus not supported for this type");
                            }

                            else if ($1.category == TYPE_CONST && $3.category == TYPE_CONST) {
                                // Only handle integer mod
                                $$.category = TYPE_CONST;
                                $$.type == TYPE_INT;
                                $$.ntValue.iValue = $1.ntValue.iValue % $3.ntValue.iValue;
                            }

                            else $$.category = TYPE_VAR;

                            // Code gen
                            if ($1.type == TYPE_INT && $3.type == TYPE_INT) fprintf(jasmFile, "\t\tirem\n");

                        }
                        | '-' expression %prec UMINUS
                        {
                            // Trace("\nTRACE: -E\n");
                            if ($2.type == TYPE_STRING || $2.type == TYPE_BOOL) {
                                yyerror("Unary minus not supported for this type");
                            }
                            else {
                                if ($2.type == TYPE_INT) $$.type = TYPE_INT;
                                else if ($2.type == TYPE_REAL) $$.type = TYPE_REAL;

                                if ($2.category == TYPE_CONST) {
                                    $$.category = TYPE_CONST;
                                    if ($2.type == TYPE_INT) $$.ntValue.iValue = -($2.ntValue.iValue);
                                    else $$.ntValue.fValue = -($2.ntValue.fValue);
                                }
                                else $$.category = TYPE_VAR;
                            }
                            // Code gen
                            if ($2.type == TYPE_INT) fprintf(jasmFile, "\t\tineg\n");
                        }
                        | expression OR expression
                        {
                            // Trace("\nTRACE: E OR E\n");
                            if ($1.type != $3.type) yyerror("Type not match");
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_VAR;

                            // Code gen
                            fprintf(jasmFile, "\t\tior\n");
                        }
                        | expression AND expression
                        {
                            // Trace("\nTRACE: E AND E\n");
                            if ($1.type != $3.type) yyerror("Type not match");
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_VAR;

                            // Code gen
                            fprintf(jasmFile, "\t\tiand\n");
                        }
                        | NOT expression
                        {
                            // Trace("\nTRACE: NOT E\n");
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_VAR;

                            // Code gen
                            fprintf(jasmFile, "\t\tsipush 1\n");
                            fprintf(jasmFile, "\t\tior\n");
                        }
                        | expression '<' expression
                        {
                            // Trace("\nTRACE: E comparison_op E\n");
                            if ($1.type != $3.type) yyerror("Type not match");
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_VAR;

                            // Code gen
                            Lfirst = getLabel(); // 0
                            Lsecond = getLabel(); // 1

                            fprintf(jasmFile, "\t\tisub\n");
                            fprintf(jasmFile, "\t\tiflt L%d\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_0\n");
                            fprintf(jasmFile, "\t\tgoto L%d\n", Lsecond);
                            fprintf(jasmFile, "\tL%d:\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_1\n");
                            fprintf(jasmFile, "\tL%d:\n", Lsecond);
                        }
                        | expression '>' expression
                        {
                            // Trace("\nTRACE: E comparison_op E\n");
                            if ($1.type != $3.type) yyerror("Type not match");
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_VAR;

                            // Code gen
                            Lfirst = getLabel(); // 0
                            Lsecond = getLabel(); // 1

                            fprintf(jasmFile, "\t\tisub\n");
                            fprintf(jasmFile, "\t\tifgt L%d\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_0\n");
                            fprintf(jasmFile, "\t\tgoto L%d\n", Lsecond);
                            fprintf(jasmFile, "\tL%d:\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_1\n");
                            fprintf(jasmFile, "\tL%d:\n", Lsecond);
                        }
                        | expression '=' expression
                        {
                            // Trace("\nTRACE: E comparison_op E\n");
                            if ($1.type != $3.type) yyerror("Type not match");
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_VAR;

                            // Code gen
                            Lfirst = getLabel(); // 0
                            Lsecond = getLabel(); // 1

                            fprintf(jasmFile, "\t\tisub\n");
                            fprintf(jasmFile, "\t\tifeq L%d\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_0\n");
                            fprintf(jasmFile, "\t\tgoto L%d\n", Lsecond);
                            fprintf(jasmFile, "\tL%d:\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_1\n");
                            fprintf(jasmFile, "\tL%d:\n", Lsecond);
                        }
                        | expression LEQUAL expression
                        {
                            // Trace("\nTRACE: E comparison_op E\n");
                            if ($1.type != $3.type) yyerror("Type not match");
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_VAR;

                            // Code gen
                            Lfirst = getLabel(); // 0
                            Lsecond = getLabel(); // 1

                            fprintf(jasmFile, "\t\tisub\n");
                            fprintf(jasmFile, "\t\tifle L%d\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_0\n");
                            fprintf(jasmFile, "\t\tgoto L%d\n", Lsecond);
                            fprintf(jasmFile, "\tL%d:\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_1\n");
                            fprintf(jasmFile, "\tL%d:\n", Lsecond);
                        }
                        | expression GEQUAL expression
                        {
                            // Trace("\nTRACE: E comparison_op E\n");
                            if ($1.type != $3.type) yyerror("Type not match");
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_VAR;
                            
                            // Code gen
                            Lfirst = getLabel(); // 0
                            Lsecond = getLabel(); // 1

                            fprintf(jasmFile, "\t\tisub\n");
                            fprintf(jasmFile, "\t\tifge L%d\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_0\n");
                            fprintf(jasmFile, "\t\tgoto L%d\n", Lsecond);
                            fprintf(jasmFile, "\tL%d:\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_1\n");
                            fprintf(jasmFile, "\tL%d:\n", Lsecond);
                        }
                        | expression NOTEQUAL expression
                        {
                            // Trace("\nTRACE: E comparison_op E\n");
                            if ($1.type != $3.type) yyerror("Type not match");
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_VAR;

                            // Code gen
                            Lfirst = getLabel(); // 0
                            Lsecond = getLabel(); // 1

                            fprintf(jasmFile, "\t\tisub\n");
                            fprintf(jasmFile, "\t\tifne L%d\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_0\n");
                            fprintf(jasmFile, "\t\tgoto L%d\n", Lsecond);
                            fprintf(jasmFile, "\tL%d:\n", Lfirst);
                            fprintf(jasmFile, "\t\ticonst_1\n");
                            fprintf(jasmFile, "\tL%d:\n", Lsecond);
                        }
                        | func_invoc
                        | array_ref
                        | '(' expression ')'
                        {
                            // Trace("\nTRACE: (E)\n");
                            $$ = $2;
                        }
                        | literal_const
                        {
                            $$.category = TYPE_CONST;
                            if ($1.type == TYPE_INT) {
                                $$.ntValue.iValue = $1.ntValue.iValue;
                                $$.type = TYPE_INT;
                                if (tabTop != 0) fprintf(jasmFile, "\t\tsipush %d\n", $1.ntValue.iValue);
                            }
                            else if ($1.type == TYPE_REAL) {
                                $$.ntValue.fValue = $1.ntValue.fValue;
                                $$.type = TYPE_REAL;
                            }
                            else if ($1.type == TYPE_BOOL) {
                                $$.ntValue.bValue = $1.ntValue.bValue;
                                $$.type = TYPE_BOOL;
                                if (tabTop != 0) fprintf(jasmFile, "\t\ticonst_%d\n", $1.ntValue.bValue);
                            }
                            else if ($1.type == TYPE_STRING) {
                                strcpy($$.ntValue.sValue, $1.ntValue.sValue);
                                $$.type = TYPE_STRING;
                                if (tabTop != 0) fprintf(jasmFile, "\t\tldc \"%s\"\n", $1.ntValue.sValue);
                            }

                        }
                        | ID
                        {
                            // Trace("\nTRACE: ID expression\n");
                            /* Repeatedly look for symbols in current and before tables */
                            int foundInTab = -1;
                            int index;

                            for (int i = tabTop; i >= 0; i--) { 
                                index = lookup($1, stack[i]);
                                if (index != -1) {  // Found
                                    foundInTab = i;      // Found in this table
                                    break;
                                }
                            }

                            if (foundInTab == -1) yyerror("Undeclared identifier");
                            else {

                                $$.category = stack[foundInTab]->table[index]->category;
                                if (stack[foundInTab]->table[index]->type == TYPE_INT) {
                                    $$.type = TYPE_INT;
                                    $$.ntValue.iValue = stack[foundInTab]->table[index]->symbolVal.iValue;
                                }
                                else if (stack[foundInTab]->table[index]->type == TYPE_REAL) {
                                    $$.type = TYPE_REAL;
                                    $$.ntValue.fValue = stack[foundInTab]->table[index]->symbolVal.fValue;
                                }
                                else if (stack[foundInTab]->table[index]->type == TYPE_BOOL) {
                                    $$.type = TYPE_BOOL;
                                    $$.ntValue.bValue = stack[foundInTab]->table[index]->symbolVal.bValue;
                                }
                                else {
                                    $$.type = TYPE_STRING;
                                    strcpy($$.ntValue.sValue, stack[foundInTab]->table[index]->symbolVal.sValue);
                                }

                                // Code gen
                                if  ($$.category == TYPE_CONST) { // global and local constant
                                    if ($$.type == TYPE_STRING) fprintf(jasmFile, "\t\tldc \"%s\"\n", $$.ntValue.sValue);
                                    else if ($$.type = TYPE_INT) fprintf(jasmFile, "\t\tsipush %d\n", $$.ntValue.iValue);
                                    else if ($$.type == TYPE_BOOL) fprintf(jasmFile, "\t\ticonst_%d\n", $$.ntValue.bValue);
                                }
                                else if (foundInTab == 0 && $$.category == TYPE_VAR) { // global variable, only consider int
                                    fprintf(jasmFile, "\t\tgetstatic int %s.%s\n", filename, $1);
                                }
                                else { // local variable
                                    fprintf(jasmFile, "\t\tiload %d\n", stack[foundInTab]->table[index]->indexLoc);
                                }
                            }
                            
                        }
                        ;
%%

void yyerror(char *msg) {
    fprintf(stderr, "%s\n", msg);
}

int main(int argc, char *argv[]) {

    /* ./codegen example.st */
    yyin = fopen(argv[1], "r");

    /* Extract file name */
    strcpy(filename, strtok(argv[1], ".")); // example

    strcpy(ext, filename);
    strcat(ext, ".jasm");

    jasmFile = fopen(ext, "w");

    init();
    initLhandler();
    yyparse();
    dump(stack[tabTop]);
    stack[tabTop--] = NULL;

    fclose(jasmFile);
    return 0;
}