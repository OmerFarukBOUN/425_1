//
// Created by Ilgaz on 2.06.2024.
//
#include "blocks.hpp"

std::ostream &operator<<(std::ostream &os, const Identifier_t &id) {
    os << id.name << "(" << id.llvm_name << ")";
    return os;
}

void IdentifierList_t::insert(const Identifier_t *item_ptr) {
    if (item_ptr == nullptr) return;
    auto item = *item_ptr;
    for (const auto &other: this->id_list) {
        if (item == other) {
            char str[] = "Declared previously declared variable %s";
            char str2[1000];
            snprintf(str2, sizeof(str2), str, item.name.c_str());
            yyerror(str2);
        }
    }
    id_list.push_back(item);
}

std::ostream &operator<<(std::ostream &os, const IdentifierList_t &ids) {
    auto uset = ids.id_list;
    os << "{";
    for (auto it = uset.begin(); it != uset.end(); ++it) {
        if (it != uset.begin()) {
            os << ", ";
        }
        os << *it;
    }
    os << "}";
    return os;
}

std::string VarDecl_t::make_code() {
    std::string code;
    for (const auto &item: ids->id_list) {
        code += item.llvm_name + " = alloca i32, align 4\n";
    }
    return code;
}

void ConstDecl_t::insert(Const_t *cons) {
    if (cons == nullptr) return;
    ids->insert(cons);
    consts.push_back(cons);
}

std::string ConstDecl_t::make_code() {
    std::string code = VarDecl_t::make_code();
    for (const auto item: consts) {
        code += "store i32 " + std::to_string(item->val) + ", ptr " + item->llvm_name + "\n";
    }
    return code;
}
