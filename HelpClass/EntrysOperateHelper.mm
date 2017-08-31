//
//  EntrysOperateHelper.m
//  MOA
//
//  Created by neo on 13-8-17.
//  Copyright (c) 2013年 moa. All rights reserved.
//

#import "EntrysOperateHelper.h"
#import "BaseOperateForCoredata.h"
//#import "CoredataManager.h"
#import "MOAModelManager+Translate.h"//mark1
#include <ifaddrs.h>
#include <arpa/inet.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CommonCrypto/CommonDigest.h>//md5
#import "MOAZipArchive.h"
#import "MOAGroup+Operate.h"
#import "MOAPerson+Operate.h"
#import "MOAMessage+Operate.h"
#include <mach-o/loader.h>
#import "NSDateFormatter+TimeZone.h"
#import <sys/utsname.h>
#import <sys/mount.h>
#import <AdSupport/ASIdentifierManager.h>
//#import "CoredataManager+FileUpAndDown.h"

#include "auth.pb.h"
#include "push.pb.h"
#include <string>

using namespace std;
using namespace com::sangfor::moa::protobuf;

@implementation EntrysOperateHelper

+ (id)getObjFromExtendSet:(NSSet *)set
	  withUniqueNameValue:(NSString *)nameValue
{
	return [EntrysOperateHelper getObjFromExtendSet:set withUniqueKey:@"name" andKeyValue:nameValue];
}
+ (NSArray *)getObjsFromExtendSet:(NSSet *)set
	  withUniqueNameValue:(NSString *)nameValue
{
	return [EntrysOperateHelper getObjsFromExtendSet:set withUniqueKey:@"name" andKeyValue:nameValue];
}
+ (NSArray *)getObjsFromExtendSet:(NSSet *)set
			withUniqueKey:(NSString *)key
			  andKeyValue:(NSString *)keyValue
{
    NSMutableSet *result = [[NSMutableSet alloc] init];
	for (id elem in set) {
		id value = [EntrysOperateHelper getValueForKey:key atObj:elem];
		if (value == nil) {
			NSLogToFile(@"Bug: the elem(%@:%@) has no valid value for key(%@) ", [elem class], elem, key);
		}
		if ([value isEqualToString:keyValue]) {
			[result addObject:elem];
		}
	}
	if ([result count] == 0) {
		return nil;
	}
	NSArray *soryArray = [NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES]];
	NSArray *sortResult = [result sortedArrayUsingDescriptors:soryArray];
    return sortResult;
}

+ (id)getObjFromExtendSet:(NSSet *)set
			withUniqueKey:(NSString *)key
			  andKeyValue:(NSString *)keyValue
{
    NSArray *result = [EntrysOperateHelper getObjsFromExtendSet:set
                                            withUniqueKey:key
                                              andKeyValue:keyValue];
	if ([result count] >= 1) {
        return result[0];
    }
	return result;
}


+ (BOOL)setValue:(id)value forKey:(NSString *)key atObj:(id)obj
{
	if (! [key isKindOfClass:[NSString class]]) {
		NSLogToFile(@"Bug: invalid arg for set value for key(%@) of obj(%@).", key, obj);
		return NO;
	}
	if (obj == nil) {
		return YES;
	}
	NSSet *setToSetLabel = nil;
	if ([obj isKindOfClass:[NSManagedObject class]] || [obj isKindOfClass:[MOAManagedObjectNoCache class]]) {
		setToSetLabel = [NSSet setWithObject:obj];
	}else{
		setToSetLabel = obj;
	}
	if ((! [setToSetLabel isKindOfClass:[NSSet class]])
		&& (! [setToSetLabel isKindOfClass:[NSArray class]])) {
		NSLogToFile(@"Bug: obj(%@) should be NSSet/NSArray or NSManagedObject.", setToSetLabel);
		logAbort(@"Bug: obj(%@) should be NSSet/NSArray or NSManagedObject.", setToSetLabel);
		return NO;
	}
	for (NSManagedObject *objToSetLabel in setToSetLabel) {
		if (![objToSetLabel isKindOfClass:[NSManagedObject class]] && ![objToSetLabel isKindOfClass:[MOAManagedObjectNoCache class]]) {
			NSLogToFile(@"Bug: objToSetLabel(%@) should be NSManagedObject.", objToSetLabel);
			logAbort(@"Bug: objToSetLabel(%@) should be NSManagedObject.", objToSetLabel);
			return NO;
		}
		
		@try{
			if (value == [NSNull null]) {
				id orgValue = [objToSetLabel valueForKey:key];
				if ([orgValue isKindOfClass:[NSMutableSet class]]) {
					[orgValue removeAllObjects];
					value = orgValue;
				}else{
					value = nil;
				}
			}
			[objToSetLabel setValue:value forKey:key];
		}@catch (NSException *exception) {
			NSLogToFile(@"Bug: invalid arg for set value(%@) for key(%@) of obj(%@): %@.", value, key, obj, exception);
			logMsg(@"Bug: invalid arg for set value(%@) for key(%@) of obj(%@): %@.", value, key, obj, exception);
			return NO;
		}

	}

	return YES;
}

/**
 *  根据key获取value  不产生日志
 *
 *  @param key key description
 *  @param obj obj description
 *
 *  @return return value description
 */
+ (id)tryToGetValueForKey:(NSString *)key atObj:(id)obj
{
	return [EntrysOperateHelper getValueForKey:key atObj:obj error:nil];
}
+ (id)getValueForKey:(NSString *)key atObj:(id)obj
{
	NSError *error = nil;
	id value = [EntrysOperateHelper getValueForKey:key atObj:obj error:&error];
	if (error != nil) {
		NSLogToFile(@"Bug: invalid arg for get value for key(%@) of obj(%@)", key, obj);
	}
	return value;
}

+ (id)getValueForKey:(NSString *)key atObj:(id)obj error:(NSError **)error;
{
	id resultValue = nil;
	if ((obj == nil) || (! [key isKindOfClass:[NSString class]])) {
		if (error != nil) {
			NSLogToFile(@"Bug: invalid arg for get value for key(%@) of obj(%@).", key, obj);
			*error = [NSError errorWithDomain:@"invalid arg" code:0 userInfo:nil];
		}
		return nil;
	}
	@try{
		resultValue = [obj valueForKey:key];
	}@catch (NSException *exception) {
		if (error != nil) {
			*error = [NSError errorWithDomain:@"invalid arg" code:0 userInfo:nil];
			logMsg(@"Bug: invalid arg for get value for key(%@) of obj(%@): %@.", key, obj, exception);
		}
		return nil;
	}
	return resultValue;
}

+ (id)valueForKey:(NSString *)key expectClass:(Class)cls convertToJson:(BOOL)convert fromDict:(NSDictionary *)dict
{
    NSAssert([key isKindOfClass:[NSString class]], nil);
    if([key isKindOfClass:[NSString class]] == NO
       || ([dict isKindOfClass:[NSDictionary class]] == NO && dict)) {
        NSAssert(0, nil);
        return nil;
    }
    
    id value = dict[key];
    if(value == nil || [value isKindOfClass:[NSNull class]]) {
        return nil;
    }
    
    if(convert) {
        if([value isKindOfClass:[NSString class]] == NO) {
            if([value isKindOfClass:cls]) {
                return value;
            }
            NSLogToFile(@"Warn: value for %@ no match class\n%@", key, dict);
            NSAssert(0, nil);
            return nil;
        }
        value = [value json];
        
        if([value isKindOfClass:[NSDictionary class]]) {
            value = [EntrysOperateHelper removeNullKeys:value];
        }
    }
    
    if([cls isSubclassOfClass:[NSDate class]] && [value isKindOfClass:[NSNumber class]]) {
        value = [EntrysOperateHelper dateGMTFromServerTime:[value longLongValue]];
    }
    
    if([value isKindOfClass:cls] == NO) {
        NSLogToFile(@"Warn: value for %@ no match class\n%@", key, dict);
        NSAssert(0, nil);
        return nil;
    }
    
    return value;
}

+ (NSDictionary *)compareAndReturnItemsToDelWithNewMembers:(id)newMember
												withOldSet:(NSSet *)oldSet
											   inUniqueKey:(NSString *)uniqueKey
{
	NSMutableSet *setToBeDel = [[NSMutableSet alloc] init];
	NSSet *setToBeAdd = nil;
	//1. 参数检查
	if (kFlagDebug) {
		if ((newMember == nil)
			|| (oldSet == nil)
			|| (! [oldSet isKindOfClass:[NSSet class]])
			|| (uniqueKey == nil)
			|| (! [uniqueKey isKindOfClass:[NSString class]])) {
			NSLogToFile(@"Bug: Cant insert new member with invalid key.(oldset%@:%@)", [oldSet class], oldSet);
			return nil;
		}
	}
	//2. 解析
	if ([newMember isKindOfClass:[NSSet class]]) {
		//2.1 读取新的key集合
		NSMutableSet *newKeysSet = [[NSMutableSet alloc] init];
		for (id elem in newMember) {
//			id value = [NSString stringWithFormat:@""];
//			if (! [elem validateValue:&value forKey:uniqueKey error:nil]) {
//				NSLogToFile(@"Bug: the elem(%@:%@) has no valid value for key(%@) ", [elem class], elem, uniqueKey);
//				if (kFlagDebug) {
//					logAbort(@"");
//				}
//				return nil;
//			}
//			value = [elem valueForKey:uniqueKey];
			id value = [EntrysOperateHelper getValueForKey:uniqueKey atObj:elem];
			if (value == nil) {
				NSLogToFile(@"Bug: the elem(%@:%@) has no valid value for key(%@) ", [elem class], elem, uniqueKey);
				return nil;
			}
			[newKeysSet addObject:value];
		}
		//2.2 对比, 查看旧的key是否在新的集合中
		for (id elem in oldSet) {
//			id value = [NSString stringWithFormat:@""];
//			if (! [elem validateValue:&value forKey:uniqueKey error:nil]) {
//				NSLogToFile(@"Bug: the elem(%@:%@) has no valid value for key(%@) ", [elem class], elem, uniqueKey);
//				if (kFlagDebug) {
//					logAbort(@"");
//				}
//				return nil;
//			}
			id value = [EntrysOperateHelper getValueForKey:uniqueKey atObj:elem];
			if (value == nil) {
				NSLogToFile(@"Bug: the elem(%@:%@) has no valid value for key(%@) ", [elem class], elem, uniqueKey);
				return nil;
			}
			//value = [elem valueForKey:uniqueKey];
			if ([newKeysSet containsObject:value]) {
				[setToBeDel addObject:elem];
			}
		}
		setToBeAdd = newMember;
	} else {
		//读取出新的name值
//		id newNameValue = [NSString stringWithFormat:@""];
//		if ((! [newMember validateValue:&newNameValue forKey:uniqueKey error:nil])
//			|| (! [newNameValue isKindOfClass:[NSString class]])){
//			NSLogToFile(@"Bug: the newMember(%@:%@) has no valid value for key(%@) or value isnt NSString(%@)",
//				  [newMember class], newMember, uniqueKey, [newNameValue class]);
//			if (kFlagDebug) {
//				logAbort(@"");
//			}
//			return nil;
//		}
		id newNameValue = [EntrysOperateHelper getValueForKey:uniqueKey atObj:newMember];
		if (newNameValue == nil) {
			NSLogToFile(@"Bug: the elem(%@:%@) has no valid value for key(%@) ", [newNameValue class], newNameValue, uniqueKey);
			return nil;
		}

		newNameValue = [newMember valueForKey:uniqueKey];
		
		for (id elem in oldSet) {
//			id value = [NSString stringWithFormat:@""];
//			if (! [elem validateValue:&value forKey:uniqueKey error:nil]) {
//				NSLogToFile(@"Bug: the elem(%@:%@) has no valid value for key(%@) ", [elem class], elem, uniqueKey);
//				if (kFlagDebug) {
//					logAbort(@"");
//				}
//				return nil;
//			}
//			value = [elem valueForKey:uniqueKey];
			id value = [EntrysOperateHelper getValueForKey:uniqueKey atObj:elem];
			if (value == nil) {
				NSLogToFile(@"Bug: the elem(%@:%@) has no valid value for key(%@) ", [elem class], elem, uniqueKey);
				return nil;
			}
			
			if ([value isEqualToString:newNameValue]) {
				[setToBeDel addObject:elem];
			}
		}
		setToBeAdd = [NSSet setWithObject:newMember];
	}
	return @{@"del":setToBeDel, @"add":setToBeAdd};
}
+ (BOOL)deleteFileWithAbsolutePath:(NSString *)path
{
	if (! [path isKindOfClass:[NSString class]]) {
		return NO;
	}
	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
		NSError *error = nil;
		BOOL result = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
		if (result == NO) {
			NSLog(@"Failed to remove file<%@>:%@", path, error);
		}else{
			NSLog(@"delete file <%@> success", path);
		}
		return YES;
	}
	return NO;
}

//删除用户文件夹下的
+ (BOOL)deleteFileWithUserPath:(NSString *)path
{
	return [CoredataManager deleteUserDocumentFile:path];
}
///**
// *  Description
// *
// *  @param data data description
// *  @param path path description
// *
// *  @return return value description
// */
//+ (NSString *)saveNSData:(NSData *)data
//			 intoPath:(NSString *)path
//{
//	return [CoredataManager saveNSData:data intoPath:path];
//}


////指定entryName, 向其内部插入data携带的数据, 插入并返回新插入的对象
//+ (id)insertNewObjIntoEntryName:(NSString *)entryName
//					   withData:(NSDictionary *)data
//		 inManagedObjectContext:(NSManagedObjectContext *)context
//{
//	return [BaseOperateForCoredata insertNewObjIntoEntryName:entryName
//													withData:data
//									  inManagedObjectContext:context];
//}
/**
 *  根据UTF8字符串转换成NSString
 *
 *  @param characters UTF8字符串
 *  @param length     UTF8字符串长度
 *
 *  @return NSString
 */
