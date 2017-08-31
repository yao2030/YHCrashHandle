//
//  GetIPAddress.m
//  MOA
//
//  Created by neo on 14-12-11.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import "GetIPAddress.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>
#import "AFNetworking.h"

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"
@implementation GetIPAddress
+ (NSString *)getIPAddress:(BOOL)preferIPv4
{
	NSArray *searchArray = preferIPv4 ?
	@[ IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
	@[ IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
	
	NSDictionary *addresses = [self getIPAddresses];
//	NSLog(@"addresses: %@", addresses);
	
	__block NSString *address;
	[searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
	 {
		 address = addresses[key];
		 if(address) *stop = YES;
	 } ];
	return address ? address : @"0.0.0.0";
}

+ (NSDictionary *)getIPAddresses
{
	NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
	
	// retrieve the current interfaces - returns 0 on success
	struct ifaddrs *interfaces;
	if(!getifaddrs(&interfaces)) {
		// Loop through linked list of interfaces
		struct ifaddrs *interface;
		for(interface=interfaces; interface; interface=interface->ifa_next) {
			if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
				continue; // deeply nested code harder to read
			}
			const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
			char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
			if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
				NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
				NSString *type;
				if(addr->sin_family == AF_INET) {
					if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
						type = IP_ADDR_IPv4;
					}
				} else {
					const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
					if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
						type = IP_ADDR_IPv6;
					}
				}
				if(type) {
					NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
					addresses[key] = [NSString stringWithUTF8String:addrBuf];
				}
			}
		}
		// Free memory
		freeifaddrs(interfaces);
	}
	return [addresses count] ? addresses : nil;
}

+ (void)fetchWANIPAddressWithCompletion:(void(^)(NSString *ipAddress))completion
{
    if (!completion) {
        return;
    }
    
    NSString *getIpStrOfHttps = @"https://pv.sohu.com/cityjson?ie=utf-8";
    //NSString *getIpStrOfHttp = @"http://ifconfig.me/ip";

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    [manager GET:getIpStrOfHttps parameters:@"" success:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
        NSString *address = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        NSLog(@"address:%@", address); //var returnCitySN = {"cip": "14.127.219.87", "cid": "440000", "cname": "广东省"}
        NSString *returnIp = nil;
        if ([address isKindOfClass:[NSString class]]) {
            if ([address rangeOfString:@"returnCitySN"].location != NSNotFound)
            {
                NSRange leftRange = [address rangeOfString:@"{"];
                NSRange rightRange = [address rangeOfString:@"}"];
                if (leftRange.location != NSNotFound && rightRange.location != NSNotFound && leftRange.location < rightRange.location) {
                    NSInteger length = (rightRange.location-leftRange.location) + 1;
                    if (length > 0 && length < address.length) {
                        NSString * nowIp = [address substringWithRange:NSMakeRange(leftRange.location, length)];
                        NSData * data = [nowIp dataUsingEncoding:NSUTF8StringEncoding];
                        NSDictionary * dict = [EntrysOperateHelper dictFromJson:data errorOut:YES];
                        if ([dict isKindOfClass:[NSDictionary class]] && [dict[@"cip"] isKindOfClass:[NSString class]]) {
                            returnIp = dict[@"cip"];
                        }
                    }
                }
            }
        }
        
        if (returnIp) {
            completion([returnIp trimmingSpaceAndNewLine]);
        }
        else {
            NSLog(@"fetch WAN IP Address failed:%@", responseObject);
        }
    } failure:^(NSURLSessionDataTask * _Nonnull task, NSError * _Nonnull error) {
        NSLog(@"fetch WAN IP Address failed:%@", error);
    }];
}

