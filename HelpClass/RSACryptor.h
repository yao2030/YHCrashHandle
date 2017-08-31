//
//  RSACryptor.h
//  MOA
//
//  Created by chentong on 16-02-17.
//  Copyright (c) 2016年 chentong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <openssl/rsa.h>
#import <openssl/pem.h>

/**
 @abstract  padding type
 */
typedef NS_ENUM(NSInteger, RSA_PADDING_TYPE) {
    
    RSA_PADDING_TYPE_NONE       = RSA_NO_PADDING,
    RSA_PADDING_TYPE_PKCS1      = RSA_PKCS1_PADDING,
    RSA_PADDING_TYPE_SSLV23     = RSA_SSLV23_PADDING
};

@interface RSACryptor : NSObject
{
    RSA *_rsaPublic;
    RSA *_rsaPrivate;
    
    @public
    RSA *_rsa;
}

+(instancetype) shareInstance;

-(void) setPulicKeyWithPath:(NSString *)path;
-(void) setPrivateKeyWithPath:(NSString *)path;

/**
 @abstract  encrypt text using RSA public key
 @param     padding type add the plain text
 @return    encrypted data
 */
- (NSData *)encryptWithPublicKeyUsingPadding:(RSA_PADDING_TYPE)padding
                                   plainData:(NSData *)plainData;

/**
 @abstract  encrypt text using RSA private key
 @param     padding type add the plain text
 @return    encrypted data
 */
- (NSData *)encryptWithPrivateKeyUsingPadding:(RSA_PADDING_TYPE)padding
                                    plainData:(NSData *)plainData;

/**
 @abstract  decrypt text using RSA private key
 @param     padding type add the plain text
 @return    encrypted data
 */
- (NSData *)decryptWithPrivateKeyUsingPadding:(RSA_PADDING_TYPE)padding
                                   cipherData:(NSData *)cipherData;

/**
 @abstract  decrypt text using RSA public key
 @param     padding type add the plain text
 @return    encrypted data
 */
- (NSData *)decryptWithPublicKeyUsingPadding:(RSA_PADDING_TYPE)padding
                                  cipherData:(NSData *)cipherData;
- (NSString *)decryptStringWithPublicKeyUsingPadding:(RSA_PADDING_TYPE)padding
                                  cipherData:(NSData *)cipherData;
@end