+ (const char *)UTF8String:(id)obj
{
	if ([obj isKindOfClass:[NSString class]]) {
		return [obj UTF8String];
	}else if (obj == [NSNull null]) {
		return "";
	}else{
		if (kFlagDebug) {
			logAbort(@"Bug: unknown class:(%@) to UTF8String ", [obj class]);
		}
	}
	return "";
}
+ (NSString *)getNSStringWithUTF8String:(const char *)characters
{
	id result = nil;
	@try{
		result = [NSString stringWithUTF8String:characters];
	}@catch (NSException *exception) {
		NSLogToFile(@"Error: invalid UTF-8 data:%s, %@", characters, exception);
		result = @"(undefine)";
	}
	if (result == nil) {
		result = @"(undefine)";
	}
	if ([result length] == 0)  {//空串设置成 [NSNull null]
		result = [NSNull null];
	}
	return result;
}
+ (NSString *)getNSStringAllowEmptyWithUTF8String:(const char *)characters
{
    id result = nil;
    @try{
        result = [NSString stringWithUTF8String:characters];
    }@catch (NSException *exception) {
        NSLogToFile(@"Error: invalid UTF-8 data:%s, %@", characters, exception);
        result = @"(undefine)";
    }
    if (result == nil) {
        result = @"(undefine)";
    }
    return result;
}
/**
 *  根据 orgDict[key]下的数据  (字典就替换/删除key, 数组就删除dict下的值, 其他就替换)
 *  此函数主要用于修改dict第二级数据
 *
 *  @param orgDict 原dict
 *  @param key     NSDictionary 或 其他对象
 *  @param value   原dict下的key
 *
 *  @return 新产生的NSDictionary
 */
+ (NSMutableDictionary *)fixedDict:(NSDictionary *)orgDict
					  ofKey:(id)key
				  withValue:(id)value
{
	if (value == nil) {
		NSLogToFile(@"Bug: new value should not be nil");
		logAbort(@"Bug: new value should not be nil");
	}
	BOOL isMutableable = NO;
	if ([orgDict isKindOfClass:[NSMutableDictionary class]]) {
		isMutableable = YES;
	}
	NSMutableDictionary *resultDict = [NSMutableDictionary dictionaryWithDictionary:orgDict];
	if ([value isKindOfClass:[NSDictionary class]]) {
		if ([orgDict[key] isKindOfClass:[NSDictionary class]]) {//两者均为字典, 则合并数据
			NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:orgDict[key]];
			[newDict addEntriesFromDictionary:value];
			resultDict[key] = newDict;
			
		}else {//其他类型的原值, 则直接替换成 value字典
			resultDict[key] = value;
		}
	}else if ([value isKindOfClass:[NSArray class]]) {//value若为数组, 则其一定为orgDict[key] 字典下的将要被remove的keys
		if (! [orgDict[key] isKindOfClass:[NSDictionary class]]) {
			NSLogToFile(@"Bug: This case, orgDict[key] should be dict:%@", orgDict[key]);
			logAbort(@"Bug: This case, orgDict[key] should be dict:%@", orgDict[key]);
		}
		NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:orgDict[key]];
		for (id key in value) {
			[newDict removeObjectForKey:key];
		}
		resultDict[key] = newDict;
	}else{
		resultDict[key] = value;
	}
	if (isMutableable) {
		return resultDict;
	}
	return resultDict;
}

/**
 *  在oldString上添加新的updataFlag值newString
 *
 *  @param newString
 *  @param oldString
 *
 *  @return 添加结果
 */
+ (NSString *)addUpdataFlagString:(NSString *)newString toOldString:(NSString *)oldString
{
	if(newString == nil) {
		logAbort(@"newString = nil");//正常情况这里不应该为空
		return oldString;
	}
    if(oldString == nil) {
        NSLog(@"Entryhelp update: %@ ==(+%@)==> %@", oldString, newString, newString);
		return newString;
	}
    
	NSArray *oldFlagList = [oldString componentsSeparatedByString:kUpdateSeparator];
	NSArray *newFlagList = [newString componentsSeparatedByString:kUpdateSeparator];
	NSMutableSet *unicodeList = [NSMutableSet setWithArray:oldFlagList];
	[unicodeList addObjectsFromArray:newFlagList];
    [unicodeList removeObject:@""];
    
    NSString *result = [unicodeList.allObjects componentsJoinedByString:kUpdateSeparator];
    NSLog(@"Entryhelp update: %@ ==(+%@)==> %@", oldString, newString, result);
	return result;
}

+ (NSString *)delUpdataFlagString:(NSString *)newString toOldString:(NSString *)oldString
{
    NSArray *oldFlagList = [oldString componentsSeparatedByString:kUpdateSeparator];
    NSArray *newFlagList = [newString componentsSeparatedByString:kUpdateSeparator];
    
    NSMutableSet *list = [NSMutableSet setWithArray:oldFlagList];
    [list minusSet:[NSSet setWithArray:newFlagList]];
    [list removeObject:@""];
    
    NSString *result = [list.allObjects componentsJoinedByString:kUpdateSeparator];
    NSLog(@"Entryhelp update: %@ ==(-%@)==> %@", oldString, newString, result);
    return result.length? result: nil;
}

/**
 *  服务器格式 ZHONG JING|YING WEI
 *
 *  @param newPinyin <#newPinyin description#>
 *
 *  @return <#return value description#>
 */
+ (NSDictionary *)convertNetPinyin:(NSString *)aPinyin
{
	if (aPinyin == nil) {
		return @{};
	}
	NSString *newPinyin = [aPinyin uppercaseString];
    NSMutableArray *FullPin = [[NSMutableArray alloc] initWithCapacity:0];
    NSMutableArray *simPin = [[NSMutableArray alloc] initWithCapacity:0];
    NSMutableArray *singlePins = [NSMutableArray arrayWithArray:[newPinyin componentsSeparatedByString:@" "]];
    for (; ; ) {
        if ([singlePins containsObject:@""]) {
            [singlePins removeObject:@""];
        }else{
            break;
        }
    }
    NSMutableArray *resolvePins = [[NSMutableArray alloc] initWithCapacity:0];
    for (int i = 0; i < singlePins.count; i++) {
        NSArray *array = [[singlePins objectAtIndex:i] componentsSeparatedByString:@"|"];
        [resolvePins addObject:array];
    }
    [FullPin addObject:@""];
    [simPin addObject:@""];
    for (int i = 0; i < resolvePins.count; i++) {
        NSMutableArray *fullArray = [NSMutableArray arrayWithCapacity:0];
        NSMutableArray *simArray = [NSMutableArray arrayWithCapacity:0];
        for (int j = 0 ; j < [[resolvePins objectAtIndex:i] count]; j++) {
            for (int k = 0; k < FullPin.count; k++) {
                [fullArray addObject:[[FullPin objectAtIndex:k] stringByAppendingString:[[resolvePins objectAtIndex:i] objectAtIndex:j]]];
            }
            for (int k = 0; k < simPin.count; k++) {
                [simArray addObject:[[simPin objectAtIndex:k] stringByAppendingString:[[[resolvePins objectAtIndex:i] objectAtIndex:j] substringToIndex:1]]];
            }
        }
        [FullPin removeAllObjects];
        [FullPin addObjectsFromArray:fullArray];
        [simPin removeAllObjects];
        [simPin addObjectsFromArray:simArray];
    }
    NSString *allFullPin = @"";
    for (NSString *string in FullPin) {
        allFullPin = [[allFullPin stringByAppendingString:string] stringByAppendingString:@" "];
    }
    NSString *allSimPin = @"";
    for (NSString *string in simPin) {
        allSimPin = [[allSimPin stringByAppendingString:string] stringByAppendingString:@" "];
    }
	NSDictionary *dic = @{
						  @"fullSpell":allFullPin,
						  @"simpleSpell":allSimPin,
						  };
    return dic;
	
	
}

+ (NSDate *)serverDate
{
    NSDate *serverDate = [[NSDate date] dateByAddingTimeInterval:-[CoredataManager timeIntervalFromServerTime]];
    return serverDate;
}

//将服务器时间转化为本地时间
+ (NSDate*)localDateFromServerDate:(NSDate*)date
{
    NSDate *localDate = [date dateByAddingTimeInterval:[CoredataManager timeIntervalFromServerTime]];
    return localDate;
}

+ (NSNumber *)getUserSID
{
	return [CoredataManager getUserSID];
}
+ (NSDate *)localDate:(NSDate *)dateGMT
{
	NSTimeZone *zone = [NSTimeZone systemTimeZone];
	NSInteger interval = [zone secondsFromGMTForDate:dateGMT];
	NSDate *localeDate = [dateGMT dateByAddingTimeInterval:interval];
	return localeDate;
}
//+ (int64_t)getGMT1970sFromlocalDate:(NSDate *)dateLocal
//{
//	NSTimeZone *zone = [NSTimeZone systemTimeZone];
//	return [zone secondsFromGMTForDate:dateLocal];
//}
+ (NSDate *)dateGMTFromServerTime:(int64_t)timemMicoSeconds
{
	return [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)timemMicoSeconds/1000.0f];
}
+ (int64_t)serverTimeFromDateGMT:(NSDate *)GMTDate
{
	return ([GMTDate timeIntervalSince1970]*1000);
	//return [NSDate dateWithTimeIntervalSince1970:timemMicoSeconds/1000];
}
/**
 *  在当前时间上增加0.1毫秒
 *
 *  @param orgDate orgDate description
 *
 *  @return return value description
 */
+ (NSDate *)plusOneMilliSecond:(NSDate *)orgDate
{
	return [orgDate dateByAddingTimeInterval:0.0001];//0.1ms
}

