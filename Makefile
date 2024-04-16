LEX  = flex -I
YACC = bison -tdy -Wcounterexamples

CC   = gcc -DYYDEBUG=1

all:	y.tab.c lex.yy.c
	$(CC) -o hw y.tab.c lex.yy.c -ly -ll -lm


y.tab.c y.tab.h:	hw.y
	$(YACC) hw.y


lex.yy.c:	hw.l
	$(LEX) hw.l

clean:
	rm lex.yy.c
	rm y.tab.c
	rm y.tab.h
	rm hw
