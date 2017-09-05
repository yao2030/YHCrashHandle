//
//  hook_msg_send.c
//  animation
//
//  Created by Elliot on 2017/5/8.
//  Copyright © 2017年 sangfor. All rights reserved.
//

#ifdef __arm64__


#include "inlinehook.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <assert.h>

#include <mach/mach.h>
#include <mach/message.h>
#include <sys/mman.h>

#include <objc/message.h>

#include <dlfcn.h>
#include <mach-o/dyld.h>

#ifndef	__DeclareSendRpc
#define	__DeclareSendRpc(_NUM_, _NAME_)
#endif

#ifndef	__BeforeSendRpc
#define	__BeforeSendRpc(_NUM_, _NAME_)
#endif

#ifndef	__AfterSendRpc
#define	__AfterSendRpc(_NUM_, _NAME_)
#endif

#define msgh_request_port	msgh_remote_port
#define msgh_reply_port		msgh_local_port

#ifdef  __MigPackStructs
#pragma pack(4)
#endif
typedef struct {
    mach_msg_header_t Head;
    mach_msg_body_t msgh_body;
    mach_msg_port_descriptor_t src_task;
    NDR_record_t NDR;
    mach_vm_address_t target_address;
    mach_vm_size_t size;
    mach_vm_offset_t mask;
    int flags;
    mach_vm_address_t src_address;
    boolean_t copy;
    vm_inherit_t inheritance;
} Request __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack()
#endif

#ifdef  __MigPackStructs
#pragma pack(4)
#endif
typedef struct {
    mach_msg_header_t Head;
    NDR_record_t NDR;
    kern_return_t RetCode;
    mach_vm_address_t target_address;
    vm_prot_t cur_protection;
    vm_prot_t max_protection;
    mach_msg_trailer_t trailer;
} Reply __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack()
#endif

#ifdef  __MigPackStructs
#pragma pack(4)
#endif
typedef struct {
    mach_msg_header_t Head;
    NDR_record_t NDR;
    kern_return_t RetCode;
    mach_vm_address_t target_address;
    vm_prot_t cur_protection;
    vm_prot_t max_protection;
} __Reply __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack()
#endif

#ifdef  __MigPackStructs
#pragma pack(4)
#endif
typedef struct {
    mach_msg_header_t Head;
    NDR_record_t NDR;
    kern_return_t RetCode;
    mach_vm_address_t target_address;
    vm_prot_t cur_protection;
    vm_prot_t max_protection;
} __Reply__manual_mach_vm_remap_t __attribute__((unused));
#ifdef  __MigPackStructs
#pragma pack()
#endif

struct instructions_mem {
    uint32_t *mem;
    uint32_t used;
    uint32_t size;
    struct instructions_mem *prev;
};

extern uintptr_t vmemnew(ssize_t len);

static struct instructions_mem *instructions_mem = NULL;

struct instructions_mem *alloc_instructions_mem(int count) {
    if(instructions_mem == NULL || instructions_mem->size - instructions_mem->used < count) {
        uintptr_t mem = vmemnew(vm_page_size);
        
        struct instructions_mem *new_mem = malloc(sizeof(struct instructions_mem));
        new_mem->mem = (uint32_t *)mem;
        new_mem->size = (uint32_t)vm_page_size/4;
        new_mem->used = 0;
        new_mem->prev = NULL;
        
        if(instructions_mem == NULL) {
            instructions_mem = new_mem;
        }else {
            new_mem->prev = instructions_mem;
            instructions_mem = new_mem;
        }
        return new_mem;
    }
    return instructions_mem;
}

static kern_return_t get_page_info(uintptr_t ptr, vm_prot_t *prot_p, vm_inherit_t *inherit_p) {
    vm_address_t region = (vm_address_t) ptr;
    vm_size_t region_len = 0;
    struct vm_region_submap_short_info_64 info;
    mach_msg_type_number_t info_count = VM_REGION_SUBMAP_SHORT_INFO_COUNT_64;
    natural_t max_depth = 99999;
    kern_return_t kr = vm_region_recurse_64(mach_task_self(), &region, &region_len,
                                            &max_depth,
                                            (vm_region_recurse_info_t) &info,
                                            &info_count);
    *prot_p = info.protection & (PROT_READ | PROT_WRITE | PROT_EXEC);
    *inherit_p = info.inheritance;
    return kr;
}