+ (NSString *)descriptionForManagerObject:(NSManagedObject *)obj exceptKeys:(NSArray *)exceptKeys
{
    NSMutableString *content = [NSMutableString string];
    
    unsigned int outCount = 0;
    objc_property_t *properties = class_copyPropertyList([obj class], &outCount);
    for(int i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *key = [[NSString alloc]initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        if([exceptKeys containsObject:key]) {
            continue;
        }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id value = [obj respondsToSelector:NSSelectorFromString(key)]? [obj performSelector:NSSelectorFromString(key)]: nil;
        if([value isKindOfClass:[NSManagedObject class]]) {
            value = [NSString stringWithFormat:@"<relationship to %@: %llx>", [value class], (int64_t)value];
        }else if([value isKindOfClass:[NSSet class]]) {
            value = [NSString stringWithFormat:@"<to many relationship count:%d >", (int)[value count]];
        }
        [content appendFormat:@"\t\t%@ = %@,\n", key, value];
    }
#pragma clang diagnostic pop
    
    NSString *str = [NSString stringWithFormat:@"<%@: 0x%llx> id: %@; data: {\n%@}", [obj class], (int64_t)obj, obj.objectID, content];
    return str;
}

#pragma mark - encode & decode
/**
 *  读取对象的MD5值
 *
 *  @param obj 支持对象: NSString(UTF8转码), UIImage, NSData
 *
 *  @return 32位字符
 */
+ (NSString *)getMD5String:(id)obj
{
	NSData *md5 = [self getMD5:obj];
	
	unsigned char buff[CC_MD5_DIGEST_LENGTH];
	NSAssert(md5.length == CC_MD5_DIGEST_LENGTH, nil);
	
	[md5 getBytes:buff length:CC_MD5_DIGEST_LENGTH];
	
	NSMutableString *hash = [NSMutableString string];
	for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {//每个字符转成2个字符
        [hash appendFormat:@"%02X", buff[i]];
	}
	return [hash uppercaseString];
}
+ (NSData *)getMD5:(id)obj
{
	if (obj == nil) {
		return nil;
	}
	NSData *data = obj;
	if ([obj isKindOfClass:[NSString class]]) {
		NSString *string = obj;
		data = [NSData dataWithBytes:[string UTF8String]
							  length:[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
	}else if ([obj isKindOfClass:[UIImage class]]) {
		data = UIImageJPEGRepresentation(obj, 1.0f);
	}else if ([obj isKindOfClass:[NSData class]]) {
		
	}else{
		logAbort(@"Bug: unsupport class(%@) to get md5", [obj class]);
	}
	unsigned char result[CC_MD5_DIGEST_LENGTH];
	CC_MD5(data.bytes, data.length, result);
	
	NSData *dataMD5 = [NSData dataWithBytes:result length:CC_MD5_DIGEST_LENGTH];
	return dataMD5;
}
/**
 *	计算 SHA1 ， 并将原始结果结果保存于指定的 uint8数组里
 *
 *	@param obj    obj description
 *	@param digest digest description，  长度 CC_SHA1_DIGEST_LENGTH
 *
 *	@return return value description
 */
+ (BOOL)getSHA1:(id)obj withDigest:(uint8_t *)digest
{
	NSData *objData = [self dataWithObj:obj];
	if (! objData) {
		return NO;
	}
	//uint8_t digest[CC_SHA1_DIGEST_LENGTH];
	
	CC_SHA1(objData.bytes, objData.length, digest);
	return YES;
}

+ (id)objFromArchiverData:(NSData *)data withKey:(NSString *)key
{
	if (! data) {
		return nil;
	}
	if (! key) {
		key = @"Sangfor";
	}
	NSKeyedUnarchiver *unarchiver = nil;
	id obj = nil;
	@try {
		unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
		obj = [unarchiver decodeObjectForKey:key];
	}
	@catch (NSException *exception) {
		NSLog(@"%@", exception);
		exception = nil;
	}
	@finally {
		[unarchiver finishDecoding];
	}
	return obj;
	
}
+ (NSData *)archiverDataFromObj:(id)obj withKey:(NSString *)key
{
	if (! obj) {
		return nil;
	}
	if (! key) {
		key = @"Sangfor";
	}
	NSMutableData *currentData = [[NSMutableData alloc] init];
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:currentData];
	[archiver encodeObject:obj forKey:key];
	[archiver finishEncoding];
	return currentData;
}

/**
 *  将 obj 转换成 NSData
 *
 *  @param obj NSString=UTF8_char, UIImage,
 *
 *  @return return value description
 */
+ (NSData *)dataWithObj:(id)obj
{
	if (obj == nil) {
		return nil;
	}
	NSData *data = obj;
	if ([obj isKindOfClass:[NSString class]]) {
		NSString *string = obj;
		data = [NSData dataWithBytes:[string UTF8String]
							  length:[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
	}else if ([obj isKindOfClass:[UIImage class]]) {
		data = UIImageJPEGRepresentation(obj, 1.0f);
	}else if ([obj isKindOfClass:[NSData class]]) {
		
	}else{
		
		logAbort(@"Bug: unsupport class(%@) to get md5", [obj class]);
	}
	return data;
}

#pragma mark -
/**
 *  显示提示信息
 *
 *  @param message message description
 */
+ (void)showAlertMsg:(NSString *)message
{
	if (message == nil) {
		return;
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		MOAAlert *alert = [[MOAAlert alloc] initWithTitle:nil
														message:message
													   delegate:nil
											  cancelButtonTitle:NSLocalizedString(@"OK", nil)
											  otherButtonTitles:nil];
		[alert show];
	});
	
}

#pragma mark -- picture deal 【Pixel】

#define kThumbPixel		200	//Pixel  默认图像缩略图最大边像素
#define kThumbPoint		(kThumbPixel/kMainScreenScale)	//point  默认图像缩略图最大边点
#define kLongPicRatio	2	//长图长宽比例， 超过此比例即为长图
#define kDefaultCompressRatio	0.008	//无大小限制时使用此压缩
#define getPexelSize(org)	CGSizeMake(org.size.width*org.scale, org.size.height*org.scale)	//获取图片的像素级size
#define scalePixelRect(rect, scale)	CGRectMake(rect.origin.x/scale, rect.origin.y/scale, rect.size.width/scale, rect.size.height/scale)	//根据 scale 缩放像素级的 rect
#define scalePixelSize(size, scale)	CGSizeMake(size.width/scale, size.height/scale)	//根据 scale 缩放像素级的 size

+ (CGSize)ResizeSize:(CGSize)orgSize withMaxSize:(CGSize)maxSize
{
	CGFloat sWidth = 0, sHight = 0;
	if (maxSize.width > 0 && orgSize.width > maxSize.width) {
		sWidth = orgSize.width/maxSize.width;
	}
	if (maxSize.height > 0 && orgSize.height > maxSize.height) {
		sHight = orgSize.height/maxSize.height;
	}
	CGFloat s = sWidth;
	if (s < sHight) {
		s = sHight;
	}
	if (s == 0) {
		return orgSize;
	}
	return CGSizeMake(orgSize.width/s, orgSize.height/s);
}

/**
 *  单位：像素
 *
 *	@param orgSize orgSize description
 *
 *	@return return value description
 */
+ (NSValue *)getThumbSizeWithOrgSize:(NSValue *)orgSize
{
	NSAssert(orgSize, nil);
	if (! orgSize) {
		return [NSValue valueWithCGSize:CGSizeZero];
	}
	CGSize org = [orgSize CGSizeValue];

	//1. 取长短边
	CGFloat longSide = 0.0f;
	CGFloat shortSide = 0.0f;
	if (org.height >= org.width) {
		longSide = org.height;
		shortSide = org.width;
	}else{
		longSide = org.width;
		shortSide = org.height;
	}
	if (! (longSide && shortSide)) {
		NSLog(@"Tips: size is invalid:%@", NSStringFromCGSize(org));
		return [NSValue valueWithCGSize:CGSizeZero];
	}
	
	CGFloat longResult = longSide;
	CGFloat shortResult = shortSide;
	//2. 获取比例
	CGFloat scale = longSide / shortSide;
	if (scale >= kLongPicRatio) {//比例大于2就算长图
		if (shortSide > (kThumbPixel/kLongPicRatio)) {
			longResult = kThumbPixel;
			shortResult = (kThumbPixel/kLongPicRatio);
		}else{
			if (longSide > kThumbPixel) {
				longResult = kThumbPixel;
			}
		}
	}else{
		if (longSide > kThumbPixel) {
			CGFloat scaleAll = kThumbPixel / longSide;
			longResult = kThumbPixel;
			shortResult = scaleAll * shortSide;
		}
	}
	 
	if (org.height >= org.width) {
		return [NSValue valueWithCGSize:CGSizeMake(shortResult, longResult)];
	}else{
		return [NSValue valueWithCGSize:CGSizeMake(longResult, shortResult)];
	}
}

/**
 *  亚素平 UIImage 对象, 大于 maxPoint 尺寸会被等比缩放
 *
 *  @param orgImage orgImage description
 *  @param maxPixel maxPixel, 若=0, 则不会缩放
 *
 *  @return {@"orgData":NSData,  "compressData":NSData}=成功, nil=转换失败
 */
+ (NSDictionary *)compressIMImage:(UIImage *)orgImage
{
	return [self compressIMImage:orgImage andDealOrgImage:YES];
}
+ (NSDictionary *)compressIMImage:(UIImage *)orgImage andDealOrgImage:(BOOL)dealOrg
{
	if (! [orgImage isKindOfClass:[UIImage class]]) {
		return nil;
	}
	
	NSInteger maxBytes = 0;
	CGSize maxSize = CGSizeZero;
	CGFloat maxPixel = kThumbPixel;//长宽最大 kThumbPixel

	return [self compressImage:orgImage withMaxBytes:maxBytes toMaxSize:maxSize andMaxPixel:maxPixel];
}
/**
 *	获取长图的缩略图
 *
 *	@param orgImage orgImage description
 *
 *	@return return value description
 */
+ (UIImage *)getThumbWithLongImage:(UIImage *)orgImage
{
	if (! orgImage) {
		return nil;
	}
	NSAssert([orgImage isKindOfClass:[UIImage class]], nil);
	// 1. 取长短边
	CGSize org = getPexelSize(orgImage);
	CGFloat longSide = 0.0f;
	CGFloat shortSide = 0.0f;
	if (org.height >= org.width) {
		longSide = org.height;
		shortSide = org.width;
	}else{
		longSide = org.width;
		shortSide = org.height;
	}
	NSAssert(longSide && shortSide, @"longSide && shortSide shouldnt be 0");
	NSAssert(longSide >= kThumbPixel, @"long side should be > kThumbPoint points to use this function");
	NSAssert(longSide / shortSide >= kLongPicRatio, @"longSide / shortSide >= kLongPicRatio should be YES to use this function");
	
	// 2. 获取短边的大小
	CGFloat drawShort = 0;
	if (shortSide >= (kThumbPixel/2)) {
		drawShort = (kThumbPixel/2);
	}else{
		drawShort = shortSide;
	}
	

	//---------------------------//
	// 3. 先缩放原图
	CGFloat resizeRatio = drawShort / shortSide;
	orgImage = [self resizeImage:orgImage withScale:resizeRatio];

	// 4. 再截取
	CGRect cutRect;
	CGSize orgSize = getPexelSize(orgImage);
	if (orgSize.width > orgSize.height) {//水平长
		CGFloat offset = (orgSize.width - kThumbPixel)/2;
		cutRect = CGRectMake(offset, 0, kThumbPixel, drawShort);
	}else{
		CGFloat offset = (orgSize.height - kThumbPixel)/2;
		cutRect = CGRectMake(0, offset, drawShort, kThumbPixel);
	}
	orgImage = [self getSubImageInRect:scalePixelRect(cutRect, orgImage.scale) withOrgImage:orgImage];
	return orgImage;
	
}
/**
 *	按比例缩放图像
 *
 *	@param orgImage orgImage description
 *	@param scale    scale description
 *
 *	@return return value description
 */
+ (UIImage*)resizeImage:(UIImage *)orgImage withScale:(CGFloat)scale
{
	NSAssert([orgImage isKindOfClass:[UIImage class]], nil);
	if (! [orgImage isKindOfClass:[UIImage class]]) {
		return nil;
	}
	//缩放
	CGSize orgSize = orgImage.size;
	UIImage *result = orgImage;
	if (fabs(1.0f - scale) > FLT_EPSILON) {//检查是否需要缩放
		NSInteger width = (NSInteger)(orgSize.width * scale);
		NSInteger height = (NSInteger)(orgSize.height * scale);
		CGSize newSize = CGSizeMake(width, height);
		
		
		//---------------------------//
		
		// 创建一个bitmap的contextm,并把它设置成为当前正在使用的context
		UIGraphicsBeginImageContextWithOptions(newSize, NO, orgImage.scale);
		//UIGraphicsBeginImageContext(newSize);
		// 绘制改变大小的图片
		[orgImage drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
		// 从当前context中创建一个改变大小后的图片
		result = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
	}
	NSAssert(orgImage.scale == result.scale, nil);
	return result;
}
//截取部分图像
+ (UIImage*)getSubImageInRect:(CGRect)rect withOrgImage:(UIImage *)orgImage
{
	CGRect rectInPixel = CGRectMake(rect.origin.x * orgImage.scale,
									rect.origin.y * orgImage.scale,
									rect.size.width * orgImage.scale,
									rect.size.height * orgImage.scale);
    CGImageRef subImageRef = CGImageCreateWithImageInRect(orgImage.CGImage, rectInPixel);
    CGRect smallBounds = CGRectMake(0, 0, CGImageGetWidth(subImageRef), CGImageGetHeight(subImageRef));
	UIGraphicsBeginImageContextWithOptions(smallBounds.size, NO, orgImage.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextDrawImage(context, smallBounds, subImageRef);
    UIImage* smallImage = [UIImage imageWithCGImage:subImageRef scale:orgImage.scale orientation:UIImageOrientationUp];
    UIGraphicsEndImageContext();
	CGImageRelease(subImageRef);
	NSAssert(orgImage.scale == smallImage.scale, nil);
    return smallImage;
}
+ (NSDictionary *)compressImage:(UIImage *)orgImage withMaxBytes:(NSInteger)maxBytes toMaxSize:(CGSize)maxSize andMaxPixel:(CGFloat)maxPixel
{
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	if (! [orgImage isKindOfClass:[UIImage class]]) {
		NSLogToFile(@"Bug: invalid arg for compressImage:(%@)", [orgImage class]);
		return nil;
	}
	
	
	
	// 1. 尺寸压缩
	if (! CGSizeEqualToSize(maxSize, CGSizeZero)) {
		BOOL isResized = NO;
		orgImage = [EntrysOperateHelper resizeUIImage:orgImage withMaxSize:maxSize andIsResized:&isResized];
	}
	
	// 2. 压缩大小 -- 或者使用默认压缩率
	NSData *orgData = nil;
	if (maxBytes == 0) {//使用默认压缩率
		orgData = UIImageJPEGRepresentation(orgImage, kDefaultCompressRatio);//原始图默认转换为1.0的jpg
	}else{
		orgData = UIImageJPEGRepresentation(orgImage, 1.0);//原始图默认转换为1.0的jpg
	}
	result[@"orgData"] = orgData;
	if (maxBytes != 0) {//使用大小限制
		if (orgData == nil) {
			NSLog(@"UIImageJPEGRepresentation failed with:(%@)",orgImage);
			return nil;
		}else{
			NSLog(@"length=%zd maxSize=%zd",orgData.length,maxBytes);
			//检查是否需要压缩原图
			if (orgData.length > maxBytes) {//大于最大字节数, 则按照maxSize压缩
				CGFloat quality = 1.0f;
				if (orgData.length > maxBytes) {
					quality = (CGFloat)maxBytes / (CGFloat)(orgData.length) ;
					orgData = UIImageJPEGRepresentation(orgImage, quality);//原始图默认转换为1.0的jpg
					if (orgData == nil) {
						NSLog(@"UIImageJPEGRepresentation failed with(resized):(%@)",orgImage);
						return nil;
					}
				}
			}
			result[@"orgData"] = orgData;
		}
	}
	if (maxPixel == 0) {
		return result;
	}
	
	NSValue *thumbValue = [self getThumbSizeWithOrgSize:[NSValue valueWithCGSize:getPexelSize( orgImage)]];
	if (! thumbValue) {
		NSLogToFile(@"Warn: failed to get thumbSize foe image size:%@", NSStringFromCGSize(orgImage.size));
		return nil;
	}
	//判断是否是长图
	CGSize thumbSize = scalePixelSize([thumbValue CGSizeValue], orgImage.scale);
	CGSize orgSize = orgImage.size;
	UIImage* compressImage = nil;
	BOOL isResized = NO;
	result[@"compressData"] = orgData;
	CGFloat ra = thumbSize.height/(thumbSize.width?thumbSize.width:1)
	- orgSize.height/(orgSize.width?orgSize.width:1);
	if (ra < 0) {
		ra = -ra;
	}
	if (ra > FLT_EPSILON) {//属于长图
		compressImage = [self getThumbWithLongImage:orgImage];
		isResized = YES;
	}else{
		compressImage = [EntrysOperateHelper resizeUIImage:orgImage withMaxSize:CGSizeMake(maxPixel, maxPixel) andIsResized:&isResized];
	}
	
	if (isResized == YES) {
		//UIImage *compressImage = [UIImage imageWithData:orgData scale:scale];
		NSData *compressData = UIImageJPEGRepresentation(compressImage, 1.0);//原始图默认转换为1.0的jpg
		if (compressData != nil) {
			result[@"compressData"] = compressData;
			
		}
	}
	return result;
}
/**
 *	根据 maxOrgSize (像素单位) 缩放图片
 *
 *	@param image      image description
 *	@param maxOrgSize 最大像素尺寸
 *	@param isResized  isResized description
 *
 *	@return return value description
 */
+ (UIImage *)resizeUIImage:(UIImage *)image withMaxSize:(CGSize)maxOrgSize andIsResized:(BOOL*)isResized
{
	//maxSize 转换成像素
	CGSize maxSize = scalePixelSize(maxOrgSize, image.scale);
	if (isResized != nil) {
		*isResized = NO;
	}
	UIImage *result = image;
	if (! [image isKindOfClass:[UIImage class]]) {
		return nil;
	}
	CGSize orgSize = [image size];
	CGFloat scaleWidth = 1.0f;
	CGFloat scaleHight = 1.0f;
	if (orgSize.width > maxSize.width) {
		scaleWidth = maxSize.width / orgSize.width;
	}
	if (orgSize.height > maxSize.height) {
		scaleHight = maxSize.height / orgSize.height;
	}
	CGFloat scale = scaleWidth;
	if (scale > scaleHight) {
		scale = scaleHight;
	}
	//缩放
	
	if (fabs(1.0f - scale) > FLT_EPSILON) {//检查是否需要缩放
		if (isResized != nil) {
			*isResized = YES;
		}
		return [self resizeImage:image withScale:scale];
	}
	return result;
}

+ (NSURL *)absoluteURL:(NSString *)relativePath
{
	if (! relativePath) {
		return nil;
	}
	NSURL *homeURL = [CoredataManager getUserDocumentUrl];
	if (homeURL == nil) {
		return nil;
	}
	return [homeURL URLByAppendingPathComponent:relativePath];
}

+ (void)cancelAllLocalNotifications
{
	NSLog(@"Tips: cancelAllLocalNotifications");
	[[UIApplication sharedApplication] cancelAllLocalNotifications];
}

+ (BOOL)isDeletedOfNSmanagedObject:(id)obj
{
	if (obj == nil) {
		return YES;
	}
	if ([obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSSet class]]) {
		//BOOL result = NO;
		for (NSManagedObject *elem in obj) {
			if ([EntrysOperateHelper isDeletedOfNSmanagedObject:elem]) {
				//result = YES;
				return YES;
			}
		}
		return NO;
    }else if([obj isKindOfClass:[MOAManagedObjectNoCache class]]) {
        return NO;
    }else if (! [obj isKindOfClass:[NSManagedObject class]]){
		NSLogToFile(@"Bug: obj should be nsmanagedobject / nsarray / nsset:(%@)", [obj class]);
		if (kFlagDebug) {
			logAbort(@"obj should be nsmanagedobject / nsarray / nsset:(%@)", [obj class]);
		}
		return YES;
		
	}
	if ([obj isDeleted]) {
		return YES;
	}
	if (! [obj isFault]) {
		if (! ((NSManagedObject *)obj).managedObjectContext) {
			return YES;
		}else{
			return NO;
		}
	}else{
		NSManagedObjectContext *currentContext = [CoredataManager getContextInCurrenrThread];
		if ([currentContext respondsToSelector:@selector(existingObjectWithID:error:)])
		{
			NSManagedObjectID   *objectID           = [obj objectID];
			if ([objectID isTemporaryID]) {
				if ([[obj retainLabel] integerValue] == 0) {
					[currentContext deleteObject:obj];
					return YES;
				}
			}
			NSManagedObject     *managedObjectClone = [currentContext existingObjectWithID:objectID error:NULL];
			
			if (!managedObjectClone){
				return YES;                 // Deleted.
			}else{
				return NO;                  // Not deleted.
			}
		}else{
			if (! currentContext) {
				return YES;
			}
			NSLog(@"Unsupported version of IOS detected:%@", currentContext);
			NSAssert(currentContext == nil, @"check why it dont response to existingObjectWithID:error:");
			return NO;
		}
	}
	
}
/**
 *	转化 OSStatus 为字符串
 *
 *	@param error error description
 *
 *	@return return value description
 */
+ (NSString *)FormatError:(OSStatus)error
{
	char str[sizeof(int)*8 + 1];//'****'
	memset(str, 0, sizeof(str));
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    return [NSString stringWithUTF8String:str];
}

+ (NSDictionary *)compareNewObjs:(id)newObjs withOldSet:(NSSet *)oldSet
{
	if (! [oldSet isKindOfClass:[NSSet class]]) {
		logAbort(@"Bug: oldSet should be set:%@", [oldSet class]);
	}
	NSSet *newSet = nil;
	if ([newObjs isKindOfClass:[NSManagedObject class]] || [newObjs isKindOfClass:[MOAManagedObjectNoCache class]]) {
		newSet = [NSSet setWithObject:newObjs];
	}else if ([newObjs isKindOfClass:[NSSet class]]) {
		newSet = newObjs;
	}else if ([newObjs isKindOfClass:[NSArray class]]) {
		newSet = [NSSet setWithArray:newObjs];
	}
	
	NSMutableSet *same = [NSMutableSet set];
	NSMutableSet *old = [NSMutableSet set];
	NSMutableSet *neww = [NSMutableSet set];

	for (NSManagedObject *obj in oldSet) {
		if ([newSet containsObject:obj]) {
			[same addObject:obj];
		}else{
			[old addObject:obj];
		}
	}
	for (NSManagedObject *obj in newSet) {
		if (! [same containsObject:obj]) {
			[neww addObject:obj];
		}
	}
	return @{@"same":[NSSet setWithSet:same],
			 @"old":[NSSet setWithSet:old],
			 @"new":[NSSet setWithSet:neww],};
}
/**
 *	异步请求网络url
 *
 *	@param urlString urlString description
 *	@param seconds   seconds description
 *	@param callback  callback description
 */
+ (void)asyncNetRequestToURL:(NSString *)urlString
				 withTimeout:(NSTimeInterval)seconds
		 andCompletionHandle:(MOACallback)callback
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSData *result = [self syncNetRequestToURL:urlString withTimeout:seconds];
		if (callback) {
			callback(result);
		}
	});
}
/**
 *	同步请求网络url
 *
 *	@param urlString urlString description
 *	@param seconds   seconds description
 *
 *	@return return value description
 */
+ (NSData *)syncNetRequestToURL:(NSString *)urlString withTimeout:(NSTimeInterval)seconds
{
	if (! urlString) {
		return nil;
	}
	NSURL *reqUrl = [NSURL URLWithString:urlString];
    
    NSAssert([reqUrl.scheme isEqualToString:@"https"], nil);
    
	NSURLRequest *urlRequest = [NSURLRequest requestWithURL:reqUrl cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:seconds];
	NSURLResponse *response = nil;
	NSError *error = nil;
	NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest
										 returningResponse:&response
													 error:&error];
	
	
	if (([data length] > 0)
		&& (error == nil)){
		//NSLog(@"%lu bytes of data was returned.", (unsigned long)[data length]);
	}else if ([data length] == 0 &&
			  error == nil){
		NSLogToFile(@"Warn: No data was returned.");
		data = nil;
	}else if (error != nil){
		NSLogToFile(@"Error: %@", error);
		data = nil;
	}
	return data;

}
+ (NSString *)jsonStringFromNSObject:(id)obj
{
	NSData *data = [self jsonDataFromNSObject:obj];
	if (data) {
		return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	return @"{}";
}
+ (NSData *)jsonDataFromNSObject:(id)obj
{
	if (! obj || [obj isEqual:[NSNull null]]) {
		return nil;
	}
	NSError *error = nil;
	if (! [NSJSONSerialization isValidJSONObject:obj]) {
		NSLogToFile(@"Bug: jsonFromNSObject arg error:%@", obj);//NSNumber 不可做 key, 不能包含 NSDate
		return nil;
	}
	NSData *jsonObject = [NSJSONSerialization dataWithJSONObject:obj options:0 error:&error];
	
	if (! jsonObject) {
		NSLogToFile(@"Warn: jsonFromNSObject failed:%@", error);
	}
	return jsonObject;
}


+ (id)objFromString:(NSString *)jsonString
{
	id result = [self dictFromJsonString:jsonString];
	return result;
}
+ (id)dictFromJsonString:(NSString *)jsonString
{
	if (! [jsonString isKindOfClass:[NSString class]]) {
		return nil;
	}
    return [self dictFromJson:[jsonString dataUsingEncoding:NSUTF8StringEncoding] errorOut:YES];
}
+ (id)dictFromJson:(NSData *)jsonData errorOut:(BOOL)err
{
	if (! jsonData) {
		return nil;
	}
	NSError *error = nil;
	id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&error];
	if (jsonObject != nil &&
		error == nil){
		
	}else if (error != nil){
        if(err) {
            NSLogToFile(@"Warn: happened while deserializing the JSON data:%@ \n from:%@\n%@", error, [NSString stringWithUTF8String:(const char *)[jsonData bytes]], jsonData);
            NSAssert(0, nil);
        }
		return nil;
	}
	return jsonObject;
}

