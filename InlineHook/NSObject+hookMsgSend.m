//
//  NSObject+hookMsgSend.m
//  animation
//
//  Created by luqizhou on 2017/4/28.
//  Copyright © 2017年 sangfor. All rights reserved.
//

#import "NSObject+hookMsgSend.h"

#include <pthread.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <objc/runtime.h>

#include <sys/time.h>
#include <sys/mman.h>

#include "inlinehook.h"


#ifdef __arm64__

#define MIN_CALL_TIME   0.001f   //仅记录大于1ms的调用

//存储每个线程每级函数嵌套时的寄存器缓存（因为可变参数的特殊性，hook之后不能利用堆栈做寄存器缓存）
struct RegisterStorage {
    NSInteger x19;   //pointer for function storage
    NSInteger x20;   //pointer for register storage
    NSInteger x21;   //temporary register
    NSInteger lr;
    NSInteger x[19]; //arm64可变参数时，会先存满r0-r18，在存sp，所以r0-r18都要备份
    NSInteger nop;
    NSInteger d[32]; //浮点寄存器都是临时寄存器，要备份
    NSInteger ret0;
    NSInteger ret1;
};

//存储c函数指针（用于给汇编回调）
struct FunctionStorage {
    void(*will_call)();
    void *(*orig_call)();
    void(*did_call)();
    struct RegisterStorage *(*get_register_storage)();
};

//存储每个线程的堆栈空间，用于快速匹配线程号（直接通过mach_thread_self取线程号涉及系统调用，性能很差）
struct StackStorage {
    void *stack_bottom;
    void *stack_top;
    mach_port_t machThread;
};

//方法调用统计信息
struct CallStorage {
    const char *cls;
    const char *sel;
    struct timeval begin;
    struct timeval end;
    mach_port_t thread;
    int16_t deep;
    uint8_t isClass;
};
struct CallStorageRecord {
    struct CallStorage call;
    struct CallStorage *recordPos;
};

//方法调用统计信息缓存池
#define CALL_STORAGE_POOL_SIZE  (8*1024)
struct CallStoragePool {
    struct CallStoragePool *next;
    uint32_t used;
    struct CallStorage pool[CALL_STORAGE_POOL_SIZE];
};

#define MAX_THREAD_INFO_SIZE    1000        //线程id求模做hash
#define MAX_CALLSTACK_DEEP      192         //支持的最大函数嵌套深度
struct ThreadInfo {
    struct RegisterStorage registerStorage[MAX_CALLSTACK_DEEP];
    struct CallStorageRecord callStorageRecord[MAX_CALLSTACK_DEEP];
    mach_port_t thread;
    int16_t callStackDeep;
    int16_t callStackRecordDeep;
    struct ThreadInfo *next;
};

static struct ThreadInfo **threadInfo;          //线程信息
static dispatch_semaphore_t threadInfoLock = 0; //线程信息锁

static struct StackStorage stackStorage[1024];  //线程堆栈信息
static dispatch_semaphore_t stackStorageLock = 0; //

struct FunctionStorage functionStorage;  //汇编回调函数指针

static struct CallStoragePool *callStoragePoolCurrent = NULL;   //函数调用记录缓存池
static struct CallStoragePool *callStoragePoolHead = NULL;      //函数调用记录缓存池
static dispatch_semaphore_t callStoragePoolLock = 0;        //函数调用记录缓存池锁

static mach_port_t mainThread;                  //主线程id

static IMP(*fLookUpImpOrForward)(Class cls, SEL sel, id inst, bool initialize, bool cache, bool resolver) = NULL;
static uintptr_t imageLoadAddrStart = 0;        //app可执行文件的加载起始地址
static uintptr_t imageLoadAddrEnd = 0;          //app可执行文件的加载结束地址

static IMP excludeImps[128];
BOOL msgSendLog = NO;

#pragma mark - utils

