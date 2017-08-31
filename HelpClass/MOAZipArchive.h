//
//  MOAZipArchive.h
//  MOA
//
//  Created by neo on 14-10-15.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import "SSZipArchive.h"

@interface MOAZipArchive : MOASSZipArchive
+ (NSURL *)zipFilesAtPaths:(NSArray *)paths;
+ (NSURL *)zipFilesAtPaths:(NSArray *)paths excludeFileNames:(NSArray *)excludeNames withPassword:(NSString *)password;

+ (NSData *)zipData:(NSData *)data withFileName:(NSString *)fileName;
+ (NSData *)zipData:(NSData *)data withPassword:(NSString *)password withFileName:(NSString *)fileName;
@end
