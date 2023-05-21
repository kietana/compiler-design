##################################################################
#
#	Makefile -- P Parser
#
##################################################################

all: parser

parser: y.tab.c lex.yy.c symboltable.c symboltable.h
	gcc -o parser y.tab.c lex.yy.c symboltable.c -ll 

lex.yy.c: st.l
	lex st.l

y.tab.c: st.y
	yacc -y -o y.tab.c -d st.y

clean:
	rm -f parser lex.yy.c *.o y.tab.c y.tab.h