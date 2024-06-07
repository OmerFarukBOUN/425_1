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

class Identifier_t : Code_t {
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

class IdentifierList_t {
public:
    std::vector<Identifier_t> id_list;

    void insert(const Identifier_t *item_ptr);

    friend std::ostream &operator<<(std::ostream &os, const IdentifierList_t &ids);
};

class VarDecl_t {
    IdentifierList_t *ids;
public:
    explicit VarDecl_t(IdentifierList_t *ids) : ids(ids) {}

    virtual std::string make_code() {
        std::string code;
        for (const auto &item: ids->id_list) {
            code += item.llvm_name + " = alloca i32, align 4";
        }
        return code;
    }
};

#endif //INC_425_1_BLOCKS_H
