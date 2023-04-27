%{
#include "SymbolTable.h"
#define LIST                strcat(buf,yytext)
#define token(t)            {LIST; printf("<%s>\n", #t);}
#define tokenInteger(t,i)   {LIST; printf("<%s:%d>\n", #t, i);}
#define tokenString(t,s)    {LIST; printf("<%s:%s>\n", #t, s);}

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
"."             { token('.'); }
","             { token(','); }
":"             { token(':'); }
";"             { token(';'); }
"("             { token('('); }
")"             { token(')'); }
"["             { token('['); }
"]"             { token(']'); }
"{"             { token('{'); }
"}"             { token('}'); }
 /* Arithmetic */
"+"             { token('+'); }
"-"             { token('-'); }
"*"             { token('*'); }
"/"             { token('/'); }
"mod"           { token(MOD); }
":="            { token(':='); }
 /* Relop */
"<"             { token('<'); }
"<="            { token('<='); }
">"             { token('>'); }
">="            { token('>='); }
"="             { token('='); }
"and"           { token(AND); }
"or"            { token(OR); }
"not"           { token(NOT); }
"not="          { token(NOT=); }
 /* Keywords */
"array"         { token(ARRAY); }
"begin"         { token(BEGIN); }
"bool"          { token(BOOL); }
"char"          { token(CHAR); }
"const"         { token(CONST); }
"decreasing"    { token(DECREASING); }
"default"       { token(DEFAULT); }
"do"            { token(DO); }
"else"          { token(ELSE); }
"end"           { token(END); }
"exit"          { token(EXIT); }
"false"         { token(FALSE); }
"for"           { token(FOR); }
"function"      { token(FUNCTION); }
"get"           { token(GET); }
"if"            { token(IF); }
"int"           { token(INT); }
"loop"          { token(LOOP); }
"of"            { token(OF); }
"put"           { token(PUT); }
"procedure"     { token(PROCEDURE); }
"real"          { token(REAL); }
"result"        { token(RESULT); }
"return"        { token(RETURN); }
"skip"          { token(SKIP); }
"string"        { token(STRING); }
"then"          { token(THEN); }
"true"          { token(TRUE); }
"var"           { token(VAR); }
"when"          { token(WHEN); }

{identifier}    {
                tokenString(IDENTIFIER, yytext);
                int index = insert(yytext);
                }

{integer}       { tokenInteger(INTEGER, atoi(yytext)); }

{real}          { tokenString(REAL, yytext); }

{string}        {
                for (int i = 1; i < yyleng - 1; i++) {
                    if (yytext[i] == '\"') {
                        i++;
                    }
                    char temp[2] = {yytext[i], '\0'};
                    strcat(str, temp);
                }
                tokenString(STRING, str);
                str[0] = '\0';
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

int main()
{
    create();
    yylex();
    printf("\nSymbol Table:\n");
    dump();
    return 0;
}