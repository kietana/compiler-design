scanner: lex.yy.c SymbolTable.c SymbolTable.h
        gcc -o scanner -O lex.yy.c SymbolTable.c -ll

lex.yy.c: lex.l
        lex lex.l
clean:
        rm scanner lex.yy.c