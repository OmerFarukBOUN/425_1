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


@.str = private unnamed_addr constant [7 x i8] c"teast\0A\00"
@.str2 = private unnamed_addr constant [7 x i8] c"tttst\0A\00"

define i32 @main() {
  call void(ptr)* @push(ptr blockaddress(@main, %d))
  call void(ptr)* @push(ptr blockaddress(@main, %a))
  call void(ptr)* @push(ptr blockaddress(@main, %b))
br label %c
c:
  %6 = call ptr()* @pop()
  indirectbr i8* %6, [label %a, label %b, label %c, label %d]
br label %a
a:
  %10 = call i32 (ptr, ...) @printf(ptr noundef @.str)
  br label %b
b:
  %11 = call i32 (ptr, ...) @printf(ptr noundef @.str2)
br label %c
d:
  ret i32 0
}

declare i32 @printf(ptr noundef, ...) #1