//
//  NSObject+zombie.h
//  MOA
//
//  Created by luqizhou on 15-2-28.
//  Copyright (c) 2015年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (zombie)

+ (NSArray *)findZombie:(void *)addr;

+ (void)enableZombie:(int)cacheSize;

@end