+ (NSDictionary *)removeNullKeys:(NSDictionary *)dict
{
    NSAssertRet(dict, dict == nil || [dict isKindOfClass:[NSDictionary class]], nil);
    
    if(dict == nil) {
        return nil;
    }
    
    NSMutableArray *nullKeys = [NSMutableArray array];
    [dict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if([obj isKindOfClass:[NSNull class]]) {
            [nullKeys addObject:key];
        }
    }];
    if(nullKeys.count) {
        NSMutableDictionary *mutableDict = [dict mutableCopy];
        [mutableDict removeObjectsForKeys:nullKeys];
        dict = mutableDict;
    }
    
    return dict;
}

/**
 *	遍历处理 dirPath (全路径) 下的文件 -- 使用block方法
 *
 *	@param dirPath   dirPath description
 *	@param dealBlock dealBlock , 全路径参数传入
 *
 *	@return return value description
 */
+ (BOOL)dealAllFilesAtDirPath:(NSString *)dirPath withBlock:(MOACallback)dealBlock
{
	if (! dirPath) {
		return NO;
	}
	//1. 获取系统目录
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray* tempArray = [fileManager contentsOfDirectoryAtPath:dirPath error:nil];
	if (tempArray.count  > 0) {
		[tempArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			NSString* fullPath = [dirPath stringByAppendingPathComponent:obj];
			BOOL flag = YES;
			if ([fileManager fileExistsAtPath:fullPath isDirectory:&flag]) {
				if (!flag) {
					if (dealBlock) {
						dealBlock(fullPath);
					}
				}
			}
			
		}];
	}
	return YES;
}

+ (NSString *)deviceType
{
	struct utsname devInfo;
	uname(&devInfo);
	
	NSString *machineModel = [NSString stringWithCString:devInfo.machine encoding:NSUTF8StringEncoding];
	machineModel = [machineModel stringByReplacingOccurrencesOfString:@"," withString:@""];
	machineModel = [machineModel stringByReplacingOccurrencesOfString:@" " withString:@"_"];
	return machineModel;
}

+ (NSString *)deviceTypeName
{
   return [EntrysOperateHelper deviceTypeNameWithType:nil];
}

+ (NSString *)deviceTypeNameWithType:(NSString *)deviceType
{
    if (!deviceType) {
        deviceType = [EntrysOperateHelper deviceType];
    }
    
    static NSDictionary *map = nil;
    static NSArray *mapAllKeys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"ModelLabelAndModelTypeRelation" ofType:@"plist"];
        map = [NSDictionary dictionaryWithContentsOfFile:path];
        mapAllKeys = map.allKeys;
    });
    NSDictionary *realTypeInfo = nil;
    for (NSString *tempKey in mapAllKeys) {
        if ([deviceType rangeOfString:tempKey].location != NSNotFound) {
            realTypeInfo = map[tempKey];
            break;
        }
    }
    
    NSString *deviceTypeName = @"苹果手机";
    if (realTypeInfo[deviceType]) {
        deviceTypeName = realTypeInfo[deviceType];
        if ([deviceTypeName rangeOfString:@"("].location != NSNotFound) {
            deviceTypeName = [deviceTypeName substringToIndex:[deviceTypeName rangeOfString:@"("].location];
        }
    }
    
    return deviceTypeName;
}

+ (NSString *)HexStringFromBytes:(const void *)bytes andLength:(NSUInteger)length
{
	char tmpChars[length * 2];
	for (NSUInteger i = 0; i < length; i++) {
		UInt8 *ch = (UInt8 *)bytes + i;
		UInt8 value = (*ch)>>4;
		tmpChars[i*2] = (value>=0x0A)?('A'+ value - 0x0A):('0'+ value);
		value = (*ch)&0x0F;
		tmpChars[i*2 + 1] = (value>=0x0A)?('A'+ value - 0x0A):('0'+ value);
	}
	return [[NSString alloc] initWithBytes:tmpChars length:length*2 encoding:NSUTF8StringEncoding];
}
/**
 *	系统大版本号， 如5、6、7
 *
 *	@return return value description
 */
+ (NSInteger)systemVersionNumber
{
	NSString *systemVerion = [[UIDevice currentDevice] systemVersion];
	NSArray *numbers = [systemVerion componentsSeparatedByString:@"."];
	if (numbers.count > 0 && [numbers[0] length] == 1) {
		return [numbers[0] integerValue];
	}
	return 6;
}

