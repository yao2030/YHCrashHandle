//
//  NSObject+zombie.m
//  MOA
//
//  Created by luqizhou on 15-2-28.
//  Copyright (c) 2015年 moa. All rights reserved.
//

#import "NSObject+zombie.h"
#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

#import <dlfcn.h>
#import <sys/types.h>

typedef struct
{
    void *objAddr;
    const char *className;
}Zombie;

#if(__SIZE_WIDTH__ > 32)
#define DEFAULT_ZOMBIE_CAHE_SIZE    (4*1024*1024)
#else
#define DEFAULT_ZOMBIE_CAHE_SIZE    (2*1024*1024)
#endif

static OSSpinLock spinlock = OS_SPINLOCK_INIT;
Zombie *pZombieArray = NULL;
int zombieOffset = 0;
int zombieCount = 0;
/*
static void (*CFOriginDealloc)(CFTypeRef obj);

struct rebinding {
    char *name;
    void *replacement;
};

int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

void CFZombieDealloc(CFTypeRef obj)
{
    CFOriginDealloc(obj);
}

typedef struct objc_classs *Classs;
struct objc_classs {
    Classs isa;
    Classs super_class;
    const char *name;
    long version;
    long info;
    long instance_size;
    void *ivars;
    void **methodLists;
    void *cache;
    void *protocols;
};*/

@implementation NSObject (zombie)

+ (void)enableZombie:(int)cacheSize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        int zombieCacheSize = (cacheSize <= 0 || cacheSize >= DEFAULT_ZOMBIE_CAHE_SIZE)? DEFAULT_ZOMBIE_CAHE_SIZE: cacheSize;
        
        pZombieArray = malloc(zombieCacheSize);
        if(pZombieArray)
        {
            zombieOffset = 0;
            zombieCount = zombieCacheSize/sizeof(Zombie);
            memset(pZombieArray, 0, zombieCacheSize);
            
            Method orgMethod = class_getInstanceMethod([NSObject class], NSSelectorFromString(@"dealloc"));
            Method newMethod = class_getInstanceMethod([NSObject class], @selector(zombieDealloc));
            method_exchangeImplementations(orgMethod, newMethod);
        }
        
//        char *method = "CFRelease";
//        CFOriginDealloc = dlsym(RTLD_DEFAULT, method);
//        rebind_symbols((struct rebinding[1]){{method, CFZombieDealloc}}, 1);
        
//        @autoreleasepool {
//            NSString *s = [NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]];
//            
//            struct objc_classs *obj = (__bridge struct objc_classs *)s;
//            NSLog(@"%s", object_getClassName(s));
//            NSLog(@"%s", obj->isa->name);
//            
//            CFRelease((__bridge CFTypeRef)(s));
//            CFRelease((__bridge CFTypeRef)(s));
//            CFRelease((__bridge CFTypeRef)(s));
//            CFRelease((__bridge CFTypeRef)(s));
//            s = nil;
//        }
    });
}

+ (NSArray *)findZombie:(void *)addr
{
    if(zombieCount <= 0 || addr == NULL)
    {
        return nil;
    }
    
    NSMutableArray *classNameArray = [NSMutableArray array];
    
    OSSpinLockLock(&spinlock);
    
    for(int i = zombieOffset - 1; i > 0; i--)
    {
        Zombie *zombie = &pZombieArray[i];
        if(zombie->objAddr == addr)
        {
            NSAssert(zombie->className, nil);
            [classNameArray addObject:[NSString stringWithCString:zombie->className encoding:NSUTF8StringEncoding]];
        }
    }
    
    for(int i = zombieCount - 1; i >= zombieOffset; i--)
    {
        Zombie *zombie = &pZombieArray[i];
        if(zombie->objAddr == NULL)
        {
            break;
        }
        else if(zombie->objAddr == addr)
        {
            NSAssert(zombie->className, nil);
            [classNameArray addObject:[NSString stringWithCString:zombie->className encoding:NSUTF8StringEncoding]];
        }
    }
    
    OSSpinLockUnlock(&spinlock);
    
    return classNameArray;
}

- (void)zombieDealloc
{
    OSSpinLockLock(&spinlock);
    Zombie *zombie = &pZombieArray[zombieOffset];
    if(++zombieOffset >= zombieCount)
    {
        zombieOffset = 0;
    }
    OSSpinLockUnlock(&spinlock);
    
    const char *className = object_getClassName(self);
    NSAssert(className, nil);
    
    zombie->objAddr = (__bridge void *)self;
    zombie->className = className;
    
    [self zombieDealloc];
}

