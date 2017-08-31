//
//  TCPServer.h
//  MOA
//
//  Created by neo on 14-1-16.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface TCPServer : NSObject
+ (TCPServer *)sharedInstance;
+ (NSMutableDictionary *)globleConfig;
- (BOOL)startServerOnPort:(UInt16)port withName:(NSString *)name andRecvCallback:(CallbackWithFlag)callback;
- (void)stopServerWithName:(NSString *)name;

- (void)closeConnectionWithInputStream:(NSInputStream *)nsinputStream orOutStream:(NSOutputStream *)nsoutputStream;

- (BOOL)findName:(NSString **)outName
	   andConfig:(NSMutableDictionary **)outClientConfig
 withInputStream:(NSInputStream *)inputStream orOutStream:(NSOutputStream *)outputStream;

- (BOOL)writeNSString:(NSString *)stringValue withName:(NSString *)name;
- (BOOL)writeData:(NSData *)data withName:(NSString *)name;
@end
