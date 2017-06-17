//
//  AppStack.m
//  AppStack
//
//  Created by luqizhou on 16/9/20.
//  Copyright © 2016年 sangfor. All rights reserved.
//

#import "AppStack.h"
#import <UIKit/UIKit.h>

#include <pthread.h>
#include <mach/mach.h>
#include <sys/types.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>


#if defined(__arm64__)
#define ADDR_FMT                "0x%016lx"
#define NLIST                   struct nlist_64
#define THREAD_STATE_COUNT      ARM_THREAD_STATE64_COUNT
#define THREAD_STATE            ARM_THREAD_STATE64
#define FRAME_POINTER           __fp
#define STACK_POINTER           __sp
#define INSTRUCTION_ADDRESS     __pc

#elif defined(__arm__)
#define ADDR_FMT                "0x%08lx"
#define NLIST                   struct nlist
#define THREAD_STATE_COUNT      ARM_THREAD_STATE_COUNT
#define THREAD_STATE            ARM_THREAD_STATE
#define FRAME_POINTER           __r[7]
#define STACK_POINTER           __sp
#define INSTRUCTION_ADDRESS     __pc

#elif defined(__x86_64__)
#define ADDR_FMT                "0x%016lx"
#define NLIST                   struct nlist_64
#define THREAD_STATE_COUNT      x86_THREAD_STATE64_COUNT
#define THREAD_STATE            x86_THREAD_STATE64
#define FRAME_POINTER           __rbp
#define STACK_POINTER           __rsp
#define INSTRUCTION_ADDRESS     __rip

#elif defined(__i386__)
#define ADDR_FMT                "0x%08lx"
#define NLIST                   struct nlist
#define THREAD_STATE_COUNT      x86_THREAD_STATE32_COUNT
#define THREAD_STATE            x86_THREAD_STATE32
#define FRAME_POINTER           __ebp
#define STACK_POINTER           __esp
#define INSTRUCTION_ADDRESS     __eip

#else
#error unknown arch

#endif


typedef struct StackFrame {
    const struct StackFrame *prev;
    const void *lr;
} StackFrame;

@implementation AppStack

static thread_t mainThread = 0;

+ (void)load {
    mainThread = mach_thread_self();
}

+ (NSString *)mainCallStack {
    return [self callStack:&mainThread andCount:1].firstObject;
}

+ (NSString *)currentCallStack {
    const thread_t currentThread = mach_thread_self();
    return [self callStack:&currentThread andCount:1].firstObject;
}

+ (NSString *)allCallStack {
    thread_act_array_t threads;
    mach_msg_type_number_t threadCount = 0;
    const mach_port_t currentThread = mach_thread_self();
    
    kern_return_t ret = task_threads(mach_task_self(), &threads, &threadCount);
    if(ret != KERN_SUCCESS) {
        return nil;
    }
    NSArray *callStacks = [self callStack:threads andCount:threadCount];
    NSAssert(callStacks.count == threadCount, nil);
    NSMutableString *desc = [NSMutableString string];
    for(int i = 0; i < threadCount; i++) {
        thread_t thread = ((thread_t *)threads)[i];
        NSString *header = [NSString stringWithFormat:@"Thread %d %@ %@:", i, ((thread==mainThread)? @"Main": @""), ((thread==currentThread)? @"Current": @"")];
        [desc appendFormat:@"%@\n%@\n", header, callStacks[i]];
    }
    
    [desc appendFormat:@"\n%@\n", [self imageAddrDescription]];
    
    return desc;
}

+ (NSArray *)callStack:(const thread_t *)threads andCount:(int)count {
    NSMutableArray *description = [NSMutableArray array];
    const mach_port_t currentThread = mach_thread_self();
    for(int i = 0; i < count; i++) {
        BOOL resume = NO;
        thread_t thread = threads[i];
        if(thread != currentThread) {
            if(thread_suspend(thread) == KERN_SUCCESS) {
                resume = YES;
            }
        }
        
        NSString *threadStack = [self callStackOfThread:thread];
        if(threadStack) {
            [description addObject:threadStack];
        }else {
            [description addObject:@"<null>"];
        }
        
        if(resume) {
            thread_resume(thread);
        }
    }
    return description;
}

