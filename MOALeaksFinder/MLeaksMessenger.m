//
//  MLeaksMessenger.m
//  MOA
//
//  Created by yanghao on 16/7/27.
//  Copyright © 2016年 moa. All rights reserved.
//
#import "MLeaksMessenger.h"

static __weak UIAlertView *alertView;

@implementation MLeaksMessenger

+ (void)alertWithTitle:(NSString *)title message:(NSString *)message {
    [self alertWithTitle:title message:message delegate:nil additionalButtonTitle:nil];
}

+ (void)alertWithTitle:(NSString *)title
               message:(NSString *)message
              delegate:(id<UIAlertViewDelegate>)delegate
 additionalButtonTitle:(NSString *)additionalButtonTitle {
    [alertView dismissWithClickedButtonIndex:0 animated:NO];
    UIAlertView *alertViewTemp = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:delegate
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:additionalButtonTitle, nil];
    [alertViewTemp show];
    alertView = alertViewTemp;
    
    NSLog(@"%@: %@", title, message);
}

@end
