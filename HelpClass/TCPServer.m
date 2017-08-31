//
//  TCPServer.m
//  MOA
//
//  Created by neo on 14-1-16.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import "TCPServer.h"
#import <sys/socket.h>
#import <netinet/in.h>
#include <sys/types.h>
#include <net/ethernet.h>
#include <arpa/inet.h>
#include <assert.h>

#define TCPSERVER_DEFAULT_PORT	30000
#define TCPSERVER_DEFAULT_NAME	@"wuyuan"
#define DEFAULT_RECV_BUFF_SIZE 1024*5


#ifdef NSLog
#undef NSLog
#endif

@interface TCPServer ()



@end
/**
 *	@{name:@{@"port":Port,
			@"socket":CFSocket(id),
			@"readCallback":callback
			@"clients":@[@{
							@"socket":CFSocket(id),
							@"ip":NSString,
							@"port":NSnumber,
							@"write":NSOutputStream,
							@"read":NSInputStream,
							@"userinfo":id,
							@"readCallback":callback (option)
			}]
	}
 }
 */
static NSMutableDictionary *globelConfig;

@implementation TCPServer

+ (instancetype)sharedInstance
{
	static TCPServer *sharedTCPServer;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedTCPServer = [[TCPServer alloc] init];
		globelConfig = [NSMutableDictionary dictionary];
	});
	return sharedTCPServer;
}
+ (NSMutableDictionary *)globleConfig
{
	return globelConfig;
}
+ (NSMutableDictionary *)findConfigWithName:(NSString *)name
{
	if (! name) {
		name = TCPSERVER_DEFAULT_NAME;
	}
	if (! [name isKindOfClass:[NSString class]]) {
		NSLogToFile(@"Warn: invalid arg: %@", name);
		return nil;
	}
	NSMutableDictionary *result = nil;
	@synchronized(globelConfig){
		result = globelConfig[name];
	}
	return result;

}



/**
 *	开启服务
 *
 *	@param port     port
 *	@param name     name description
 *	@param callback 接收消息回调
 *
 *	@return return value description
 */