+ (NSString *)callStackOfThread:(thread_t)thread {
    
    static const int bsStackSize = 50;
    const void *bsBuffer[bsStackSize] = {0};
    int bsOffset = 0;
    
    _STRUCT_MCONTEXT context = {0};
    mach_msg_type_number_t stateCount = THREAD_STATE_COUNT;
    kern_return_t ret = thread_get_state(thread, THREAD_STATE, (thread_state_t)&context.__ss, &stateCount);
    if(ret != KERN_SUCCESS) {
        return nil;
    }
    
    const void *pc = (void *)context.__ss.INSTRUCTION_ADDRESS;
    if(pc == NULL) {
        return nil;
    }
    bsBuffer[bsOffset++] = pc;
    
    BOOL success = YES;
    StackFrame frame = {0};
    const void *framePtr = (void *)context.__ss.FRAME_POINTER;
    
#if defined(__arm__) || defined(__arm64__)
    const void *lr = (void *)context.__ss.__lr;
    bsBuffer[bsOffset++] = lr;
#else
    const void *lr = (void *)context.__ss.STACK_POINTER;
    if(framePtr == NULL || [self vmCopy:lr to:&frame size:sizeof(frame)] != KERN_SUCCESS) {
        return nil;
    }
    lr = frame.prev;
    bsBuffer[bsOffset++] = lr;
#endif
    
    do {
        if(framePtr == NULL || [self vmCopy:(void *)framePtr to:&frame size:sizeof(frame)] != KERN_SUCCESS) {
            success = NO;
            break;
        }
        bsBuffer[bsOffset++] = frame.lr;
        framePtr = frame.prev;
    }while(frame.lr != NULL && frame.prev != NULL && bsOffset < bsStackSize);
    
    if(success == NO) {
        return nil;
    }
    
    return [self symbolicate:(void **)bsBuffer];
}

+ (kern_return_t)vmCopy:(const void *)from to:(void *)to size:(size_t)size {
    vm_size_t bytes = 0;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)from, (vm_size_t)size, (vm_address_t)to, &bytes);
}

+ (NSString *)symbolicate:(void **)bsBuffer {
    if(bsBuffer == NULL) {
        return nil;
    }
    
    NSMutableArray *symbols = [NSMutableArray array];
    
    void *addr = *bsBuffer;
    while(addr) {
        [symbols addObject:[self symbolicateOfAddr:addr]];
        bsBuffer++;
        addr = *bsBuffer;
    }
    
    NSMutableString *str = [NSMutableString string];
    for(int i = 0; i < symbols.count; i++) {
        [str appendFormat:@"%-3d %@\n", i, symbols[i]];
    }
    
    return str;
}

+ (void *)cmdInHeader:(const struct mach_header *)header {
    void *ret = NULL;
    switch(header->magic) {
        case MH_MAGIC:
        case MH_CIGAM:
            ret = (void *)(header + 1);
            break;
        case MH_MAGIC_64:
        case MH_CIGAM_64:
            ret = (void *)(((struct mach_header_64 *)header) + 1);
            break;
    }
    return ret;
}

+ (int)indexOfImageHeader:(void *)address {
    
    for(int i = 0; i < _dyld_image_count(); i++) {
        const struct mach_header *header = _dyld_get_image_header(i);
        if(header != NULL) {
            const void *cmd = [self cmdInHeader:header];
            intptr_t offset = (intptr_t)address - _dyld_get_image_vmaddr_slide(i);
            if(cmd == NULL) {
                continue;
            }
            for(int j = 0; j < header->ncmds; j++) {
                const struct load_command *loadCmd = (struct load_command *)cmd;
                if(loadCmd->cmd == LC_SEGMENT) {
                    const struct segment_command *segCmd = (struct segment_command *)cmd;
                    if(offset >= segCmd->vmaddr && offset < segCmd->vmaddr + segCmd->vmsize) {
                        return i;
                    }
                }else if(loadCmd->cmd == LC_SEGMENT_64) {
                    const struct segment_command_64 *segCmd = (struct segment_command_64*)cmd;
                    if(offset >= segCmd->vmaddr && offset < segCmd->vmaddr + segCmd->vmsize) {
                        return i;
                    }
                }
                cmd += loadCmd->cmdsize;
            }
        }
    }
    return -1;
}

+ (void *)segmentBaseOfImageIndex:(int)index {
    const struct mach_header *header = _dyld_get_image_header(index);
    const void *cmd = [self cmdInHeader:header];
    
    if(cmd == NULL) {
        return NULL;
    }
    
    for(int i = 0; i < header->ncmds; i++) {
        const struct load_command *loadCmd = (struct load_command *)cmd;
        if(loadCmd->cmd == LC_SEGMENT) {
            const struct segment_command *segmentCmd = (struct segment_command *)cmd;
            if(strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0) {
                return (void *)((long)(segmentCmd->vmaddr - segmentCmd->fileoff));
            }
        }else if(loadCmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segmentCmd = (struct segment_command_64 *)cmd;
            if(strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0) {
                return (void *)(segmentCmd->vmaddr - segmentCmd->fileoff);
            }
        }
        cmd += loadCmd->cmdsize;
    }
    return NULL;
}

