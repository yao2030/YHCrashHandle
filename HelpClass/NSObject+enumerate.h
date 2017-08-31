//
//  NSObject+enumerate.h
//  MOA
//
//  Created by luqizhou on 16/3/19.
//  Copyright © 2016年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (enumerate)

+ (void)enumeratePropertysKeyUsingBlock:(void (^)(NSString *key, BOOL *stop))block;
- (void)enumeratePropertysUsingBlock:(void (^)(NSString *key, id value, BOOL *stop))block;

- (NSString *)pointerDescription;

- (BOOL)matchPredicate:(NSPredicate *)predicate;

@end
