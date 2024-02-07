##################################################################
#
#	Makefile -- P Code Generation
#
##################################################################

all: codegen

codegen: y.tab.c lex.yy.c symboltable.c symboltable.h label.c label.h
	gcc -o codegen y.tab.c lex.yy.c symboltable.c label.c -ll 

lex.yy.c: st.l
	lex st.l

y.tab.c: st.y
	yacc -y -o y.tab.c -d st.y

clean:
	rm -f codegen lex.yy.c *.o y.tab.c y.tab.h *.jasm *.class

run: codegen
	./codegen $(file).st
	./javaa $(file).jasm
	java $(file)