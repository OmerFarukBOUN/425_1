LEX  = flex -I
YACC = bison -dy

CC   = gcc -DYYDEBUG=1

hw:	y.tab.o lex.yy.o
	$(CC) -o hw y.tab.c lex.yy.c -ly -ll -lm 


lex.yy.o:	lex.yy.c y.tab.h


lex.yy.o y.tab.o:	hdr.h


y.tab.c y.tab.h:	hw.y 
			$(YACC) hw.y


lex.yy.c:		hw.l
			$(LEX) hw.l