static kern_return_t suspend_other_thread(void) {
    thread_act_array_t threads;
    mach_msg_type_number_t count = 0;
    kern_return_t ret = task_threads(mach_task_self(), &threads, &count);
    assert(ret == 0);
    
    const mach_port_t thread_self = mach_thread_self();
    
    for(int i = 0; i < count; i++) {
        thread_t thread = threads[i];
        if(thread != thread_self) {
            if(thread_suspend(thread) != KERN_SUCCESS) {
                assert(0);
            }
        }
    }
    return 0;
}

static kern_return_t resume_other_thread(void) {
    thread_act_array_t threads;
    mach_msg_type_number_t count = 0;
    kern_return_t ret = task_threads(mach_task_self(), &threads, &count);
    assert(ret == 0);
    
    const mach_port_t thread_self = mach_thread_self();
    
    for(int i = 0; i < count; i++) {
        thread_t thread = threads[i];
        if(thread != thread_self) {
            if(thread_resume(thread) != KERN_SUCCESS) {
                assert(0);
            }
        }
    }
    return 0;
}

static void volatile_memcpy(int8_t *dst, const int8_t *src, ssize_t len) {
    volatile int8_t *_dst = dst;
    while(len--) {
        *_dst++ = *src++;
    }
}

static kern_return_t __MIG_check__Reply__manual_mach_vm_remap_t(__Reply__manual_mach_vm_remap_t *Out0P) {
    typedef __Reply__manual_mach_vm_remap_t __Reply __attribute__((unused));
    unsigned int msgh_size;
    if(Out0P->Head.msgh_id != 4913) {
        if (Out0P->Head.msgh_id == MACH_NOTIFY_SEND_ONCE) {
            return MIG_SERVER_DIED;
        }else {
            return MIG_REPLY_MISMATCH;
        }
    }
    
    msgh_size = Out0P->Head.msgh_size;
    if((Out0P->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX)
       || ((msgh_size != (mach_msg_size_t)sizeof(__Reply)) && (msgh_size != (mach_msg_size_t)sizeof(mig_reply_error_t) || Out0P->RetCode == KERN_SUCCESS))) {
        return MIG_TYPE_ERROR;
    }
    
    if(Out0P->RetCode != KERN_SUCCESS) {
        return ((mig_reply_error_t *)Out0P)->RetCode;
    }
    
    return MACH_MSG_SUCCESS;
}

