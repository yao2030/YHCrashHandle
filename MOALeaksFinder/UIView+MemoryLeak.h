//
//  UIView+MemoryLeak.h
//  MOA
//
//  Created by yanghao on 16/7/27.
//  Copyright © 2016年 moa. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "MLeaksFinder.h"

#if _INTERNAL_MLF_ENABLED

@interface UIView (MemoryLeak)

@end

#endif