+ (NSString *)symbolicateOfAddr:(void *)address {
    
    int index = [self indexOfImageHeader:address];
    if(index < 0) {
        return [self descriptionForAddress:address baseAddress:NULL imgName:NULL funcName:NULL];
    }
    
    const struct mach_header *header = _dyld_get_image_header(index);
    const void *cmd = [self cmdInHeader:header];
    intptr_t imageBase = (intptr_t)_dyld_get_image_vmaddr_slide(index);
    intptr_t offset = (intptr_t)address - imageBase;
    intptr_t segmentBase = (intptr_t)[self segmentBaseOfImageIndex:index] + imageBase;
    intptr_t bestDistance = INT_MAX;
    const NLIST *bestMatch = NULL;
    
    for(int i = 0; i < header->ncmds; i++) {
        const struct load_command *loadCmd = (struct load_command *)cmd;
        if(loadCmd->cmd == LC_SYMTAB) {
            const struct symtab_command *symtabCmd = (struct symtab_command *)loadCmd;
            const uintptr_t stringTable = segmentBase + symtabCmd->stroff;
            const NLIST *symbolTable = (NLIST *)(segmentBase + symtabCmd->symoff);
            
            for(int j = 0; j < symtabCmd->nsyms; j++) {
                if(symbolTable[j].n_value != 0) {
                    uintptr_t symbolBase = symbolTable[j].n_value;
                    uintptr_t currentDistance = offset - symbolBase;
                    if((offset >= symbolBase) && (currentDistance <= bestDistance)) {
                        bestMatch = &symbolTable[j];
                        bestDistance = currentDistance;
                    }
                }
            }
            
            if(bestMatch != NULL) {
                const void *funcBase = (void *)(bestMatch->n_value + imageBase);
                const char *funcName = (char *)((intptr_t)stringTable + (intptr_t)bestMatch->n_un.n_strx);
                const char *imgName = _dyld_get_image_name(index);
                imgName = imgName? (strrchr(imgName, '/') + 1): imgName;
                if(funcName && *funcName == '_') {
                    funcName++;
                }
                
                return [self descriptionForAddress:address baseAddress:(void *)funcBase imgName:imgName funcName:funcName];
            }
        }
        cmd += loadCmd->cmdsize;
    }
    
    return [self descriptionForAddress:address baseAddress:NULL imgName:NULL funcName:NULL];
}

+ (NSString *)descriptionForAddress:(const void *)address baseAddress:(const void *)baseAddress imgName:(const char *)imgName funcName:(const char *)funcName {
    intptr_t offset = (intptr_t)(address - baseAddress);
    if(imgName == NULL) {
        imgName = "???";
    }
    if(funcName == NULL) {
        funcName = [NSString stringWithFormat:@"0x%lx", (intptr_t)baseAddress].UTF8String;
    }
    
    return [NSString stringWithFormat:@"%-36s " ADDR_FMT " %s + %lu", imgName, (intptr_t)address, funcName, offset];
}

+ (NSString *)viewStack {
#if (!defined __OPTIMIZE__) || (defined __COMPLIE_ENTERPRISE__)
    
    //这是个简单加密后的recursiveDescription字符串，是私有api，所以通过字符串拼接的方式生成selector进行方法调用
    static unsigned char uiStackSelectorBinary[] = {0xcd,0xe4,0xde,0xd4,0xcd,0xce,0xd8,0xd1,0xe4,0xc3,0xe4,0xce,0xde,0xcd,0xd8,0xcf,0xd3,0xd8,0xda,0xd9};
    unsigned char selector[128] = {0};
    for(int i = 0; i < sizeof(uiStackSelectorBinary); i++) {
        unsigned char c = uiStackSelectorBinary[i];
        selector[i] = (c-0xa5)^0x5a;
    }
    
    SEL sel = NSSelectorFromString([NSString stringWithUTF8String:(char *)selector]);
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    NSArray *windows = [UIApplication sharedApplication].windows;
    NSMutableString *description = [NSMutableString string];
    
    for(UIWindow *w in windows) {
        _Pragma("clang diagnostic push")
        _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"")
        NSString *stack = [w performSelector:sel withObject:nil];
        _Pragma("clang diagnostic pop")
        
        if([stack isKindOfClass:[NSString class]]) {
            [description appendString:@"\r\n\r\n"];
            if(w == keyWindow) {
                [description appendString:@"keyWindow\r\n"];
            }
            [description appendString:stack];
        }
    }
    
    return description;