- (BOOL)startServerOnPort:(UInt16)port withName:(NSString *)name andRecvCallback:(CallbackWithFlag)callback
{
	if (! name) {
		name = TCPSERVER_DEFAULT_NAME;
	}
	if (port == 0) {
		port = TCPSERVER_DEFAULT_PORT;
	}
	
	NSMutableDictionary *config = [TCPServer findConfigWithName:name];
	BOOL alreadyStart = NO;
	if (config) {
		if (! CFSocketIsValid((__bridge CFSocketRef)config[@"socket"])) {
			NSLog(@"Tips: old socket is invalid");
		}
		if ([config[@"shouldReset"] boolValue] == YES) {
			NSLogToFile(@"Info: restart");
			[self stopServerWithName:name];
		}else{
			alreadyStart = YES;
		}
	}
	config = [NSMutableDictionary dictionary];
	
	
	CFSocketContext CTX = {0, (__bridge void *)(name), NULL, NULL, NULL};
	CFSocketRef sock = CFSocketCreate(NULL, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)AcceptCallBack, &CTX);
	if (sock == NULL) {
		NSLogToFile(@"Warn: create socket failed for server");
		return NO;
		
	}
	//NSLog(@"Tips: create socket success");
	int flagRebind = YES;
	int result = setsockopt(CFSocketGetNative(sock),
							SOL_SOCKET,
							SO_REUSEADDR,
							&flagRebind,
							sizeof(flagRebind));
	if (result) {
		NSLogToFile(@"Warn: setsockopt failed: %d", result);
	}
	
	struct sockaddr_in addr;
	memset(&addr, 0, sizeof(addr));
	addr.sin_len = sizeof(addr);
	addr.sin_family = AF_INET;
	addr.sin_port = htons(port);
	addr.sin_addr.s_addr = htonl(INADDR_ANY);
	
	CFDataRef address = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&addr, sizeof(addr));
	CFSocketError bindErr = CFSocketSetAddress(sock, address);
	if (bindErr != kCFSocketSuccess) {
		if (! alreadyStart) {
			NSLogToFile(@"Warn: bind addr failed:%ld", bindErr);
		}
		CFSocketInvalidate(sock);
		CFRelease(sock);
		return YES;
	}

	if (alreadyStart) {
		[self stopServerWithName:name andCloseSock:NO];//关闭之前的无效服务
		NSLog(@"old server is invalid, close it");
		//CFSocketInvalidate(sock);
		//CFRelease(sock);
		//return [self startServerOnPort:port withName:name andRecvCallback:callback];
	
	}
	
	CFRunLoopSourceRef sourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, sock, 0);
	
	//add config
	id socket = (__bridge_transfer id)sock;
	config[@"socket"] = socket;
	config[@"port"] = [NSNumber numberWithInt:port];
	if (callback) {
		config[@"readCallback"] = callback;
	}
	config[@"clients"] = [NSMutableArray array];
	@synchronized(globelConfig){
		globelConfig[name] = config;
	}
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		CFRunLoopRef runloop = CFRunLoopGetCurrent();
		id runloopRef = (__bridge id)runloop;
		globelConfig[name][@"runloopRef"] = runloopRef;
		id runLoopSourceRef = (__bridge id)sourceRef;
		globelConfig[name][@"runLoopSourceRef"] = runLoopSourceRef;
		CFRunLoopAddSource(runloop, sourceRef, kCFRunLoopCommonModes);
		CFRelease(sourceRef);
		NSLog(@"Tips: server socket is listening on port %d", port);
		CFRunLoopRun();
		NSLog(@"Runloop exit");
	});
	return YES;
}
/**
 *	根据name关闭对应的服务
 *
 *	@param name name description
 */
- (void)stopServerWithName:(NSString *)name
{
	return [self stopServerWithName:name andCloseSock:YES];
}
- (void)stopServerWithName:(NSString *)name andCloseSock:(BOOL)closeSock
{
	
	[self closeAllConnectionsWithName:name];
	//alloc resouces
	NSMutableDictionary *config = [TCPServer findConfigWithName:name];

	if (closeSock) {
		if (config[@"socket"]) {
			CFSocketRef sock = (__bridge CFSocketRef)config[@"socket"];
			assert( CFGetTypeID(sock) == CFSocketGetTypeID() );
			CFSocketInvalidate(sock);
		}
	}
	CFRunLoopSourceRef runLoopSourceRef = (__bridge CFRunLoopSourceRef)config[@"runLoopSourceRef"];
	CFRunLoopRef runloopRef = (__bridge CFRunLoopRef)config[@"runloopRef"];
	CFRunLoopRemoveSource(runloopRef, runLoopSourceRef, kCFRunLoopCommonModes);
	CFRunLoopStop(runloopRef);
	
	@synchronized(globelConfig){
		if (name) {
			[globelConfig removeObjectForKey:name];
		}
	}
	
	//NSLog(@"Tips: stoped server:%@", name);
}

- (void)closeAllConnectionsWithName:(NSString *)name
{
	if (! name) {
		name = TCPSERVER_DEFAULT_NAME;
	}
	NSMutableDictionary *config = [TCPServer findConfigWithName:name];
	@synchronized(config){
		if (! config) {
			//NSLogToFile(@"Warn: no server start with name:(%@)", name);
			return;
		}
		
		[(NSMutableArray *)config[@"clients"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			[[TCPServer sharedInstance] closeConnectionWithClientConfig:obj];
		}];
		[config[@"clients"] removeAllObjects];
	}
}
	
