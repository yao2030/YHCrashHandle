//
//  LogServer.h
//  MOA
//
//  Created by neo on 14-1-18.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import "TCPServer.h"

@interface LogServer : TCPServer
+ (BOOL)start;
+ (void)stop;
+ (void)logWithFormat:(NSString *)format, ...;
+ (void)logToFileWithFormat:(NSString *)format, ...;
+ (BOOL)enableLoger:(NSNumber *)toEnable;

+ (void)flushRedirectStderr:(BOOL)close;
+ (void)openRedirectStderr:(NSString *)path;

@end