+ (NSInteger)clientAppType
{
    NSString *bundelID = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundelID isEqualToString:@"com.sangfor.PocketBackup"]) {
        return APP_BACKUP;
    }
    PB_AppType ret = APP_RELEASE;
    if(kFlagComplieWithEnterprise) {
        ret = APP_ENTERPRISE;
    }else {
        if(kFlagDebug) {
            ret = APP_DEBUG;
        }else {
            ret = APP_RELEASE;
        }
    }
    
    return ret;
}

+ (NSInteger)clientDeviceType
{
    PB_ClientDevType ret = PBCDT_IOS;
    
    extern BOOL gbLoginAsWeb;
    if(gbLoginAsWeb) {
        ret = PBCDT_WEB;
        NSLogToFile(@"Info: auth to server as web");
    }else {
        if(kFlagComplieWithEnterprise) {    //企业证书
            ret = PBCDT_IOS_ENTERPRISE;
        }else{
            ret = PBCDT_IOS;
        }
    }
    
    return (NSInteger)ret;
}

+ (NSString *)appSimpleVersion
{
    id ret = @"3.4.0";
#ifdef __OPTIMIZE__
    NSDictionary *plist = [[NSBundle mainBundle] infoDictionary];
    if(plist[@"CFBundleShortVersionString"]) {
        ret = plist[@"CFBundleShortVersionString"];
    }
#endif
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLogToFile(@"Info: appSimpleVersion %@", ret);
    });;
    return ret;
}

+ (NSString *)systemVersion
{
    return [UIDevice currentDevice].systemVersion;
}

+ (NSDictionary *)partitionString:(NSString *)orgString
					   withString:(NSString *)keyString
				   AndIgnoredCase:(BOOL)ignoreCase
{
	if (orgString.length == 0 || keyString.length == 0) {
		return nil;
	}
	NSRange range = [orgString rangeOfString:keyString options:ignoreCase?NSCaseInsensitiveSearch:0];
	if (range.location == NSNotFound) {
		return nil;
	}
	NSUInteger keyStartIndex = range.location;
	NSUInteger keyEndIndex = range.location + range.length - 1;
	NSString *headString = [orgString substringWithRange:(NSRange){0, keyStartIndex - 0}];
	NSString *endString = [orgString substringWithRange:(NSRange){keyEndIndex + 1, orgString.length-1-keyEndIndex}];
	return @{@"start":(headString?headString:@""),
			 @"end":(endString?endString:@"")};
}


#define  kCustomDefaultFileName @"defaultCumstomName"
+ (NSArray *)getCustomDatasWithName:(NSString *)name
{
	return [self custom:YES getCustomDatasWithName:name];
}
+ (NSArray *)custom:(BOOL)custom getCustomDatasWithName:(NSString *)name
{
	NSURL *userPath = nil;
	if (custom) {
		userPath = [CoredataManager getUserDocumentUrl];
		NSAssert(userPath, nil);
	}else{
		userPath = [self getURLForDocumentSubDir:nil];
	}
	NSURL *fileUrl= [userPath URLByAppendingPathComponent:name?name:kCustomDefaultFileName];
	NSArray *value = [[NSArray alloc] initWithContentsOfURL:fileUrl];
	if (value && ! [value isKindOfClass:[NSArray class]]) {
		value = nil;
	}
	return value;
}
+ (BOOL)appendCustomData:(id)customDate withName:(NSString *)name
{
	return [self custom:YES appendCustomData:customDate withName:name];
}
+ (BOOL)custom:(BOOL)custom appendCustomData:(id)customDate withName:(NSString *)name
{
	NSArray *appendDate = customDate;
	if (! [appendDate isKindOfClass:[NSArray class]]) {
		appendDate = [NSArray arrayWithObject:appendDate];
	}
	
	NSURL *userPath = nil;
	if (custom) {
		userPath = [CoredataManager getUserDocumentUrl];
	}else{
		userPath = [EntrysOperateHelper getURLForDocumentSubDir:nil];
	}
	
	NSURL *fileUrl= [userPath URLByAppendingPathComponent:name?name:kCustomDefaultFileName];
	
	NSArray *value = [[NSArray alloc] initWithContentsOfURL:fileUrl];
	if (value && ! [value isKindOfClass:[NSArray class]]) {
		value = nil;
	}
	NSMutableArray *newValue = [NSMutableArray arrayWithArray:value];
	for (id obj in appendDate) {
		if (![obj isKindOfClass:[NSString class]]
			&& ![obj isKindOfClass:[NSNumber class]]) {
			return NO;
		}
		if ([newValue containsObject:obj]) {
			[newValue removeObject:obj];
		}
		[newValue insertObject:obj atIndex:0];
	}
	

	return [newValue writeToURL:fileUrl atomically:YES];
}
+ (BOOL)removeCustomData:(id)customDate withName:(NSString *)name
{
	return [self custom:YES removeCustomData:customDate withName:name];
}
+ (BOOL)custom:(BOOL)custom removeCustomData:(id)customDate withName:(NSString *)name
{
	NSArray *removeDate = customDate;
	if (! [removeDate isKindOfClass:[NSArray class]]) {
		removeDate = [NSArray arrayWithObject:removeDate];
	}
	
	NSURL *userPath = nil;
	if (custom) {
		userPath = [CoredataManager getUserDocumentUrl];
	}else{
		userPath = [EntrysOperateHelper getURLForDocumentSubDir:nil];
	}
	
	NSURL *fileUrl= [userPath URLByAppendingPathComponent:name?name:kCustomDefaultFileName];
	
	NSArray *value = [[NSArray alloc] initWithContentsOfURL:fileUrl];
	if (value && ! [value isKindOfClass:[NSArray class]]) {
		value = nil;
	}
	NSMutableArray *newValue = [NSMutableArray arrayWithArray:value];
	for (id obj in removeDate) {
		if (![obj isKindOfClass:[NSString class]]
			&& ![obj isKindOfClass:[NSNumber class]]) {
			return NO;
		}
		if ([newValue containsObject:obj]) {
			[newValue removeObject:obj];
		}
		//[newValue insertObject:obj atIndex:0];
	}
	
	
	return [newValue writeToURL:fileUrl atomically:YES];
}
/**
 *	根据指定的 key 进行升降序排列内容后返回数组
 *
 *	@param set set description
 *	@param key key description
 *	@param asc asc description
 *
 *	@return return value description
 */
+ (NSArray *)sortNSSet:(NSSet *)set withKey:(NSString *)key ascending:(BOOL)asc
{
	NSAssert(key , nil);
	if (! set) {
		return nil;
	}
	NSAssert([set isKindOfClass:[NSSet class]], nil);
	if (set.count == 0) {
		return [NSArray array];//空集合返回空数组
	}
	NSArray *soryArray = [NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:key ascending:asc]];
	return [set sortedArrayUsingDescriptors:soryArray];
}

/**
 *	根据文件路径创建其父文件夹
 *
 *	@param filePath 带文件名的路径
 *
 *	@return return value description
 */
+ (NSError *)touchDirForFilePath:(NSString *)filePath
{
	//检查目录有效性
	NSError *error = nil;
	NSURL *fileURL = [NSURL fileURLWithPath:filePath];
	NSURL *dirURL = [fileURL URLByDeletingLastPathComponent];
#if(!TARGET_IPHONE_SIMULATOR)
    NSDictionary *attr = @{NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication};
#else
    NSDictionary *attr = nil;
#endif
    NSDictionary *dirAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:dirURL.path error:nil];
    if(dirAttr && [dirAttr[NSFileProtectionKey] isEqualToString:NSFileProtectionCompleteUntilFirstUserAuthentication] == NO) {
        NSMutableDictionary *newAttr = [dirAttr mutableCopy];
        [newAttr addEntriesFromDictionary:attr];
        if([[NSFileManager defaultManager] setAttributes:newAttr ofItemAtPath:dirURL.path error:&error] == NO) {
            NSAssert(0, nil);
            NSLogToFile(@"Error: Failed to create the directory(%@). Error = %@", dirURL.path, error);
            return error;
        }
        return nil;
    }
    
    if ([[NSFileManager defaultManager] createDirectoryAtPath:dirURL.path
			   withIntermediateDirectories:YES
								attributes:attr
									 error:&error]){
		//NSLog(@"Successfully created the directory:%@", newFolderUrl.path);
	} else {
        NSAssert(0, nil);
		NSLogToFile(@"Error: Failed to create the directory(%@). Error = %@", dirURL.path, error);
		return error;
	}
    
	return nil;
}

/**
 *	json转obj对象，遍历查找 obj 对象， 若其dict里的key与所查找的对相匹配了， 则将值整理成数组返回
 *
 *	@param json  NSSet, NSArray, NSDictionary
 *	@param key key description， 主要是 nsstring
 *
 *	@return return value description  nil=未找到
 */
+ (NSArray *)searchJson:(NSString *)json forKey:(id)key
{
	NSDictionary *dict = [EntrysOperateHelper dictFromJsonString:json];
	if (dict) {
		return [EntrysOperateHelper searchObj:dict forKey:key];
	}
	return nil;
}
/**
 *	遍历查找 obj 对象， 若其dict里的key与所查找的对相匹配了， 则将值整理成数组返回
 *
 *	@param obj obj description  NSSet, NSArray, NSDictionary
 *	@param key key description， 主要是 nsstring
 *
 *	@return return value description  nil=未找到
 */
+ (NSArray *)searchObj:(id)obj forKey:(id)key
{
	NSAssert(key != nil, nil);
	NSMutableArray *result = [NSMutableArray array];
	if ([obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSSet class]]) {
		for (id elem in obj) {
			NSArray *tmpResult = [self searchObj:elem forKey:key];
			if (tmpResult.count > 0) {
				[result addObjectsFromArray:tmpResult];
			}
		}
	}else if ([obj isKindOfClass:[NSDictionary class]]) {
		NSArray *keys = [(NSDictionary *)obj allKeys];
		for (id elem in keys) {
			if ([elem isEqual:key]) {
				[result addObject:obj[elem]];
			}
			
			NSArray *tmpResult = [self searchObj:obj[elem] forKey:key];
			if (tmpResult.count > 0) {
				[result addObjectsFromArray:tmpResult];
			}
			
			tmpResult = [self searchObj:elem forKey:key];
			if (tmpResult.count > 0) {
				[result addObjectsFromArray:tmpResult];
			}
			
		}
	}
	if (result.count == 0) {
		return nil;
	}
	return result;
}

+ (NSString *)getWifiBSSID
{
	NSDictionary *ssidInfo = [self fetchSSIDInfo];
	return ssidInfo[@"BSSID"];
}
+ (NSDictionary *)fetchSSIDInfo
{
    NSArray *ifs = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
    //NSLog(@"Supported interfaces: %@", ifs);
    NSDictionary *info = nil;
    for (NSString *ifnam in ifs) {
        info = (__bridge_transfer  NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
        //NSLog(@"name:%@ => %@", ifnam, info);
        if (info && [info count]) {
            break;
        }
    }
	return info;
}
+ (id)objectForKey:(id)key
{
	return [self objectForKey:key isUser:YES];
}
+ (id)objectForKey:(id)key isUser:(BOOL)isUser
{
	NSURL *docURL = nil;
	if (isUser) {
		docURL = [CoredataManager defaultInstance].userConfig.documentURL;
	}else{
		docURL = [self getURLForDocumentSubDir:nil];
	}
	NSURL *fileURL = [docURL URLByAppendingPathComponent:kUserSettingFile];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        NSDictionary *dic = [NSDictionary dictionaryWithContentsOfFile:[fileURL path]];
		return dic[key];
    }
	return nil;
}
+ (void)saveObject:(id)obj forKey:(NSString *)key
{
	NSAssert([MOAModelManager defaultInstance] != nil, nil);
	[self saveObject:obj forKey:key isUser:YES];
}
+ (void)saveObject:(id)obj forKey:(NSString *)key isUser:(BOOL)isUser
{
    NSURL *docURL = nil;
	if (isUser) {
		docURL = [[CoredataManager defaultInstance] getDocumentUrlWithSubDirName:nil];
	}else{
		docURL = [self getURLForDocumentSubDir:nil];
	}
	
	NSURL *fileURL = [docURL URLByAppendingPathComponent:kUserSettingFile];
    if (fileURL == nil) {
        logMsg(@"saveObject(%d-%@) no url, config:%@", isUser, key, [CoredataManager userConfig]);
        return;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:[fileURL path]]) {
        [fileManager createFileAtPath:[fileURL path] contents:nil attributes:nil];
    }
	NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithCapacity:0];
    [dic setDictionary:[[NSDictionary alloc] initWithContentsOfFile:[fileURL path]]];
    dic[key]=obj;
	[dic writeToFile:[fileURL path] atomically:YES];
}

+ (void)setMark:(id)mark forName:(NSString *)name
{
	NSAssert(([mark isKindOfClass:[NSString class]] || [mark isKindOfClass:[NSNumber class]]) && name != nil, nil);
	NSString *markName = [NSString stringWithFormat:@"marksForPlat(%@)", name];
	[EntrysOperateHelper saveObject:mark forKey:markName];
}
+ (id)markForName:(NSString *)name
{
	NSAssert(name != nil, nil);
	NSString *markName = [NSString stringWithFormat:@"marksForPlat(%@)", name];
	return [EntrysOperateHelper objectForKey:markName];
}

