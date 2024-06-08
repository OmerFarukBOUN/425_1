@stack = dso_local global [1000 x ptr] undef
@sp    = global i64 undef;

define dso_local void @push(ptr %val) {
    %sp   = load i64, i64* @sp
    %addr = getelementptr inbounds [1000 x ptr], ptr @stack, i64 0, i64 %sp

    store ptr %val, ptr %addr

    %newsp = add i64 %sp, 1
    store i64 %newsp, i64* @sp

    ret void
}

define ptr @peek() {
    %sp    = load i64, i64* @sp
    %topsp = sub i64 %sp, 1
    %addr  = getelementptr [1000 x ptr], ptr @stack, i64 0, i64 %topsp
    %val   = load ptr, ptr %addr

    ret ptr %val
}

define ptr @pop() {
    %val = call ptr()* @peek()

    %sp    = load i64, i64* @sp
    %newsp = sub i64 %sp, 1
    store i64 %newsp, i64* @sp

    ret ptr %val
}

@.str.d = private unnamed_addr constant [3 x i8] c"%d\00"
@.str.dn = private unnamed_addr constant [4 x i8] c"%d\0A\00"
declare i32 @printf(ptr noundef, ...)
declare i32 @scanf(ptr noundef, ...)

