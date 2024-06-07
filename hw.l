%{
#include "y.tab.hpp"
#include <stdio.h>
#include <stdlib.h>
#include <string>
int yyerror(const char *s);
int yycolumn = 1;
#define LINEBUF_LEN 256
char linebuf[LINEBUF_LEN] = {0};

#define YY_USER_ACTION strcpy(linebuf + yycolumn - 1, yytext);\
    yylloc.first_line = yylloc.last_line = yylineno; \
    yylloc.first_column = yycolumn; yylloc.last_column = yycolumn + yyleng - 1; \
    yycolumn += yyleng;
%}

%option yylineno

%%

"function"       { return FUNCTION; }
"do"             { return DO; }
"const"          { return CONST; }
"var"            { return VAR; }
"arr"            { return ARR; }
"procedure"      { return PROCEDURE; }
"if"             { return IF; }
"then"           { return THEN; }
"else"           { return ELSE; }
"while"          { return WHILE; }
"for"            { return FOR; }
"break"          { return BREAK; }
"return"         { return RETURN; }
"read"           { return READ; }
"write"          { return WRITE; }
"writeline"      { return WRITELINE; }
"begin"          { return BEGIN_; }
"end"            { return END; }
"odd"            { return ODD; }
"to"             { return TO; }
"call"           { return CALL; }
"."              { return '.'; }
","              { return ','; }
";"              { return ';'; }
"("              { return '('; }
")"              { return ')'; }
"["              { return '['; }
"]"              { return ']'; }
"="              { return '='; }
"<>"             { return NE; }
"<"              { return '<'; }
">"              { return '>'; }
"<="             { return LE; }
">="             { return GE; }
"+"              { return '+'; }
"-"              { return '-'; }
"*"              { return '*'; }
"/"              { return '/'; }
"%"              { return '%'; }
"!"              { return '!'; }
":="             { return AS; }
[ \t]          ; // Skip whitespace and newline characters
\n               {yycolumn = 1; memset(linebuf, 0, LINEBUF_LEN);}
[0-9]+[a-zA-Z]+  { yyerror ("invalid token"); return ERR; }
[a-zA-Z][a-zA-Z0-9]* {yylval.IDENTIFIER = new Identifier_t(yytext, yytext + yyleng); return IDENTIFIER; }
[0-9]+           {yylval.NUMBER = std::stoi(std::string(yytext, yytext + yyleng)); return NUMBER; }
"/*"([^*]|"*"[^/])*"*/" { /* Ignore comments */ }
.                { fprintf(stderr, "Unexpected character: %s\n", yytext); exit(1); }

%%

int yywrap() {
    return 1;
}

