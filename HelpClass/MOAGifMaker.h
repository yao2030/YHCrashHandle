//
//  MOAGifMaker.h
//  MOA
//
//  Created by neo on 14-10-11.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MOAGifMaker : NSObject
+ (instancetype)shareInstance;
- (void)test;

+ (NSData *)createWithOption:(NSDictionary *)option andImages:(NSArray *)images andImageTimePoints:(NSArray *)timePoints;
@end
