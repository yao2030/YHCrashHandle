//
//  NSData+AES256.m
//  MOA
//
//  Created by neo on 14-8-26.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import "NSData+AES256.h"
#import <CommonCrypto/CommonCryptor.h>

@implementation NSData (AES256)
- (NSData *)AES128EncryptWithDataKey:(NSData *)key
{
    char keyPtr[kCCKeySizeAES128 + 1]; // room for terminator (unused)
    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
    [key getBytes:keyPtr length:key.length];
    
    //	char ivPtr[kCCKeySizeAES128 + 1]; // room for terminator (unused)
    //    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
    //	[key getBytes:ivPtr length:key.length];
    
    NSUInteger dataLength = [self length];
    
    size_t bufferSize           = dataLength + kCCBlockSizeAES128;
    void* buffer                = malloc(bufferSize);
    
    size_t numBytesEncrypted    = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES, 0,
                                          keyPtr, kCCKeySizeAES128,
                                          NULL /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesEncrypted);
    
    if (cryptStatus == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    
    free(buffer);
    return nil;
}
//- (NSData *)AES256EncryptWithDataKey:(NSData *)key
//{
//	char keyPtr[kCCKeySizeAES256 + 1]; // room for terminator (unused)
//    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
//	[key getBytes:keyPtr length:key.length];
//    
//	
//    NSUInteger dataLength = [self length];
//	
//    size_t bufferSize           = dataLength + kCCBlockSizeAES128;
//    void* buffer                = malloc(bufferSize);
//	
//    size_t numBytesEncrypted    = 0;
//    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
//                                          keyPtr, kCCKeySizeAES256,
//                                          NULL /* initialization vector (optional) */,
//                                          [self bytes], dataLength, /* input */
//                                          buffer, bufferSize, /* output */
//                                          &numBytesEncrypted);
//	
//    if (cryptStatus == kCCSuccess) {
//        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
//    }
//	
//    free(buffer);
//    return nil;
//}
//
//- (NSData *)AES256DecryptWithDataKey:(NSData *)key
//{
//    char keyPtr[kCCKeySizeAES256 + 1]; // room for terminator (unused)
//    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
//	[key getBytes:keyPtr length:key.length];
//	
//    NSUInteger dataLength = [self length];
//	
//    size_t bufferSize           = dataLength + kCCBlockSizeAES128;
//    void* buffer                = malloc(bufferSize);
//	
//    size_t numBytesDecrypted    = 0;
//    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
//                                          keyPtr, kCCKeySizeAES256,
//                                          NULL /* initialization vector (optional) */,
//                                          [self bytes], dataLength, /* input */
//                                          buffer, bufferSize, /* output */
//                                          &numBytesDecrypted);
//	
//    if (cryptStatus == kCCSuccess) {
//        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
//    }
//	
//    free(buffer); //free the buffer;
//    return nil;
//}
- (NSData *)AES256EncryptWithKey:(NSString *)key
{
	return [self AES256EncryptWithKey:key withOptions:kCCOptionPKCS7Padding];
}
- (NSData *)AES256EncryptWithKey:(NSString *)key withOptions:(uint32_t)options
{
	// 'key' should be 32 bytes for AES256, will be null-padded otherwise
	char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
	bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
	
	// fetch key data
	[key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
	
	NSUInteger dataLength = [self length];
	
	//See the doc: For block ciphers, the output size will always be less than or
	//equal to the input size plus the size of one block.
	//That's why we need to add the size of one block here
	size_t bufferSize = dataLength + kCCBlockSizeAES128;
	void *buffer = malloc(bufferSize);
	
	size_t numBytesEncrypted = 0;
	CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, options,
										  keyPtr, kCCKeySizeAES256,
										  NULL /* initialization vector (optional) */,
										  [self bytes], dataLength, /* input */
										  buffer, bufferSize, /* output */
										  &numBytesEncrypted);
	if (cryptStatus == kCCSuccess) {
		//the returned NSData takes ownership of the buffer and will free it on deallocation
		return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
	}
	
	free(buffer); //free the buffer;
	return nil;
}
- (NSData *)AES256DecryptWithKey:(NSString *)key
{
	return [self AES256DecryptWithKey:key withOptions:kCCOptionPKCS7Padding];
}
- (NSData *)AES256DecryptWithKey:(NSString *)key withOptions:(CCOptions)options
{
	// 'key' should be 32 bytes for AES256, will be null-padded otherwise
	char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
	bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
	
	// fetch key data
	[key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
	
	NSUInteger dataLength = [self length];
	
	//See the doc: For block ciphers, the output size will always be less than or
	//equal to the input size plus the size of one block.
	//That's why we need to add the size of one block here
	size_t bufferSize = dataLength + kCCBlockSizeAES128;
	void *buffer = malloc(bufferSize);
	
	size_t numBytesDecrypted = 0;
	CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
										  keyPtr, kCCKeySizeAES256,
										  NULL /* initialization vector (optional) */,
										  [self bytes], dataLength, /* input */
										  buffer, bufferSize, /* output */
										  &numBytesDecrypted);
	
	if (cryptStatus == kCCSuccess) {
		//the returned NSData takes ownership of the buffer and will free it on deallocation
		return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
	}
	
	free(buffer); //free the buffer;
	return nil;
}
@end
