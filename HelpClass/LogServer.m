//
//  LogServer.m
//  MOA
//
//  Created by neo on 14-1-18.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import "LogServer.h"
//#import "CoredataManager+NetConnect.h"
#import "WYScript.h"
#include <unistd.h>

#define LOG_SERVER_NAME	@"LogServer"
#define LOG_SERVER_PORT	30001

#ifdef NSLog
#undef NSLog
#endif

/**
 *	config格式:
 @"userinfo":NSMutableDictionary
 
 */

static FILE *redirectStderr = NULL;

@implementation LogServer


+ (BOOL)start
{
	if (! kFlagDebug && !g_enableDebug) {// 非debug模式不开启
		return YES;
	}
	TCPServer *shareServer = [TCPServer sharedInstance];
	return [shareServer startServerOnPort:LOG_SERVER_PORT withName:LOG_SERVER_NAME andRecvCallback:^(id result, id userInfo, NSInteger *flag) {
		NSString *name = nil;
		NSMutableDictionary *clientConfig = nil;
		[shareServer findName:&name andConfig:&clientConfig withInputStream:userInfo orOutStream:nil];
		NSData *recvData = result;
		static BOOL startWYScript = NO;
		startWYScript = (kFlagDebug || g_enableDebug);
		if (recvData) {
			if (recvData.length == 5) {// ^C 控制符
				NSString *ctlString = [EntrysOperateHelper HexStringFromBytes:recvData.bytes andLength:recvData.length];
				if ([ctlString isEqualToString:@"FFF4FFFD06"]) {
					if (startWYScript == YES) {
						[self writeNSString:@"Info: exit WY Script\n"];
						startWYScript = NO;
						return ;
					}
					NSLog(@"client want to exit");
					if (flag) {
						*flag = YES;
					}
					return ;
				}else{
					NSLog(@"Tips: unknown ctl command:%@", ctlString);
				}
			}
			NSString *recvString = [[NSString alloc] initWithBytes:recvData.bytes
															length:recvData.length
														  encoding:NSUTF8StringEncoding];
			if ([recvString hasSuffix:@"\n"]) {
				
				if (startWYScript) {
					dispatch_async(dispatch_get_main_queue(), ^{
						@try {
							NSError *error = nil;
							[WYScript runCommand:recvString error:&error];
						}
						@catch (NSException *exception) {
							NSLog(@"Exception Info:%@", exception);
						}
						@finally {
							
						}
						
					});
				}else{
					recvString = [recvString stringByReplacingOccurrencesOfString:@"\r" withString:@""];
					recvString = [recvString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
					
					if ([recvString isEqualToString:@"script"]) {
						startWYScript = YES;
						[self writeNSString:@"Info: start WY Script\n"];
						return;
					}
				}
				
				
				
				
				
//				if ([recvString isEqualToString:@"startNetLog"]) {
//					NSLog(@"Tips: Start record net log");
//					[CoredataManager setNetLogFile:YES];
//				}else if ([recvString isEqualToString:@"stopNetLog"]) {
//					NSLog(@"Tips: Stop record net log");
//					[CoredataManager setNetLogFile:NO];
//				}else{
//					NSLogToFile(@"Warn: Unknown command:%@", recvString);
//				}
				return ;
			}
			if (recvString) {
				NSLog(@"Recv(%zd): %@", recvData.length, recvString);
			}else{
				
			}
		}
	}];
}

+ (void)stop
{
	if (! kFlagDebug && !g_enableDebug) {// 非debug模式不开启
		return ;
	}
	TCPServer *shareServer = [TCPServer sharedInstance];
	[shareServer stopServerWithName:LOG_SERVER_NAME];
	
}

+ (void)writeNSString:(NSString *)stringValue
{
	TCPServer *shareServer = [TCPServer sharedInstance];
	[shareServer writeNSString:stringValue withName:LOG_SERVER_NAME];
}

#pragma mark - log
+ (void)logWithFormat:(NSString *)format, ...
{
	if (! (kFlagDebug || g_enableDebug)) {
		return;
	}
	if (! [LogServer globleConfig][LOG_SERVER_NAME]) {
		return;
	}
    va_list argList;
	
    NSAssert(format != nil, nil);
    va_start(argList, format);
	NSString *value = [[NSString alloc] initWithFormat:format arguments:argList];
    va_end(argList);
	value = [NSString stringWithFormat:@"%@ %@\r\n", [EntrysOperateHelper stringFromDate:nil andFormat:nil], value];
	[self writeNSString:value];
}
+ (BOOL)enableLoger:(NSNumber *)toEnable
{
	static BOOL enable = YES;
	if (toEnable) {
		enable = [toEnable boolValue];
	}
	return enable;
}

+ (void)flushRedirectStderr:(BOOL)close
{
    @synchronized(self) {
        if(redirectStderr) {
            fflush(redirectStderr);
            if(close) {
                fclose(redirectStderr);
                redirectStderr = NULL;
            }
        }
    }
}

+ (void)openRedirectStderr:(NSString *)path
{
    @synchronized(self) {
        [self flushRedirectStderr:YES];
        redirectStderr = freopen(path.UTF8String, "a+", stderr);
    }
}

+ (void)logToFileWithFormat:(NSString *)format, ...
{
    static BOOL lastResult = YES;
    static NSString *path = nil;
	static NSFileHandle *fileHandle  = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSURL *filePath = [[EntrysOperateHelper getURLForDocumentSubDir:nil] URLByAppendingPathComponent:@"log/appEventsLog.txt"];
    
		if([EntrysOperateHelper touchDirForFilePath:filePath.path]) {
			NSLogToFile(@"Warn: create appEventsLog.txt path failed");
			return;
		}
        
        NSFileManager *manager = [NSFileManager defaultManager];
        if([manager fileExistsAtPath:filePath.path])
        {
            [manager setAttributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} ofItemAtPath:filePath.path error:nil];
        }
        else
        {
            [manager createFileAtPath:filePath.path contents:nil attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication}];
        }
        
        path = filePath.path;
		fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
        
