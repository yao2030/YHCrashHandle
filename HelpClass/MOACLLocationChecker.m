//
//  MOACLLocationChecker.m
//  MOA
//
//  Created by neo on 14-10-8.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import "MOACLLocationChecker.h"
#import <CoreLocation/CoreLocation.h>
#import <CoreLocation/CLLocationManagerDelegate.h>

@interface MOACLLocationChecker () <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *locationCheckManager;
@end

@implementation MOACLLocationChecker

+ (MOACLLocationChecker *)shareInstatnce
{
	static MOACLLocationChecker *s_instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		s_instance = [[MOACLLocationChecker alloc] init];
	});
	return s_instance;
}

+ (void)check
{
	if (ISIOS8) {
		CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
		NSLogToFile(@"Info: location status :%d", status);
		if (status == kCLAuthorizationStatusNotDetermined) {
            MOACLLocationChecker *checker = [self shareInstatnce];
            if(checker.locationCheckManager == nil)
            {
                checker.locationCheckManager = [[CLLocationManager alloc] init];
                if ([checker.locationCheckManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
                    [checker.locationCheckManager performSelector:@selector(requestWhenInUseAuthorization)];
                }
                checker.locationCheckManager.delegate = checker;
                [checker.locationCheckManager startUpdatingLocation];
            }
		}
	}
}

#pragma mark -  Protocol CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
	if ([self.locationCheckManager isEqual:manager] ) {// 第一次启动检测定位
		if (status != kCLAuthorizationStatusNotDetermined) {
			[self.locationCheckManager stopUpdatingLocation];
			self.locationCheckManager = nil;
		}
		
		NSLogToFile(@"Info: location status changed:%d", status);
	}
}

@end
