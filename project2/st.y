%{
#include "symboltable.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#define Trace(t)        printf(t)

void yyerror(char *msg);
int yylex();
%}

 /* Yacc declarations */

%union {
    char idName[256];           // id name NOT value
    int iVal;                   // int value
    float fVal;                 // float value
    int bVal;                   // bool value: true | false
    char sVal[256];             // string value
    int t;                      // type
    struct info i;              // for non-terminal use
}

 /* Delimiters and operators */
%token MOD ASSIGN LEQUAL GEQUAL AND OR NOT NOTEQUAL

 /* Keywords */
%token ARRAY ST_BEGIN BOOL CHAR CONST DECREASING DEFAULT DO ELSE END EXIT FALSE FOR FUNCTION GET IF INT LOOP OF PUT PROCEDURE REAL RESULT RETURN SKIP STRING THEN TRUE VAR WHEN

%token <idName> ID
%token <iVal> INTVAL
%token <fVal> REALVAL
%token <bVal> BOOLVAL
%token <sVal> STRINGVAL

 /* Semantic def for non terminals types */
%type <t> type_dec
%type <i> literal_const const_exp bool_exp expression opt_actual_arg expression_list func_invoc array_ref

 /* Associativity and precedence */
%left OR
%left AND
%left NOT
%left '<' LEQUAL '>' GEQUAL '=' NOTEQUAL
%left '+' '-'
%left '*' '/' MOD
%nonassoc UMINUS

%%

program:                opt_decs opt_stmts { Trace("\nTRACE: program\n"); };

 /* zero or more variable, constant, or function declarations */
opt_decs:               dec opt_decs
                        | /* No declaration */
                        ;

 /* Declaration part */
dec:                    var_dec | const_dec | func_dec;

 /* zero or more statements */
opt_stmts:              stmt opt_stmts
                        | /* No statements */
                        ;

 /* Statement part */
stmt:                   block | simple | conditional | loop | func_invoc;

 /* zero or more variable, or constant declarations and statements, NO function declaration */
opt_decs_stmts:         var_dec opt_decs_stmts
                        | const_dec opt_decs_stmts
                        | stmt opt_decs_stmts
                        | /* No declaration nor statement */
                        ;

 /* Literal constant */
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

 /* Constant Declaration */
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
                                symPtr->hasValue = 1;
                                
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
                                symPtr->hasValue = 1;
                                
                                if ($4.type == TYPE_INT) symPtr->symbolVal.iValue = $4.ntValue.iValue;
                                else if ($4.type == TYPE_REAL) symPtr->symbolVal.fValue = $4.ntValue.fValue;
                                else if ($4.type == TYPE_BOOL) symPtr->symbolVal.bValue = $4.ntValue.bValue;
                                else if ($4.type == TYPE_STRING) strcpy(symPtr->symbolVal.sValue, $4.ntValue.sValue);
                                
                                int index = insert(symPtr);
                            }
                        }
                        ;

 /* Variable declaration */
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
                                symPtr->hasValue = 1;
                                
                                int index = insert(symPtr);
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
                                symPtr->hasValue = 1;
                                
                                int index = insert(symPtr);
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
                                symPtr->hasValue = 0;
                                
                                int index = insert(symPtr);
                            }
                        }
                        | array_dec
                        ;

const_exp:              expression;

 /* Array declaration, var identifier : array num .. num of type */