//判断外网IP所属区域
+ (void)fetchWANIPAddressRegion:(NSString *)address completion:(void(^)(NSString *regionOfAddress))completion
{
    if (!completion) {
        return;
    }
    if (address.length == 0) {
        completion(nil);
    }
    
    /* //测试地址
     1 69.235.24.133 3127 HTTP [C]美国 加利福尼亚大学 06-04 17:39 0.767 whois
     2 153.19.50.62 80 HTTP 波兰 ProxyCN 06-04 17:31 0.992 whois
     3 203.69.66.102 80 HTTP 台湾省 中华电信 06-04 17:46 0.996 whois
     4 59.39.145.178 3128 HTTP 广东省惠州市 电信 06-04 17:36 0.998 whois
     5 115.68.28.11 8080 HTTP 欧洲 ProxyCN 06-04 17:33 0.998 whois
     6 169.235.24.133 3128 HTTP 美国 06-04 17:50 1.000 whois
     7 210.51.23.244 80 HTTP 上海市 漕河泾网通IDC机房 06-04 17:48 1.000 whois
     8 220.194.58.240 3128 HTTP 北京市 联通
     */
    
    //http://ip.taobao.com/service/getIpInfo.php?ip=%@
    //https://ip.ws.126.net/ipquery?ip=%@
    //https://apis.baidu.com/apistore/iplookupservice/iplookup?ip=%@
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
//    [manager.requestSerializer setValue:@"2f22850ac8191f0714f56033fab866d9" forHTTPHeaderField:@"apikey"];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    NSString *urlStr = [NSString stringWithFormat:@"http://ip.taobao.com/service/getIpInfo.php?ip=%@", address];
    [manager GET:urlStr parameters:@"" success:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
        NSString *jsonString = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        //对应百度url解析方式
        /*
        if ([jsonString isKindOfClass:[NSString class]]) {
            NSDictionary *jsonObj = [EntrysOperateHelper dictFromJsonString:jsonString];
            if ([jsonObj isKindOfClass:[NSDictionary class]] && [jsonObj[@"retData"] isKindOfClass:[NSDictionary class]] && [jsonObj[@"retData"][@"country"] isKindOfClass:[NSString class]]) {
                NSLog(@"fetchWANIPAddressRegion success:%@", jsonObj);
                completion(jsonObj[@"retData"][@"country"]);
            }
            else {
                NSLog(@"fetchWANIPAddressRegion failed:%@", jsonObj);
                completion(nil);
            }
        }
         */
        //淘宝url解析方式
        if ([jsonString isKindOfClass:[NSString class]]) {
            NSDictionary *jsonObj = [EntrysOperateHelper dictFromJsonString:jsonString];
            if ([jsonObj isKindOfClass:[NSDictionary class]] && [jsonObj[@"data"] isKindOfClass:[NSDictionary class]] && [jsonObj[@"data"][@"country_id"] isKindOfClass:[NSString class]]) {
                NSLog(@"fetchWANIPAddressRegion success:%@", jsonObj);
                completion(jsonObj[@"data"][@"country_id"]);
            }
            else {
                NSLog(@"fetchWANIPAddressRegion failed:%@", jsonObj);
                completion(nil);
            }
        }
        
    } failure:^(NSURLSessionDataTask * _Nonnull task, NSError * _Nonnull error) {
        NSLog(@"fetchWANIPAddressRegion failed:%@", error);
        completion(nil);
    }];
}

+ (void)toCheckWANIPAddressRegion
{
    NSLog(@"start toCheckWANIPAddressRegion:%f", [NSDate timeIntervalSinceReferenceDate]);
    NSString *regionOfAddress = [[NSUserDefaults standardUserDefaults] objectForKey:kMOAWANAddressRegionKey];
    if (regionOfAddress == nil || [regionOfAddress isEqualToString:@"CN"]==NO) {
        [[self class] fetchWANIPAddressWithCompletion:^(NSString *ipAddress) {
            if ([ipAddress isKindOfClass:[NSString class]] == NO) {
                return ;
            }
            [[self class] fetchWANIPAddressRegion:ipAddress completion:^(NSString *regionOfAddress) {
                if ([regionOfAddress isKindOfClass:[NSString class]] == NO) {
                    return ;
                }
                if ([regionOfAddress isEqualToString:@"中国"]) {
                    regionOfAddress = @"CN";
                }
                [[NSUserDefaults standardUserDefaults] setObject:regionOfAddress forKey:kMOAWANAddressRegionKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
                NSLogToFile(@"update region of address success: %@", regionOfAddress);
                [[NSNotificationCenter defaultCenter] postNotificationName:kMOAWANAddressRegionChangeNoti object:nil];
                NSLog(@"end toCheckWANIPAddressRegion:%f", [NSDate timeIntervalSinceReferenceDate]);
            }];
        }];
    }
}

@end