#ifdef __OPTIMIZE__
        filePath = [[EntrysOperateHelper getURLForDocumentSubDir:nil] URLByAppendingPathComponent:@"log/stderr.txt"];
        [EntrysOperateHelper touchDirForFilePath:filePath.path];
        if([manager fileExistsAtPath:filePath.path]) {
            if([[manager attributesOfItemAtPath:filePath.path error:nil][NSFileSize] longLongValue] > 2*1024*1024) {
                [manager removeItemAtPath:filePath.path error:nil];
                [manager createFileAtPath:filePath.path contents:nil attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication}];
            }else {
                [manager setAttributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} ofItemAtPath:filePath.path error:nil];
            }
        }else {
            [manager createFileAtPath:filePath.path contents:nil attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication}];
        }
        [self openRedirectStderr:filePath.path];
#endif
        
	});

	NSAssert(fileHandle != nil, nil);
	if (! [self enableLoger:nil]) {
		return;
	}
	NSString *userName = [[MOAModelManager defaultInstance] getUserName];
	@synchronized(fileHandle) {
		uint64_t oldFileSize = [fileHandle seekToEndOfFile];
#define kMaxLocalLogSize 2*1024*1024
		if (oldFileSize > kMaxLocalLogSize) {//大于2M就截断成1M
			//todo  tunck
			[fileHandle seekToFileOffset:oldFileSize - kMaxLocalLogSize/2];
			NSData * retainData = [fileHandle readDataToEndOfFile];
			[fileHandle truncateFileAtOffset:0];
			[fileHandle writeData:retainData];
		}
		va_list argList;
		NSAssert(format != nil, nil);
		va_start(argList, format);
		NSString *value = [[NSString alloc] initWithFormat:format arguments:argList];
		va_end(argList);
       
#ifndef __OPTIMIZE__
		NSLog(@"%@", value);
#endif
        
		value = [NSString stringWithFormat:@"[%@-%@]%@\n", userName, [EntrysOperateHelper stringFromDate:nil andFormat:@"yyyyMMdd HH:mm:ss"], value];
		
        if(lastResult == NO)
        {
            if([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
            {
                return;
            }
            
            int fd = open(path.UTF8String, O_RDONLY);
            if(fd < 0)
            {
                return;
            }
            
            close(fd);
            lastResult = YES;
        }
        
        @try {
            [fileHandle writeData:[value dataUsingEncoding:NSUTF8StringEncoding]];
        }
        @catch (NSException *exception) {
            lastResult = NO;
        }
        @finally {
        }
	}
}


@end
