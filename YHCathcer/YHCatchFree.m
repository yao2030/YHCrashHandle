//
//  YHFree.m
//  testCrash
//
//  Created by yanghao on 2017/5/16.
//  Copyright © 2017年 justlike. All rights reserved.
//

#import "YHCatchFree.h"
#import "YHCatchProxy.h"
#import "queue.h"
#import "fishhook.h"
#import <dlfcn.h>
#import <libkern/OSAtomic.h>
#import <UIKit/UIKit.h>
#import "NSObject+MemoryLeak.h"


#include <malloc/malloc.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <sys/time.h>
#include <objc/runtime.h>
#include <pthread/pthread.h>

//static uintptr_t imageLoadAddrStart = 0;        //app可执行文件的加载起始地址
//static uintptr_t imageLoadAddrEnd = 0;          //app可执行文件的加载结束地址
//
//void yhResetImageLoadAddress(void) {
//	NSString *executableName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"];//可执行文件名
//	
//	for(int i = 0; i < _dyld_image_count(); i++) {
//		const struct mach_header* header = _dyld_get_image_header(i);
//		const char *name = _dyld_get_image_name(i);
//		if(name == NULL) {
//			continue;
//		}
//		
//		NSString *imageName = [[NSString stringWithUTF8String:name] lastPathComponent];
//		if(imageName == nil || [imageName isEqualToString:executableName] == NO) {
//			continue;
//		}
//		
//		uintptr_t cmdPtr = 0;
//		if(header->magic == MH_MAGIC || header->magic == MH_CIGAM) {
//			cmdPtr = (uintptr_t)(header + 1);
//		}else if(header->magic == MH_MAGIC_64 || header->magic == MH_CIGAM_64) {
//			cmdPtr = (uintptr_t)(((struct mach_header_64 *)header) + 1);
//		}else {
//			continue;
//		}
//		//实际是从_TEXT段开始的，而不是SEG_PAGEZERO（待验证）
//		for(uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
//			struct load_command* loadCmd = (struct load_command*)cmdPtr;
//			cmdPtr += loadCmd->cmdsize;
//			if(loadCmd->cmd == LC_SEGMENT) {
//				struct segment_command *segPtr = (struct segment_command *)cmdPtr;
//				if(strcmp(segPtr->segname, SEG_TEXT) == 0) {
//					imageLoadAddrStart = (uintptr_t)(segPtr->vmaddr);
//					imageLoadAddrEnd = (uintptr_t)(segPtr->vmaddr + segPtr->vmsize);
//				}else if(strcmp(segPtr->segname, SEG_PAGEZERO) == 0){
//					
//				}else if(strcmp(segPtr->segname, SEG_DATA) == 0){
//					imageLoadAddrEnd += (uintptr_t)(segPtr->vmsize);
//				}
//				NSLog(@"%d、 %s vmaddr:0x%08x vmsize:0x%08x", iCmd, segPtr->segname, segPtr->vmaddr, segPtr->vmsize);
//			}else if(loadCmd->cmd == LC_SEGMENT_64) {
//				struct segment_command_64 *segPtr = (struct segment_command_64 *)cmdPtr;
//				if(strcmp(segPtr->segname, SEG_TEXT) == 0) {
//					imageLoadAddrStart = (uintptr_t)(segPtr->vmaddr);
//					imageLoadAddrEnd = (uintptr_t)(segPtr->vmaddr + segPtr->vmsize);
//				}else if(strcmp(segPtr->segname, SEG_PAGEZERO) == 0){
//					
//				}else if(strcmp(segPtr->segname, SEG_DATA) == 0){
//					imageLoadAddrEnd += (uintptr_t)(segPtr->vmsize);
//				}
//				NSLog(@"%d、 %s vmaddr:0x%llx vmsize:0x%llx", iCmd, segPtr->segname, segPtr->vmaddr, segPtr->vmsize);
//			}
//		}
//		imageLoadAddrEnd = (uintptr_t)header + (imageLoadAddrEnd - imageLoadAddrStart);
//		imageLoadAddrStart = (uintptr_t)header;
//		NSLog(@"%@ load addr: 0x%lx ~0x%lx", executableName, (uintptr_t)imageLoadAddrStart, (uintptr_t)imageLoadAddrEnd);
//		break;
//	}
//	
//	assert(imageLoadAddrStart && imageLoadAddrEnd);
//}


//获取系统时间
static inline void yhGet_time(struct timeval *t) {
	gettimeofday(t, NULL);
}

static inline NSTimeInterval yhTime_diff(struct timeval *t1, struct timeval *t2) {  //unit: us
	NSTimeInterval t;
	t = (uint32_t)(t2->tv_sec - t1->tv_sec);
	t += (t2->tv_usec - t1->tv_usec)/1000000.0;
	return t;
}

//释放对象queue
static dispatch_queue_t YHFreeGetDisplayQueue() {
	
#define MAX_QUEUE_COUNT 5
	static int queueCount;
	static dispatch_queue_t queues[MAX_QUEUE_COUNT];
	static dispatch_once_t onceToken;
	static int32_t counter = 0;
	dispatch_once(&onceToken, ^{
		queueCount = (int)[NSProcessInfo processInfo].activeProcessorCount;
		queueCount = queueCount < 1 ? 1 : queueCount > MAX_QUEUE_COUNT ? MAX_QUEUE_COUNT : queueCount;
		if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
			for (NSUInteger i = 0; i < queueCount; i++) {
				dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
				queues[i] = dispatch_queue_create("com.yh.free.render", attr);
			}
		} else {
			for (NSUInteger i = 0; i < queueCount; i++) {
				queues[i] = dispatch_queue_create("com.yh.free.render", DISPATCH_QUEUE_SERIAL);
				dispatch_set_target_queue(queues[i], dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
			}
		}
	});
	int32_t cur = OSAtomicIncrement32(&counter);
	if (cur < 0) cur = -cur;
	return queues[(cur) % queueCount];
#undef MAX_QUEUE_COUNT
	
}