void resetImageLoadAddress(void) {
    NSString *executableName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"];
    
    for(int i = 0; i < _dyld_image_count(); i++) {
        const struct mach_header* header = _dyld_get_image_header(i);
        const char *name = _dyld_get_image_name(i);
        if(name == NULL) {
            continue;
        }
        
        NSString *imageName = [[NSString stringWithUTF8String:name] lastPathComponent];
        if(imageName == nil || [imageName isEqualToString:executableName] == NO) {
            continue;
        }
        
        uintptr_t cmdPtr = 0;
        if(header->magic == MH_MAGIC || header->magic == MH_CIGAM) {
            cmdPtr = (uintptr_t)(header + 1);
        }else if(header->magic == MH_MAGIC_64 || header->magic == MH_CIGAM_64) {
            cmdPtr = (uintptr_t)(((struct mach_header_64 *)header) + 1);
        }else {
            continue;
        }
        
        for(uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
            struct load_command* loadCmd = (struct load_command*)cmdPtr;
            cmdPtr += loadCmd->cmdsize;
            if(loadCmd->cmd == LC_SEGMENT) {
                struct segment_command *segPtr = (struct segment_command *)cmdPtr;
                if(strcmp(segPtr->segname, SEG_TEXT) == 0) {
                    imageLoadAddrStart = (uintptr_t)(segPtr->vmaddr);
                    imageLoadAddrEnd = (uintptr_t)(segPtr->vmaddr + segPtr->vmsize);
                }
                NSLog(@"%d、 %s vmaddr:0x%08x vmsize:0x%08x", iCmd, segPtr->segname, segPtr->vmaddr, segPtr->vmsize);
            }else if(loadCmd->cmd == LC_SEGMENT_64) {
                struct segment_command_64 *segPtr = (struct segment_command_64 *)cmdPtr;
                if(strcmp(segPtr->segname, SEG_TEXT) == 0) {
                    imageLoadAddrStart = (uintptr_t)(segPtr->vmaddr);
                    imageLoadAddrEnd = (uintptr_t)(segPtr->vmaddr + segPtr->vmsize);
                }
                NSLog(@"%d、 %s vmaddr:0x%llx vmsize:0x%llx", iCmd, segPtr->segname, segPtr->vmaddr, segPtr->vmsize);
            }
        }
        
        imageLoadAddrEnd = (uintptr_t)header + (imageLoadAddrEnd - imageLoadAddrStart);
        imageLoadAddrStart = (uintptr_t)header;
        NSLog(@"%@ load addr: 0x%lx ~0x%lx", executableName, (uintptr_t)imageLoadAddrStart, (uintptr_t)imageLoadAddrEnd);
        break;
    }
    
    assert(imageLoadAddrStart && imageLoadAddrEnd);
}

static inline mach_port_t thread_index() {
    //在汇编里实现，获取当前函数的栈地址
    extern void *get_sp(void);
    void *sp = get_sp();
    
    //如果能在栈缓存中匹配到栈地址，则可以快速获取之前记录过的线程id
    int i = 0;
    for(; i < sizeof(stackStorage)/sizeof(stackStorage[0]); i++) {
        struct StackStorage *p = &stackStorage[i];
        if(p->stack_bottom == NULL) {
            break;
        }
        if(sp <= p->stack_top && sp > p->stack_bottom) {    //LQZ 这里有bug，如果一个新线程分配的栈空间和一个被销毁的线程栈空间有重复，可能会出问题
            return p->machThread;
        }
    }
    
    //如果不能匹配到，则通过系统调用获取到当前线程id，和当前线程的栈空间，比记录到缓存，下次快速获取
    
    dispatch_semaphore_wait(stackStorageLock, DISPATCH_TIME_FOREVER);
    
    struct StackStorage *p = NULL;
    for(; i < sizeof(stackStorage)/sizeof(stackStorage[0]); i++) {
        p = &stackStorage[i];
        if(p->stack_bottom == NULL) {
            break;
        }
    }
    assert(i < sizeof(stackStorage)/sizeof(stackStorage[0]));
    
    pthread_t thread = pthread_self();
    p->stack_top = pthread_get_stackaddr_np(thread);
    p->stack_bottom = p->stack_top - pthread_get_stacksize_np(thread);
    p->machThread = mach_thread_self();
    assert(sp <= p->stack_top && sp > p->stack_bottom);
    
    dispatch_semaphore_signal(stackStorageLock);
    
    printf("create thread(%05d) stack strorage 0x%lx ~ 0x%lx\n", p->machThread, (uintptr_t)p->stack_bottom, (uintptr_t)p->stack_top);
    return p->machThread;
}

