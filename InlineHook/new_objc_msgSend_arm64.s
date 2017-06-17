#ifdef __arm64__

.text
.align 4
.globl _new_objc_msgSend

.macro LOAD_D0_D31
ldp d0 , d1, [$0, #0x00]
ldp d2 , d3, [$0, #0x10]
ldp d4 , d5, [$0, #0x20]
ldp d6 , d7, [$0, #0x30]
ldp d8 , d9, [$0, #0x40]
ldp d10, d11, [$0, #0x50]
ldp d12, d13, [$0, #0x60]
ldp d14, d15, [$0, #0x70]
ldp d16, d17, [$0, #0x80]
ldp d18, d19, [$0, #0x90]
ldp d20, d21, [$0, #0xa0]
ldp d22, d23, [$0, #0xb0]
ldp d24, d25, [$0, #0xc0]
ldp d26, d27, [$0, #0xd0]
ldp d28, d29, [$0, #0xe0]
ldp d30, d31, [$0, #0xf0]
.endmacro

.macro STORE_D0_D31
stp d0 , d1, [$0, #0x00]
stp d2 , d3, [$0, #0x10]
stp d4 , d5, [$0, #0x20]
stp d6 , d7, [$0, #0x30]
stp d8 , d9, [$0, #0x40]
stp d10, d11, [$0, #0x50]
stp d12, d13, [$0, #0x60]
stp d14, d15, [$0, #0x70]
stp d16, d17, [$0, #0x80]
stp d18, d19, [$0, #0x90]
stp d20, d21, [$0, #0xa0]
stp d22, d23, [$0, #0xb0]
stp d24, d25, [$0, #0xc0]
stp d26, d27, [$0, #0xd0]
stp d28, d29, [$0, #0xe0]
stp d30, d31, [$0, #0xf0]
.endmacro

.macro LOAD_X0_X18
ldp x0, x1, [$0, #0x08*0]
ldp x2, x3, [$0, #0x08*2]
ldp x4, x5, [$0, #0x08*4]
ldp x6, x7, [$0, #0x08*6]
ldp x8, x9, [$0, #0x08*8]
ldp x10, x11, [$0, #0x08*10]
ldp x12, x13, [$0, #0x08*12]
ldp x14, x15, [$0, #0x08*14]
ldp x16, x17, [$0, #0x08*16]
ldr x18, [$0, #0x08*18]
.endmacro

.macro STORE_X0_X18
stp x0, x1, [$0, #0x08*0]
stp x2, x3, [$0, #0x08*2]
stp x4, x5, [$0, #0x08*4]
stp x6, x7, [$0, #0x08*6]
stp x8, x9, [$0, #0x08*8]
stp x10, x11, [$0, #0x08*10]
stp x12, x13, [$0, #0x08*12]
stp x14, x15, [$0, #0x08*14]
stp x16, x17, [$0, #0x08*16]
str x18, [$0, #0x08*18]
.endmacro

_new_objc_msgSend_fix:
    ldr x21, [sp, #-0x8]
_new_objc_msgSend:
    sub sp, sp, #0x20+0x08*20       //在sp开辟空间用来备份寄存器
    stp x19, x20, [sp]              //备份x19,x20,x21,lr,x0~x18,
    stp x21, lr, [sp, #0x10]
    add x21, sp, #0x20
    STORE_X0_X18 x21
    adrp x20, _functionStorage@PAGE //取出funBak，x20=funBak
    add x20, x20,_functionStorage@PAGEOFF
    ldr x21, [x20, #0x18]           //加载funBak.get_register_storage地址，并调用
    blr x21
    mov x19, x0                     //x19=regBak，struct RegisterStorage，当前线程当前函数的寄存器缓存空间
    ldp x0, x1, [sp]                //取出原来的x19，x20，并备份到regBak
    stp x0, x1, [x19]
    ldp x0, x1, [sp, #0x10]         //取出原来的x21，lr，并备份到regBak
    stp x0, x1, [x19, #0x10]
    add x21, sp, #0x20              //取出原来的x0~x18，并备份到regBak
    LOAD_X0_X18 x21
    add x21, x19, #8*4
    STORE_X0_X18 x21
    add x21, x19, #8*24             //备份所有浮点寄存器
    STORE_D0_D31 x21
    add sp, sp, #0x20+0x08*20       //还原sp
    ldr x21, [x20, #0x00]           //载入funBak.will_call并跳转
    blr x21
    add x21, x19, #8*4              //还原x0~x18
    LOAD_X0_X18 x21
    add x21, x19, #8*24             //还原所有浮点寄存器
    LOAD_D0_D31 x21
    ldr x21, [x20, #0x08]           //载入funBak.orig_call并跳转
    blr x21
    stp x0, x1, [x19, #8*56]        //备份函数返回值regBak.ret0=x0 regBak.ret1=x1
    add x21, x19, #8*24             //备份所有浮点寄存器(返回值)
    STORE_D0_D31 x21
    add x21, x19, #8*4             //还原x0~x18
    LOAD_X0_X18 x21
    ldr x21, [x20, #0x10]           //载入funBak.did_call并跳转
    blr x21
    add x21, x19, #8*24             //还原所有浮点寄存器
    LOAD_D0_D31 x21
    ldp x0, x1, [x19, #8*56]        //还原返回值x0=regBak.ret0 x1=regBak.ret1
    ldp x21, lr, [x19, #0x10]       //还原x19,x20,x21,lr
    ldp x19, x20, [x19]
    ret

#endif
