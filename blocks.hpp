//
// Created by Ilgaz on 2.06.2024.
//

#ifndef INC_425_1_BLOCKS_H
#define INC_425_1_BLOCKS_H

#include <utility>
#include <vector>
#include <string>
#include <iostream>
#include <ostream>
#include <unordered_set>

std::string get_temp();

std::string get_label();

extern int yyerror(const char *s);

class Code_t {
public:
    virtual std::string make_code() const {
        return "";
    }
};

class Statement_t : public Code_t {
public:
    const std::string code;

    explicit Statement_t(std::string code) : code(std::move(code)) {}

    std::string make_code() const override { return code; }

    friend Statement_t operator+(const Statement_t &a, const Statement_t &b) {
        return Statement_t(a.code + b.code);
    }
};

class Expression_t : public Statement_t {
public:
    std::string result_var;

    Expression_t(std::string code, std::string resultVar) : Statement_t(std::move(code)),
                                                            result_var(std::move(resultVar)) {}

    std::string make_code() const override {
        return code;
    }
};

class Identifier_t : public Code_t {
public:
    const std::string name;
    const std::string llvm_name;

    Identifier_t(char *begin, char *end) : name(begin, end), llvm_name("%" + name) {}

    virtual Expression_t *load(const std::string &temp) const {
        return new Expression_t(temp + " = load i32, ptr " + llvm_name + "\n", temp);
    }

public:
    bool operator==(const Identifier_t &rhs) const {
        return name == rhs.name;
    }

    bool operator!=(const Identifier_t &rhs) const {
        return !(rhs == *this);
    }
};

class FuncIdentifier_t : public Identifier_t {
public:
    const int arg_count;

    FuncIdentifier_t(const Identifier_t *id, const int arg_count) : Identifier_t(*id), arg_count(arg_count) {}
};

template<>
struct std::hash<Identifier_t> {
    std::size_t operator()(const Identifier_t &k) const {
        return std::hash<std::string>()(k.name);
    }
};

class Scope_t {
    std::unordered_set<Identifier_t> items;
    const std::string type;
public:
    explicit Scope_t(std::string type) : type(std::move(type)) {}

    void add(Identifier_t *id);

    void use(Identifier_t *id);

    void remove(Identifier_t *id);

    friend std::ostream &operator<<(std::ostream &os, const Scope_t &scope);

    int get_arg_size(Identifier_t *id) const;
};

class Const_t : public Identifier_t {
public:
    const int val;

    Const_t(const Identifier_t *id, const int val) : Identifier_t(*id), val(val) {}
};

class Array_t : public Identifier_t {
public:
    const int length;

    Array_t(const Identifier_t *id, const int index) : Identifier_t(*id), length(index) {}
};

class IdentifierList_t : public Code_t {
public:
    std::vector<Identifier_t *> id_list;

    void insert(Identifier_t *item_ptr);

    friend std::ostream &operator<<(std::ostream &os, const IdentifierList_t &ids);

    void add_to_scope(Scope_t &) const;

    void remove_from_scope(Scope_t &) const;

    int size() const {
        return id_list.size();
    }
};

class Decl_t : public Code_t {

public:
    IdentifierList_t *ids;

    Decl_t() : ids(new IdentifierList_t()) {}

    void add_to_scope(Scope_t &scope) const {
        ids->add_to_scope(scope);
    }

    void remove_from_scope(Scope_t &scope) const {
        ids->remove_from_scope(scope);
    }
};

class VarDecl_t : public Decl_t {
public:
    VarDecl_t() = default;

    explicit VarDecl_t(IdentifierList_t *ids) {
        this->ids = ids;
    }

    std::string make_code() const override;
};

class ConstDecl_t : public VarDecl_t {
public:
    std::vector<Const_t *> consts;

    void insert(Const_t *);

    std::string make_code() const override;
};

class ArrDecl_t : public Decl_t {
public:
    std::vector<Array_t *> arrays;

    void insert(Array_t *);

    std::string make_code() const override;
};

class Proc_t;

class ProcDecl_t : public Decl_t {
public:
    std::vector<Proc_t *> procs;

    void insert(Proc_t *);

    void set_labels(std::vector<std::string>);

    std::string make_code() const override;
};

class Block_t : public Code_t {
    ConstDecl_t *constDecl;
    VarDecl_t *varDecl;
    ArrDecl_t *arrDecl;
    ProcDecl_t *procDecl;
    Statement_t *statement;
public:
    Block_t(ConstDecl_t *constDecl, VarDecl_t *varDecl, ArrDecl_t *arrDecl, ProcDecl_t *procDecl,
            Statement_t *statement);

    void remove_from_scope(Scope_t &scope, Scope_t &proc_scope, Scope_t &array_scope) const;

    std::string make_code() const override;

};

class Function_t : public Code_t {
public:
    Identifier_t *id;
    IdentifierList_t *identifiers;
    Block_t *block;

    Function_t(Identifier_t *id, IdentifierList_t *identifiers, Block_t *block);

    std::string make_code() const override;
};

class Proc_t : public Code_t {
public:
    Identifier_t *id;
    Block_t *block;
    std::vector<std::string> labels;

    Proc_t(Identifier_t *id, Block_t *block) : id(id), block(block) {}

    std::string make_code() const override;
};

#endif //INC_425_1_BLOCKS_H