static struct ThreadInfo *get_thread_info(void) {
    mach_port_t thread = thread_index();//mach_thread_self();
    NSInteger index = thread % MAX_THREAD_INFO_SIZE;
    
    struct ThreadInfo *info = threadInfo[index];
    struct ThreadInfo *next = info;
    while(next) {
        if(next->thread == thread) {
            return next;
        }
        next = next->next;
    }
    
    dispatch_semaphore_wait(threadInfoLock, DISPATCH_TIME_FOREVER);
    
    struct ThreadInfo *ret = malloc(sizeof(struct ThreadInfo));
    memset(ret, 0, sizeof(struct ThreadInfo));
    ret->thread = thread;
    ret->next = threadInfo[index];
    threadInfo[index] = ret;
    
    dispatch_semaphore_signal(threadInfoLock);
    printf("create thread(%05d) info at %03zd %s conflict\n", thread, index, ret->next?"with":"without");
    
    return ret;
}

static inline void convert_time(char *buf, int size, struct timeval *t) {
    struct tm *tm = localtime(&t->tv_sec);
    ssize_t pos = strftime(buf, size, "%Y-%m-%d %H:%M:%S", tm);
    sprintf(buf+pos, ".%06d", t->tv_usec);
}

//获取系统时间
static inline void get_time(struct timeval *t) {
    gettimeofday(t, NULL);
}

static inline NSTimeInterval time_diff(struct timeval *t1, struct timeval *t2) {  //unit: us
    NSTimeInterval t;
    t = (uint32_t)(t2->tv_sec - t1->tv_sec);
    t += (t2->tv_usec - t1->tv_usec)/1000000.0;
    return t;
}

//保存函数调用记录
struct CallStorage *save_call_record(struct CallStorage *call) {
    if(msgSendLog == NO) {
        return NULL;
    }
    
    assert(call->cls && call->sel && call->thread);
    
    dispatch_semaphore_wait(callStoragePoolLock, DISPATCH_TIME_FOREVER);
    
    uint32_t used = callStoragePoolCurrent->used;
    if(used >= CALL_STORAGE_POOL_SIZE) {
        struct CallStoragePool *pool = malloc(sizeof(struct CallStoragePool));
        memset(pool, 0, sizeof(struct CallStoragePool));
        callStoragePoolCurrent->next = pool;
        callStoragePoolCurrent = pool;
        printf("create call storage pool\n");
    }
    
    struct CallStorage *ret = &(callStoragePoolCurrent->pool[callStoragePoolCurrent->used++]);
    dispatch_semaphore_signal(callStoragePoolLock);
    
    memcpy(ret, call, sizeof(struct CallStorage));

#if 0
    char buf[MAX_CALLSTACK_DEEP*2+1];
    
    int size = (call->deep) * 2;
    memset(buf, ' ', size);
    buf[size] = 0;
    
    printf("call[%05d] %s %c[%s %s]\n", call->thread, buf, call->isClass?'+':'-', call->cls, call->sel);
#endif
    
    return ret;
}

#pragma mark - handler

//获取当前线程当前嵌套深度的寄存器缓存空间
struct RegisterStorage *get_register_storage(void) {
    struct ThreadInfo *info = get_thread_info();
    int16_t deep = info->callStackDeep;
    struct RegisterStorage *p = info->registerStorage;
    return &p[deep];
}

