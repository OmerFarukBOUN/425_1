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

Scope_t functions("function");
Scope_t procedures("procedure");
Scope_t scope("variable");
Scope_t arrays("array");

std::vector<std::string> callbacks;
std::string curr_fn_name;
%}

%token FUNCTION DO CONST VAR ARR PROCEDURE IF THEN ELSE WHILE FOR BREAK RETURN READ WRITE WRITELINE BEGIN_ END ODD CALL TO ERR
%token IDENTIFIER NUMBER NE LE GE AS

%define api.value.type union
%type <int> NUMBER
%type <Identifier_t *> IDENTIFIER Function
%type <Array_t *> Array
%type <IdentifierList_t *> IdentifierList NeIdentifierList FunctionVars
%type <VarDecl_t *> VarDecl
%type <Const_t *> Assignment
%type <ConstDecl_t *> ConstAssignmentList ConstDecl
%type <Expression_t *> Factor Term Expression FuncCall Condition ERR
%type <ArrDecl_t *> ArrList ArrDecl
%type <Statement_t *> Statement StatementList
%type <Block_t *> Block
%type <ProcDecl_t *> ProcDecl
%type <Function_t *> FunctionBlock
%type <std::vector<Expression_t*> *> ExpressionList
%type <std::string *> NeFunctionList FunctionList

%left '+' '-'
%left '*' '/' '%'
%right '='
%nonassoc '<' '>'
%locations
%debug
%%

Program : FunctionList Block '.' YYEOF { std::cout << *$1 + $2->make_code(); }
        | FunctionList Block YYEOF { printf("Missing '.' at the end of file.\n"); exit(1); }
        ;

FunctionList : NeFunctionList {$$ = $1;}
             | /* empty */ {$$ = new std::string;}
             ;

NeFunctionList : FunctionBlock {$$ = new std::string($1->make_code());}
             | NeFunctionList FunctionBlock {$$ = $1; *$1 += $2->make_code();}
             ;

Function: FUNCTION IDENTIFIER {$$ = $2; curr_fn_name = $2->name;}

FunctionBlock : Function FunctionVars DO Block '.' {$$=new Function_t($1, $2, $4);functions.add($1);}
              ;

FunctionVars : '(' IdentifierList ')' {$$ = $2; $$->add_to_scope(scope);}

IdentifierList : NeIdentifierList {$$ = $1;}
               | /* empty */ {$$ = new IdentifierList_t;}
               ;

NeIdentifierList : IDENTIFIER { $$ = new IdentifierList_t(); $$->insert($1);}
               | NeIdentifierList ',' IDENTIFIER { $$ = $1; $$->insert($3); }
               | error ',' IDENTIFIER {$$ = new IdentifierList_t(); $$->insert($3);}
               ;

Block : ConstDecl VarDecl ArrDecl ProcDecl Statement {
             $$ = new Block_t($1, $2, $3, $4, $5);
             $$->remove_from_scope(scope, procedures, arrays);
             $4->set_labels(callbacks);
         }
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
        | VAR error ';' { $$ = new VarDecl_t(); }
        | /* Empty */ { $$ = new VarDecl_t(); }
        ;

ArrDecl : ARR ArrList ';' { $$ = $2; $$->add_to_scope(arrays);}
        | /* Empty */ { $$ = new ArrDecl_t(); }
        ;

ArrList : Array { $$ = new ArrDecl_t(); $$->insert($1); }
        | ArrList ',' Array { $$ = $1; $$->insert($3); }
        ;

Array : IDENTIFIER '[' NUMBER ']' { $$ = new Array_t($1, $3); }
      ;

ProcDecl : ProcDecl PROCEDURE IDENTIFIER ';' Block ';' { $$ = $1; $$->insert(new Proc_t($3, $5));}
         | /* Empty */ { $$ = new ProcDecl_t; }
         ;

Statement : IDENTIFIER AS Expression { /* Process assignment statement */ }
          | IDENTIFIER '[' Expression ']' AS Expression { /* Process assignment statement */ }
          | CALL IDENTIFIER {
              std::string callback = get_label();
              callbacks.push_back(callback);
              std::string code = "br label %" + callback + "\n"
                  + "call void(ptr)* @push(ptr blockaddress(@" + curr_fn_name + ", %"+callback+"))"
                  + "br label %" + $2->name;
          }
          | BEGIN_ StatementList END { $$ = $2;}
          | IF Condition THEN Statement '!' {
              std::string current = get_label();
              std::string end = get_label();
              std::string code = "br i32 " + $2->result_var + ", label " + current + ", label " + end + "\n";
              code += current + ":\n";
              code += $4->code;
              code += end + ":\n";
              $$ = new Statement_t(code);
          }
          | IF Condition THEN Statement ELSE Statement '!' {
              std::string current = get_label();
              std::string else_label = get_label();
              std::string end_label;
              std::string code = "br i32 " + $2->result_var + ", label " + current + ", label " + else_label + "\n";
              code += current + ":\n";
              code += $4->code;
              code += "br label " + end_label + "\n";
              code += else_label + ":\n";
              code += $6->code + end_label + ":\n";
              $$ = new Statement_t(code);
          }
          | WHILE Condition DO Statement {
              std::string current = get_label();
              std::string cont = get_label();
              std::string end = get_label();
              std::string code = current + ":\n";
              code += $2->code;
              code += "br i32 " + $2->result_var + ", label " + cont + ", label " + end + "\n";
              code += cont + ":\n";
              code += $4->code;
              code += "br label " + current + "\n";
              code += end + ":\n";
              $$ = new Statement_t(code);
          }
          | FOR IDENTIFIER AS Expression TO Expression DO Statement { /* Process for loop */ }
          | BREAK { /* Process break statement */ }
          | RETURN Expression { /* Process return statement */ }
          | READ '(' IDENTIFIER ')' { /* Process read statement */ }
          | WRITE '(' Expression ')' { /* Process write statement */ }
          | WRITELINE '(' Expression ')' { /* Process writeline statement */ }
          | FuncCall { /* $$ = $1; */}
          | /* Empty */ { /* No statement */ }
          | error {DEBUG("Statement error\n");}
          ;

