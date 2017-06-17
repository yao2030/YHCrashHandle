//
//  YHCatchProxy.h
//  testCrash
//
//  Created by yanghao on 2017/5/13.
//  Copyright © 2017年 justlike. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YHCatchProxy : NSObject
@property (readwrite,assign,nonatomic) Class origClass;

@end
