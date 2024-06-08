%code requires {
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <iostream>
#include <fstream>
#include "../blocks.hpp"
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <vector>
#include <stack>
#include <unordered_set>
#include <iostream>
#include <fstream>
#include <stdio.h>

#include "../blocks.hpp"

#define YYDEBUG 1
int yylex();
int yyerror(const char *);
extern int yylineno;
#define LINEBUF_LEN 256
extern char linebuf[LINEBUF_LEN];

int debug_print = 0;
#define DEBUG(...) if(debug_print) printf(__VA_ARGS__);

std::stack<std::string> label_stack;

Scope_t functions("function");
Scope_t procedures("procedure");
Scope_t scope("variable");
Scope_t arrays("array");

std::vector<std::string> callbacks;
std::string curr_fn_name;

int optimised = 0;
std::ofstream out;

int error = 0;

static char *last_strchr(char *haystack, char needle)
{
    if (needle == '\0')
        return (char *) haystack;

    char *result = NULL;
    for (;;) {
        char *p = strchr(haystack, needle);
        if (p == NULL)
            break;
        result = p;
        haystack = p + 1;
    }

    return result;
}

std::ifstream preamble("preamble.ll");

%}
%token FUNCTION DO CONST VAR ARR PROCEDURE IF THEN ELSE WHILE FOR BREAK RETURN READ WRITE WRITELINE BEGIN_ END ODD CALL TO ERR
%token IDENTIFIER NUMBER NE LE GE AS

%define api.value.type union
%type <int> NUMBER
%type <Identifier_t *> IDENTIFIER Function For_Var
%type <Array_t *> Array
%type <IdentifierList_t *> IdentifierList NeIdentifierList FunctionVars
%type <VarDecl_t *> VarDecl
%type <Const_t *> Assignment
%type <ConstDecl_t *> ConstAssignmentList ConstDecl
%type <Expression_t *> Factor Term Expression FuncCall Condition ERR
%type <ArrDecl_t *> ArrList ArrDecl
%type <Statement_t *> Statement StatementList
%type <std::string *> While For
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

Program : FunctionList Block '.' YYEOF {
            if(error) exit(1);
            out << preamble.rdbuf()
                << *$1
                << "define i32 @main() {\n"
                << $2->make_code()
                << "ret i32 0"
                << "}";
        }
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

