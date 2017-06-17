//
//  NSObject+MemoryLeak.h
//  MOA
//
//  Created by yanghao on 16/7/27.
//  Copyright © 2016年 moa. All rights reserved.
//
#import <Foundation/Foundation.h>

#define MLCheck(TARGET) [self willReleaseObject:(TARGET) relationship:@#TARGET];

@interface NSObject (MemoryLeak)

- (BOOL)willDealloc;
- (void)willReleaseObject:(id)object relationship:(NSString *)relationship;

- (void)willReleaseChild:(id)child;
- (void)willReleaseChildren:(NSArray *)children;

- (NSArray *)viewStack;

+ (void)swizzleSEL:(SEL)originalSEL withSEL:(SEL)swizzledSEL;

@end