#define SEND_BUFF_SIZE	(1024*50)
void AcceptCallBack(CFSocketRef s,
					CFSocketCallBackType type,
					CFDataRef address,
					const void *data,
					void *info)
{
	CFSocketNativeHandle sock = *(CFSocketNativeHandle *)data;
	NSString *name = (__bridge NSString*)info;
	NSMutableDictionary *config = [TCPServer findConfigWithName:name];
	if (! config) {
		NSLogToFile(@"Warn: cant find config for server name:%@", name);
		return;
	}
	CFReadStreamRef readStream = NULL;
	CFWriteStreamRef writeStream = NULL;
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, sock, &readStream, &writeStream);
	if (!readStream || !writeStream) {
		//close(sock);
		NSLogToFile(@"Warn: (%@) create pair with socket failed", name);
		return;
	}
	
	//add client config
	NSMutableDictionary *clientConfig = [NSMutableDictionary dictionaryWithCapacity:5];
	
	clientConfig[@"BSDsocket"] = [NSNumber numberWithInteger:sock];
	clientConfig[@"read"] = (__bridge_transfer NSInputStream*)readStream;
	clientConfig[@"write"] = (__bridge_transfer NSOutputStream*)writeStream;
	clientConfig[@"sendBuff"] = [NSMutableData dataWithCapacity:SEND_BUFF_SIZE];
	clientConfig[@"sendIndex"] = @0;
	clientConfig[@"endIndex"] = @0;
	
	NSData *addrData =  (__bridge NSData *)address;
	struct sockaddr_in *clientAddr = (struct sockaddr_in *)addrData.bytes;
    
    char ip[INET6_ADDRSTRLEN];
    memset(ip, 0, sizeof(ip));
    inet_ntop(clientAddr->sin_family, &clientAddr->sin_addr, ip, sizeof(ip));
    clientConfig[@"ip"] = [NSString stringWithUTF8String:ip];
    
	clientConfig[@"port"] = [NSNumber numberWithInt:ntohs(clientAddr->sin_port)];
	NSLog(@"Tips: accept from %@:%@", clientConfig[@"ip"], clientConfig[@"port"]);
	[(NSMutableArray *)config[@"clients"] addObject:clientConfig];
	CFStreamClientContext streamContext = {0, info, NULL, NULL, NULL};
	CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventCanAcceptBytes, ReadStreamClientCallBack, &streamContext);
	CFWriteStreamSetClient(writeStream, kCFStreamEventErrorOccurred | kCFStreamEventCanAcceptBytes, WriteStreamClientCallBack, &streamContext);
	CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	CFWriteStreamScheduleWithRunLoop(writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	if(! CFReadStreamOpen(readStream))
	{
		NSLogToFile(@"Warn: Open ReadStream failed");
	}
	if(! CFWriteStreamOpen(writeStream))
	{
		NSLogToFile(@"Warn: Open WriteStream failed");
	}
	
	
}


