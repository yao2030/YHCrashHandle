//
//  NSObject+invoke.h
//  MOA
//
//  Created by luqizhou on 16/6/21.
//  Copyright © 2016年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (invoke)

+ (id)invokeSelect:(SEL)selector obj:(id)obj objcTypes:(const char *)types enumerateArgs:(void (^)(NSInvocation *invocation))block;

+ (NSString *)ctypes:(id)obj sel:(SEL)sel;

@end