#else
    return @"此功能因为使用到私有API，所以APP Store版不开放";
#endif
}

+ (NSString *)imageAddrDescription
{
    NSMutableSet *dylibs = [NSMutableSet setWithObjects:@"UIKit", @"GraphicsServices", @"ImageIO", @"CFNetwork", @"AVFoundation", @"Foundation", @"CoreFoundation", @"CoreLocation", @"CoreData", @"CoreGraphics", @"libobjc.A.dylib", @"libsystem_kernel.dylib", @"libsystem_pthread.dylib", @"libdispatch.dylib", nil];
    
    NSString *executableName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"];
    if(executableName) {
        [dylibs addObject:executableName];
    }
    
    NSMutableString *description = [NSMutableString string];
    
    for(int i = 0; i < _dyld_image_count(); i++) {
        const struct mach_header* header = _dyld_get_image_header(i);
        const char *name = _dyld_get_image_name(i);
        if(name == NULL) {
            continue;
        }
        
        NSString *imageName = [[NSString stringWithUTF8String:name] lastPathComponent];
        if(imageName == nil || [dylibs containsObject:imageName] == NO) {
            continue;
        }
        
        uintptr_t cmdPtr = (uintptr_t)[self cmdInHeader:header];
        if(cmdPtr == 0) {
            continue;
        }
        
        uint8_t *uuid = NULL;
        
        for(uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
            struct load_command* loadCmd = (struct load_command*)cmdPtr;
            switch(loadCmd->cmd) {
                case LC_UUID: {
                    struct uuid_command* uuidCmd = (struct uuid_command*)cmdPtr;
                    uuid = uuidCmd->uuid;
                    break;
                }
            }
            cmdPtr += loadCmd->cmdsize;
        }
        
        cpu_type_t majorCode = header->cputype;
        cpu_subtype_t minorCode = header->cpusubtype;
        NSString *archDesc = [self cpuArchWithMajor:majorCode minor:minorCode];
        NSString *s = [self imageDescriptionWithName:imageName baseAddr:(NSInteger)header cpuDesc:archDesc uuid:uuid];
        [description appendString:s];
    }
    
    return description;
}

+ (NSString *)cpuArchWithMajor:(NSInteger)majorCode minor:(NSInteger)minorCode
{
    switch(majorCode) {
        case CPU_TYPE_ARM: {
            switch (minorCode) {
                case CPU_SUBTYPE_ARM_V6:
                    return @"armv6";
                case CPU_SUBTYPE_ARM_V7:
                    return @"armv7";
                case CPU_SUBTYPE_ARM_V7F:
                    return @"armv7f";
                case CPU_SUBTYPE_ARM_V7K:
                    return @"armv7k";
                case CPU_SUBTYPE_ARM_V7S:
                    return @"armv7s";
                default:
                    return @"arm";
            }
            break;
        }
        case CPU_TYPE_ARM64:
            return @"arm64";
        case CPU_TYPE_X86:
            return @"x86";
        case CPU_TYPE_X86_64:
            return @"x86_64";
    }
    
    return nil;
}

+ (NSString *)imageDescriptionWithName:(NSString *)name baseAddr:(NSInteger)baseAddr cpuDesc:(NSString *)cpuDesc uuid:(const unsigned char *)uuid
{
    NSString *description = nil;
#if(__SIZE_WIDTH__ == 32)
    description = [NSString stringWithFormat:@"" ADDR_FMT " %@ %@ %@\n", baseAddr, name, cpuDesc, [self uuidStrFromBytes:uuid]];
#elif(__SIZE_WIDTH__ == 64)
    description = [NSString stringWithFormat:@"" ADDR_FMT " %@ %@ %@\n", baseAddr, name, cpuDesc, [self uuidStrFromBytes:uuid]];
#endif
    
    return description;
}

+ (NSString *)uuidStrFromBytes:(const unsigned char *)bytes
{
    if(bytes == NULL) {
        return nil;
    }
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"<"];
    for(int i = 0; i < 16; i++) {
        [str appendFormat:@"%02x", bytes[i]];
    }
    [str appendFormat:@">"];
    return str;
}

@end