//调用objc_msgSend前的回调
void will_objc_msgSend(__unsafe_unretained id slf, SEL op, ...) {
    struct ThreadInfo *info = get_thread_info();
    int16_t deep = info->callStackDeep++;
    assert(deep < MAX_CALLSTACK_DEEP);
    
    if(slf && msgSendLog /*&& info->thread == mainThread*/) {
        Class cls = object_getClass(slf);
        IMP imp = fLookUpImpOrForward(cls, op, nil, NO, YES, YES);
        //IMP imp = class_getMethodImplementation(cls, op);

        if(((uintptr_t)imp >= imageLoadAddrStart && (uintptr_t)imp < imageLoadAddrEnd)) { //如果是系统方法则不统计
            for(int i = 0; i < sizeof(excludeImps); i++) {
                IMP exImp = excludeImps[i];
                if(exImp == imp) {
                    return;
                }else if(exImp == 0) {
                    break;
                }
            }
            
            const char *clsName = object_getClassName(slf);
            const char *selName = sel_getName(op);
            
            struct CallStorageRecord *threadCallRecord = info->callStorageRecord;
            struct CallStorageRecord *callRecord = &threadCallRecord[deep];
            get_time(&callRecord->call.begin);
            callRecord->call.cls = clsName;
            callRecord->call.sel = selName;
            callRecord->call.thread = info->thread;
            callRecord->call.isClass = object_isClass(slf);
            
            int16_t recordDeep = info->callStackRecordDeep++;
            callRecord->call.deep = recordDeep;
            
            struct CallStorage *call = save_call_record(&callRecord->call);
            callRecord->recordPos = call;
        
//            char buf[MAX_CALLSTACK_DEEP*2+1];
//            memset(buf, ' ', call->deep*2);
//            buf[call->deep*2] = 0;
//            printf("call[%05d] %s [%s %s]\n", call->thread, buf, call->cls, call->sel);
        }
    }
}

void did_objc_msgSend(__unsafe_unretained id slf, SEL op, ...) {
    struct ThreadInfo *info = get_thread_info();
    int16_t deep = --(info->callStackDeep);
    assert(deep >= 0);
    
    struct CallStorageRecord *threadCallRecord = info->callStorageRecord;
    if(threadCallRecord && msgSendLog) {
        struct CallStorageRecord *callRecord = &threadCallRecord[deep];
        if(callRecord->recordPos) {
            --(info->callStackRecordDeep);
            get_time(&callRecord->recordPos->end);
            callRecord->recordPos = NULL;
        }
    }
}

#pragma mark - file record

static ssize_t set_html_header(FILE *file) {
    static const char header[] = "<html>\n<head>\n<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf8\" />\n<title>方法调用统计</title>\n</head>\n\n<script language=javascript id=clientEventHandlersJS>\nvar number=2;\nfunction ShowFLT(i) {\n\tlbmc = eval('LM' + i);\n\tif (lbmc.style.display == 'none') {\n\t\tlbmc.style.display = '';\n}else {\n\t\tlbmc.style.display = 'none';\n\t}\n}\n</script>\n\n<style type=\"text/css\">\n.color{color:#BC6738;}\n</style>\n\n<body>\n<table width=\"1300\" height=\"250\" border=\"0\" align=\"left\">\n<tbody>\n<tr>\n<td align=\"left\" valign=\"top\">\n<ul>\n\n\n";
    return fwrite(header, sizeof(header)-1, 1, file);
}

static ssize_t set_html_tail(FILE *file) {
    static const char *tail = "\n\n\n</ul>\n</td>\n</tr>\n</tbody>\n</table>\n</body>\n</html>\n";
    return fwrite(tail, sizeof(tail)-1, 1, file);
}

static FILE *init_record(const char *path) {
    FILE *file = fopen(path, "w");
    if(file) {
        set_html_header(file);
    }
    assert(file);
    return file;
}

static void end_record(FILE *file) {
    if(file) {
        set_html_tail(file);
        fclose(file);
    }
}

static void add_record_tail(FILE *file) {
    fprintf(file, "</li>\n\n");
}

