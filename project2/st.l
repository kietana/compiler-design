%{
#include "union.h"
#include "y.tab.h"
#define LIST                strcat(buf,yytext)
#define token(t)            {LIST; printf("<%s>\n", #t); }
#define tokenInteger(t,i)   {LIST; printf("<%s:%d>\n", #t, i);}
#define tokenReal(t,r)      {LIST; printf("<%s:%f>\n", #t, r);}
#define tokenString(t,s)    {LIST; printf("<%s:%s>\n", #t, s);}
#define tokenChar(t)        {LIST; printf("<%c>\n", t); }
#define MAX_LINE_LENG 256

int linenum = 1;
char buf[MAX_LINE_LENG];
char str[MAX_LINE_LENG] = "";

%}

digit           [0-9]
integer         {digit}+
real            {digit}+\.{digit}+
letter          [a-zA-Z]
identifier      {letter}({letter}|{digit})*
string          \"([^"\n]|\"\")*\"

%x SINGLE_LINE_COMMENT MULTIPLE_LINE_COMMENT

%%
 /* Delimiters */
"."             { LIST; return '.'; }
","             { LIST; return ','; }
":"             { LIST; return ':'; }
";"             { LIST; return ';'; }
"("             { LIST; return '('; }
")"             { LIST; return ')'; }
"["             { LIST; return '['; }
"]"             { LIST; return ']'; }
"{"             { LIST; return '{'; }
"}"             { LIST; return '}'; }
 /* Arithmetic */
"+"             { LIST; return '+'; }
"-"             { LIST; return '-'; }
"*"             { LIST; return '*'; }
"/"             { LIST; return '/'; }
"mod"           { LIST; return MOD; }
":="            { LIST; return ASSIGN; }
 /* Relop */
"<"             { LIST; return '<'; }
"<="            { LIST; return LEQUAL; }
">"             { LIST; return '>'; }
">="            { LIST; return GEQUAL; }
"="             { LIST; return '='; }
"and"           { LIST; return AND; }
"or"            { LIST; return OR;}
"not"           { LIST; return NOT; }
"not="          { LIST; return NOTEQUAL; }
 /* Keywords */
"array"         { LIST; return ARRAY;}
"begin"         { LIST; return ST_BEGIN; }
"bool"          { LIST; return BOOL; }
"char"          { LIST; return CHAR; }
"const"         { LIST; return CONST; }
"decreasing"    { LIST; return DECREASING; }
"default"       { LIST; return DEFAULT; }
"do"            { LIST; return DO; }
"else"          { LIST; return ELSE; }
"end"           { LIST; return END; }
"exit"          { LIST; return EXIT; }
"for"           { LIST; return FOR; }
"function"      { LIST; return FUNCTION; }
"get"           { LIST; return GET; }
"if"            { LIST; return IF; }
"int"           { LIST; return INT; }
"loop"          { LIST; return LOOP; }
"of"            { LIST; return OF; }
"put"           { LIST; return PUT; }
"procedure"     { LIST; return PROCEDURE; }
"real"          { LIST; return REAL; }
"result"        { LIST; return RESULT; }
"return"        { LIST; return RETURN; }
"skip"          { LIST; return SKIP; }
"string"        { LIST; return STRING; }
"then"          { LIST; return THEN;}
"var"           { LIST; return VAR;}
"when"          { LIST; return WHEN; }
"true"          {
                LIST; 
                yylval.bVal = 1;
                return BOOLVAL;
                }
"false"         {
                LIST; 
                yylval.bVal = 0;
                return BOOLVAL;
                }

{identifier}    {
                LIST; 
                strcpy(yylval.idName, yytext);
                return ID;
                }

{integer}       {
                LIST; 
                yylval.iVal = atoi(yytext);
                return INTVAL;
                }

{real}          {
                LIST; 
                yylval.fVal = atof(yytext);
                return REALVAL;
                }

{string}        {
                for (int i = 1; i < yyleng - 1; i++) {
                    if (yytext[i] == '\"') {
                        i++;
                    }
                    char temp[2] = {yytext[i], '\0'};
                    strcat(str, temp);
                }
                LIST; 
                strcpy(yylval.sVal, str);
                str[0] = '\0';
                return STRINGVAL;
                }

 /* Start of single line comment */
^\%                         {
                            LIST;
                            BEGIN SINGLE_LINE_COMMENT;
                            }

 /* Content of single line comment */
<SINGLE_LINE_COMMENT>[^\n]  { LIST; }

 /* The end of single line comment */
<SINGLE_LINE_COMMENT>\n     {
                            LIST;
                            printf("%d: %s", linenum++, buf);
                            buf[0] = '\0';
                            BEGIN 0;
                            }

 /* Start of multiple line comment */
^(\{\%)                     {
                            LIST;
                            BEGIN MULTIPLE_LINE_COMMENT;
                            }

 /* Content of multiple line comment */
<MULTIPLE_LINE_COMMENT>.    { LIST; }

<MULTIPLE_LINE_COMMENT>\n   {
                            LIST;
                            printf("%d: %s", linenum++, buf);
                            buf[0] = '\0';
                            }

 /* The end of multiple line comment */
<MULTIPLE_LINE_COMMENT>"%}" {
                            LIST;
                            BEGIN 0;
                            }

\n      {
        LIST;
        printf("%d: %s", linenum++, buf);
        buf[0] = '\0';
        }

[ \t]*  { LIST; }

.       {
        LIST;
        printf("%d:%s\n", linenum+1, buf);
        printf("bad character:'%s'\n", yytext);
        exit(-1);
        }
%%