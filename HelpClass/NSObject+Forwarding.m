//
//  NSObject+Forwarding.m
//  MOA
//
//  Created by jch jason on 14/12/10.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import "NSObject+Forwarding.h"
#import <objc/runtime.h>
#import "CRUnrecognizedRepair.h"


@implementation NSObject (Forwarding)


+ (void)load
{
    Method originalSignatureMethod = class_getInstanceMethod(self, @selector(methodSignatureForSelector:));
    Method newSignatureMethod = class_getInstanceMethod(self, @selector(methodSignatureForSelectorExchange:));
    method_exchangeImplementations(originalSignatureMethod, newSignatureMethod);
    
    Method originalForwardMethod = class_getInstanceMethod(self, @selector(forwardInvocation:));
    Method newForwardMethod = class_getInstanceMethod(self, @selector(forwardInvocationExchange:));
    method_exchangeImplementations(originalForwardMethod, newForwardMethod);
    
    Method originalForwardTargetMethod = class_getInstanceMethod(self, @selector(forwardingTargetForSelector:));
    Method newForwardTargetMethod = class_getInstanceMethod(self, @selector(forwardingTargetForSelectorExchange:));
    method_exchangeImplementations(originalForwardTargetMethod, newForwardTargetMethod);
    
    Method originalForwardTargetClassMethod = class_getClassMethod(self, @selector(forwardingTargetForSelector:));
    Method newForwardTargetClassMethod = class_getClassMethod(self, @selector(forwardingTargetForClassSelectorExchange:));
    method_exchangeImplementations(originalForwardTargetClassMethod, newForwardTargetClassMethod);
    
}


+ (id)forwardingTargetForClassSelectorExchange:(SEL)aSelector {
    if ([CRUnrecognizedRepair needRepairForSelector:aSelector andClass:self]) {
        return [CRUnrecognizedRepair class];
    }
    return [self forwardingTargetForClassSelectorExchange:aSelector];
}

- (id)forwardingTargetForSelectorExchange:(SEL)aSelector {
    static NSArray *classes = nil;
    if(classes == nil) {
        classes = @[NSStringFromClass([NSNull class]),
                    NSStringFromClass([NSDictionary class]),
                    NSStringFromClass([NSArray class]),
                    NSStringFromClass([NSNumber class])
                    ];
    }
    
    if ([CRUnrecognizedRepair needRepairForSelector:aSelector andObject:self]) {
        CRUnrecognizedRepair *repair = [[CRUnrecognizedRepair alloc]init];
        return repair;
    }
    
    if([classes containsObject:NSStringFromClass([self class])] == NO) {
        return [self forwardingTargetForSelectorExchange:aSelector];
    }
    
    NSAssert(0, @"给对象发了不支持的消息");  
    
    NSArray *objs = @[@{}, @[], @"", @0];
    for(id o in objs) {
        if([o respondsToSelector:aSelector]) {
            NSLogToFile(@"Bug: %@ forwarding to %@", [self class], [o class]);
            return o;
        }
    }
    return [self forwardingTargetForSelectorExchange:aSelector];
}

- (void)forwardInvocationExchange:(NSInvocation *)invocation
{
    if([self isKindOfClass:[MOAManagedObjectNoCache class]]) {
        return [self forwardInvocationExchange:invocation];
    }
    
    if (!kFlagDebug&&[[self class]shoudCreateTableViewSignature:[invocation selector]]) {
        UITableView *tableView = [[UITableView alloc]init];
        [invocation invokeWithTarget:tableView];
        NSLogToFile(@"bug:%s dose not respond to method %@",object_getClassName(self),NSStringFromSelector([invocation selector]));
    }
    else{
        logAbort(@"bug:%s dose not respond to method %@",object_getClassName(self),NSStringFromSelector([invocation selector]));
    }
}


- (NSMethodSignature *)methodSignatureForSelectorExchange:(SEL)selector
{
    if([self isKindOfClass:[MOAManagedObjectNoCache class]]) {
        return [self methodSignatureForSelectorExchange:selector];
    }
    
    NSMethodSignature *sig = [[self class] instanceMethodSignatureForSelector:selector];
    if(sig == nil) {
        if ([[self class] shoudCreateTableViewSignature:selector]) {
            sig = [UITableView instanceMethodSignatureForSelector:selector];
        }
    }
    return sig;
}

+(BOOL)shoudCreateTableViewSignature:(SEL)selector
{
    //如果是tableview的方法,那么不崩溃
    return  ![UIView instancesRespondToSelector:selector]&&[UITableView instancesRespondToSelector:selector];
}

//获取一个类所有方法
- (NSArray*)getClassAllMethods:(Class)class
{
    NSMutableArray *methodsArray = [[NSMutableArray alloc]init];
    unsigned int count;
    Method *methods = class_copyMethodList([self class], &count);
    for (int i = 0; i < count; i++)
    {
        Method method = methods[i];
        SEL selector = method_getName(method);
        NSString *name = NSStringFromSelector(selector);
        [methodsArray addObject:name];
    }
    return methodsArray;
}

@end