static void add_record(FILE *file, int deep, const char *content, struct timeval *begin, struct timeval *end, mach_port_t thread, bool hasSub) {
    
    //printf("%s deep:%d sub:%d\n", content, deep, hasSub);
    
    static const char *defaultColor = "#895454";
    static const char *highlightColor = "#E00F2D";
    static const char *subColor = "#356969";
    static const char tab[] = "&emsp;";
    static char *emsp = NULL;
    if(emsp == NULL) {
        const int len = 10*1024;
        emsp = malloc(len);
        int i = 0;
        for(; i+sizeof(tab) < len; i+=(sizeof(tab)-1)) {
            memcpy(emsp+i, tab, sizeof(tab)-1);
        }
        emsp[i] = 0;
    }
    
    char time_str[32];
    convert_time(time_str, sizeof(time_str), begin);
    
    static int elementID = 0;
    const int offset = 27;
    
    NSTimeInterval t = time_diff(begin, end);
    bool highlight = (t > 0.05);    //超过50ms高亮
    
    if(deep == 0) {
        ++elementID;
        const char *color = highlight? highlightColor: defaultColor;
        if(hasSub) {
            fprintf(file, "<li style=\"PADDING-LEFT: %dpx; color:%s;\">\n<a onclick=javascript:ShowFLT(%d) href=\"javascript:void(0)\"><code>...</code></a>\n<code>%s [%5d] %s in %0.3fms</code>\n</li>\n", 0, color, elementID, time_str, thread, content, t*1000);
            fprintf(file, "<li style=\"PADDING-LEFT: %dpx; DISPLAY: none; color:%s;\" id=LM%d>\n", offset, subColor, elementID);
        }else {
            fprintf(file, "<li style=\"PADDING-LEFT: %dpx; color:%s;\">\n<code>%s [%5d] %s in %0.3fms</code>\n</li>\n\n", offset, color, time_str, thread, content, t*1000);
        }
    }else {
        int offset = deep*2*(sizeof(tab)-1);
        assert(emsp[offset] == '&');
        emsp[offset] = 0;
        if(highlight) {
            fprintf(file, "<a class=\"color\"><code>%s [%5d] %s%s in %0.3fms</code><br></a>\n", time_str, thread, emsp, content, t*1000);
        }else {
            fprintf(file, "<code>%s [%5d] %s%s in %0.3fms</code><br>\n", time_str, thread, emsp, content, t*1000);
        }
        emsp[offset] = '&';
    }
}

void write_call(struct CallStorage *call, FILE *file) {
    char buf[1024];
    
    static struct CallStorage **callBuf = NULL;
    static ssize_t callBufSize = 0;
    static ssize_t used = 0;
    
    if(call == NULL) {
        if(callBuf) {
            free(callBuf);
            callBuf = NULL;
            used = 0;
        }
        return;
    }
    assert(call->cls);
    
    if(callBuf == NULL) {
        callBufSize = 1024;
        callBuf = malloc(sizeof(void *)*callBufSize);
        used = 0;
    }else if(used >= callBufSize) {
        callBufSize = callBufSize * 2;
        callBuf = realloc(callBuf, sizeof(void *)*callBufSize);
    }
    
    if(call->deep == 0) {
        bool hasSub = false;
        if(used > 1) {
            for(int i = 1; i < used; i++) {
                struct CallStorage *call = callBuf[i];
                if(time_diff(&call->begin, &call->end) >= MIN_CALL_TIME) { //非首级且耗时小于1ms过滤
                    hasSub = true;
                    break;
                }
            }
        }
        
        for(int i = 0; i < used; i++) {
            struct CallStorage *call = callBuf[i];
            assert(i==0 || call->deep>0);
            assert(i>0  || call->deep==0);
            if(i > 0 && time_diff(&call->begin, &call->end) < MIN_CALL_TIME) {
                continue;
            }
            const char *cls = call->cls? call->cls: "unknown";
            const char *sel = call->sel? call->sel: "unknown";
            sprintf(buf, "%c[%s %s]", (call->isClass?'+':'-'), cls, sel);
            add_record(file, call->deep, buf, &call->begin, &call->end, call->thread, (i==0)?hasSub:false);
        }
        if(hasSub) {
            add_record_tail(file);
        }
        used = 0;
    }
    
    callBuf[used++] = call;
}

