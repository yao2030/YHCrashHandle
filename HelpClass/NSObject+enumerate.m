//
//  NSObject+enumerate.m
//  MOA
//
//  Created by luqizhou on 16/3/19.
//  Copyright © 2016年 moa. All rights reserved.
//

#import "NSObject+enumerate.h"

@implementation NSObject (enumerate)

+ (void)enumeratePropertysKeyUsingBlock:(void (^)(NSString *key, BOOL *stop))block
{
    if(block == nil) {
        return;
    }
    
    unsigned int outCount = 0;
    objc_property_t *properties = class_copyPropertyList(self, &outCount);
    for(int i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *key = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        
        BOOL stop = NO;
        block(key, &stop);
        
        if(stop) {
            break;
        }
    }
}

- (void)enumeratePropertysUsingBlock:(void (^)(NSString *key, id value, BOOL *stop))block
{
    if(block == nil) {
        return;
    }
    
    unsigned int outCount = 0;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    for(int i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *key = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        id value = [self valueForKey:key];
        
        BOOL stop = NO;
        block(key, value, &stop);
        
        if(stop) {
            break;
        }
    }
}

- (NSString *)pointerDescription
{
    if(sizeof(void *) == 8) {
        return [NSString stringWithFormat:@"0x%llx", (unsigned long long)self];
    }
    return [NSString stringWithFormat:@"0x%x", (unsigned int)self];
}

- (BOOL)matchPredicate:(NSPredicate *)predicate
{
    NSAssertRet(NO, predicate, nil);
    return ([@[self] filteredArrayUsingPredicate:predicate].count > 0);
}

@end
