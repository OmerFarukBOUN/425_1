%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex();
int yyerror(const char *);
extern int yylineno;

#define YYSTYPE_IS_DECLARED
#define YYSTYPE_IS_POINTER
typedef struct {
    char *strval;
    int numval;
} YYSTYPE;

%}

%token FUNCTION DO CONST VAR ARR PROCEDURE IF THEN ELSE WHILE FOR BREAK RETURN READ WRITE WRITELINE BEGIN_ END ODD CALL TO
%token IDENTIFIER NUMBER NE LE GE
%left '+' '-'
%left '*' '/' '%'
%right '='
%nonassoc '<' '>'


%%

Program : FunctionList Block '.' { printf("Parsed successfully.\n"); exit(0); }
        | Block '.' { printf("Parsed successfully.\n"); exit(0); }
        | error '.'
        ;

FunctionList : FunctionBlock
             | FunctionList FunctionBlock { /* Combine function blocks */ } 
             | error FunctionBlock
             ;

FunctionBlock : FUNCTION IDENTIFIER '(' IdentifierList ')' DO Block '.' { /* Process function block */ }
              | FUNCTION error '.'
              ;

IdentifierList : IDENTIFIER { $$ = $1; }
               | IdentifierList ',' IDENTIFIER { /* Combine identifiers */ }
               | error ',' IDENTIFIER
               ;

Block : ConstDecl VarDecl ArrDecl ProcDecl Statement { /* Process block */ }
      ;

ConstDecl : CONST ConstAssignmentList ';' { /* Process constant declaration */ }
          | CONST error ';'
          | /* Empty */ { /* No constant declaration */ }
          ;

ConstAssignmentList : IDENTIFIER '=' NUMBER { /* Process constant assignment */ }
                    | ConstAssignmentList ',' IDENTIFIER '=' NUMBER { /* Combine constant assignments */ }
                    | error ',' IDENTIFIER '=' NUMBER
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

ProcDecl : PROCEDURE IDENTIFIER ';' Block ';' { /* Process procedure declaration */ }
         | /* Empty */ { /* No procedure declaration */ }
         ;

Statement : IDENTIFIER '=' Expression { /* Process assignment statement */ }
          | CALL IDENTIFIER { /* Process function call statement */ }
          | BEGIN_ StatementList END { /* Process compound statement */ }
          | IF Condition THEN Statement '!' { /* Process if statement */ }
          | IF Condition THEN Statement ELSE Statement '!' { /* Process if-else statement */ }
          | WHILE Condition DO Statement { /* Process while loop */ }
          | FOR IDENTIFIER '=' Expression TO Expression DO Statement { /* Process for loop */ }
          | BREAK { /* Process break statement */ }
          | RETURN Expression { /* Process return statement */ }
          | READ '(' IDENTIFIER ')' { /* Process read statement */ }
          | WRITE '(' Expression ')' { /* Process write statement */ }
          | WRITELINE '(' Expression ')' { /* Process writeline statement */ }
          | /* Empty */ { /* No statement */ }
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
       ;

FuncCall : IDENTIFIER '(' ExpressionList ')' { /* Process function call */ }
         ;

ExpressionList : Expression { /* Process single expression */ }
               | ExpressionList ';' Expression { /* Combine expressions */ }
               ;

%%
int yyerror(const char *s) {
    printf("Syntax error at line %d\n", yylineno);
    return 0;
}
int main() {
    yyparse();
    return 0;
}

