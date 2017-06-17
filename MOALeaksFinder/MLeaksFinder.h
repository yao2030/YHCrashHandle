//
//  MLeaksFinder.h
//  MOA
//
//  Created by yanghao on 16/7/27.
//  Copyright © 2016年 moa. All rights reserved.
//
#import "NSObject+MemoryLeak.h"
#import <Foundation/Foundation.h>
#import "YHCatchFree.h"

#ifndef __OPTIMIZE__
#define _INTERNAL_MLF_ENABLED 1
#else
#define _INTERNAL_MLF_ENABLED 0
#endif


#if (defined __COMPLIE_ENTERPRISE__) || (!defined __OPTIMIZE__)
#define _INTERNAL_WILDPOINT_ENABLED 1
#else
#define _INTERNAL_WILDPOINT_ENABLED 0
#endif

