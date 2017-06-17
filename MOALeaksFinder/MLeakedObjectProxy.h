//
//  MLeakedObjectProxy.h
//  MOA
//
//  Created by yanghao on 16/7/27.
//  Copyright © 2016年 moa. All rights reserved.
//
#import <Foundation/Foundation.h>

@interface MLeakedObjectProxy : NSObject

+ (BOOL)isAnyObjectLeakedAtPtrs:(NSSet *)ptrs;
+ (void)addLeakedObject:(id)object;

@end