void write_call_stack(struct CallStorage *pool, char *buf, FILE *file, int left, int right, int deep) {
//    printf("write_call_stack left:%d right:%d deep:%d\n", left, right, deep);
    
    int subStart = left;
    int subEnd = left;
    int16_t minSubDeep = INT16_MAX;
    
    for(int i = left; i < right; i++) {
        struct CallStorage *call = &pool[i];
        if(call->deep == deep) {
            const char *cls = call->cls? call->cls: "unknown";
            const char *sel = call->sel? call->sel: "unknown";
            bool hasSub = (subEnd > subStart)? true: false;
            sprintf(buf, "%c[%s %s]", (call->isClass?'+':'-'), cls, sel);
            
            add_record(file, call->deep, buf, &call->begin, &call->end, call->thread, hasSub);
            
            if(subStart < subEnd) {
                assert(minSubDeep > call->deep);
                write_call_stack(pool, buf, file, subStart, subEnd, minSubDeep);
            }
            
            subStart = subEnd = i + 1;
            
            if(call->deep == 0 && hasSub) {
                add_record_tail(file);
            }
            continue;
        }
        subEnd++;
        minSubDeep = MIN(minSubDeep, call->deep);
    }
}

#pragma mark - api

@implementation NSObject (hookMsgSend)

+ (void)profilerTest {
    NSDate *t1 = [NSDate date];
    for(int i = 0; i < 100000; i++) {
        @autoreleasepool {
            NSString *str = [NSString stringWithFormat:@"%@", [NSDate date]];
            str = [str stringByAppendingFormat:@"%@-%@", @([NSDate date].timeIntervalSince1970), str.stringByDeletingLastPathComponent];
        }
    }
    NSDate *t2 = [NSDate date];
    NSTimeInterval tt2 = t2.timeIntervalSince1970;
    NSTimeInterval tt1 = t1.timeIntervalSince1970;
    NSTimeInterval t = tt2 - tt1;
    NSLog(@"xxx %0.6fs", (float)t);
    
    exit(0);
}

+ (void)resetExcludeImps {
#if 1  
    struct exclude {
        Class cls;
        SEL sel;
        BOOL clsMethod;
    };
    
    memset(excludeImps, 0, sizeof(excludeImps));
    
    struct exclude exclude[] = {
        {[NSObject class], NSSelectorFromString(@"dealloc"), NO},
        {[NSArray class], @selector(arrayWithObjects:count:), YES},
        {[NSDictionary class], @selector(dictionaryWithObjects:forKeys:count:), YES},
        {[UIView class], @selector(pointInside:withEvent:), NO},
        {[UIView class], @selector(touchExtendInset), NO},
        {[UIView class], @selector(setTouchExtendInset:), NO},
        
        {[NSObject class], @selector(forwardingTargetForSelector:), NO},
        {[NSObject class], @selector(methodSignatureForSelector:), NO},
        {[NSObject class], @selector(forwardInvocation:), NO},
    };
      
    int j = 0;
    for(int i = 0; i < sizeof(exclude)/sizeof(exclude[0]); i++) {
        struct exclude ex = exclude[i];
        Method method = ex.clsMethod? class_getClassMethod(ex.cls, ex.sel): class_getInstanceMethod(ex.cls, ex.sel);
        
        uintptr_t imp = (uintptr_t)method_getImplementation(method);
        assert(imp >= imageLoadAddrStart && imp < imageLoadAddrEnd);
        
        excludeImps[j++] = (IMP)imp;
    }
    return;
#endif
}

+ (void)load {
    //[self startRecord];
//    NSDate *t1 = [NSDate date];
//    for(int i = 0; i < 100000; i++) {
//        mach_thread_self();
//    }
//    NSDate *t2 = [NSDate date];
//    NSTimeInterval tt2 = t2.timeIntervalSince1970;
//    NSTimeInterval tt1 = t1.timeIntervalSince1970;
//    NSTimeInterval t = tt2 - tt1;
//    NSLog(@"xxx %0.6fs", (float)t);
//    exit(0);
}

