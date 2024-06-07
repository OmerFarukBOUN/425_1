%code requires {
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <iostream>
#include "../blocks.hpp"
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <vector>
#include <unordered_set>
#include <iostream>
#include "../blocks.hpp"

#define YYDEBUG 1
int yylex();
int yyerror(const char *);
extern int yylineno;
#define LINEBUF_LEN 256
extern char linebuf[LINEBUF_LEN];

int debug_print = 0;
#define DEBUG(...) if(debug_print) printf(__VA_ARGS__);

int temp_count = 0;
std::string get_temp(){
    temp_count += 1;
    return "%temp_" + std::to_string(temp_count - 1);
}
Scope_t functions("function");
Scope_t procedures("procedure");
Scope_t scope("variable");
%}

%token FUNCTION DO CONST VAR ARR PROCEDURE IF THEN ELSE WHILE FOR BREAK RETURN READ WRITE WRITELINE BEGIN_ END ODD CALL TO ERR
%token IDENTIFIER NUMBER NE LE GE AS

%define api.value.type union
%type <int> NUMBER
%type <Identifier_t *> IDENTIFIER
%type <Array_t *> Array
%type <IdentifierList_t *> IdentifierList NeIdentifierList
%type <VarDecl_t *> VarDecl
%type <Const_t *> Assignment
%type <ConstDecl_t *> ConstAssignmentList ConstDecl
%type <Expression_t *> Factor Term Expression FuncCall ERR
%type <ArrDecl_t *> ArrList ArrDecl
%type <Statement_t *> Statement StatementList
%type <std::vector<Expression_t*> *> ExpressionList

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

IdentifierList : NeIdentifierList {$$ = $1; std::cout << *$$ << "\n";}
               | /* empty */ {$$ = new IdentifierList_t;}
               ;

NeIdentifierList : IDENTIFIER { $$ = new IdentifierList_t(); $$->insert($1);}
               | NeIdentifierList ',' IDENTIFIER { $$ = $1; $$->insert($3); }
               | error ',' IDENTIFIER {$$ = new IdentifierList_t(); $$->insert($3);}
               ;

Block : ConstDecl VarDecl ArrDecl ProcDecl Statement { /* Process block */ }
      ;

ConstDecl : CONST ConstAssignmentList ';' { $$ = $2; $$->add_to_scope(scope);}
          | /* Empty */ {$$ = new ConstDecl_t();}
          ;

ConstAssignmentList : Assignment { $$ = new ConstDecl_t(); $$ -> insert($1); }
                    | ConstAssignmentList ',' Assignment { $$ = $1; $$ -> insert($3); }
                    ;

Assignment : IDENTIFIER AS NUMBER {$$ = new Const_t($1, $3);}
           | error {$$ = nullptr;}
           ;

VarDecl : VAR NeIdentifierList ';' { $$ = new VarDecl_t($2); $$->add_to_scope(scope);}
        | VAR error ';' { $$ = new VarDecl_t(new IdentifierList_t()); }
        | /* Empty */ { $$ = new VarDecl_t(new IdentifierList_t()); }
        ;

ArrDecl : ARR ArrList ';' { $$ = $2; }
        | /* Empty */ { $$ = new ArrDecl_t(); }
        ;

ArrList : Array { $$ = new ArrDecl_t(); $$->insert($1); }
        | ArrList ',' Array { $$ = $1; $$->insert($3); }
        ;

Array : IDENTIFIER '[' NUMBER ']' { $$ = new Array_t($1, $3); }
      ;

ProcDecl : ProcDecl PROCEDURE IDENTIFIER ';' Block ';' { /* Process procedure declaration */ }
         | /* Empty */ { /* No procedure declaration */ }
         ;

Statement : IDENTIFIER AS Expression { /* Process assignment statement */ }
          | IDENTIFIER '[' Expression ']' AS Expression { /* Process assignment statement */ }
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
          | FuncCall { /*$$ = $1;*/ }
          | /* Empty */ { /* No statement */ }
          | error {DEBUG("Statement error\n");}
          ;

StatementList : Statement { $$ = $1; }
              | StatementList ';' Statement { $$ = new Statement_t(*$1 + *$3); }
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

Expression : Term { /* $$ = $1; */}
           | Expression '+' Term { /* Process addition */ }
           | Expression '-' Term { /* Process subtraction */ }
           ;

Term : Factor { /* $$ = $1; */}
     | Term '*' Factor { /* Process multiplication */ }
     | Term '/' Factor { /* Process division */ }
     | Term '%' Factor { /* Process modulus */ }
     ;

Factor : IDENTIFIER {scope.use($1); $$ = $1->load(get_temp());}
       | NUMBER { $$ = new Expression_t("", std::to_string($1)); }
       | '(' Expression ')' { $$ = $2; }
       | IDENTIFIER '[' Expression ']' {std::string current = get_temp(); std::string code = current + " = getelementptr i32*" + $1->llvm_name + ", i32 " + $3->result_var + "\n"; $$ = new Expression_t(code, current); }
       | FuncCall { $$ = $1;}
       | error {DEBUG("Factor error\n");}
       | ERR
       ;

FuncCall : IDENTIFIER '(' ExpressionList ')' { std::string current = get_temp(); std::string code = ""; int i; for(i=0; i < $3->size()-1; i++) {code += "i32" + $3->at(i)->result_var + ", ";} code +=$3->at(i)->result_var+ "/n"; $$ = new Expression_t(code, current); }
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


