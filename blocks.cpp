//
// Created by Ilgaz on 2.06.2024.
//
#include "blocks.hpp"

void IdentifierList_t::insert(const Identifier_t *item_ptr) {
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

std::ostream &operator<<(std::ostream &os, const Identifier_t &id) {
    os << id.name << "(" << id.llvm_name << ")";
    return os;
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