+ (NSString *)stringFromDate:(NSDate *)date andFormat:(NSString *)format withTimeZone:(NSTimeZone *)timeZone
{
    NSAssert(!date||[date isKindOfClass:[NSDate class]], nil);
    if (! date) {
        date = [NSDate date];
    }
    if (! format) {
        format = @"yyyyMMdd HH:mm:ss";
    }
    
    NSMutableDictionary *threadDict = [NSThread currentThread].threadDictionary;
    NSMutableDictionary *dateFormatters = nil;
    
    @synchronized(threadDict)
    {
        dateFormatters = threadDict[@"dateFormatters"];
        if(dateFormatters == nil)
        {
            dateFormatters = [NSMutableDictionary dictionary];
            threadDict[@"dateFormatters"] = dateFormatters;
        }
    }
    
    NSDateFormatter *formatter = dateFormatters[format];
    if(formatter == nil) {
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
        formatter.dateFormat = format;
        dateFormatters[format] = formatter;
    }
    
    if(timeZone == nil) {
        timeZone = [NSTimeZone systemTimeZone];
    }
    
    if(formatter.timeZone != timeZone) {
        formatter.timeZone = timeZone;
    }
    
    return [formatter stringFromDate:date];
}

+ (NSString *)stringFromDate:(NSDate *)date andFormat:(NSString *)format
{
    return [self stringFromDate:date andFormat:format withTimeZone:nil];
}

+ (NSString *)stringFromDate:(NSDate *)date andGMT8Format:(NSString *)format
{
    return [self stringFromDate:date andFormat:format withTimeZone:[NSTimeZone timeZoneWithName:@"Asia/Shanghai"]];
}

+ (NSDate *)dateFromString:(NSString *)dateStr withFormatter:(NSString *)format withTimeZone:(NSTimeZone *)timeZone
{
    NSAssert(format, nil);
    
    NSMutableDictionary *threadDict = [NSThread currentThread].threadDictionary;
    NSMutableDictionary *dateFormatters = nil;
    
    @synchronized(threadDict)
    {
        dateFormatters = threadDict[@"dateFormatters"];
        if(dateFormatters == nil)
        {
            dateFormatters = [NSMutableDictionary dictionary];
            threadDict[@"dateFormatters"] = dateFormatters;
        }
    }
    
    NSDateFormatter *formatter = dateFormatters[format];
    if(formatter == nil)
    {
        formatter = [[NSDateFormatter alloc] init];
        formatter.timeZone = [NSTimeZone systemTimeZone];
        
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
        formatter.dateFormat = format;
        dateFormatters[format] = formatter;
    }
    
    if(timeZone == nil) {
        timeZone = [NSTimeZone systemTimeZone];
    }
    
    if(formatter.timeZone != timeZone) {
        formatter.timeZone = timeZone;
    }
    
    NSDate *ret = [formatter dateFromString:dateStr];
    
    /*
     如果结果等于nil，则可能是某些特殊日期的时制切换点导致
     那就将北京时区切换成8时区再做一次转换，可能在特殊日期会产生1h的偏差
     例如 1990-04-15 00:00:00的北京时间是不存在的，直接从1990-04-14 23:59:59跳到1990-04-15 01:00:00
     
     北京时区有下列特殊点：
     1940-06-03
     1941-03-16
     1986-05-04
     1987-04-12
     1988-04-10
     1989-04-16
     1990-04-15
     1991-04-14
     */
    
    if(ret == nil && dateStr.length > 0) {
        NSTimeInterval seconds = timeZone.secondsFromGMT;
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:seconds];
        ret = [formatter dateFromString:dateStr];
    }
    
    return ret;
}

+ (NSDate *)dateFromString:(NSString *)dateStr andGMT8Format:(NSString *)format
{
    return [self dateFromString:dateStr withFormatter:format withTimeZone:[NSTimeZone timeZoneWithName:@"Asia/Shanghai"]];
}

+ (NSDate *)dateFromString:(NSString *)dateStr withFormatter:(NSString *)format
{
    return [self dateFromString:dateStr withFormatter:format withTimeZone:nil];
}

+ (NSData *)dataFromHexFile:(NSString *)path
{
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSAssert(data.length%2 == 0, nil);
    NSMutableData *result = [NSMutableData data];
    const unsigned char *buf = (const unsigned char *)data.bytes;
    unsigned char value = 0;
    for(int i = 0; i < data.length; i++) {
        value = (i%2 == 0)? 0: (value << 4);
        
        unsigned char c = buf[i];
        if(c >= '0' && c <= '9') {
            value += c - '0';
        }else if(c >= 'a' && c <= 'f') {
            value += c - 'a' + 10;
        }else if(c >= 'A' && c <= 'F') {
            value += c - 'A' + 10;
        }else {
            NSAssert(0, nil);
        }
        
        if(i%2) {
            [result appendBytes:&value length:sizeof(value)];
        }
    }
    NSAssert(result.length = data.length/2, nil);
    return result;
}

//  YH  直接转 零时区
+ (NSDate *)dateZeroFromString:(NSString *)dateStr withFormatter:(NSString *)format
{
	NSAssert(dateStr && format, nil);
	
	
	NSDateFormatter *formatter = nil;
	if(formatter == nil)
	{
		formatter = [[NSDateFormatter alloc] init];
		formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
		
		formatter.dateFormat = format;
	}
	
	return [formatter dateFromString:dateStr];
}

+ (id)removeNullFromObj:(id)orgObj hasNull:(BOOL *)hasNull {
    id ret = nil;
    if([orgObj isKindOfClass:[NSNull class]]) {
        ret = nil;
        if(hasNull) {
            *hasNull = YES;
        }
    }else if([orgObj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [orgObj enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            id newObj = [self removeNullFromObj:obj hasNull:hasNull];
            if(newObj) {
                dict[key] = obj;
            }
        }];
        if(dict.count) {
            ret = dict;
        }
    }else if([orgObj isKindOfClass:[NSArray class]]) {
        NSMutableArray *array = [NSMutableArray array];
        [orgObj enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            id newObj = [self removeNullFromObj:obj hasNull:hasNull];
            if(newObj) {
                [array addObject:newObj];
            }
        }];
        if(array.count) {
            ret = array;
        }
    }else if([orgObj isKindOfClass:[NSSet class]]) {
        NSMutableSet *set = [NSMutableSet set];
        [orgObj enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
            id newObj = [self removeNullFromObj:obj hasNull:hasNull];
            if(newObj) {
                [set addObject:newObj];
            }
        }];
        if(set.count) {
            ret = set;
        }
    }else {
        ret = orgObj;
    }
    
    return ret;
}

+ (id)mutableForCollention:(id)obj
{
	if ([obj isKindOfClass:[NSArray class]]) {
		NSMutableArray *result = [NSMutableArray arrayWithCapacity:[obj count]];
		for (id elem in (NSArray *)obj) {
			id newElem = [self mutableForCollention:elem];
			if (newElem) {
				[result addObject:newElem];
			}else{
				return nil;
			}
		}
		return result;
	}else if ([obj isKindOfClass:[NSDictionary class]]) {
		NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[(NSMutableDictionary *)obj count]];
		NSArray *keys = [(NSMutableDictionary *)obj allKeys];
		for (id key in keys) {
			id newKey = [self mutableForCollention:key];
			id newValue = [self mutableForCollention:obj[key]];
			if (newKey && newValue) {
				result[newKey] = newValue;
			}else{
				return nil;
			}
		}
		return result;
	}else if ([obj isKindOfClass:[NSSet class]]) {
		NSMutableSet *result = [NSMutableSet setWithCapacity:[(NSSet *)obj count]];
		for (id elem in (NSSet *)obj) {
			id newElem = [self mutableForCollention:elem];
			if (newElem) {
				[result addObject:newElem];
			}else{
				return nil;
			}
		}
		return result;
	}else{
		return obj;
	}
}

+ (NSURL *)urlByReplaceUrl:(NSURL *)oldURL withNewHost:(NSString *)newHost
{
	NSAssert(oldURL.absoluteString.length > 0, nil);
	NSAssert(newHost.length > 0, nil);

	NSString *oldHost = oldURL.host;
	if (oldHost.length == 0) {
		NSLogToFile(@"Error: old URL<%@> has invalid host", oldURL);
		return oldURL;
	}
	//替换host为IP, 加快速度
	BOOL isFile = [oldURL isFileURL];
	

	NSRange range = [oldURL.absoluteString rangeOfString:oldHost];
	if (range.location != NSNotFound) {
		NSString *newPath = [oldURL.absoluteString stringByReplacingCharactersInRange:range withString:newHost];
		NSAssert(newPath.length > 0, nil);
		NSURL *newURL = [NSURL URLWithString:newPath];
		if (isFile) {
			newURL = [NSURL fileURLWithPath:newPath];
		}
		return newURL;
	}else{
		return oldURL;
	}
}

+ (NSString *)pathWithIMAttachment
{
    return [NSTemporaryDirectory() stringByAppendingPathComponent:IMATTACHMENT_PATH];
}
+ (NSURL *)getURLForTmpCache
{
	static NSURL *rootCacheURL = nil;
	//1. 获取系统Cache目录
	if (! rootCacheURL) {
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *urls = [fileManager URLsForDirectory:NSCachesDirectory
											inDomains:NSUserDomainMask];
		if ([urls count] == 0) {
			NSLogToFile(@"Error: Failed to get system url");
			return nil;
		}
		rootCacheURL = [urls[0] URLByAppendingPathComponent:kCacheRootDir];
		// touch
		NSURL *tmpURL = [rootCacheURL URLByAppendingPathComponent:@"test.log"];
		[EntrysOperateHelper touchDirForFilePath:tmpURL.path];
	}
	return rootCacheURL;
}

+ (NSURL *)getURLForTmpFileUse:(NSString *)fileName isDir:(BOOL)isDir
{
	NSURL *rootCacheURL = [self getURLForTmpCache];
	if (! fileName) {
		fileName = [EntrysOperateHelper stringFromDate:nil andFormat:@"HHmmssSSS"];
	}
	NSURL *aimURL = [rootCacheURL URLByAppendingPathComponent:fileName];
	NSURL *touchURL = aimURL;
	if (isDir) {
		touchURL = [touchURL URLByAppendingPathComponent:@"test.log"];
		[EntrysOperateHelper touchDirForFilePath:touchURL.path];
	}
	return aimURL;
}

+ (NSURL *)getURLForDocumentSubDir:(NSString *)subDir
{
	static NSURL *url = nil;
	if (url) {
		if (subDir) {
			NSURL *result = [url URLByAppendingPathComponent:subDir];
			NSURL *resultTmp = [result URLByAppendingPathComponent:@"test.log"];
			[EntrysOperateHelper touchDirForFilePath:resultTmp.path];
			return result;
		}
		return url;
	}
	NSAssert([subDir isKindOfClass:[NSString class]] || ! subDir, nil);
	//1. 获取系统目录
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *urls = [fileManager URLsForDirectory:NSDocumentDirectory
										inDomains:NSUserDomainMask];
	if ([urls count] == 0) {
		NSLogToFile(@"Error: Failed to get system url");
		return nil;
	}
	NSURL *folderUrl = urls[0];
	if (subDir.length > 0) {
		folderUrl = [folderUrl URLByAppendingPathComponent:subDir];
	}
	
	//2. 创建路径
	NSURL *tmpURL = [folderUrl URLByAppendingPathComponent:@"test.log"];
	NSError *err = [EntrysOperateHelper touchDirForFilePath:tmpURL.path];
	if (err) {
		NSLogToFile(@"Error: create user document failed:%@", err);
		return nil;
	}
	url = folderUrl;
	NSLog(@"Tips: Document Dir:%@", url);
	return folderUrl;
}

#pragma mark - helps for ui translate

+ (MOACallback)switchCompletionHandleWithMainThread:(MOACallback)callback
{
	if ([NSThread isMainThread] && callback) {
		callback = ^(id result){
			NSManagedObjectID *resultID = [CoredataManager objectIDWithObject:result];
			dispatch_async(dispatch_get_main_queue(), ^{
				id newResult = [CoredataManager objectWithObjectID:resultID];
				callback(newResult);
			});
		};
	}
	return callback;
};
+ (NSDictionary *)messageDictFromUIArg:(NSDictionary *)orgDict
{
	NSAssert([orgDict isKindOfClass:[NSDictionary class]], nil);
	
	/*
	 @{@"name":@"icon.jpg",
	 @"image":NSData,
	 @"key":NSString
	 };
	 
	 @"name":NSString,
	 @"value": NSString,
	 @"size":NSNumber,
	 @"type": NSNumber,
	 @"typeInfo":NSString
	 */
	NSAssert([orgDict[@"name"] isKindOfClass:[NSString class]], nil);
	NSAssert([orgDict[@"image"] isKindOfClass:[NSData class]], nil);
	NSAssert([orgDict[@"key"] isKindOfClass:[NSDictionary class]], nil);
	NSString *key = orgDict[@"key"][@"sha1"];
	NSAssert([key isKindOfClass:[NSString class]], nil);
	NSAssert([orgDict[@"key"][@"size"] isKindOfClass:[NSNumber class]], nil);
	
	//保存文件
	NSString *filepath = [CoredataManager saveNSData:orgDict[@"image"]
										withFileName:key
										 intoUserDir:kFilesDir];
	NSAssert(filepath, nil);
	
	NSMutableDictionary *picDict = [NSMutableDictionary dictionaryWithDictionary:@{kFileKeyForJson:key,
																				   @"size":orgDict[@"key"][@"size"],
																				   }];
	if (orgDict[@"width"]) {
		NSAssert([orgDict[@"width"] isKindOfClass:[NSNumber class]], nil);
		picDict[@"width"] = orgDict[@"width"];
	}
	if (orgDict[@"height"]) {
		NSAssert([orgDict[@"height"] isKindOfClass:[NSNumber class]], nil);
		picDict[@"height"] = orgDict[@"height"];
	}
	picDict[@"size"] = orgDict[@"key"][@"size"];
	return @{@"name":orgDict[@"name"],
			 @"size":orgDict[@"key"][@"size"],
			 @"type":@(kFileDBSaveTypeQiniu),
			 @"typeInfo":@"picture",
			 @"value":[EntrysOperateHelper jsonStringFromNSObject:picDict],
			 };
	
}