@end
/*
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>

#ifdef __LP64__
typedef struct mach_header_64 mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct section_64 section_t;
typedef struct nlist_64 nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64
#else
typedef struct mach_header mach_header_t;
typedef struct segment_command segment_command_t;
typedef struct section section_t;
typedef struct nlist nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif

//struct rebinding {
//    char *name;
//    void *replacement;
//};

struct rebindings_entry {
    struct rebinding *rebindings;
    size_t rebindings_nel;
    struct rebindings_entry *next;
};

static struct rebindings_entry *_rebindings_head = NULL;
static int prepend_rebindings(struct rebindings_entry **rebindings_head,
                              struct rebinding rebindings[],
                              size_t nel) {
    struct rebindings_entry *new_entry = malloc(sizeof(struct rebindings_entry));
    if (!new_entry) {
        return -1;
    }
    new_entry->rebindings = malloc(sizeof(struct rebinding) * nel);
    if (!new_entry->rebindings) {
        free(new_entry);
        return -1;
    }
    memcpy(new_entry->rebindings, rebindings, sizeof(struct rebinding) * nel);
    new_entry->rebindings_nel = nel;
    new_entry->next = *rebindings_head;
    *rebindings_head = new_entry;
    return 0;
}

static void perform_rebinding_with_section(struct rebindings_entry *rebindings,
                                           section_t *section,
                                           intptr_t slide,
                                           nlist_t *symtab,
                                           char *strtab,
                                           uint32_t *indirect_symtab) {
    uint32_t *indirect_symbol_indices = indirect_symtab + section->reserved1;
    void **indirect_symbol_bindings = (void **)((uintptr_t)slide + section->addr);
    for (uint i = 0; i < section->size / sizeof(void *); i++) {
        uint32_t symtab_index = indirect_symbol_indices[i];
        if (symtab_index == INDIRECT_SYMBOL_ABS || symtab_index == INDIRECT_SYMBOL_LOCAL ||
            symtab_index == (INDIRECT_SYMBOL_LOCAL   | INDIRECT_SYMBOL_ABS)) {
            continue;
        }
        uint32_t strtab_offset = symtab[symtab_index].n_un.n_strx;
        char *symbol_name = strtab + strtab_offset;
        struct rebindings_entry *cur = rebindings;
        while (cur) {
            for (uint j = 0; j < cur->rebindings_nel; j++) {
                if (strlen(symbol_name) > 1 &&
                    strcmp(&symbol_name[1], cur->rebindings[j].name) == 0) {
                    indirect_symbol_bindings[i] = cur->rebindings[j].replacement;
                    goto symbol_loop;
                }
            }
            cur = cur->next;
        }
    symbol_loop:;
    }
}

static void rebind_symbols_for_image(struct rebindings_entry *rebindings,
                                     const struct mach_header *header,
                                     intptr_t slide) {
    Dl_info info;
    if (dladdr(header, &info) == 0) {
        return;
    }
    
    segment_command_t *cur_seg_cmd;
    segment_command_t *linkedit_segment = NULL;
    struct symtab_command* symtab_cmd = NULL;
    struct dysymtab_command* dysymtab_cmd = NULL;
    
    uintptr_t cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        if (cur_seg_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            if (strcmp(cur_seg_cmd->segname, SEG_LINKEDIT) == 0) {
                linkedit_segment = cur_seg_cmd;
            }
        } else if (cur_seg_cmd->cmd == LC_SYMTAB) {
            symtab_cmd = (struct symtab_command*)cur_seg_cmd;
        } else if (cur_seg_cmd->cmd == LC_DYSYMTAB) {
            dysymtab_cmd = (struct dysymtab_command*)cur_seg_cmd;
        }
    }
    
    if (!symtab_cmd || !dysymtab_cmd || !linkedit_segment ||
        !dysymtab_cmd->nindirectsyms) {
        return;
    }
    
    // Find base symbol/string table addresses
    uintptr_t linkedit_base = (uintptr_t)slide + linkedit_segment->vmaddr - linkedit_segment->fileoff;
    nlist_t *symtab = (nlist_t *)(linkedit_base + symtab_cmd->symoff);
    char *strtab = (char *)(linkedit_base + symtab_cmd->stroff);
    
    // Get indirect symbol table (array of uint32_t indices into symbol table)
    uint32_t *indirect_symtab = (uint32_t *)(linkedit_base + dysymtab_cmd->indirectsymoff);
    
    cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        if (cur_seg_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            if (strcmp(cur_seg_cmd->segname, SEG_DATA) != 0) {
                continue;
            }
            for (uint j = 0; j < cur_seg_cmd->nsects; j++) {
                section_t *sect =
                (section_t *)(cur + sizeof(segment_command_t)) + j;
                if ((sect->flags & SECTION_TYPE) == S_LAZY_SYMBOL_POINTERS) {
                    perform_rebinding_with_section(rebindings, sect, slide, symtab, strtab, indirect_symtab);
                }
                if ((sect->flags & SECTION_TYPE) == S_NON_LAZY_SYMBOL_POINTERS) {
                    perform_rebinding_with_section(rebindings, sect, slide, symtab, strtab, indirect_symtab);
                }
            }
        }
    }
}

static void _rebind_symbols_for_image(const struct mach_header *header,
                                      intptr_t slide) {
    rebind_symbols_for_image(_rebindings_head, header, slide);
}

int rebind_symbols_image(void *header,
                         intptr_t slide,
                         struct rebinding rebindings[],
                         size_t rebindings_nel) {
    struct rebindings_entry *rebindings_head = NULL;
    int retval = prepend_rebindings(&rebindings_head, rebindings, rebindings_nel);
    rebind_symbols_for_image(rebindings_head, header, slide);
    free(rebindings_head);
    return retval;
}

int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel) {
    int retval = prepend_rebindings(&_rebindings_head, rebindings, rebindings_nel);
    if (retval < 0) {
        return retval;
    }
    // If this was the first call, register callback for image additions (which is also invoked for
    // existing images, otherwise, just run on existing images
    if (!_rebindings_head->next) {
        _dyld_register_func_for_add_image(_rebind_symbols_for_image);
    } else {
        uint32_t c = _dyld_image_count();
        for (uint32_t i = 0; i < c; i++) {
            _rebind_symbols_for_image(_dyld_get_image_header(i), _dyld_get_image_vmaddr_slide(i));
        }
    }
    return retval;
}
*/