void ReadStreamClientCallBack(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo)
{
	NSString *name = (__bridge NSString*)clientCallBackInfo;
	NSMutableDictionary *config = [TCPServer findConfigWithName:name];
	if (! config) {
		NSLogToFile(@"Warn: cant find config for server name:%@", name);
		return;
	}
	@synchronized(config){
		__block NSMutableDictionary *clientConfig = nil;
		[(NSMutableArray *)config[@"clients"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			NSMutableDictionary *elemConfig = obj;
			NSInputStream *inputStream = elemConfig[@"read"];
			if ([inputStream isEqual:(__bridge NSInputStream *)stream]) {
				clientConfig = elemConfig;
				*stop = YES;
			}
		}];
		
		if (! clientConfig) {
			NSLogToFile(@"Warn: cant find client config for server name:%@", name);
			return;
		}
		//TCPServer *shareServer = [TCPServer sharedInstance];
		if (type == kCFStreamEventErrorOccurred) {
			NSLog(@"err occur for name: %@ and config:%@, rm", name, clientConfig);
			//[shareServer closeConnectionWithName:name andClientConfig:clientConfig];
			[[TCPServer sharedInstance] closeConnectionWithClientConfig:clientConfig];
			[config[@"clients"] removeObject:clientConfig];
			return;
		}else if (type == kCFStreamEventHasBytesAvailable) {
			UInt8 buff[DEFAULT_RECV_BUFF_SIZE + 1];
			memset(buff, 0, DEFAULT_RECV_BUFF_SIZE + 1);
			if (stream) {
				CFIndex count = CFReadStreamRead(stream, buff, DEFAULT_RECV_BUFF_SIZE);
				if (count == -1 || count == 0) {
					NSLog(@"Tips: client(%@:%@) exit", clientConfig[@"ip"], clientConfig[@"port"]);
					[[TCPServer sharedInstance] closeConnectionWithClientConfig:clientConfig];
					[config[@"clients"] removeObject:clientConfig];
					if (count == -1) {
						NSLogToFile(@"Warn: get -1 from CFReadStreamRead()");
						config[@"shouldReset"] = @YES;
					}
					return;
				}
				NSData *recvData = [NSData dataWithBytes:buff length:count];
				CallbackWithFlag callback = clientConfig[@"readCallback"];
				if (! callback) {
					callback = config[@"readCallback"];
				}
				if (callback) {
					NSInteger stopFlag = NO;
					callback(recvData, (__bridge NSInputStream *)stream, &stopFlag);
					if (stopFlag) {
						[[TCPServer sharedInstance] closeConnectionWithClientConfig:clientConfig];
						[config[@"clients"] removeObject:clientConfig];
						NSLog(@"client exit");
					}
				}
			}
		}else{
			NSLog(@"Unknown type send:%d", (int)type);
		}
	}
	
}

/**
 *	查找对应的配置项
 *
 *	@param outName         outName description
 *	@param outClientConfig outClientConfig description
 *	@param stream          stream description
 *
 *	@return return value description
 */
- (BOOL)findName:(NSString **)outName
	   andConfig:(NSMutableDictionary **)outClientConfig
 withInputStream:(NSInputStream *)inputStream orOutStream:(NSOutputStream *)outputStream
{
	NSArray *names = [globelConfig allKeys];
	__block BOOL flagStop = NO;
	for (NSString *name in names) {
		NSMutableArray *clientsConfig = globelConfig[name][@"clients"];
		[(NSMutableArray *)clientsConfig enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			NSMutableDictionary *clientConfig = obj;
			
			if ((inputStream && [clientConfig[@"read"] isEqual:inputStream])
				|| (outputStream && [clientConfig[@"write"] isEqual:outputStream])) {
				if (name) {
					*outName = name;
				}
				if (clientConfig) {
					*outClientConfig = clientConfig;
				}
				*stop = YES;
				flagStop = YES;
			}
			
			
		}];
		if (flagStop) {
			break;
		}
	}
	if (flagStop) {
		return YES;
	}
	return NO;
}
/**
 *	根据 readstream 关闭对应的连接
 *
 *	@param stream stream description
 */
