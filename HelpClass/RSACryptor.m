//
//  RSACryptor.m
//  MOA
//
//  Created by chentong on 16-02-17.
//  Copyright (c) 2016年 chentong. All rights reserved.
//

#import "RSACryptor.h"

@implementation RSACryptor

- (instancetype)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

+(instancetype)shareInstance
{
    static RSACryptor *cryptor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cryptor = [[RSACryptor alloc] init];
    });
    return cryptor;
}

-(void)setPrivateKeyWithPath:(NSString *)path
{
    FILE *privateKeyFile;
    const char *privateKeyFileName = [path cStringUsingEncoding:NSASCIIStringEncoding];
    privateKeyFile = fopen(privateKeyFileName,"rb");
    if (NULL != privateKeyFile)
    {
        BIO *bpubkey = NULL;
        bpubkey = BIO_new(BIO_s_file());
        BIO_read_filename(bpubkey, privateKeyFileName);
        
        _rsaPrivate = PEM_read_bio_RSAPrivateKey(bpubkey, NULL, NULL, NULL);
        assert(_rsaPrivate != NULL);
        BIO_free_all(bpubkey);
    }
}

-(void)setPulicKeyWithPath:(NSString *)path
{
    FILE *publicKeyFile;
    const char *publicKeyFileName = [path cStringUsingEncoding:NSASCIIStringEncoding];
    publicKeyFile = fopen(publicKeyFileName,"rb");
    if (NULL != publicKeyFile)
    {
        BIO *bpubkey = NULL;
        bpubkey = BIO_new(BIO_s_file());
        BIO_read_filename(bpubkey, publicKeyFileName);
        
        _rsaPublic = PEM_read_bio_RSA_PUBKEY(bpubkey, NULL, NULL, NULL);
        assert(_rsaPublic != NULL);
        BIO_free_all(bpubkey);
    }
}

- (NSData *)encryptWithPublicKeyUsingPadding:(RSA_PADDING_TYPE)padding plainData:(NSData *)plainData
{
    NSAssert(_rsaPublic != NULL, @"You should import public key first");
    
    if ([plainData length] && _rsaPublic != NULL)
    {
        int len = (int)[plainData length];
        unsigned char *plainBuffer = (unsigned char *)[plainData bytes];
        
        //result len
        int clen = RSA_size(_rsaPublic);
        unsigned char *cipherBuffer = calloc(clen, sizeof(unsigned char));
        
        RSA_public_encrypt(len,plainBuffer,cipherBuffer, _rsaPublic,  padding);
        
        NSData *cipherData = [[NSData alloc] initWithBytes:cipherBuffer length:clen];
        
        free(cipherBuffer);
        
        return cipherData;
    }
    
    return nil;
}

- (NSData *)encryptWithPrivateKeyUsingPadding:(RSA_PADDING_TYPE)padding plainData:(NSData *)plainData
{
    NSAssert(_rsaPrivate != NULL, @"You should import private key first");
    
    if ([plainData length] && _rsaPrivate != NULL)
    {
        int len = (int)[plainData length];
        unsigned char *plainBuffer = (unsigned char *)[plainData bytes];
        
        //result len
        int clen = RSA_size(_rsaPrivate);
        unsigned char *cipherBuffer = calloc(clen, sizeof(unsigned char));
        
        RSA_private_encrypt(len,plainBuffer,cipherBuffer, _rsaPrivate,  padding);
        
        NSData *cipherData = [[NSData alloc] initWithBytes:cipherBuffer length:clen];
        
        free(cipherBuffer);
        
        return cipherData;
    }
    
    return nil;
}

- (NSData *)decryptWithPrivateKeyUsingPadding:(RSA_PADDING_TYPE)padding cipherData:(NSData *)cipherData
{
    NSAssert(_rsaPrivate != NULL, @"You should import private key first");
    
    if ([cipherData length] && _rsaPrivate != NULL)
    {
        int len = (int)[cipherData length];
        unsigned char *cipherBuffer = (unsigned char *)[cipherData bytes];
        
        //result len
        int mlen = RSA_size(_rsaPrivate);
        unsigned char *plainBuffer = calloc(mlen, sizeof(unsigned char));
        
        RSA_private_decrypt(len, cipherBuffer, plainBuffer, _rsaPrivate, padding);
        
        NSData *plainData = [[NSData alloc] initWithBytes:plainBuffer length:strlen((const char *)plainBuffer)];
        
        free(plainBuffer);
        
        return plainData;
    }
    
    return nil;
}

- (NSData *)decryptWithPublicKeyUsingPadding:(RSA_PADDING_TYPE)padding cipherData:(NSData *)cipherData
{
    NSAssert(_rsaPublic != NULL, @"You should import public key first");
    
    if ([cipherData length] && _rsaPublic != NULL)
    {
        int len = (int)[cipherData length];
        unsigned char *cipherBuffer = (unsigned char *)[cipherData bytes];
        
        //result len
        int mlen = RSA_size(_rsaPublic);
        unsigned char *plainBuffer = calloc(mlen, sizeof(unsigned char));
        
        RSA_public_decrypt(len, cipherBuffer, plainBuffer, _rsaPublic, padding);
        
        NSData *plainData = [[NSData alloc] initWithBytes:plainBuffer length:strlen((const char *)plainBuffer)];
        
        free(plainBuffer);
        
        return plainData;
    }
    
    return nil;
}

-(NSString *)decryptStringWithPublicKeyUsingPadding:(RSA_PADDING_TYPE)padding cipherData:(NSData *)cipherData
{
    NSData *data = [self decryptWithPublicKeyUsingPadding:padding cipherData:cipherData];
    NSString *plainText = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    return plainText;
}

@end