static kern_return_t syscall_vm_remap(uintptr_t dst, uintptr_t src, ssize_t len, vm_inherit_t inheritance) {
    union {
        Request In;
        Reply Out;
    } Mess;
    
    Request *InP = &Mess.In;
    Reply *Out0P = &Mess.Out;
    
    mach_msg_return_t msg_result;
    kern_return_t check_result;
    mach_port_t task_self = mach_task_self();
    
    __DeclareSendRpc(4813, "mach_vm_remap")
    
    InP->msgh_body.msgh_descriptor_count = 1;
    InP->src_task.name = task_self;
    InP->src_task.disposition = 19;
    InP->src_task.type = MACH_MSG_PORT_DESCRIPTOR;
    InP->NDR = NDR_record;
    InP->target_address = dst;
    InP->size = len;
    InP->mask = 0;
    InP->flags = VM_FLAGS_OVERWRITE;
    InP->src_address = src;
    InP->copy = TRUE;
    InP->inheritance = inheritance;
    InP->Head.msgh_bits = MACH_MSGH_BITS_COMPLEX|MACH_MSGH_BITS(19, MACH_MSG_TYPE_MAKE_SEND_ONCE);
    InP->Head.msgh_request_port = task_self;
    InP->Head.msgh_reply_port = mig_get_reply_port();
    InP->Head.msgh_id = 4813;
    InP->Head.msgh_reserved = 0;
    
    __BeforeSendRpc(4813, "mach_vm_remap")
    
    extern mach_msg_return_t syscall_mach_msg(mach_msg_header_t *msg, mach_msg_option_t option, mach_msg_size_t send_size, mach_msg_size_t rcv_size, mach_port_name_t rcv_name, mach_msg_timeout_t timeout, mach_port_name_t notify);
    msg_result = syscall_mach_msg(&InP->Head, MACH_SEND_MSG|MACH_RCV_MSG|MACH_MSG_OPTION_NONE, (mach_msg_size_t)sizeof(Request), (mach_msg_size_t)sizeof(Reply), InP->Head.msgh_reply_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    
    __AfterSendRpc(4813, "mach_vm_remap")
    assert(msg_result == MACH_MSG_SUCCESS);
    
    check_result = __MIG_check__Reply__manual_mach_vm_remap_t((__Reply__manual_mach_vm_remap_t *)Out0P);
    assert(msg_result == MACH_MSG_SUCCESS);
    
    return KERN_SUCCESS;
}

kern_return_t vmemprotect(uintptr_t addr, int writable) {
    int flag = PROT_READ | PROT_EXEC | (writable? PROT_WRITE: 0);
    kern_return_t ret = mprotect((void *)addr, PAGE_SIZE, flag);
    assert(ret == 0);
    return ret;
}

uintptr_t vmemnew(ssize_t len) {
    ssize_t fix_len = align_up(len, vm_page_size);
    uintptr_t ret = (uintptr_t)mmap(NULL, fix_len, PROT_READ|PROT_WRITE|PROT_EXEC, MAP_ANON|MAP_SHARED, -1, 0);
    assert(ret);
    return ret;
}

kern_return_t vmemcpy(uintptr_t dst, uintptr_t src, ssize_t len) {
    uintptr_t fix_dst = align_down(dst, vm_page_size);
    ssize_t fix_len = align_up(len, vm_page_size);
    
    mach_port_t task_self = mach_task_self();
    
    vm_prot_t prot = 0;
    vm_inherit_t inherit = 0;
    kern_return_t kr = get_page_info(fix_dst, &prot, &inherit);
    assert(kr == 0);
    
    uintptr_t tmp_mem = vmemnew(fix_len);
    
    kr = vm_copy(task_self, fix_dst, fix_len, (vm_address_t)tmp_mem);
    assert(kr == 0);
    //memcpy((void *)tmp_mem, (const void *)fix_dst, fix_len);
    
    suspend_other_thread();
    
    extern void *syscall_mmap(void *, size_t, int, int, int, off_t);
    uintptr_t mmret = (uintptr_t)syscall_mmap((void *)fix_dst, fix_len, PROT_NONE, MAP_ANON|MAP_SHARED|MAP_FIXED, -1, 0);
    assert((mmret&0xfff) == 0);
    
    ssize_t offset = dst - fix_dst;
    volatile_memcpy((int8_t *)(tmp_mem+offset), (const int8_t *)(src), len);
    
    extern int syscall_mprotect(void *, size_t, int);
    kr = syscall_mprotect((void *)tmp_mem, fix_len, prot);
    assert(kr == 0);
    
    syscall_vm_remap(fix_dst, tmp_mem, fix_len, inherit);
    
    munmap((void *)tmp_mem, fix_len);
    
    resume_other_thread();
    
    assert(*((int32_t *)dst) == *((int32_t *)src));
    
    return 0;
}

ssize_t set_inline_header(int32_t *instrunctions, uintptr_t new_call_prepare, uintptr_t orig_call_addr, uint variable_parameter) {
    if(variable_parameter) {
        instrunctions[0] = 0xf81f83f5; //str x21, [sp, #-0x08]  //可变参数，不能破坏栈前数据，由new_call_prepare去还原x21
    }else {
        instrunctions[0] = 0xa9bf7bf5; //stp x21, lr, [sp, #-0x10]! //固定参数，用栈保存x21
    }
    instrunctions[1] = ADRP(X21, (orig_call_addr+4), new_call_prepare);
    instrunctions[2] = ADD(X21, X21, ADDR_OFFSET(new_call_prepare));
    instrunctions[3] = BR(X21);
    
    return 4*sizeof(int32_t);
}

ssize_t set_inline_new_call_prepare(struct instructions_mem *instructions_mem, uintptr_t new_call, uint variable_parameter) {
    uint32_t count = instructions_mem->used;
    instructions_mem->mem[instructions_mem->used++] = ADR(X21, 24);
    instructions_mem->mem[instructions_mem->used++] = LDR(X21, X21, 0);
    instructions_mem->mem[instructions_mem->used++] = BLR(X21);
    instructions_mem->mem[instructions_mem->used++] = 0xa9407bf5;  //ldp x21, lr, [sp]
    instructions_mem->mem[instructions_mem->used++] = ADD(SP, SP, 0x10);
    instructions_mem->mem[instructions_mem->used++] = RET();
    instructions_mem->mem[instructions_mem->used++] = (uint32_t)new_call;
    instructions_mem->mem[instructions_mem->used++] = (uint32_t)(new_call>>32);
    
    return (instructions_mem->used-count)*sizeof(int32_t);
}

ssize_t set_inline_orig_call_prepare(struct instructions_mem *instructions_mem, uintptr_t orig_call, ssize_t header_len) {
    assert(header_len%4 == 0);
    
    uint32_t count = instructions_mem->used;
    uint32_t *mem = instructions_mem->mem+instructions_mem->used;
    memcpy(mem, (void *)orig_call, header_len);
    instructions_mem->used += header_len/4;
    
    instructions_mem->mem[instructions_mem->used++] = ADR(X21, 12);
    instructions_mem->mem[instructions_mem->used++] = LDR(X21, X21, 0);
    instructions_mem->mem[instructions_mem->used++] = BR(X21);
    
    uintptr_t addr = orig_call + header_len;
    instructions_mem->mem[instructions_mem->used++] = (uint32_t)addr;
    instructions_mem->mem[instructions_mem->used++] = (uint32_t)(addr>>32);
    
    for(int i = 0; i < header_len/4; i++) {
        int32_t op = mem[i];
        if(IS_OPCODE(op, OPCODE_B_COND, OPCODE_B_COND_MASK)) {
            int32_t cond = op&0x1f;
            int32_t rel_addr = ((op&(~OPCODE_B_COND_MASK))>>5)<<2;
            uintptr_t new_rel_addr = (uintptr_t)(instructions_mem->mem+instructions_mem->used) - (uintptr_t)(mem+i);
            mem[i] = B_COND(new_rel_addr, cond);
            
            uintptr_t abs_addr = (uintptr_t)(orig_call+i*4) + rel_addr;
            instructions_mem->mem[instructions_mem->used++] = ADR(X21, 12);
            instructions_mem->mem[instructions_mem->used++] = LDR(X21, X21, 0);
            instructions_mem->mem[instructions_mem->used++] = BR(X21);
            instructions_mem->mem[instructions_mem->used++] = (uint32_t)abs_addr;
            instructions_mem->mem[instructions_mem->used++] = (uint32_t)(abs_addr>>32);
        }
    }
    
    return (instructions_mem->used-count)*sizeof(int32_t);
}

uintptr_t find_lookUpImpOrNil(void) {
    uintptr_t ret = 0;
    uint32_t *pMsgSend = (uint32_t *)class_getMethodImplementation;
    
    for(int i = 0; i < 100; i++) {
        uint32_t instruction = pMsgSend[i];
        if(IS_OPCODE(instruction, OPCODE_BL, OPCODE_BL_MASK)) {
            uintptr_t addr = instruction & (~OPCODE_BL);
            addr <<= 2;
            ret = (uintptr_t)&pMsgSend[i] + addr;
            break;
        }else if(IS_OPCODE(instruction, OPCODE_RET, OPCODE_RET_MASK)) {
            break;
        }
    }
    assert(ret);
    return ret;
}

kern_return_t inline_hook(struct rebinding *rebinding, uintptr_t *orig_call_ret) {
    
    assert(rebinding->name && rebinding->new_call);
    
    uintptr_t orig_call = (uintptr_t)dlsym(RTLD_DEFAULT, rebinding->name);
    assert(orig_call);
    
    struct instructions_mem *newmem = alloc_instructions_mem(128);
    vmemprotect((uintptr_t)newmem->mem, 1);
    
    int32_t instructions[32];
    ssize_t len;
    
    if(rebinding->variable_parameter) { //如果是可变参数，new_call必须是汇编实现，且new_call-4的地方放置ldr x21, [sp, #-8]的指令
        len = set_inline_header(instructions, rebinding->new_call-4, orig_call, rebinding->variable_parameter);
    }else {
        len = set_inline_header(instructions, (uintptr_t)(newmem->mem+newmem->used), orig_call, rebinding->variable_parameter);
        set_inline_new_call_prepare(newmem, rebinding->new_call, rebinding->variable_parameter);
    }
    
    uintptr_t orig_call_fix = (uintptr_t)(newmem->mem+newmem->used);
    set_inline_orig_call_prepare(newmem, orig_call, len);
    
    if(orig_call_ret) {
        *orig_call_ret = orig_call_fix;
    }
    
    vmemprotect((uintptr_t)newmem->mem, 0);
    
    suspend_other_thread();
    vmemcpy((uintptr_t)orig_call, (uintptr_t)instructions, len);
    resume_other_thread();
    
    return 0;
}

#endif
