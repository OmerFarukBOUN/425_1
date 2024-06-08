//
// Created by Ilgaz on 2.06.2024.
//
#include "blocks.hpp"
#include <cstdlib>

int label_count = 0;

std::string get_label() {
    label_count += 1;
    return "label_" + std::to_string(label_count - 1);
}

std::string get_temp() {
    return "%temp_" + std::to_string(std::rand());
}

std::ostream &operator<<(std::ostream &os, const Identifier_t &id) {
    os << id.name << "(" << id.llvm_name << ")";
    return os;
}

void IdentifierList_t::insert(Identifier_t *item) {
    if (item == nullptr) return;
    for (const auto &other: this->id_list) {
        if (*item == *other) {
            char str[] = "Declared previously declared identifier %s";
            char str2[1000];
            snprintf(str2, sizeof(str2), str, item->name.c_str());
            yyerror(str2);
        }
    }
    id_list.push_back(item);
}

int IdentifierList_t::size() const {
    return id_list.size();
}

std::ostream &operator<<(std::ostream &os, const IdentifierList_t &ids) {
    auto uset = ids.id_list;
    os << "{";
    for (auto it = uset.begin(); it != uset.end(); ++it) {
        if (it != uset.begin()) {
            os << ", ";
        }
        os << **it;
    }
    os << "}";
    return os;
}


std::ostream &operator<<(std::ostream &os, const Scope_t &scope) {
    auto uset = scope.items;
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
        code += item->llvm_name + " = alloca i32\n";
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

void ArrDecl_t::insert(Array_t *array) {
    ids->insert(array);
    arrays.push_back(array);
}

std::string ArrDecl_t::make_code() const {
    std::string code;
    for (const auto &item: arrays) {
        code += item->llvm_name + " = alloca i32, i32 " + std::to_string(item->length) + "\n";
    }
    return code;
}

void Scope_t::add(Identifier_t *id) {
    auto p = items.insert(*id);
    if (!p.second) {
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

int Scope_t::get_arg_size(Identifier_t *id) const {
    if (type == "function") {
        auto it = items.find(*id);
        if (it == items.end()) {
            std::string errmsg = "Used undeclared " + type + ": " + id->name;
            yyerror(errmsg.c_str());
            return -1;
        }
        Identifier_t* item = const_cast<Identifier_t*>(&(*it));
        FuncIdentifier_t *func = dynamic_cast<FuncIdentifier_t *>(item);
        return func->arg_count;
    }
    return -1;
}

Block_t::Block_t(ConstDecl_t *constDecl, VarDecl_t *varDecl, ArrDecl_t *arrDecl, ProcDecl_t *procDecl,
                 Statement_t *statement) : constDecl(constDecl), varDecl(varDecl), arrDecl(arrDecl), procDecl(procDecl),
                                           statement(statement) {
}

void Block_t::remove_from_scope(Scope_t &scope, Scope_t &proc_scope, Scope_t &array_scope) const {
    constDecl->remove_from_scope(scope);
    varDecl->remove_from_scope(scope);
    procDecl->remove_from_scope(proc_scope);
    arrDecl->remove_from_scope(array_scope);
}

std::string Block_t::make_code() const {
    return constDecl->make_code()
           + varDecl->make_code()
           + procDecl->make_code()
           + arrDecl->make_code()
           + statement->make_code();
}

Function_t::Function_t(Identifier_t *id, IdentifierList_t *identifiers, Block_t *block) : id(id),
                                                                                          identifiers(identifiers),
                                                                                          block(block) {}

std::string Function_t::make_code() const {
    auto str = "define i32 @" + id->name + "(  ";
    bool first = true;
    for (const auto &item: identifiers->id_list) {
        if (first) {
            first = false;
        } else {
            str += ", ";
        }
        str += "i32 %var_" + item->name;
    }
    str += ") {\n";
    for (const auto &item: identifiers->id_list) {
        str += item->llvm_name + " = alloca i32\n"
               + "store i32 %var_" + item->name + ", ptr " + item->llvm_name + "\n";
    }
    str += block->make_code()
           + "ret i32 0\n"
           + "}\n";
    return str;
}

void ProcDecl_t::insert(Proc_t *proc) {
    ids->insert(proc->id);
    procs.push_back(proc);
}

void ProcDecl_t::set_labels(std::vector<std::string> asd) {
    for (const auto &item: procs) {
        item->labels = std::move(asd);
    }
}

std::string ProcDecl_t::make_code() const {
    auto end_label = get_label();
    std::string code = "br label %" + end_label + "\n";
    for (const auto &item: procs) {
        code += item->make_code();
    }
    code += end_label + ":\n";
    return code;
}

std::string Proc_t::make_code() const {
    std::string labels_str;
    bool first = true;
    for (const auto &item: labels) {
        if (first) {
            first = false;
        } else {
            labels_str += ", ";
        }
        labels_str += "label %" + item;
    }
    auto temp = get_temp();
    return "br label %" + id->name + "\n"
           + id->name + ":\n"
           + block->make_code() + "\n"
           + temp + " = call ptr()* @pop()\n"
           + "indirectbr i8* " + temp + ", [" + labels_str + "]\n";
}
