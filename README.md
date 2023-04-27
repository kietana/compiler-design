# About Project 1
Write a lex program to recognize simple turing language tokens

# Build With
1. Lex
2. C

# Prerequisites
1. Install lex
3. Install gcc

# Running environment
1. Cygwin
2. Unix server, login `ssh -p 4091 B10915011@140.118.155.192`
3. Or any linux environment

# Files
---
1. `lex.l` file contains the regular expression and C code to recognize the token  
2. `SymbolTable.h` is a header file for symbol table and contains the function definitions of symbol table  
3. `example.st`,  `fib.st`, `HelloWorld.st` and `sigma.st` are test files  

# Build
---
To build, run this command:  
`make`  
or, build manually:
```
lex lex.l
gcc -o scanner -O lex.yy.c -ll
```

# Usage
Set example.st file as stdin  
`./scanner < example.st`  
Output should be:
```
1: {%
2:  % Example with Functions
3:  %}
4:
5: % global variables
<CONST>
<IDENTIFIER:a>
<':'>
<INT>
<':='>
<INTEGER:5>
6: const a: int := 5
<VAR>
<IDENTIFIER:c>
<':'>
<INT>
7: var c: int
8:
9: % function declaration
<FUNCTION>
<IDENTIFIER:add>
<'('>
<IDENTIFIER:a>
<':'>
<INT>
<','>
<IDENTIFIER:b>
<':'>
<INT>
<')'>
<':'>
<INT>
10: function add (a: int, b: int) : int
<RESULT>
<IDENTIFIER:a>
<'+'>
<IDENTIFIER:b>
11:   result a+b
<END>
<IDENTIFIER:add>
12: end add
13:
14: % main block
<IDENTIFIER:c>
<':='>
<IDENTIFIER:add>
<'('>
<IDENTIFIER:a>
<','>
<INTEGER:10>
<')'>
15: c := add(a, 10)
<IF>
<'('>
<IDENTIFIER:c>
<'>'>
<INTEGER:10>
<')'>
<THEN>
16: if (c > 10) then
<PUT>
<'-'>
<IDENTIFIER:c>
17:   put -c
<ELSE>
18: else
<PUT>
<IDENTIFIER:c>
19:   put c
<END>
<IF>
20: end if
<PUT>
<STRING:Hello World\n>
21: put "Hello World\n"
22:

Symbol Table:
40: add
97: a
98: b
99: c
```