static CFMutableSetRef registeredClasses;
static Class sYHCatchIsa;
static size_t sYHCatchSize;

static void(* orig_free)(void *p);

struct DSQueue* _unfreeQueue=NULL;//用来保存自己保留的内存:1这个队列要线程安全或者自己加锁;2这个队列内部应该尽量少申请和释放堆内存。
int unfreeSize=0;//用来记录保存的内存的大小

#define MAX_STEAL_MEM_SIZE 1024*1024*10//最多存这么多内存，大于这个值就释放一部分
#define MAX_STEAL_MEM_NUM 1024*1024*10//最多保留这么多个指针，再多就释放一部分
#define BATCH_FREE_NUM 1024*1024//每次释放的时候释放指针数量

//系统内存警告的时候调用这个函数释放一些内存
void free_some_mem(size_t freeNum){
	size_t count=ds_queue_length(_unfreeQueue);
	freeNum = freeNum>count?count:freeNum;
	dispatch_async(YHFreeGetDisplayQueue(), ^{
//		struct timeval t;
//		yhGet_time(&t);
		for (int i=0; i<freeNum; i++) {
			void* unfreePoint=ds_queue_get(_unfreeQueue);
			size_t memSiziee= malloc_size(unfreePoint);
			__sync_fetch_and_sub(&unfreeSize,(int)memSiziee);
			if (memSiziee>0){
				orig_free(unfreePoint);
			}
		}
//		struct timeval t1;
//		yhGet_time(&t1);
//		printf("-------------freeTime:%lf----------",yhTime_diff(&t, &t1));
	});
}

//void safe_free(void* p){
//#if 0//先注释掉
//	size_t memSiziee=malloc_size(p);
//	memset(p, 0x55, memSiziee);
//	orig_free(p);
//#else
//	int unFreeCount=ds_queue_length(_unfreeQueue);
//	if (unFreeCount>MAX_STEAL_MEM_NUM*0.9 || unfreeSize>MAX_STEAL_MEM_SIZE) {
//		free_some_mem(BATCH_FREE_NUM);
//	}else{
//		size_t memSiziee=malloc_size(p);
//		memset(p, 0x55, memSiziee);
//		__sync_fetch_and_add(&unfreeSize,(int)memSiziee);
//		ds_queue_put(_unfreeQueue, p);
//	}
//#endif
//
//	return;
//}

void loadCatchProxyClass()
{
	registeredClasses = CFSetCreateMutable(NULL, 0, NULL);
	unsigned int count = 0;
	Class *classes = objc_copyClassList(&count);
	for (unsigned int i = 0; i < count; i++) {
		CFSetAddValue(registeredClasses, (__bridge const void *)(classes[i]));
	}
	free(classes);
	classes=NULL;
	sYHCatchIsa=objc_getClass("YHCatchProxy");
	sYHCatchSize=class_getInstanceSize(sYHCatchIsa);
}

static void YHFree(void* p){
	
	int unFreeCount=ds_queue_length(_unfreeQueue);
	if (unFreeCount>MAX_STEAL_MEM_NUM*0.9 || unfreeSize>MAX_STEAL_MEM_SIZE) {
		free_some_mem(BATCH_FREE_NUM);
	}
	size_t memSiziee=malloc_size(p);
	if (memSiziee>=sYHCatchSize) {//有足够的空间才覆盖
		id obj = (__bridge id)p;
		Class origClass=object_getClass(obj);//判断是不是objc对象 ，regClasses里面有所有的类，如果可以查到，说明是objc类
		
		if (origClass && CFSetContainsValue(registeredClasses, (__bridge const void *)(origClass))
			/*&&((uintptr_t)origClass>=imageLoadAddrStart&&(uintptr_t)origClass<imageLoadAddrEnd)*/)
		{
			memset(p, 0x55, memSiziee);
			memcpy(p, &sYHCatchIsa, sizeof(void*));//把我们自己的类的isa复制过去
			
			YHCatchProxy* bug=(__bridge YHCatchProxy*)p;
			bug.origClass=origClass;
			__sync_fetch_and_add(&unfreeSize,(int)memSiziee);//多线程下int的原子加操作,多线程对全局变量进行自加，不用理线程锁了
			ds_queue_put(_unfreeQueue, p);
		}else{
			orig_free(p);
		}
	}else{
		orig_free(p);
	}
	return;
}


bool init_safe_free()
{
	_unfreeQueue=ds_queue_create(MAX_STEAL_MEM_NUM);
	orig_free=(void(*)(void*))dlsym(RTLD_DEFAULT, "free");
	rebind_symbols((struct rebinding[]){{"free", (void*)YHFree}}, 1);
	return true;
}

//static void(*orig_Calloc)(int n,int size);
//static void YHCalloc(int n,int size)
//{
//	printf("calloc:==>%zd\n",size);
//	orig_Calloc(n,size);
//	return ;
//}
//void init_safe_Calloc()
//{
//	orig_Calloc=(void(*)(int,int))dlsym(RTLD_DEFAULT, "calloc");
//	rebind_symbols((struct rebinding[]){{"calloc", (void*)YHCalloc}}, 1);
//}

@implementation YHCatchFree


+ (void)load
{
	
#if _INTERNAL_WILDPOINT_ENABLED
//	init_safe_Calloc();
//	yhResetImageLoadAddress();
	YHFreeGetDisplayQueue();
	loadCatchProxyClass();
	init_safe_free();
	
#endif

}


@end
