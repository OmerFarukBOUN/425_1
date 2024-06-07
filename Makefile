LEX  = flex -I
YACC = /opt/homebrew/opt/bison@3.8/bin/bison -td -Wcounterexamples

CC   = g++ -DYYDEBUG=1 -std=c++11

all:	build/y.tab.cpp build/y.tab.hpp build/lex.yy.cpp
	$(CC) -o build/hw build/y.tab.cpp build/lex.yy.cpp -ly -ll -lm


build/y.tab.cpp build/y.tab.hpp:	hw.y
	$(YACC) -o build/y.tab.cpp hw.y


build/lex.yy.cpp:	hw.l
	$(LEX) -o build/lex.yy.cpp hw.l

clean:
	rm build/*
