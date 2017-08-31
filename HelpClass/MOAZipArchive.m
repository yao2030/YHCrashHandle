//
//  MOAZipArchive.m
//  MOA
//
//  Created by neo on 14-10-15.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import "MOAZipArchive.h"
#import "NSData+AES256.h"

@implementation MOAZipArchive
+ (NSURL *)zipFilesAtPaths:(NSArray *)paths
{
	return [self zipFilesAtPaths:paths excludeFileNames:nil withPassword:nil];
}
/**
 *	加密 paths 里的文件, 并返回一个临时的压缩文件结果路径
 *
 *	@param paths        被压缩的文件表, 支持文件和目录
 *	@param excludeNames 目录下, 不被包含的文件名 (只要子路径里含有 指定的名字就跳过 -- 包括目录名和全文件名)
 *	@param password     加密密码
 *
 *	@return 结果路径(临时路径, 重启后会被删除)
 */
+ (NSURL *)zipFilesAtPaths:(NSArray *)paths excludeFileNames:(NSArray *)excludeNames withPassword:(NSString *)password
{
	if (paths.count == 0) {
		return nil;
	}
	NSURL *tmpUrl = [EntrysOperateHelper getURLForTmpFileUse:nil isDir:NO];
	BOOL success = [self createZipFileAtPath:tmpUrl.path withFilesAtPaths:paths andExcludeFileNames:excludeNames password:password];
	if (! success) {
		return nil;
	}
	return tmpUrl;
}
+ (NSData *)zipData:(NSData *)data withFileName:(NSString *)fileName
{
	return [self zipData:data withPassword:nil withFileName:fileName];
}
+ (NSData *)zipData:(NSData *)data withPassword:(NSString *)password withFileName:(NSString *)fileName
{
	if (fileName.length == 0) {
		fileName = nil;
	}
	NSURL *tmpUrl = [EntrysOperateHelper getURLForTmpFileUse:fileName isDir:!(fileName == nil)];
	if (fileName) {
		tmpUrl = [tmpUrl URLByAppendingPathComponent:fileName];
	}
	BOOL saveSuccess = [data writeToURL:tmpUrl atomically:YES];
	if (! saveSuccess) {
		NSLogToFile(@"Error: save to file failed");
		return nil;
	}
	NSURL *zipUrl = [EntrysOperateHelper getURLForTmpFileUse:nil isDir:NO];
	BOOL success = [self createZipFileAtPath:zipUrl.path withFilesAtPaths:@[tmpUrl.path] andExcludeFileNames:nil password:password];
	if (! success) {
		return nil;
	}
	NSData *resultData = [NSData dataWithContentsOfFile:zipUrl.path];
	return resultData;
}
@end
