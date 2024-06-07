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

extern int yyerror(const char *s);

class Code_t {
public:
    virtual std::string make_code() const {
        return "";
    }
};

class Expression_t : public Code_t {
public:
    std::string code;
    std::string result_var;

    Expression_t(std::string code, std::string resultVar) : code(std::move(code)), result_var(std::move(resultVar)) {}

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
        return new Expression_t(temp + " = load i32, ptr " + llvm_name, temp);
    }

public:
    bool operator==(const Identifier_t &rhs) const {
        return name == rhs.name;
    }

    bool operator!=(const Identifier_t &rhs) const {
        return !(rhs == *this);
    }
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
};

class Const_t : public Identifier_t {
public:
    const int val;

    Const_t(const Identifier_t *id, const int val) : Identifier_t(*id), val(val) {}
};

class Array_t : public Code_t {
public:
    const Identifier_t *id;
    const int length;

    Array_t(const Identifier_t *id, const int index) : id(id), length(index) {}
};

class IdentifierList_t : public Code_t {
public:
    std::vector<Identifier_t *> id_list;

    void insert(Identifier_t *item_ptr);

    friend std::ostream &operator<<(std::ostream &os, const IdentifierList_t &ids);
};

class VarDecl_t : public Code_t {
public:
    IdentifierList_t *ids;

    explicit VarDecl_t(IdentifierList_t *ids) : ids(ids) {}

    std::string make_code() const override;

    void add_to_scope(Scope_t &) const;
};

class ConstDecl_t : public VarDecl_t {
public:
    std::vector<Const_t *> consts;

    ConstDecl_t() : VarDecl_t(new IdentifierList_t()) {}

    void insert(Const_t *);

    std::string make_code() const override;
};


class ArrDecl_t : public Code_t {
public:
    std::vector<Array_t *> arrays;

    void insert(Array_t *);

    std::string make_code() const override;
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

class Block_t : public Code_t {

};

#endif //INC_425_1_BLOCKS_H