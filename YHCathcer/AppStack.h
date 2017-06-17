//
//  AppStack.h
//  AppStack
//
//  Created by luqizhou on 16/9/20.
//  Copyright © 2016年 sangfor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AppStack : NSObject

+ (NSString *)mainCallStack;
+ (NSString *)currentCallStack;
+ (NSString *)allCallStack;

+ (NSString *)viewStack;

+ (NSString *)imageAddrDescription;

@end
