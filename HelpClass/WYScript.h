//
//  WYScript.h
//  MOA
//
//  Created by neo on 14-5-30.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WYScript : NSObject
+ (void)runCommand:(NSString *)command withCallback:(MOACallback)callback;
+ (NSString *)runCommand:(NSString *)command error:(NSError **)error;
+ (void)resetStack;
@end
