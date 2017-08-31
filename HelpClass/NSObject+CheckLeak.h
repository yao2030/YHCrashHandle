//
//  NSObject+CheckLeak.h
//  MOA
//
//  Created by neo on 14-8-13.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (CheckLeak)
+ (void)loadChecker;
+ (NSMutableDictionary *)configs;
@end
