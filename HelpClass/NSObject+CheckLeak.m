//
//  NSObject+CheckLeak.m
//  MOA
//
//  Created by neo on 14-8-13.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import "NSObject+CheckLeak.h"
#import <objc/runtime.h>

@implementation NSObject (CheckLeak)
+ (NSMutableDictionary *)configs
{
	static NSMutableDictionary *configs = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		configs = [NSMutableDictionary dictionary];
	});
	return configs;
}

+ (NSRecursiveLock *)leakCheckLock
{
	static NSRecursiveLock *lock = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		lock = [[NSRecursiveLock alloc] init];
	});
	return lock;
}
+ (void)loadChecker
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		Method orgInitMethod = class_getInstanceMethod([self class], @selector(init));
		Method extInitMethod = class_getInstanceMethod([self class], @selector(initWithLeakChecker));
		method_exchangeImplementations(orgInitMethod, extInitMethod);
		
		Method orgDeallocMethod = class_getInstanceMethod([self class], NSSelectorFromString(@"dealloc"));
		Method extDeallocMethod = class_getInstanceMethod([self class], @selector(deallocWithLeakChecker));
		method_exchangeImplementations(orgDeallocMethod, extDeallocMethod);
	});
}
- (id)initWithLeakChecker
{
	NSDictionary *config = nil;
	NSNumber *key = [NSNumber numberWithUnsignedLongLong:(int64_t)self];
	if ([self isKindOfClass:[UIView class]]
		|| [self isKindOfClass:[UIViewController class]]) {
		config = @{@"date":[NSDate date],
				   @"className":NSStringFromClass([self class]),
				   };
		NSRecursiveLock *lock = [[self class] leakCheckLock];
		[lock lock];
		NSMutableDictionary *configs = [[self class] configs];
		if (! configs[key]) {
			configs[key] = config;
		}
		[lock unlock];
	}
	
	return [self initWithLeakChecker];
}
- (void)deallocWithLeakChecker
{
	NSNumber *key = [NSNumber numberWithUnsignedLongLong:(int64_t)self];
	if ([self isKindOfClass:[UIView class]]
		|| [self isKindOfClass:[UIViewController class]]) {
		NSRecursiveLock *lock = [[self class] leakCheckLock];
		[lock lock];
		NSMutableDictionary *configs = [[self class] configs];
		//NSAssert(configs[key] != nil, nil);
		if (configs[key]) {
			[configs removeObjectForKey:key];
		}
		
		[lock unlock];
	}
	
	[self deallocWithLeakChecker];
}


@end
