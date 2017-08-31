//
//  NSObject+observer.m
//  MOA
//
//  Created by luqizhou on 14-9-5.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import "NSObject+observer.h"
#import <objc/runtime.h>

@implementation NSObject (observer)

- (void)safeRemoveObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
{
    @try {
        [self safeRemoveObserver:observer forKeyPath:keyPath];
    }
    @catch (NSException *exception) {
        if(kFlagDebug)
        {
            [exception raise];
        }
        else
        {
            logMsg(@"\nreason:\n%@\nobservationInfo:\n%@\n", exception.reason, [self observationInfo]);
        }
    }
    @finally {
        
    }
}

+ (void)initObserverCategory
{
    Method originalMethod = class_getInstanceMethod([NSObject class], @selector(removeObserver:forKeyPath:));
    Method newMethod = class_getInstanceMethod([self class], @selector(safeRemoveObserver:forKeyPath:));

    method_exchangeImplementations(originalMethod, newMethod);
}

@end