- (void)closeConnectionWithInputStream:(NSInputStream *)nsinputStream orOutStream:(NSOutputStream *)nsoutputStream
{
	NSString *name = nil;
	NSMutableDictionary *clientConfig = nil;
	if (! [self findName:&name andConfig:&clientConfig withInputStream:nsinputStream orOutStream:nsoutputStream]) {
		return;
	}
	close([clientConfig[@"BSDsocket"] integerValue]);
	CFReadStreamRef inputStream = (__bridge CFReadStreamRef)clientConfig[@"read"];
	CFRunLoopRef runloopRef = (__bridge CFRunLoopRef)globelConfig[name][@"runloopRef"];
	CFReadStreamUnscheduleFromRunLoop(inputStream, runloopRef, kCFRunLoopCommonModes);
	CFWriteStreamRef outputStream = (__bridge CFWriteStreamRef)clientConfig[@"write"];
	CFWriteStreamUnscheduleFromRunLoop(outputStream, runloopRef, kCFRunLoopCommonModes);
	clientConfig[@"invalid"] = @YES;
}
- (void)closeConnectionWithClientConfig:(NSDictionary *)clientConfig
{
	[self closeConnectionWithInputStream:clientConfig[@"read"] orOutStream:clientConfig[@"write"]];
}
- (BOOL)addData:(NSData *)data toServerName:(NSString *)name
{
	NSMutableDictionary *config = [TCPServer findConfigWithName:name];
	if (! config) {
		return NO;
	}
	NSMutableArray *sendDicts = [NSMutableArray array];
	@synchronized(config){
//		CFRunLoopRef runloopRef = (__bridge CFRunLoopRef)config[@"runloopRef"];
//		CFRunLoopWakeUp(runloopRef);
//		CFRunLoopPerformBlock(runloopRef, kCFRunLoopCommonModes, ^{
			if (! config) {
				NSLogToFile(@"Error: find config failed with name:%@", name);
				return NO;
			}
			
			[(NSMutableArray *)config[@"clients"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
				if ([obj[@"invalid"] isEqualToNumber:@YES]) {
					return ;
				}
				NSMutableDictionary *clientConfig = obj;
				
				NSInteger totolCount = data.length;
				
				NSMutableData *sendBuff = clientConfig[@"sendBuff"];
				NSUInteger sendIndex = [clientConfig[@"sendIndex"] unsignedIntegerValue];
				NSUInteger endIndex = [clientConfig[@"endIndex"] unsignedIntegerValue];
				
				//超过buff缓冲的话截断
				NSUInteger orgLength = (endIndex>=sendIndex)?(endIndex-sendIndex):(endIndex+SEND_BUFF_SIZE-sendIndex);
				if (totolCount+orgLength >= SEND_BUFF_SIZE) {
					totolCount = SEND_BUFF_SIZE - orgLength - 1;
				}
				
				//生成 endIndex
				NSUInteger newEndIndex = endIndex + totolCount;
				if (newEndIndex >= SEND_BUFF_SIZE) {
					newEndIndex = newEndIndex - SEND_BUFF_SIZE;
				}
				
				//拷贝数据
				if (newEndIndex < endIndex) {
					memcpy(sendBuff.mutableBytes + endIndex, data.bytes, SEND_BUFF_SIZE - endIndex);
					memcpy(sendBuff.mutableBytes, data.bytes + SEND_BUFF_SIZE - endIndex, newEndIndex);
				}else{
					memcpy(sendBuff.mutableBytes + endIndex, data.bytes, newEndIndex - endIndex);
				}
				clientConfig[@"endIndex"] = [NSNumber numberWithUnsignedInteger:newEndIndex];
				
				//CFWriteStreamCanAcceptBytes((__bridge CFWriteStreamRef)clientConfig[@"write"]);
				//CFStreamStatus writeStatus = CFWriteStreamGetStatus((__bridge CFWriteStreamRef)clientConfig[@"write"]);
				if (CFWriteStreamCanAcceptBytes((__bridge CFWriteStreamRef)clientConfig[@"write"])) {//手动发送
					[sendDicts addObject:@{@"write":clientConfig[@"write"],
										   @"name":name}];
//					WriteStreamClientCallBack((__bridge CFWriteStreamRef)clientConfig[@"write"],
//											  kCFStreamEventCanAcceptBytes,
//											  (__bridge void *)name);
					//[clientConfig removeObjectForKey:@"CanAcceptBytes"];
				}
			}];
		//});
	}
	if (sendDicts.count > 0) {
		for (NSDictionary *dict in sendDicts) {
			[self WriteStreamClientWithData:dict];
		}
	}
	return YES;
	
}
- (void)WriteStreamClientWithData:(NSDictionary *)dataDict
{
	NSAssert(dataDict[@"write"] && dataDict[@"name"], nil);
	WriteStreamClientCallBack((__bridge CFWriteStreamRef)dataDict[@"write"],
							  kCFStreamEventCanAcceptBytes,
							  (__bridge void *)dataDict[@"name"]);
}