StatementList : Statement { $$ = $1; }
              | StatementList ';' Statement { $$ = new Statement_t(*$1 + *$3); }
              ;

Condition : ODD Expression { std::string current = get_temp(); std::string code = current + " = srem i32 " + $2->result_var + ", 2\n"; $$ = new Expression_t(code, current);}
          | Expression '=' Expression {
          std::string current = get_temp();
          std::string code = current + " = icmp eq i32 " + $1->result_var + ", " + $3->result_var + "\n";
          $$ = new Expression_t(code, current);
          }
          | Expression NE Expression {
          std::string current = get_temp();
          std::string code = current + " = icmp ne i32 " + $1->result_var + ", " + $3->result_var + "\n";
          $$ = new Expression_t(code, current);
          }
          | Expression '<' Expression {
          std::string current = get_temp();
          std::string code = current + " = icmp slt i32 " + $1->result_var + ", " + $3->result_var + "\n";
          $$ = new Expression_t(code, current);
          }
          | Expression '>' Expression {
          std::string current = get_temp();
          std::string code = current + " = icmp sgt i32 " + $1->result_var + ", " + $3->result_var + "\n";
          $$ = new Expression_t(code, current);
          }
          | Expression LE Expression {
          std::string current = get_temp();
          std::string code = current + " = icmp sle i32 " + $1->result_var + ", " + $3->result_var + "\n";
          $$ = new Expression_t(code, current);
          }
          | Expression GE Expression {
          std::string current = get_temp();
          std::string code = current + " = icmp sge i32 " + $1->result_var + ", " + $3->result_var + "\n";
          $$ = new Expression_t(code, current);
          }
          | error {DEBUG("Condition error\n");}
          ;

Expression : Term { $$ = $1;}
           | Expression '+' Term {
           std::string current = get_temp();
           std::string code = current + " = add i32 " + $1->result_var + ", " + $3->result_var + "\n";
           $$ = new Expression_t(code, current);
           }
           | Expression '-' Term {
           std::string current = get_temp();
           std::string code = current + " = sub i32 " + $1->result_var + ", " + $3->result_var + "\n";
           $$ = new Expression_t(code, current);
           }
           ;

Term : Factor {  $$ = $1; }
     | Term '*' Factor {
     std::string current = get_temp();
     std::string code = current + " = mul i32 " + $1->result_var + ", " + $3->result_var + "\n";
     $$ = new Expression_t(code, current);
     }
     | Term '/' Factor {
     std::string current = get_temp();
     std::string code = current + " = sdiv i32 " + $1->result_var + ", " + $3->result_var + "\n";
     $$ = new Expression_t(code, current);
     }
     | Term '%' Factor {
     std::string current = get_temp();
     std::string code = current + " = srem i32 " + $1->result_var + ", " + $3->result_var + "\n";
     $$ = new Expression_t(code, current);
     }
     ;

Factor : IDENTIFIER {scope.use($1); $$ = $1->load(get_temp());}
       | NUMBER {$$ = new Expression_t("", std::to_string($1)); }
       | '(' Expression ')' { $$ = $2; }
       | IDENTIFIER '[' Expression ']' {
                std::string current = get_temp();
                std::string code = current + " = getelementptr i32*" + $1->llvm_name + ", i32 " + $3->result_var + "\n";
                $$ = new Expression_t(code, current);
            }
       | FuncCall { $$ = $1;}
       | error {DEBUG("Factor error\n");}
       | ERR
       ;

FuncCall : IDENTIFIER '(' ExpressionList ')' {
    auto current = get_temp();
    auto code = "call i32 @" + $1->name + "(";
    bool first = true;
    for(auto expr: *$3) {
        if (first) {
            first = false;
        } else {
            code += ", ";
        }
        code += "i32 " + expr->result_var;
    }
    code += ")\n";
    $$ = new Expression_t(code, current);
};

ExpressionList : Expression { $$ = new std::vector<Expression_t*>(1, $1); }
               | ExpressionList ',' Expression { $$ = $1; $1->push_back($3); }
               | /* Empty */ { $$ = new std::vector<Expression_t*>(); }
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