#pragma mark - image get

+ (BOOL)getIconImage:(UIImage **)image forObject:(NSManagedObject *)object withOption:(NSString *)option andCallback:(MOACallback)callback
{
	NSAssert([object isKindOfClass:[MOAPerson class]] || [object isKindOfClass:[MOAGroup class]], nil);
	
	NSAssert(image != nil, nil);
	*image = nil;
	MOAMessage *icon = [(MOAPerson *)object icon];
	NSDictionary *imageDict = [EntrysOperateHelper dictFromJsonString:icon.value];
	NSString *key = imageDict[kFileKeyForJson];
	NSString *lastKey = imageDict[kLastFileKeyForJson];
//	NSArray *keys = [EntrysOperateHelper searchJson:icon.value forKey:kFileKeyForJson];
//	NSAssert(keys.count <= 1, nil);
	if (key.length == 0) {
		return YES;
	}
	BOOL isExist = [CoredataManager isFileExistForKey:key andOption:option];
	if (isExist) {
		NSString *filePath = [CoredataManager filePathWithKey:key andOption:option];
		*image = [UIImage imageWithContentsOfFile:filePath];
	}else{
		//查询是否有旧的头像
		if (lastKey.length != 0) {
			NSString *filePath = [CoredataManager filePathWithKey:lastKey andOption:option];
			*image = [UIImage imageWithContentsOfFile:filePath];
		}
		//下载
		id userInfo = nil;
		if (option) {
			userInfo = @{@"info":[MOAModelManager getAnNewFIleOperateUserInfo],
						 @"option":option};
		}
		[CoredataManager downloadFileFromServerWithKey:key
										   andUserInfo:&userInfo
								   andProgressCallback:^(id result) {
									   if ([result isKindOfClass:[NSNumber class]]) {
										   //NSLog(@"Tips: down image process:%@", result);
										   return ;
									   }
									   if (! [result isKindOfClass:[NSError class]]) {
										   //读出并传回
										   BOOL isExist = [CoredataManager isFileExistForKey:key andOption:option];
										   if (isExist) {
											   NSString *filePath = [CoredataManager filePathWithKey:key andOption:option];
											   result = [UIImage imageWithContentsOfFile:filePath];
										   }
									   }
									   
									   if (callback) {
										   callback(result);
									   }
									   return ;
								   }];
		return NO;
	}
	return YES;
}
/**
 *	检测文件的类型
 *
 *	@param filePath filePath description
 *
 *	@return return value description
 */
/*
 @"unknwon"		//未识别
 @"directory"	//目录
 @"blank"		//空文件
 @"image/png.jpg.jpg2.bmp.gif.tif.tif2"
 */

+ (NSString *)mimeForExtension:(NSString *)extension {
    NSString *defaultType = @"text/*";
    if(extension == nil) {
        return defaultType;
    }
    
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"mime" ofType:@"plist"];
        map = [NSDictionary dictionaryWithContentsOfFile:path];
    });
    
    NSAssertRet(defaultType, map.count, nil);
    
    NSString *mime = map[extension];
    if(mime == nil) {
        NSLogToFile(@"Warn: unknown mime type for extenion(%@)", extension);
    }
    
    return mime? mime: defaultType;
}

+ (NSString *)fileTypeForFile:(NSString *)filePath
{
	BOOL isDirectory = NO;
	BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
	if(!isExist || isDirectory) {
        return [self mimeForExtension:nil];
	}
    
	NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    if(!fileHandle) {
        return [self mimeForExtension:nil];
	}
	
	NSData *data = [fileHandle readDataOfLength:100];
    NSString *guessExtenion = [self probeFileExtension:data];
    if(guessExtenion == nil) {
        guessExtenion = filePath.pathExtension;
        NSLogToFile(@"Warn: can't guess file extension (%@)\n%@", filePath.lastPathComponent, data);
    }
    
    return [self mimeForExtension:guessExtenion];
}

+ (NSString *)probeFileExtension:(NSData *)data
{
    if(data.length == 0) {
        return nil;
    }
    
    static NSArray *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @[
                @{@"data": @"62706C6973743030D4", @"ext": @"archiver"},
                @{@"data": @"62706C6973743030DF", @"ext": @"plist"},
                @{@"data": @"3C21444F435459504520706C69737420", @"ext": @"plist", @"skip": @(0x27*2)},
  
                @{@"data": @"FFD8FF", @"ext": @"jpeg"},
                
                @{@"data": @"89504E47", @"ext": @"png"},
                @{@"data": @"47494638", @"ext": @"gif"},
                @{@"data": @"424D", @"ext": @"bmp"},
                
                @{@"data": @"667479707174", @"ext": @"mov", @"skip": @8},
                @{@"data": @"667479706D7034", @"ext": @"mp4", @"skip": @8},
                @{@"data": @"6674797069736F6D", @"ext": @"mp4", @"skip": @8},
                @{@"data": @"6674797033677035", @"ext": @"mp4", @"skip": @8},
                @{@"data": @"667479704D534E56", @"ext": @"mp4", @"skip": @8},
                @{@"data": @"667479706D703432", @"ext": @"m4v", @"skip": @8},
                @{@"data": @"667479704D3456", @"ext": @"m4v", @"skip": @8},
                @{@"data": @"000001BA", @"ext": @"mpv"},
                @{@"data": @"66747970336770", @"ext": @"3gp", @"skip": @8},
                @{@"data": @"6D6F6F76", @"ext": @"mov"},
                @{@"data": @"41564920", @"ext": @"avi", @"skip": @16},
                @{@"data": @"415649204C495354", @"ext": @"avi", @"skip": @16},
                @{@"data": @"2E524D46", @"ext": @"rmvb"},
                @{@"data": @"2E524D46", @"ext": @"rm"},
                @{@"data": @"3026B2758E66CF11", @"ext": @"asf"},
                @{@"data": @"3026B2758E66CF11", @"ext": @"asf"},
                @{@"data": @"3026B2758E66CF11", @"ext": @"wmv"},
                @{@"data": @"1A45DFA3", @"ext": @"mkv"},
                @{@"data": @"41564920", @"ext": @"avi", @"skip": @16},
                @{@"data": @"000001Bx", @"ext": @"mpg"},
                @{@"data": @"000001BA", @"ext": @"mpg"},
                @{@"data": @"6674797071742020", @"ext": @"mov",@"skip": @8},
                @{@"data": @"6D6F6F76", @"ext": @"mov",@"skip": @8},
                @{@"data": @"000001BA", @"ext": @"vob"},
                @{@"data": @"464C5601", @"ext": @"flv"},
                @{@"data": @"435753", @"ext": @"swf"},
                @{@"data": @"5A5753", @"ext": @"swf"},
                @{@"data": @"465753", @"ext": @"swf"},
                
                @{@"data": @"494433", @"ext": @"mp3"},
                @{@"data": @"FFEx", @"ext": @"mp3"},
                @{@"data": @"FFFx", @"ext": @"mp3"},
                
                @{@"data": @"3026B2758E66CF11", @"ext": @"wma"},
                @{@"data": @"57415645666D7420", @"ext": @"wav",@"skip": @16},
                @{@"data": @"4D546864", @"ext": @"midi"},
                @{@"data": @"4F67675300020000", @"ext": @"ogg"},
                @{@"data": @"664C614300000022", @"ext": @"flac"},
                @{@"data": @"FFF1", @"ext": @"aac"},
                @{@"data": @"FFF9", @"ext": @"aac"},
                @{@"data": @"4D414320960F000034", @"ext": @"ape"},
                @{@"data": @"2321414D52", @"ext": @"amr"},
                @{@"data": @"667479704D344120", @"ext": @"m4a",@"skip": @8},
                
                @{@"data": @"3C3F786D6C", @"ext": @"xml"},
                @{@"data": @"68746D6C3E", @"ext": @"html"},
                @{@"data": @"44656C69766572792D646174653A", @"ext": @"eml"},
                
                @{@"data": @"25504446", @"ext": @"pdf"},
                @{@"data": @"504B0304", @"ext": @"zip"},
                @{@"data": @"52617221", @"ext": @"rar"},
                @{@"data": @"2E524D46", @"ext": @"rm"},
                
                @{@"data": @"41433130", @"ext": @"tif"},
                @{@"data": @"49492A00", @"ext": @"dwg"},
                @{@"data": @"38425053", @"ext": @"psd"},
                @{@"data": @"7B5C727466", @"ext": @"rtf"},
                
                @{@"data": @"5374616E64617264204A", @"ext": @"mdb"},
                @{@"data": @"CFAD12FEC5FD746F", @"ext": @"dbx"},        //没有mime
                @{@"data": @"2142444E", @"ext": @"pst"},                //没有mime
                @{@"data": @"252150532D41646F6265", @"ext": @"eps"},    //没有mime
                @{@"data": @"AC9EBD8F", @"ext": @"qdf"},  //没有mime
                @{@"data": @"E3828596", @"ext": @"pwl"},  //没有mime
                @{@"data": @"2E7261FD", @"ext": @"ram"},
                
                @{@"data": @"4D546864", @"ext": @"mid"},
                
                
                @{@"data": @"D0CF11E0A1B11AE1", @"ext": @"doc"},
                @{@"data": @"0D444F43", @"ext": @"doc"},
                @{@"data": @"CF11E0A1B11AE100", @"ext": @"doc"},
                @{@"data": @"DBA52D00", @"ext": @"doc"},
                @{@"data": @"ECA5C100", @"ext": @"doc"},
                @{@"data": @"504B0304140006", @"ext": @"docx"},
                @{@"data": @"504B0304", @"ext": @"docx"},
                @{@"data": @"D0CF11E0A1B11AE1", @"ext": @"wps"},
                @{@"data": @"7B5C72746631", @"ext": @"rtf"},
                @{@"data": @"504B0304", @"ext": @"pages"},
                @{@"data": @"D0CF11E0A1B11AE1", @"ext": @"xls"},
                @{@"data": @"0908100000060500", @"ext": @"xls"},
                @{@"data": @"FDFFFFFF10", @"ext": @"xls"},
                @{@"data": @"FDFFFFFF1F", @"ext": @"xls"},
                @{@"data": @"FDFFFFFF22", @"ext": @"xls"},
                @{@"data": @"FDFFFFFF23", @"ext": @"xls"},
                @{@"data": @"FDFFFFFF28", @"ext": @"xls"},
                @{@"data": @"FDFFFFFF29", @"ext": @"xls"},
                @{@"data": @"504B0304", @"ext": @"xlsx"},
                @{@"data": @"504B030414000600", @"ext": @"xlsx"},
                @{@"data": @"006E1EF0", @"ext": @"ppt"},
                @{@"data": @"0F00E803", @"ext": @"ppt"},
                @{@"data": @"A0461DF0", @"ext": @"ppt"},
                @{@"data": @"FDFFFFFF0E000000", @"ext": @"ppt"},
                @{@"data": @"FDFFFFFF1C000000", @"ext": @"ppt"},
                @{@"data": @"FDFFFFFF43000000", @"ext": @"ppt"},
                @{@"data": @"504B0304", @"ext": @"pptx"},
                @{@"data": @"504B030414000600", @"ext": @"pptx"},
                @{@"data": @"D0CF11E0A1B11AE1", @"ext": @"pps"},
                @{@"data": @"504B0304140006", @"ext": @"ppsx"},
                ];
    });
    
    NSString *hexString = [EntrysOperateHelper HexStringFromBytes:data.bytes andLength:data.length];
    
    NSString *result = nil;
    for(NSDictionary *d in map) {
        NSInteger skip = [d[@"skip"] integerValue];
        NSString *s = hexString;
        if(skip) {
            if(data.length < skip) {
                continue;
            }
            s = [hexString substringFromIndex:skip];
        }
        if([s hasPrefix:d[@"data"]]) {
            result = d[@"ext"];
            break;
        }
    }
    
    return result;
}

+ (BOOL) isVideoOfFilePath:(NSString *)filePath
{
    NSString *fileType = [self fileTypeForFile:filePath];
    if ([[fileType lowercaseString] hasPrefix:@"video"]) {
        return YES;
    }else{
        return NO;
    }
}

+ (BOOL)isGifOfFilePath:(NSString *)filePath
{
	NSString *fileType = [self fileTypeForFile:filePath];
	if ([fileType isEqualToString:@"image/gif"]) {
		return YES;
	}else{
		return NO;
	}
}

+ (NSArray *)arrayFromObjs:(id)objs
{
	if ([objs isKindOfClass:[NSArray class]]) {
		return objs;
	}else if ([objs isKindOfClass:[NSSet class]]) {
		return [(NSSet *)objs allObjects];
	}else{
		return [NSArray arrayWithObject:objs];
	}
}
+ (NSSet *)setFromObjs:(id)objs
{
	if ([objs isKindOfClass:[NSSet class]]) {
		return objs;
	}else if ([objs isKindOfClass:[NSArray class]]) {
		return [NSSet setWithArray:objs];
	}else{
		return [NSSet setWithObject:objs];
	}
}


+ (NSInteger)bitCount:(NSInteger)n
{
	NSInteger c = 0;
	for (;n; ++c) {
		n &= (n-1);//清除最低位
	}
	return c;
}

#pragma mark - ui helps

