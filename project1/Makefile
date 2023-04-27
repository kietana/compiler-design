scanner: lex.yy.c
        gcc -o scanner -O lex.yy.c -ll

lex.yy.c: lex.l
        lex lex.l

clean:
        rm scanner lex.yy.c