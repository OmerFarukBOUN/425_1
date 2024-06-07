//
// Created by Ilgaz on 2.06.2024.
//

#ifndef INC_425_1_BLOCKS_H
#define INC_425_1_BLOCKS_H

#include <vector>
#include <string>
#include <iostream>
#include <ostream>

extern int yyerror(const char *s);

class Code_t {
public:
    virtual std::string make_code() {
        return "";
    }
};

class Identifier_t : public Code_t {
public:
    const std::string name;
    const std::string llvm_name;

    Identifier_t(char *begin, char *end) : name(begin, end), llvm_name("%" + name) {}

public:
    bool operator==(const Identifier_t &rhs) const {
        return name == rhs.name;
    }

    bool operator!=(const Identifier_t &rhs) const {
        return !(rhs == *this);
    }
};

class IdentifierList_t : public Code_t {
public:
    std::vector<Identifier_t> id_list;

    void insert(const Identifier_t *item_ptr);

    friend std::ostream &operator<<(std::ostream &os, const IdentifierList_t &ids);
};

class VarDecl_t : public Code_t {
public:
    IdentifierList_t *ids;

    explicit VarDecl_t(IdentifierList_t *ids) : ids(ids) {}

    std::string make_code() override;
};

class Const_t : public Identifier_t {
public:
    const int val;

    Const_t(const Identifier_t *id, const int val) : Identifier_t(*id), val(val) {}
};

class ConstDecl_t : public VarDecl_t {
public:
    std::vector<Const_t *> consts;

    ConstDecl_t() : VarDecl_t(new IdentifierList_t()) {}

    void insert(Const_t *);

    std::string make_code() override;
};

class Expression_t : public Code_t {
public:
    std::string code;
    std::string result_var;

    Expression_t(const std::string &code, const std::string &resultVar) : code(code), result_var(resultVar) {}

    std::string make_code() override {
        return code;
    }
};

#endif //INC_425_1_BLOCKS_H
