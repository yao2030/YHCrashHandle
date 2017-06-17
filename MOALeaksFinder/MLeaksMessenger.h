//  MLeaksMessenger.h
//  MOA
//
//  Created by yanghao on 16/7/27.
//  Copyright © 2016年 moa. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MLeaksMessenger : NSObject

+ (void)alertWithTitle:(NSString *)title message:(NSString *)message;
+ (void)alertWithTitle:(NSString *)title
               message:(NSString *)message
              delegate:(id<UIAlertViewDelegate>)delegate
 additionalButtonTitle:(NSString *)additionalButtonTitle;

@end
