//
//  NSDictionary+ExceptionHandle.m
//  MOA
//
//  Created by yanghao on 2017/3/23.
//  Copyright © 2017年 moa. All rights reserved.
//

#import "NSDictionary+ExceptionHandle.h"
#import "NSObject+MemoryLeak.h"
#import <objc/runtime.h>
#import "MLeaksFinder.h"

@implementation NSDictionary (ExceptionHandle)

+ (void)load {
    Method originalMethod = class_getClassMethod([NSDictionary class], @selector(dictionaryWithObjects:forKeys:count:));
    Method newMethod = class_getClassMethod([self class], @selector(hookDictionaryWithObjects:forKeys:count:));
    method_exchangeImplementations(originalMethod, newMethod);
}

+ (instancetype)hookDictionaryWithObjects:(const id  _Nonnull __unsafe_unretained *)objects forKeys:(const id<NSCopying>  _Nonnull __unsafe_unretained *)keys count:(NSUInteger)cnt {
    id __unsafe_unretained po[cnt];
    id __unsafe_unretained pk[cnt];
    
    int fixCnt = 0;
    for(int i = 0; i < cnt; i++) {
        const id __unsafe_unretained o = objects[i];
        const id __unsafe_unretained k = keys[i];
        po[fixCnt] = o;
        pk[fixCnt] = k;
        fixCnt++;
    }
    
    return [self hookDictionaryWithObjects:po forKeys:pk count:fixCnt];
}

@end


@implementation NSMutableDictionary (ExceptionHandle)

#if _INTERNAL_WILDPOINT_ENABLED

+ (void)load {
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[objc_getClass("__NSDictionaryM") swizzleSEL:@selector(setObject:forKey:) withSEL:@selector(moa_setObject:forKey:)];
		[objc_getClass("__NSDictionaryM") swizzleSEL:@selector(setValue:forKey:) withSEL:@selector(moa_setValue:forKey:)];
		[objc_getClass("__NSDictionaryM") swizzleSEL:@selector(removeObjectForKey:) withSEL:@selector(moa_removeObjectForKey:)];
		[objc_getClass("__NSDictionaryM") swizzleSEL:@selector(setObject:forKeyedSubscript:) withSEL:@selector(moa_setObject:forKeyedSubscript:)];
		
	});
	
}

- (void)moa_setObject:(id)anObject forKey:(id<NSCopying>)aKey
{
	if (!anObject)
	{
		NSLog(@"error: anObject is nil");
		NSAssert(0, nil);
		return;
	}
	if (!aKey)
	{
		NSLog(@"error: aKey is nil");
		NSAssert(0, nil);
		return;
	}
	[self moa_setObject:anObject forKey:aKey];
}

- (void)moa_setValue:(id)value forKey:(NSString *)key
{
	if (!key)
	{
		NSLog(@"error: aKey is nil");
		NSAssert(0, nil);
		return;
	}
	[self moa_setValue:value forKey:key];
}


- (void)moa_removeObjectForKey:(id)aKey
{
	if (!aKey)
	{
		NSLog(@"error: aKey is nil");
		NSAssert(0, nil);
		return;
	}
	[self moa_removeObjectForKey:aKey];
}

- (void)moa_setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key {
//	if (!obj)
//	{
//		NSLog(@"error: anObject is nil");
//		NSAssert(0, nil);
//		return;
//	}
	if (!key)
	{
		NSLog(@"error: aKey is nil");
		NSAssert(0, nil);
		return;
	}
	[self moa_setObject:obj forKeyedSubscript:key];
}
#endif

@end


