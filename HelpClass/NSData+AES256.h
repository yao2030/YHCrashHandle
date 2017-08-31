//
//  NSData+AES256.h
//  MOA
//
//  Created by neo on 14-8-26.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (AES256)

- (NSData *)AES128EncryptWithDataKey:(NSData *)key;

- (NSData *)AES256EncryptWithKey:(NSString *)key;
- (NSData *)AES256EncryptWithKey:(NSString *)key withOptions:(uint32_t)options;

- (NSData *)AES256DecryptWithKey:(NSString *)key;
@end
