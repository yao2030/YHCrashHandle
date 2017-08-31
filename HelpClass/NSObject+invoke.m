//
//  NSObject+invoke.m
//  MOA
//
//  Created by luqizhou on 16/6/21.
//  Copyright © 2016年 moa. All rights reserved.
//

#import "NSObject+invoke.h"

@implementation NSObject (invoke)

+ (id)invokeSelect:(SEL)selector obj:(id)obj objcTypes:(const char *)types enumerateArgs:(void (^)(NSInvocation *invocation))block
{
    BOOL isInstance = ([obj class] == obj)? NO: YES;
    
    if([obj isKindOfClass:[MOAManagedObjectNoCache class]]) {
        [obj methodSignatureForSelector:selector];
    }
    
    Method method = isInstance? class_getInstanceMethod([obj class], selector): class_getClassMethod([obj class], selector);
    NSAssertRet(MOAErrorMake(kResultInvalidArgs, 0), method && types, nil);
    
    NSMethodSignature *mySignature = [NSMethodSignature signatureWithObjCTypes:types];
    NSInvocation *myInvovation = [NSInvocation invocationWithMethodSignature:mySignature];
    myInvovation.target = obj;
    myInvovation.selector = selector;
    
    block(myInvovation);
    
    @try {
        [myInvovation invoke];
    }
    @catch (NSException *exception) {
        NSLogToFile(@"Error: callModelsSelector failed: %@", exception);
        return MOAErrorMake(kResultInvalidArgs, 0);
    }
    
    return myInvovation;
}

+ (NSString *)ctypes:(id)obj sel:(SEL)sel
{
    NSMethodSignature *s = [obj methodSignatureForSelector:sel];
    NSMutableString *ctypes = [NSMutableString string];
    char c = *[s methodReturnType];
    [ctypes appendFormat:@"%c", c];
    for(int i = 0; i < s.numberOfArguments; i++) {
        char c = *[s getArgumentTypeAtIndex:i];
        [ctypes appendFormat:@"%c", c];
    }
    return ctypes;
}

@end
