//
//  NSObject+hookMsgSend.h
//  animation
//
//  Created by luqizhou on 2017/4/28.
//  Copyright © 2017年 sangfor. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef __arm64__

@interface NSObject (hookMsgSend)

+ (void)startRecord;
+ (void)stopRecord:(void (^)(NSString *))completion;

@end

#endif
