//
//  GetIPAddress.h
//  MOA
//
//  Created by neo on 14-12-11.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kMOAWANAddressRegionKey @"kMOAWANAddressRegionKey"
#define kMOAWANAddressRegionChangeNoti @"kMOAWANAddressRegionChangeNoti"

@interface GetIPAddress : NSObject
+ (NSString *)getIPAddress:(BOOL)preferIPv4;
+ (NSDictionary *)getIPAddresses;

//获取外网IP
+ (void)fetchWANIPAddressWithCompletion:(void(^)(NSString *ipAddress))completion;

//判断外网IP所属区域
+ (void)fetchWANIPAddressRegion:(NSString *)address completion:(void(^)(NSString *regionOfAddress))completion;

//检查判断公网的区域
+ (void)toCheckWANIPAddressRegion;

@end
