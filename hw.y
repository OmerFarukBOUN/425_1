%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define YYDEBUG 1
int yylex();
int yyerror(const char *);
extern int yylineno;
#define LINEBUF_LEN 256
extern char linebuf[LINEBUF_LEN];

#define YYSTYPE_IS_DECLARED
#define YYSTYPE_IS_POINTER
typedef struct {
    char *strval;
    int numval;
} YYSTYPE;

int debug_print = 0;
#define DEBUG(...) if(debug_print) printf(__VA_ARGS__);

%}

%token FUNCTION DO CONST VAR ARR PROCEDURE IF THEN ELSE WHILE FOR BREAK RETURN READ WRITE WRITELINE BEGIN_ END ODD CALL TO ERR
%token IDENTIFIER NUMBER NE LE GE AS
%left '+' '-'
%left '*' '/' '%'
%right '='
%nonassoc '<' '>'
%locations
%debug
%%

Program : FunctionList Block '.' YYEOF { printf("Parsed successfully.\n"); exit(0); }
        | FunctionList Block YYEOF { printf("Missing '.' at the end of file.\n"); exit(1); }
        ;

FunctionList : NeFunctionList
             | /* empty */
             ;

NeFunctionList : FunctionBlock
             | NeFunctionList FunctionBlock { /* Combine function blocks */ }
             ;

FunctionBlock : FUNCTION IDENTIFIER '(' IdentifierList ')' DO Block '.' { /* Process function block */ }
              | FUNCTION error '.'
              ;

IdentifierList : NeIdentifierList
               | /* empty */
               ;

NeIdentifierList : IDENTIFIER { $$ = $1; }
               | NeIdentifierList ',' IDENTIFIER { /* Combine identifiers */ }
               | error ',' IDENTIFIER
               ;

Block : ConstDecl VarDecl ArrDecl ProcDecl Statement { /* Process block */ }
      ;

ConstDecl : CONST ConstAssignmentList ';' { /* Process constant declaration */ }
//          | CONST error ';'
          | /* Empty */ { /* No constant declaration */ }
          ;

ConstAssignmentList : Assignment { /* Process constant assignment */ }
                    | ConstAssignmentList ',' Assignment { /* Combine constant assignments */ }
                    | ConstAssignmentList error
                    ;

Assignment : IDENTIFIER AS NUMBER
           | error
           ;

VarDecl : VAR IdentifierList ';' { /* Process variable declaration */ }
        | VAR error ';'
        | /* Empty */ { /* No variable declaration */ }
        ;

ArrDecl : ARR ArrList ';' { /* Process array declaration */ }
        | /* Empty */ { /* No array declaration */ }
        ;

ArrList : Array { $$ = $1; }
        | ArrList ',' Array { /* Combine arrays */ }
        ;

Array : IDENTIFIER '[' Expression ']' { /* Process array */ }
      ;

ProcDecl : ProcDecl PROCEDURE IDENTIFIER ';' Block ';' { /* Process procedure declaration */ }
         | /* Empty */ { /* No procedure declaration */ }
         ;

Statement : IDENTIFIER AS Expression { /* Process assignment statement */ }
          | Array AS Expression { /* Process assignment statement */ }
          | CALL IDENTIFIER { /* Process function call statement */ }
          | BEGIN_ StatementList END { /* Process compound statement */ }
          | IF Condition THEN Statement '!' { /* Process if statement */ }
          | IF Condition THEN Statement ELSE Statement '!' { /* Process if-else statement */ }
          | WHILE Condition DO Statement { /* Process while loop */ }
          | FOR IDENTIFIER AS Expression TO Expression DO Statement { /* Process for loop */ }
          | BREAK { /* Process break statement */ }
          | RETURN Expression { /* Process return statement */ }
          | READ '(' IDENTIFIER ')' { /* Process read statement */ }
          | WRITE '(' Expression ')' { /* Process write statement */ }
          | WRITELINE '(' Expression ')' { /* Process writeline statement */ }
          | FuncCall { $$ = $1; }
          | /* Empty */ { /* No statement */ }
          | error {DEBUG("Statement error\n");}
          ;

StatementList : Statement { /* Process single statement */ }
              | StatementList ';' Statement { /* Combine statements */ }
              ;

Condition : ODD Expression { /* Process odd condition */ }
          | Expression '=' Expression { /* Process equality condition */ }
          | Expression NE Expression { /* Process inequality condition */ }
          | Expression '<' Expression { /* Process less than condition */ }
          | Expression '>' Expression { /* Process greater than condition */ }
          | Expression LE Expression { /* Process less than or equal condition */ }
          | Expression GE Expression { /* Process greater than or equal condition */ }
          | error {DEBUG("Condition error\n");}
          ;

Expression : Term { $$ = $1; }
           | Expression '+' Term { /* Process addition */ }
           | Expression '-' Term { /* Process subtraction */ }
           ;

Term : Factor { $$ = $1; }
     | Term '*' Factor { /* Process multiplication */ }
     | Term '/' Factor { /* Process division */ }
     | Term '%' Factor { /* Process modulus */ }
     ;

Factor : IDENTIFIER { /* Process identifier */ }
       | NUMBER { /* Process number */ }
       | '(' Expression ')' { /* Process expression in parentheses */ }
       | Array { $$ = $1; }
       | FuncCall { $$ = $1; }
       | error {DEBUG("Factor error\n");}
       | ERR
       ;

FuncCall : IDENTIFIER '(' ExpressionList ')' { /* Process function call */ }
         ;

ExpressionList : Expression { /* Process single expression */ }
               | ExpressionList ';' Expression { /* Combine expressions */ }
               ;

%%
int yyerror(const char *s) {
    printf("%s\n", linebuf);
    for(int i = 0; i < yylloc.first_column - 1; i++){
        printf(" ");
    }
    printf("^\n");
    printf("%s at line %d column %d\n", s, yylineno, yylloc.first_column);
    printf("----\n");
    return 0;
}
int main(int argc, char *argv[]) {
    yydebug=argc>1&&argv[1][0]=='-'&&argv[1][1]=='t';
    debug_print=argc>1&&argv[1][0]=='-'&&argv[1][1]=='d';
    yyparse();
    return 0;
}


