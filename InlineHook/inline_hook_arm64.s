#ifdef __arm64__

.text
.align 4
.globl _get_sp
.globl _syscall_mmap
.globl _syscall_mprotect
.globl _syscall_mach_msg

_get_sp:
    mov x0, sp
    ret

_syscall_mmap:
    mov x16, #197
    svc #0x80
    ret

_syscall_mprotect:
    mov x16, #74
    svc #0x80
    ret

_syscall_mach_msg:
    mov x16, #-31
    svc #0x80
    ret

#endif