+ (NSArray *)currentViewControllers
{
	AppDelegate *shareDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    
    id controller = shareDelegate.rootViewController;
   
    if (shareDelegate.rootViewController.presentedViewController){
        controller = shareDelegate.rootViewController.presentedViewController;
    } else if (shareDelegate.rootViewController.presentingViewController){
        controller = shareDelegate.rootViewController.presentingViewController;
    } else if (shareDelegate.rootViewController.viewControllers.count > 0) {
        controller = shareDelegate.rootViewController;
    }
    
	NSArray *viewControls = nil;
	
    if([controller isKindOfClass:[UITabBarController class]]) {
        controller = ((UITabBarController *)controller).selectedViewController;
        if([controller navigationController].viewControllers.count > 1) {
            viewControls = [controller navigationController].viewControllers;
        } else {
            viewControls = @[controller];
        }
    } else if ([controller isKindOfClass:[UINavigationController class]]) {
        viewControls = ((UINavigationController *)controller).viewControllers;
    } else {
		if (controller) {
			viewControls = @[controller];
		}else{
			viewControls = @[];
		}
    }
	return viewControls;
}

+ (NSString *)cutString:(NSString *)orgString intoBytesCount:(NSInteger)count andFillWithZero:(BOOL)fill
{
	if (! orgString) {
		orgString = @"";
	}
	// 1. 裁剪
	if (orgString.length > count) {
		orgString = [orgString substringToIndex:count];
	}
	for (;;) {
		if ([orgString lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > count) {
			orgString = [orgString substringToIndex:orgString.length - 1];
		}else{
			break;
		}
	}
	// 2. 填充
	NSAssert([orgString lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <= count, nil);
	if (fill) {
		NSInteger fillSize = count - [orgString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
		if (fillSize > 0) {
			char *buff = (char *)malloc(fillSize + 1);
			memset(buff, '0', fillSize);
			buff[fillSize] = '\0';
			orgString = [orgString stringByAppendingString:[NSString stringWithUTF8String:buff]];
			free(buff);
		}
	}
	return orgString;
}

+ (void)deleteCacheFilesBeforeDate:(NSDate *)date
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		NSURL *cacheDir = [EntrysOperateHelper getURLForTmpCache];
		[EntrysOperateHelper deleteFilesAtPath:cacheDir.path beforeUnaccessDate:date];
	});
}

+ (NSInteger)deleteFilesAtPath:(NSString *)path beforeUnaccessDate:(NSDate *)unaccessDate
{
	NSAssert(unaccessDate && path, nil);
	NSFileManager *fileManager = [[NSFileManager alloc] init];
	
	BOOL isDir = NO;
	BOOL isExist = [fileManager fileExistsAtPath:path isDirectory:&isDir];
	if (isExist) {
		if (! isDir) {
			// todo
			return 0;
		}else{
			// 1. 查找文件夹下所有的文件
			NSURL *fileDir = [NSURL URLWithString:path];
			if (! fileDir) {
				return 0;
			}
			NSArray *fileKeys = @[NSURLIsDirectoryKey,
								  NSURLPathKey,
								  NSURLFileSizeKey,
								  NSURLCreationDateKey,
								  NSURLContentAccessDateKey,
								  ];
			NSDirectoryEnumerator *dirEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:fileDir
																		includingPropertiesForKeys:fileKeys
																						   options:NSDirectoryEnumerationSkipsHiddenFiles |  NSDirectoryEnumerationSkipsPackageDescendants
																					  errorHandler:nil];
			
			// An array to store the all the enumerated file names in
			NSMutableArray *oprFiles = [NSMutableArray array];
			
			// Enumerate the dirEnumerator results, each value is stored in allURLs
			for (NSURL *theURL in dirEnumerator) {
				
				// 1. 文件类型
				NSNumber *isDir = nil;
				if ([theURL getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL] == NO){
					continue;
				}
				if ([isDir boolValue]) {
					//continue;
				}
				
				NSDate *lastAccessDate = nil;
				if ([theURL getResourceValue:&lastAccessDate forKey:NSURLContentAccessDateKey error:NULL] == NO){
					[theURL getResourceValue:&lastAccessDate forKey:NSURLCreationDateKey error:NULL];
				}
				NSAssert(lastAccessDate, nil);
				if ([unaccessDate compare:lastAccessDate] == NSOrderedAscending) {
					continue;
				}
				
				// Retrieve the file name. From NSURLNameKey, cached during the enumeration.
				NSString *filePath = nil;
				if ([theURL getResourceValue:&filePath forKey:NSURLPathKey error:NULL] == NO){
					continue;
				}
				NSAssert(filePath, nil);
				
				NSNumber *fileSize = nil;
				if ([theURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL] == NO){
					continue;
				}
				[oprFiles addObject:@{@"filePath":filePath,
									  @"fileSize":fileSize?fileSize:@0,
									  @"lastAccessDate":lastAccessDate}];
			}
			
			NSInteger totolSize = 0;
			for (NSDictionary *elemDict in oprFiles) {
				[EntrysOperateHelper deleteFileWithAbsolutePath:elemDict[@"filePath"]];
				totolSize += [elemDict[@"fileSize"] integerValue];
				NSLog(@"Tips: to del: %@", elemDict);
			}
			
			return totolSize;
		}
	}else {
		return 0;
	}
}

+ (void)prepareUpLoadLogFileFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate
{
    @try {
        toDate = [toDate dateByAddingTimeInterval:1.0];
        [self prepareUpLoadLogFileFromDateEx:fromDate toDate:toDate];
    }
    @catch (NSException *exception) {
        ;
    }
    @finally {
        ;
    }
}

+ (void)prepareUpLoadLogFileFromDateEx:(NSDate *)fromDate toDate:(NSDate *)toDate
{
    const static int maxReadSize = 512*1024;
    const static int limitSize = 128*1024;
    
    NSURL *filePath = [[EntrysOperateHelper getURLForDocumentSubDir:nil] URLByAppendingPathComponent:@"log/appEventsLog.txt"];
    NSFileManager *manager = [[NSFileManager alloc] init];
    BOOL isDir = NO;
    if([manager fileExistsAtPath:filePath.path isDirectory:&isDir] == NO || isDir == YES)
    {
        NSLogToFile(@"Bug: %s", __func__);
        return;
    }
    
    //拷贝日志到临时目录
    NSString *fileName = [NSString stringWithFormat:@"appEventsLog_%@_%@.txt", [EntrysOperateHelper stringFromDate:toDate andFormat:@"yyyyMMdd_HHmmss"], [CoredataManager getUserName]];
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    [manager removeItemAtPath:tmpPath error:nil];
    if([manager copyItemAtPath:filePath.path toPath:tmpPath error:nil] == NO)
    {
        NSLogToFile(@"Bug: %s", __func__);
        return;
    }
    
    //解析文件
    NSData *writeData = nil;
    NSString *fromDateStr = [EntrysOperateHelper stringFromDate:fromDate andFormat:@"yyyyMMdd HH:mm:ss"];
    NSString *toDateStr = [EntrysOperateHelper stringFromDate:toDate andFormat:@"yyyyMMdd HH:mm:ss"];
    NSFileHandle *fileHandle  = [NSFileHandle fileHandleForUpdatingAtPath:tmpPath];
    if(fileHandle)
    {
        uint64_t fileSize = [fileHandle seekToEndOfFile];
        if(fileSize > maxReadSize)
        {
            [fileHandle seekToFileOffset:fileSize - maxReadSize];
        }
        else
        {
            [fileHandle seekToFileOffset:0];
        }
        NSData *fileData = [fileHandle readDataToEndOfFile];
        NSString *fileStr = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
        if(fileStr.length > 0)
        {
            NSArray *lineArray = [fileStr componentsSeparatedByString:@"\n"];
            if(lineArray.count > 0)
            {
                NSString *userName = [[MOAModelManager defaultInstance] getUserName];
                NSString *predicateStr = [NSString stringWithFormat:@"(SELF LIKE[cd] '[*-*][*]*') AND (SELF >= '[%@-%@]') AND ((SELF <= '[%@-%@]'))", userName, fromDateStr, userName, toDateStr];
                NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateStr];
                NSArray *filterArray = [lineArray filteredArrayUsingPredicate:predicate];
                if(filterArray.count)
                {
                    int firstIndex = [lineArray indexOfObject:filterArray.firstObject];
                    int lastIndex = [lineArray indexOfObject:filterArray.lastObject];
                    if(firstIndex >= 0 && lastIndex >= 0 && firstIndex < lastIndex)
                    {
                        NSArray *writeArray = [lineArray subarrayWithRange:NSMakeRange(firstIndex, lastIndex-firstIndex+1)];
                        if(writeArray.count > 0)
                        {
                            NSString *writeStr = [writeArray componentsJoinedByString:@"\r\n"];
                            writeData = [writeStr dataUsingEncoding:NSUTF8StringEncoding];
                            if(writeData.length > limitSize)
                            {
                                writeData = [writeData subdataWithRange:NSMakeRange(writeData.length-limitSize, limitSize)];
                            }
                            
                            NSString *baseInfoStr = [NSString stringWithFormat:@"Platform:%@ %@\r\nAppVersion:%@%@%@ Build-%@\r\n\r\n", [EntrysOperateHelper deviceType], [UIDevice currentDevice].systemVersion, kCurrentVersion, kFlagDebug?@" (Debug)":@"", kFlagBranche?@" (Branche)":@"", [MOAModelManager getSVN]];
                            
                            NSMutableData *data = [NSMutableData dataWithData:[baseInfoStr dataUsingEncoding:NSUTF8StringEncoding]];
                            [data appendData:writeData];
                            writeData = data;
                            
                            NSLogToFile(@"Info: write wa exception reason log size:%zd", writeData.length);
                        }
                    }
                }
            }
        }
    }
    
    [fileHandle closeFile];
    
    if(writeData)
    {
        //拷贝至上传目录，删除临时文件
        NSURL *uploadFolder = [EntrysOperateHelper getURLForDocumentSubDir:kPATH_CRASH_LOG];
        NSString *zipName = [[fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"zip"];
        NSURL *uploadUrl = [uploadFolder URLByAppendingPathComponent:zipName];
        [manager removeItemAtURL:uploadUrl error:nil];
        writeData = [MOAZipArchive zipData:writeData withFileName:fileName];
        BOOL ret = [writeData writeToURL:uploadUrl atomically:YES];
        NSLogToFile(@"Info: write wa exception reason log(%d)\n%@", ret, uploadUrl);
    }
    
    [manager removeItemAtPath:tmpPath error:nil];
}

#define USER_APP_PATH                 @"/Applications/"
+ (BOOL)isJailBreak
{
//	if ([[NSFileManager defaultManager] fileExistsAtPath:USER_APP_PATH]) {
//		NSLog(@"The device is jail broken!");
//		NSArray *applist = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:USER_APP_PATH error:nil];
//		NSLog(@"applist = %@", applist);
//		return YES;
//	}
//	NSLog(@"The device is NOT jail broken!");
//	return NO;
	
	
	NSString *filePath = @"/Applications/Cydia.app";
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
	{
		NSLogToFile(@"jail broken");
		return YES;
	}
	
	return NO;

}

+ (NSString *)bundleIdentifier
{
	NSString *result = [[NSBundle mainBundle] infoDictionary][@"CFBundleIdentifier"];
	if (! result) {
		result = @"";
	}
	return result;
}

+ (uint64_t)deviceFreeSpace {
    struct statfs buf;
    unsigned long long freeSpace = -1;
    if(statfs("/var", &buf) >= 0) {
        freeSpace = (unsigned long long)(buf.f_bsize * buf.f_bavail);
    }
    NSLogToFile(@"Info: device free space %0.3f GB", (freeSpace/1024/1024)/1024.0);
    return freeSpace;
}

+ (NSDictionary *)getDeviceInfo
{
    NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    if (![idfa isKindOfClass:[NSString class]]) {
        idfa = @"";
    }
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:@{@"JailBreak":@([EntrysOperateHelper isJailBreak]||[MobClick isJailbroken]),// 1. 是否越狱
                                                                                @"BundleID":[EntrysOperateHelper bundleIdentifier],//
                                                                                @"Bit":@(sizeof(void*) * 8),// 设备位数
                                                                                @"OS":[[UIDevice currentDevice] systemVersion],// 系统版本
                                                                                @"Plat":[EntrysOperateHelper deviceType],//设备平台
                                                                                @"appVer": kShowedAboutVersion,
                                                                                @"idfa":idfa
                                                                                }];
    if(ISIOS7)
    {
        info[@"Bg"] = @([UIApplication sharedApplication].backgroundRefreshStatus);   //后台权限
    }
    
    return info;
}


+ (NSDictionary *)getReimburseLocalImage{
	static NSDictionary *localImageDic;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSString *addressPath = [[NSBundle mainBundle] pathForResource:@"consumeTypeImages" ofType:@"plist"];
		localImageDic = [[NSDictionary alloc]initWithContentsOfFile:addressPath];
	});
	return localImageDic;
}

+ (NSString *)classContentDescription:(NSString *)clsName {
    Class cls = NSClassFromString(clsName);
    if(cls == NULL) {
        return nil;
    }
    
    unsigned int propertyCount = 0, ivarCount = 0, methodCount = 0;
    
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    Class parentCls = class_getSuperclass(cls);
    
    printf("%s property(%d) ivar(%d) method(%d) super(%s)\n", clsName.UTF8String, propertyCount, ivarCount, methodCount, NSStringFromClass(parentCls).UTF8String);
    
    if(propertyCount > 0) {
        for(int i = 0; i < propertyCount; i++) {
            printf("\t%d、property %s\n", i, property_getName(properties[i]));
        }
    }
    
    if(ivarCount > 0) {
        for(int i = 0; i < ivarCount; i++) {
            printf("\t%d、ivar %s\n", i, ivar_getName(ivars[i]));
        }
    }
    
    if(methodCount > 0) {
        for(int i = 0; i < methodCount; i++) {
            printf("\t%d、method %s\n", i, [NSStringFromSelector(method_getName(methods[i])) UTF8String]);
        }
    }

    return nil;
}

@end
