//
// Created by Ilgaz on 2.06.2024.
//
#include "blocks.hpp"

std::ostream &operator<<(std::ostream &os, const Identifier_t &id) {
    os << id.name << "(" << id.llvm_name << ")";
    return os;
}

void IdentifierList_t::insert(Identifier_t *item) {
    if (item == nullptr) return;
    for (const auto &other: this->id_list) {
        if (*item == *other) {
            char str[] = "Declared previously declared variable %s";
            char str2[1000];
            snprintf(str2, sizeof(str2), str, item->name.c_str());
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

std::string VarDecl_t::make_code() const {
    std::string code;
    for (const auto &item: ids->id_list) {
        code += item->llvm_name + " = alloca i32, align 4\n";
    }
    return code;
}

void IdentifierList_t::add_to_scope(Scope_t &scope) const {
    for (auto id: id_list) {
        scope.add(id);
    }
}

void IdentifierList_t::remove_from_scope(Scope_t &scope) const {
    for (auto id: id_list) {
        scope.remove(id);
    }
}

void ConstDecl_t::insert(Const_t *cons) {
    if (cons == nullptr) return;
    ids->insert(cons);
    consts.push_back(cons);
}

std::string ConstDecl_t::make_code() const {
    std::string code = VarDecl_t::make_code();
    for (const auto item: consts) {
        code += "store i32 " + std::to_string(item->val) + ", ptr " + item->llvm_name + "\n";
    }
    return code;
}

void ArrDecl_t::insert(Array_t *) {

}

std::string ArrDecl_t::make_code() const {
    std::string code;
    for (const auto &item: arrays) {
        code += item->id->llvm_name + " = alloca i32, i32 " + std::to_string(item->length) + "\n";
    }
    return code;
}

void Scope_t::add(Identifier_t *id) {
    auto p = items.insert(*id);
    if (p.second) {
        std::string errmsg = "Declared previously declared " + type + ": " + id->name;
        yyerror(errmsg.c_str());
    }
}

void Scope_t::use(Identifier_t *id) {
    if (items.find(*id) == items.end()) {
        std::string errmsg = "Used undeclared " + type + ": " + id->name;
        yyerror(errmsg.c_str());
    }
}

void Scope_t::remove(Identifier_t *id) {
    items.erase(*id);
}

Block_t::Block_t(ConstDecl_t *constDecl, VarDecl_t *varDecl, ArrDecl_t *arrDecl, ProcDecl_t *procDecl,
                 Statement_t *statement) : constDecl(constDecl), varDecl(varDecl), arrDecl(arrDecl), procDecl(procDecl),
                                           statement(statement) {
}

void Block_t::remove_from_scope(Scope_t &scope) const {
    constDecl->remove_from_scope(scope);
    varDecl->remove_from_scope(scope);

}