+ (void)hookMsgSend {
    if(fLookUpImpOrForward) {
        return;
    }
    
    resetImageLoadAddress();
    [self resetExcludeImps];
    
    //在汇编里定义
    extern void new_objc_msgSend(void);
    
    mainThread = mach_thread_self();
    memset(&stackStorage, 0, sizeof(stackStorage));
    stackStorageLock = dispatch_semaphore_create(1);
    
    ssize_t len = sizeof(struct ThreadInfo *)*MAX_THREAD_INFO_SIZE;
    threadInfo = malloc(len);
    memset(threadInfo, 0, len);
    threadInfoLock = dispatch_semaphore_create(1);
    
    
    callStoragePoolLock = dispatch_semaphore_create(1);
    callStoragePoolHead = malloc(sizeof(struct CallStoragePool));
    memset(callStoragePoolHead, 0, sizeof(struct CallStoragePool));
    callStoragePoolCurrent = callStoragePoolHead;
    fLookUpImpOrForward = (void *)find_lookUpImpOrNil();
    assert(fLookUpImpOrForward);
    
    functionStorage.will_call = (void(*)())will_objc_msgSend;
    functionStorage.did_call = (void(*)())did_objc_msgSend;
    //functionStorage.orig_call = (void *(*)())rebinding.orig_call;
    functionStorage.get_register_storage = get_register_storage;
    
    struct rebinding rebinding = {"objc_msgSend", (uintptr_t)new_objc_msgSend, 1};
    kern_return_t ret = inline_hook(&rebinding, (uintptr_t *)&functionStorage.orig_call);
    assert(ret == 0 && functionStorage.orig_call);
}

+ (void)startRecord {
    msgSendLog = YES;
    [self hookMsgSend];
}

+ (void)stopRecord:(void (^)(NSString *))completion {
    msgSendLog = NO;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"timer_profiler_%d.html", (int)[NSDate date].timeIntervalSince1970]];
        FILE *file = init_record(path.UTF8String);
        
        struct CallStoragePool *pool = callStoragePoolHead;
        
        int64_t totalCalls = 0;
        while(pool) {
            totalCalls += pool->used;
            pool = pool->next;
        }
        pool = callStoragePoolHead;
        NSLog(@"total calls %lld", totalCalls);
        
//        for(int i = 0; i < pool->used ; i++) {
//            struct CallStorage *call = &pool->pool[i];
//            printf("%03d - %03d  %c[%s %s]\n", i, call->deep, call->isClass?'+':'-', call->cls, call->sel);
//        }
        
        struct CallStoragePool *nextStartPool = NULL;
        int nextStartPosition = -1;
        int currentThead = -1;
        
        while(pool || nextStartPool) {
            int i = 0;
            if(pool == NULL) {
                assert(nextStartPosition >= 0);
                pool = nextStartPool;
                i = nextStartPosition;
                
                nextStartPool = NULL;
                nextStartPosition = -1;
                currentThead = -1;
            }
            
            while(pool) {
                int used = pool->used;
                for(; i < used; i++) {
                    struct CallStorage *call = &pool->pool[i];
                    if(currentThead < 0) {
                        if(call->deep != 0) {
                            continue;
                        }
                        currentThead = call->thread;
                        write_call(call, file);
                        continue;
                    }
                    
                    if(call->thread != currentThead) {
                        if(call->deep == 0 && nextStartPool == NULL) {
                            nextStartPool = pool;
                            nextStartPosition = i;
                        }
                        continue;
                    }
                    
                    if(call->deep == 0 && nextStartPool) {
                        assert(nextStartPosition >= 0);
                        pool = nextStartPool;
                        i = nextStartPosition - 1;
                        
                        nextStartPool = NULL;
                        nextStartPosition = -1;
                        currentThead = -1;
                        continue;
                    }
                    
                    write_call(call, file);
                }
                i = 0;
                
                pool = pool->next;
            }
        }
        
        write_call(NULL, file);
        end_record(file);
        
        pool = callStoragePoolHead;
        while(pool) {
            struct CallStoragePool *next = pool->next;
            if(pool != callStoragePoolHead) {
                free(pool);
            }
            pool = next;
        }
        
        callStoragePoolHead->next = NULL;
        callStoragePoolHead->used = 0;
        callStoragePoolCurrent = callStoragePoolHead;
        
        if(completion) {
            completion(path);
        }
    });
}

@end

#endif