void WriteStreamClientCallBack(CFWriteStreamRef stream, CFStreamEventType type, void *clientCallBackInfo)
{
	NSString *name = (__bridge NSString*)clientCallBackInfo;
	NSMutableDictionary *config = [TCPServer findConfigWithName:name];
	if (! config) {
		NSLogToFile(@"Warn: cant find config for server name:%@", name);
		return;
	}
	@synchronized(config){
		__block NSMutableDictionary *clientConfig = nil;
		[(NSMutableArray *)config[@"clients"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			NSMutableDictionary *elemConfig = obj;
			NSInputStream *outputStream = elemConfig[@"write"];
			if ([outputStream isEqual:(__bridge NSOutputStream *)stream]) {
				clientConfig = elemConfig;
				*stop = YES;
			}
		}];
		
		if (! clientConfig) {
			//NSLogToFile(@"Warn: cant find client config for server name:%@", name);
			return;
		}
		if ([clientConfig[@"invalid"] isEqualToNumber:@YES]) {
			return;
		}

		if (type == kCFStreamEventErrorOccurred) {
			NSLog(@"err occur for name: %@ and config:%@, rm", name, clientConfig);
			[[TCPServer sharedInstance] closeConnectionWithClientConfig:clientConfig];
			[config[@"clients"] removeObject:clientConfig];
			return;
		}else if (type == kCFStreamEventCanAcceptBytes) {
			//NSLog(@"tips: can send..");
			//先检查是否真的可以发送， 因为会手动构造这条消息
			if (! CFWriteStreamCanAcceptBytes((__bridge CFWriteStreamRef)clientConfig[@"write"])) {//手动发送
				return ;
			}
			
			
			NSMutableData *sendBuff = clientConfig[@"sendBuff"];
			NSUInteger sendIndex = [clientConfig[@"sendIndex"] unsignedIntegerValue];
			NSUInteger endIndex = [clientConfig[@"endIndex"] unsignedIntegerValue];
			
			
			if (sendIndex == endIndex) {
				//clientConfig[@"CanAcceptBytes"] = @YES;
			}else{
				NSOutputStream *outputStream = clientConfig[@"write"];
				
				NSUInteger toSendCount = 0;
				const UInt8 *sendStartIndex = sendBuff.bytes + sendIndex;
				//clientConfig[@"CanAcceptBytes"] = @NO;
				if (endIndex > sendIndex) {
					toSendCount = endIndex - sendIndex;
				}else {
					toSendCount = SEND_BUFF_SIZE - sendIndex;
				}
				CFIndex writeLength = CFWriteStreamWrite((__bridge CFWriteStreamRef)outputStream, sendStartIndex, toSendCount);
				if (writeLength == -1) {
					[[TCPServer sharedInstance] closeConnectionWithClientConfig:clientConfig];
					[config[@"clients"] removeObject:clientConfig];
				}else{
					sendIndex += writeLength;
					if (sendIndex >= SEND_BUFF_SIZE) {
						sendIndex = 0;
					}
					clientConfig[@"sendIndex"] = [NSNumber numberWithUnsignedInteger:sendIndex];
				}
			}
		}else{
			NSLog(@"Unknown type recv:%d", (int)type);
		}
	}
}

- (BOOL)writeNSString:(NSString *)stringValue withName:(NSString *)name
{
	return [self writeData:[stringValue dataUsingEncoding:NSUTF8StringEncoding] withName:name];
}
- (BOOL)writeData:(NSData *)data withName:(NSString *)name
{
	return [self addData:data toServerName:name];
}
@end