Block : ConstDecl VarDecl ArrDecl ProcDecl Statement{
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

While : WHILE { std::string current = get_label(); $$ = new std::string(current); label_stack.push(current); }
      ;

For : FOR { std::string current = get_label(); $$ = new std::string(current); label_stack.push(current); }
      ;

For_Var : IDENTIFIER {$$ = $1; scope.add($1);}

Statement : IDENTIFIER AS Expression { $$ = new Statement_t($3->make_code() + "store i32 " + $3->result_var + ", ptr " + $1->llvm_name + "\n");}
          | IDENTIFIER '[' Expression ']' AS Expression {
                std::string current = get_temp();
                std::string code = $3->make_code() + $6->make_code()
                    + current + " = getelementptr i32*, i32* " + $1->llvm_name + ", i32 " + $3->result_var + "\n"
                    + "store i32 " + $6->result_var + ", ptr " + current + "\n";
                $$ = new Statement_t(code);
            }
          | CALL IDENTIFIER {
              std::string callback = get_label();
              callbacks.push_back(callback);
              std::string code =
                  "call void(ptr)* @push(ptr blockaddress(@" + curr_fn_name + ", %"+callback+"))\n"
                  + "br label %" + $2->name + "\n"
                  + callback + ":\n";
              $$ = new Statement_t(code);
          }
          | BEGIN_ StatementList END { $$ = $2;}
          | IF Condition THEN Statement '!' {
              std::string current = get_label();
              std::string end = get_label();
              std::string code = $2->make_code()
                   + "br i1 " + $2->result_var + ", label %" + current + ", label %" + end + "\n"
                   + current + ":\n"
                   + $4->make_code()
                   + "br label %" + end +"\n"
                   + end + ":\n";
              $$ = new Statement_t(code);
          }
          | IF Condition THEN Statement ELSE Statement '!' {
              std::string current = get_label();
              std::string else_label = get_label();
              std::string end_label;
              std::string code = $2->make_code()
                   + "br i1 " + $2->result_var + ", label %" + current + ", label %" + else_label + "\n"
                   + current + ":\n"
                   + $4->make_code()
                   + "br label %" + end_label + "\n"
                   + else_label + ":\n"
                   + $6->make_code()
                   + "br label %" + end_label +"\n"
                   + end_label + ":\n";
              $$ = new Statement_t(code);
          }
          | While Condition DO Statement {
              std::string current = get_label();
              std::string continueLabel = get_label();
              std::string end = *$1;
              if (end != label_stack.top()) {
                DEBUG("Error: While statement not in while block\n")
                exit(1);
              }
              std::string code = "br label %" + current +"\n"
                   + current + ":\n"
                   + $2->make_code()
                   + "br i1 " + $2->result_var + ", label %" + continueLabel + ", label %" + end + "\n"
                   + continueLabel + ":\n"
                   + $4->make_code()
                   + "br label %" + current + "\n"
                   + "br label %" + end +"\n"
                   + end + ":\n";
              $$ = new Statement_t(code);
              label_stack.pop();
          }
          | For For_Var AS Expression TO Expression DO Statement {
              std::string current = get_label();
              std::string continueLabel = get_label();
              std::string end = *$1;
              auto i_val_cmp = get_temp();
              auto i_val_inc = get_temp();
              auto i_val_inc2 = get_temp();
              auto cond = get_temp();
              if (end != label_stack.top()) {
                DEBUG("Error: For statement not in for block\n")
                exit(1);
              }
              std::string code = $4->make_code()
                   + $6->make_code()
                   + $2->llvm_name+ " = alloca i32\n"
                   + "store i32 " + $4->result_var + ", ptr " + $2->llvm_name + "\n"
                   + "br label %" + current +"\n"
                   + current + ":\n"
                   + i_val_cmp + " = load i32, ptr " + $2->llvm_name + "\n"
                   + cond + " = icmp slt i32 " + i_val_cmp + ", "+$6->result_var+"\n"
                   + "br i1 " + cond + ", label %" + continueLabel + ", label %" + end + "\n"
                   + continueLabel + ":\n"
                   + $8->make_code()
                   + i_val_inc + " = load i32, ptr " + $2->llvm_name + "\n"
                   + i_val_inc2 + " = add nsw i32 " + i_val_inc + ", 1\n"
                   + "store i32 " + i_val_inc2 + ", ptr " + $2->llvm_name + "\n"
                   + "br label %" + current + "\n"
                   + "br label %" + end +"\n"
                   + end + ":\n";
              $$ = new Statement_t(code);
              label_stack.pop();
              scope.remove($2);
          }
          | BREAK { $$ = new Statement_t("br label %" + label_stack.top() + "\n");}
          | RETURN Expression {$$ = new Statement_t($2->make_code() + "\nret i32 " + $2->result_var);}
          | WRITE '(' Expression ')' {
              auto ret = get_temp();
              $$ = new Statement_t($3->make_code() + ret + " = call i32 (ptr, ...) @printf(ptr @.str.d, i32 "+$3->result_var+")\n");
          }
          | WRITELINE '(' Expression ')' {
              auto ret = get_temp();
              $$ = new Statement_t($3->make_code() + ret + " = call i32 (ptr, ...) @printf(ptr @.str.dn, i32 "+$3->result_var+")\n");
          }
          | READ '(' IDENTIFIER ')' {
              $$ = new Statement_t(get_temp() + " = call i32 (ptr, ...) @scanf(ptr @.str.d, ptr "+$3->llvm_name+")\n");
          }
          | FuncCall { $$ = $1;}
          | /* Empty */ { $$ = new Statement_t(""); }
          | error {DEBUG("Statement error\n");}
          ;

StatementList : Statement { $$ = $1; }
              | StatementList ';' Statement {$$ = new Statement_t(*$1 + *$3); }
              ;

Condition : ODD Expression {
              std::string current = get_temp();
              std::string code = current + " = srem i32 " + $2->result_var + ", 2\n";
              $$ = new Expression_t($2->make_code() + code, current);
          }
          | Expression '=' Expression {
              std::string current = get_temp();
              std::string code = current + " = icmp eq i32 " + $1->result_var + ", " + $3->result_var + "\n";
              $$ = new Expression_t($1->make_code() + $3->make_code() + code, current);
          }
          | Expression NE Expression {
              std::string current = get_temp();
              std::string code = current + " = icmp ne i32 " + $1->result_var + ", " + $3->result_var + "\n";
              $$ = new Expression_t($1->make_code() + $3->make_code() + code, current);
          }
          | Expression '<' Expression {
              std::string current = get_temp();
              std::string code = current + " = icmp slt i32 " + $1->result_var + ", " + $3->result_var + "\n";
              $$ = new Expression_t($1->make_code() + $3->make_code() + code, current);
          }
          | Expression '>' Expression {
              std::string current = get_temp();
              std::string code = current + " = icmp sgt i32 " + $1->result_var + ", " + $3->result_var + "\n";
              $$ = new Expression_t($1->make_code() + $3->make_code() + code, current);
          }
          | Expression LE Expression {
              std::string current = get_temp();
              std::string code = current + " = icmp sle i32 " + $1->result_var + ", " + $3->result_var + "\n";
              $$ = new Expression_t($1->make_code() + $3->make_code() + code, current);
          }
          | Expression GE Expression {
              std::string current = get_temp();
              std::string code = current + " = icmp sge i32 " + $1->result_var + ", " + $3->result_var + "\n";
              $$ = new Expression_t($1->make_code() + $3->make_code() + code, current);
          }
          | error {DEBUG("Condition error\n");}
          ;

Expression : Term { $$ = $1;}
           | Expression '+' Term {
           std::string current = get_temp();
           std::string code = current + " = add i32 " + $1->result_var + ", " + $3->result_var + "\n";
           $$ = new Expression_t($1->make_code() + $3->make_code() + code, current);
           }
           | Expression '-' Term {
           std::string current = get_temp();
           std::string code = current + " = sub i32 " + $1->result_var + ", " + $3->result_var + "\n";
           $$ = new Expression_t($1->make_code() + $3->make_code() + code, current);
           }
           ;

Term : Factor {  $$ = $1; }
     | Term '*' Factor {
     std::string current = get_temp();
     std::string code = current + " = mul i32 " + $1->result_var + ", " + $3->result_var + "\n";
     $$ = new Expression_t($1->make_code() + $3->make_code() + code, current);
     }
     | Term '/' Factor {
     std::string current = get_temp();
     std::string code = current + " = sdiv i32 " + $1->result_var + ", " + $3->result_var + "\n";
     $$ = new Expression_t($1->make_code() + $3->make_code() + code, current);
     }
     | Term '%' Factor {
     std::string current = get_temp();
     std::string code = current + " = srem i32 " + $1->result_var + ", " + $3->result_var + "\n";
     $$ = new Expression_t($1->make_code() + $3->make_code() + code, current);
     }
     ;

Factor : IDENTIFIER {scope.use($1); $$ = $1->load(get_temp());}
       | NUMBER {$$ = new Expression_t("", std::to_string($1)); }
       | '(' Expression ')' { $$ = $2; }
       | IDENTIFIER '[' Expression ']' {
                std::string current = get_temp();
                std::string temp = get_temp();
                std::string code = $3->make_code()
                    + current + " = getelementptr i32*, i32* " + $1->llvm_name + ", i32 " + $3->result_var + "\n"
                    + temp + " = load i32, ptr " + current + "\n";
                $$ = new Expression_t(code, temp);
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
    error = 1;
    return 0;
}
int main(int argc, char *argv[]) {
    yydebug=argc>1&&argv[1][0]=='-'&&argv[1][1]=='t';
    debug_print = argc>1&&argv[1][0]=='-'&&argv[1][1]=='d';
    optimised = argc>1&&argv[1][0]=='-'&&argv[1][1]=='O';
    char* in;
    if(argc>2&&argv[1][0]=='-'){
        in = argv[2];
    } else if(argc>1){
        in = argv[1];
    } else {
        sprintf(in, "%s", "test.txt");
    }
    freopen(in, "r", stdin);
    char* pos = last_strchr(in, '.');
    std::string asd;
    if(pos != NULL){
        asd = std::string(in, pos);
    } else {
        asd = std::string(in);
    }
    out = std::ofstream(asd + ".ll");

    yyparse();

    if(optimised){
        std::string q = "/opt/homebrew/opt/llvm/bin/opt -O3 -o " + asd + ".bs " + asd + ".ll";
        system(q.c_str());
    } else {
        std::string q = "/opt/homebrew/opt/llvm/bin/opt -O0 -o " + asd + ".bs " + asd + ".ll";
        system(q.c_str());
    }
    return 0;
}