array_dec:              VAR ID ':' ARRAY INTVAL '.' '.' INTVAL OF type_dec
                        {
                            // Trace("\nTRACE: Array declaration\n");

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
                        '(' opt_formal_arg ')' ':' type_dec opt_decs_stmts END ID
                        {
                            if (strcmp($2, $11) != 0) yyerror("Function name not match");
                            else {
                                int index = lookup($2, stack[tabTop - 1]);  /* Function index, because function name is not store in new scope, tabTop-1*/
                                stack[tabTop - 1]->table[index]->type = $8; /* Store function return type */
                            }

                            popTab();
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
                        '(' opt_formal_arg ')' opt_decs_stmts END ID
                        {
                            if (strcmp($2, $9) != 0) yyerror("Function name not match");
                            else {
                                int index = lookup($2, stack[tabTop]);
                                stack[tabTop - 1]->table[index]->type = NO_TYPE;
                            }

                            popTab();
                        }
                        ;

 /* zero or more formal arguments separated by comma */
opt_formal_arg:         arg_list
                        | /* No arguments */
                        ;

arg_list:               arg_dec ',' arg_list
                        | arg_dec
                        ;

arg_dec:                ID ':' type_dec
                        {
                            int index = lookup($1, stack[tabTop]);
                            if (index != -1 && stack[tabTop]->table[index]->category == TYPE_FOR_ARG) {
                                yyerror("Formal argument redefinition");
                            }
                            else {
                                Symbol* symPtr = (Symbol*) malloc (sizeof(Symbol));
                                strcpy(symPtr->idName, $1);
                                symPtr->type = $3;
                                symPtr->category = TYPE_FOR_ARG;
                                
                                int index = insert(symPtr);
                            }
                        }
                        ;

 /* Statements, Invocations, and Expressions part */

 /* Block statement */
 block:                 ST_BEGIN
                        {
                            init();
                        }
                        opt_decs_stmts END
                        {
                            popTab();
                        }
                        ;

 /* Simple statement */
 simple:                ID ASSIGN expression
                        {
                            // Trace("\nTRACE: id := expression\n");
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
                            else if (stack[foundInTab]->table[index]->category == TYPE_CONST) {
                                yyerror("Cannot assign new value to constant");
                            }
                        }
                        | PUT expression            { /* Trace("\nTRACE: Put expression\n");*/ }
                        | GET ID                    { /* Trace("\nTRACE: Get expression\n");*/ }
                        | RESULT expression         { /* Trace("\nTRACE: Result expression\n");*/ }
                        | RETURN                    { /* Trace("\nTRACE: Return\n"); */ }
                        | EXIT opt_exit_condition   { /* Trace("\nTRACE: Exit\n");*/ }
                        | SKIP                      { /* Trace("\nTRACE: Skip\n"); */ }
                        ;

opt_exit_condition:     WHEN bool_exp { if ($2.type != TYPE_BOOL) yyerror("Exit condition not boolean type"); }
                        | /* No exit condition */
                        ;

bool_exp:               expression;

 /* Conditional statement */
conditional:            IF bool_exp THEN
                        {
                            // Trace("\nTRACE: Conditional statement with else\n");

                            if ($2.type != TYPE_BOOL) yyerror("Condition inside bracket not boolean type");
                            init();
                        }
                        opt_decs_stmts 
                        {
                            popTab();
                        }
                        ELSE
                        {
                            init();
                        }
                        opt_decs_stmts END IF
                        {
                            popTab();
                        }
                        | IF bool_exp THEN
                        {
                            // Trace("\nTRACE: Conditional statement w/o else\n");

                            if ($2.type != TYPE_BOOL) yyerror("Condition inside bracket not boolean type");
                            init();
                        }
                        opt_decs_stmts END IF
                        {
                            popTab();
                        }
                        ;

 /* Loop statement */
loop:                   LOOP 
                        {
                            // Trace("\nTRACE: Forever loop\n");
                            init();
                        }
                        opt_decs_stmts END LOOP
                        {
                            popTab();
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
                        ':' const_exp '.' '.' const_exp opt_decs_stmts END FOR
                        {
                            if ($7.category != TYPE_CONST || $10.category != TYPE_CONST) {
                                yyerror("Iteration inside bracket not constant");
                            }
                            else if ($7.type != TYPE_INT || $10.type != TYPE_INT) {
                                yyerror("Iteration inside bracket not integer type");
                            }
                            else if ($7.ntValue.iValue < $10.ntValue.iValue) {
                                yyerror("Iterator not decreasing");
                            }
                            popTab();
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
                        ':' const_exp '.' '.' const_exp opt_decs_stmts END FOR
                        {   
                            if ($6.category != TYPE_CONST || $9.category != TYPE_CONST) {
                                yyerror("Iteration inside bracket not constant");
                            }
                            else if ($6.type != TYPE_INT || $9.type != TYPE_INT) {
                                yyerror("Iteration inside bracket not integer type");
                            }
                            else if ($6.ntValue.iValue > $9.ntValue.iValue) {
                                yyerror("Iterator not increasing");
                            }
                            popTab();
                        }
                        ;

 /* Function invocation statement */
func_invoc:             ID '(' opt_actual_arg ')'
                        {
                            // Trace("\nTRACE: Function invocation\n");
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
                                $$.type = stack[foundInTab]->table[index]->type;
                                $$.category = TYPE_VAR;
                            }
                        }
                        ;

 /* Zero or more actual arguments */
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

 /* Array reference, A[integer_expression] */
array_ref:              ID '[' expression ']'
                        {
                            // Trace("\nTRACE: Array reference\n");
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
                            else if ($3.type != TYPE_INT) yyerror("Array reference not integer type");
                            else if ($3.category != TYPE_CONST) yyerror("Array reference not constant");
                            else {
                                $$.type = stack[foundInTab]->table[index]->type;
                                $$.category = stack[foundInTab]->table[index]->category;
                            }
                        };

 /* Valid components of expressions */
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

                            else {
                                $$.category = TYPE_VAR;
                                // value must be store into memory?
                            }
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

                            else {
                                $$.category = TYPE_VAR;
                                // value must be store into memory?
                            }
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

                            else {
                                $$.category = TYPE_VAR;
                                // value must be store into memory?
                            }
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

                        }
                        | '-' expression %prec UMINUS
                        {
                            // Trace("\nTRACE: -E\n");
                            if ($2.type == TYPE_STRING || $2.type == TYPE_BOOL) {
                                yyerror("Unary minus not supported for this type");
                            }

                            else if ($2.category == TYPE_CONST) {
                                $$.category = TYPE_CONST;
                                
                                if ($2.type == TYPE_INT) {
                                    $$.type == TYPE_INT;
                                    $$.ntValue.iValue = -($2.ntValue.iValue);
                                }
                                else {
                                    $$.type == TYPE_REAL;
                                    $$.ntValue.fValue = -($2.ntValue.fValue);
                                }
                            }

                            else $$.category = TYPE_VAR;

                        }
                        | expression OR expression
                        {
                            // Trace("\nTRACE: E OR E\n");
                            if ($1.type != $3.type) yyerror("Type not match");
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_VAR;
                        }
                        | expression AND expression
                        {
                            // Trace("\nTRACE: E AND E\n");
                            if ($1.type != $3.type) yyerror("Type not match");
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_VAR;
                        }
                        | NOT expression
                        {
                            // Trace("\nTRACE: NOT E\n");
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_VAR;
                        }
                        | expression comparison_op expression
                        {
                            // Trace("\nTRACE: E comparison_op E\n");
                            if ($1.type != $3.type) yyerror("Type not match");
                            $$.type = TYPE_BOOL;
                            $$.category = TYPE_VAR;
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
                            }
                            else if ($1.type == TYPE_REAL) {
                                $$.ntValue.fValue = $1.ntValue.fValue;
                                $$.type = TYPE_REAL;
                            }
                            else if ($1.type == TYPE_BOOL) {
                                $$.ntValue.bValue = $1.ntValue.bValue;
                                $$.type = TYPE_BOOL;
                            }
                            else if ($1.type == TYPE_STRING) {
                                strcpy($$.ntValue.sValue, $1.ntValue.sValue);
                                $$.type = TYPE_STRING;
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
                            }
                            
                        }
                        ;

comparison_op:          '<' | '>' | '='| LEQUAL | GEQUAL | NOTEQUAL;
%%

void yyerror(char *msg) {
    fprintf(stderr, "%s\n", msg);
}

int main() {
    init();
    yyparse();
    dump(stack[tabTop]);
    stack[tabTop--] = NULL;
}