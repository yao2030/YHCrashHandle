//
//  hook_msg_send.h
//  animation
//
//  Created by Elliot on 2017/5/8.
//  Copyright © 2017年 sangfor. All rights reserved.
//

#ifdef __arm64__


#ifndef inlinehook_h
#define inlinehook_h

#include <stdio.h>
#include <mach/mach.h>

#define X0      (0)
#define X1      (1)
#define X2      (2)
#define X3      (3)
#define X4      (4)
#define X5      (5)
#define X6      (6)
#define X7      (7)
#define X8      (8)
#define X9      (9)
#define X10     (10)
#define X11     (11)
#define X12     (12)
#define X13     (13)
#define X14     (14)
#define X15     (15)
#define X16     (16)
#define X17     (17)
#define X18     (18)
#define X19     (19)
#define X20     (20)
#define X21     (21)
#define X22     (22)
#define X23     (23)
#define X24     (24)
#define X25     (25)
#define X26     (26)
#define X27     (27)
#define X28     (28)
#define X29     (29)
#define X30     (30)
#define FP      X29
#define LR      X30
#define SP      (31)

#define OPCODE_BR           (0xd61f0000)
#define OPCODE_BLR          (OPCODE_BR+(1<<21))
#define OPCODE_B            (0x14000000)
#define OPCODE_B_COND       (0x54000000)
#define OPCODE_B_COND_MASK  (0xfc000000)
#define OPCODE_BL           (0x94000000)
#define OPCODE_BL_MASK      (0xfc000000)
#define OPCODE_ARD          (0x10000000)
#define OPCODE_LDR          (0xf9400000)
#define OPCODE_ADRP         (0x90000000)
#define OPCODE_ADD          (0x91000000)
#define OPCODE_RET          (0xd65f03c0)
#define OPCODE_RET_MASK     (0xffffffff)


#define BR(reg)                 ((uint32_t)(OPCODE_BR   + ((reg)<<5)))
#define BLR(reg)                ((uint32_t)(OPCODE_BLR  + ((reg)<<5)))
#define B(off)                  ((uint32_t)(OPCODE_B    + ((off)>>2)))
#define B_COND(off, cond)       ((uint32_t)(OPCODE_B_COND + (((off)>>2)<<5) + (cond)))
#define BL(off)                 ((uint32_t)(OPCODE_BL   + ((BIT_LIMIT(off, 28))>>2)))     //28bit相对跳转
#define ADR(reg, off)           ((uint32_t)(OPCODE_ARD  + (((off)>>2)<<5)) + reg)
#define LDR(reg1, reg2, off)    ((uint32_t)(OPCODE_LDR  + reg1 + (reg2<<5) + (off<<10)))
#define ADD(reg1, reg2, val)    ((uint32_t)(OPCODE_ADD  + reg1 + (reg2<<5) + (BIT_LIMIT(val, 12)<<10)))  //val [0, 4095]
#define RET()                   ((uint32_t)OPCODE_RET)

#define IS_OPCODE(inst, opcode, mask)   (((inst)&(mask)) == (opcode))

#define PAGE_BIT            (12)
#define ADDR_OFFSET(addr)   (((uintptr_t)(addr))&((1<<(PAGE_BIT+1))-1))
#define ADDR_PAGE(addr)     (((uintptr_t)(addr)) >> PAGE_BIT)
#define BIT_LIMIT(val, bit) ((val)&((1<<(bit))-1))

#define align_up(val, ali)      ((((val)+(ali)-1)/(ali))*(ali))
#define align_down(val, ali)    (((val)/(ali))*(ali))

static inline uint32_t ADRP(uint reg, uintptr_t pc, uintptr_t addr) {
    uint64_t diff = align_down(addr, 1<<12) - align_down(pc, 1<<12);
    return (uint32_t)(OPCODE_ADRP | reg | ((diff & 0x3000) << 17) | ((diff & 0x1ffffc000) >> 9));
}

struct rebinding {
    const char *name;
    uintptr_t new_call;
    uint8_t variable_parameter;
};

uintptr_t find_lookUpImpOrNil(void);

kern_return_t inline_hook(struct rebinding *rebinding, uintptr_t *orig_call);

#endif /* inlinehook_h */


#endif
