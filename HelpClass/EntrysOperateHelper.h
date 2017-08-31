//
//  EntrysOperateHelper.h
//  MOA
//
//  Created by neo on 13-8-17.
//  Copyright (c) 2013年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>

#define valueFunction(retType, fromValue, key, isjson)  valueKeyFunction(retType, fromValue, key, key, isjson)
#define valueKeyFunction(retType, fromValue, key, name, isjson) \
- (retType *)name { \
    return [EntrysOperateHelper valueForKey:@#key expectClass:[retType class] convertToJson:isjson fromDict:fromValue]; \
}

#define dateFunction(fromValue, key) dateKeyFunction(fromValue, key, key)
#define dateKeyFunction(fromValue, key, name) \
- (NSDate *)name { \
    id value = [EntrysOperateHelper valueForKey:@#key expectClass:[NSNumber class] convertToJson:NO fromDict:fromValue]; \
    if(value) { \
        NSDate *ret = [EntrysOperateHelper dateGMTFromServerTime:[value longLongValue]]; \
        return ret; \
    } \
    return nil; \
}

@interface EntrysOperateHelper : NSObject
/*对比新的成员 到 以 uniqueKey为唯一属性 的 NSSet 中,
 返回值: @{
	@"del":NSSet -> 需要先删除的集合
	@"add":NSSet -> 需要添加的集合
 }
 */
+ (NSDictionary *)compareAndReturnItemsToDelWithNewMembers:(id)newMember
												withOldSet:(NSSet *)oldSet
											   inUniqueKey:(NSString *)uniqueKey;

+ (BOOL)setValue:(id)value forKey:(NSString *)key atObj:(id)obj;
+ (id)tryToGetValueForKey:(NSString *)key atObj:(id)obj;
+ (id)getValueForKey:(NSString *)key atObj:(id)obj error:(NSError **)error;
+ (id)getValueForKey:(NSString *)key atObj:(id)obj;
+ (id)valueForKey:(NSString *)key expectClass:(Class)cls convertToJson:(BOOL)convert fromDict:(NSDictionary *)dict;

+ (NSString *)descriptionForManagerObject:(NSManagedObject *)obj exceptKeys:(NSArray *)exceptKeys;

//辅助API, 在扩展集中查找 拥有 唯一键值 key:keyvalue 的元素, nil=未找到
+ (id)getObjFromExtendSet:(NSSet *)set
			withUniqueKey:(NSString *)key
			  andKeyValue:(NSString *)keyValue;
//进一步封装, 因为大部分扩展属性都是 以 name 属性来确定唯一性的
+ (id)getObjFromExtendSet:(NSSet *)set
	  withUniqueNameValue:(NSString *)nameValue;


+ (NSArray *)getObjsFromExtendSet:(NSSet *)set
            withUniqueNameValue:(NSString *)nameValue;
+ (NSArray *)getObjsFromExtendSet:(NSSet *)set
                  withUniqueKey:(NSString *)key
                    andKeyValue:(NSString *)keyValue;

/**
 *	获取服务器时间
 *
 *	@return date
 */
+ (NSDate *)serverDate;
/**
 *	将服务器时间转化为本地时间
 *
 *	@param date	本地时间
 *
 *	@return date
 */
+ (NSDate*)localDateFromServerDate:(NSDate*)date;
/**
 *	获取用户的sid
 *
 *	@return sid
 */
+ (NSNumber *)getUserSID;
//删除文件
/**
 *	删除绝对路径下的文件
 *
 *	@param path	绝对路径
 *
 *	@return 删除成功or失败
 */
+ (BOOL)deleteFileWithAbsolutePath:(NSString *)path;
/**
 *	删除用户路径下的文件
 *
 *	@param path	用户路径
 *
 *	@return 删除成功or失败
 */
+ (BOOL)deleteFileWithUserPath:(NSString *)path;

//+ (NSString *)saveNSData:(NSData *)data
//			 intoPath:(NSString *)path;

//UI界面特殊化处理 tableview 时, 针对 section/row 的转化 (自动更新匹配)



////插入新对象, 线程不安全
////指定entryName, 向其内部插入data携带的数据, 插入并返回新插入的对象
//+ (id)insertNewObjIntoEntryName:(NSString *)entryName
//					   withData:(NSDictionary *)data
//		 inManagedObjectContext:(NSManagedObjectContext *)context;
+ (const char *)UTF8String:(id)obj;
+ (NSString *)getNSStringWithUTF8String:(const char *)characters;
+ (NSString *)getNSStringAllowEmptyWithUTF8String:(const char *)characters;

+ (NSMutableDictionary *)fixedDict:(NSDictionary *)orgDict
					  ofKey:(id)key
				  withValue:(id)value;


+ (NSDictionary *)convertNetPinyin:(NSString *)aPinyin;
+ (NSString *)addUpdataFlagString:(NSString *)newString toOldString:(NSString *)oldString;
+ (NSString *)delUpdataFlagString:(NSString *)newString toOldString:(NSString *)oldString;


/**
 *  格林威治时间 转 本地时间
 *
 *  @param dateGMT 格林威治时间
 *
 *  @return 本地时间
 */
+ (NSDate *)localDate:(NSDate *)dateGMT;

+ (NSDate *)dateGMTFromServerTime:(int64_t)timemMicoSeconds;
//+ (int64_t)getGMT1970sFromlocalDate:(NSDate *)dateLocal; -- 弃用
+ (int64_t)serverTimeFromDateGMT:(NSDate *)GMTDate;
/**
 *  在当前时间上增加0.1毫秒
 *
 *  @param orgDate orgDate description
 *
 *  @return return value description
 */
+ (NSDate *)plusOneMilliSecond:(NSDate *)orgDate;
/**
 *	计算 SHA1 ， 并将原始结果结果保存于指定的 uint8数组里
 *
 *	@param obj    obj description
 *	@param digest digest description，  长度 CC_SHA1_DIGEST_LENGTH
 *
 *	@return return value description
 */
+ (BOOL)getSHA1:(id)obj withDigest:(uint8_t *)digest;
/**
 *  读取对象的MD5值string
 *
 *  @param obj 支持对象: NSString(UTF8转码), UIImage, NSData
 *
 *  @return 32位字符
 */
+ (NSString *)getMD5String:(id)obj;
/**
 *	对象（NSString(UTF8转码), UIImage, NSData）的MD5值
 *
 *	@param obj	目标对象 支持对象: NSString(UTF8转码), UIImage, NSData
 *
 *	@return MD5 data
 */
+ (NSData *)getMD5:(id)obj;
/**
 *	 对象（NSString(UTF8转码), UIImage, NSData）转data
 *
 *	@param obj	目标对象 支持对象: NSString(UTF8转码), UIImage, NSData
 *
 *	@return data
 */
+ (NSData *)dataWithObj:(id)obj;
/**
 *  显示提示信息
 *
 *  @param message 提示信息
 */
+ (void)showAlertMsg:(NSString *)message;

+ (CGSize)ResizeSize:(CGSize)orgSize withMaxSize:(CGSize)maxSize;
/**
 *  单位：像素
 *
 *	@param orgSize orgSize description
 *
 *	@return return value description
 */
+ (NSValue *)getThumbSizeWithOrgSize:(NSValue *)orgSize;
/**
 *  亚素平 UIImage 对象, 大于 maxPoint 尺寸会被等比缩放
 *
 *  @param orgImage orgImage description
 *  @param maxPixel maxPixel, 若=0, 则不会缩放
 *
 *  @return {@"orgData":NSData,  "compressData":NSData}=成功, nil=转换失败
 */
+ (NSDictionary *)compressIMImage:(UIImage *)orgImage andDealOrgImage:(BOOL)dealOrg;
/**
 *  亚素平 UIImage 对象, 大于 maxPoint 尺寸会被等比缩放
 *
 *  @param orgImage orgImage description
 *  @param maxPixel maxPixel, 若=0, 则不会缩放
 *
 *  @return {@"orgData":NSData,  "compressData":NSData}=成功, nil=转换失败
 */
+ (NSDictionary *)compressIMImage:(UIImage *)orgImage;
+ (NSDictionary *)compressImage:(UIImage *)orgImage withMaxBytes:(NSInteger)maxBytes toMaxSize:(CGSize)maxSize andMaxPixel:(CGFloat)maxPixel;
/**
 *	按比例缩放图像
 *
 *	@param orgImage orgImage description
 *	@param scale    scale description
 *
 *	@return return value description
 */
+ (UIImage *)resizeImage:(UIImage *)orgImage withScale:(CGFloat)scale;

+ (NSURL *)absoluteURL:(NSString *)relativePath;
+ (void)cancelAllLocalNotifications;

+ (BOOL)isDeletedOfNSmanagedObject:(NSManagedObject *)obj;
/**
 *	转化 OSStatus 为字符串
 *
 *	@param error error description
 *
 *	@return return value description
 */
+ (NSString *)FormatError:(OSStatus)error;
+ (NSDictionary *)compareNewObjs:(id)newObjs withOldSet:(NSSet *)oldSet;
/**
 *	异步请求网络url
 *
 *	@param urlString urlString description
 *	@param seconds   seconds description
 *	@param callback  callback description
 */
+ (void)asyncNetRequestToURL:(NSString *)urlString
				 withTimeout:(NSTimeInterval)seconds
		 andCompletionHandle:(MOACallback)callback;

/**
 *	对象转JSONString
 *
 *	@param obj	目标对象
 *
 *	@return jsonstring
 */
+ (NSString *)jsonStringFromNSObject:(id)obj;
/**
 *	对象转jsondata,若失败则返回nil
 *
 *	@param obj	目标对象
 *
 *	@return jsondata
 */
+ (NSData *)jsonDataFromNSObject:(id)obj;
/**
 *	以json目标去解析字符串， 若不是json, 则直接返回原string
 *
 *	@param jsonString jsonString description
 *
 *	@return return value description
 */
+ (id)objFromString:(NSString *)jsonString;
/**
 *	json字符串转对象，若不是json, 则返回nil
 *
 *	@param jsonString	json字符串
 *
 *	@return id 对象
 */
+ (id)dictFromJsonString:(NSString *)jsonString;
/**
 *	jsondata转对象，若不是json, 则返回nil
 *
 *	@param jsonString	json字符串
 *
 *	@return id 对象
 */
+ (id)dictFromJson:(NSData *)jsonData errorOut:(BOOL)err;
/**
 *	移除字典dictionary中的所有null对象，若空则返回nil
 *
 *	@param dict	目标字典dict
 *
 *	@return dict
 */
+ (NSDictionary *)removeNullKeys:(NSDictionary *)dict;
+ (id)removeNullFromObj:(id)orgObj hasNull:(BOOL *)hasNull;

+ (BOOL)dealAllFilesAtDirPath:(NSString *)dirPath withBlock:(MOACallback)dealBlock;
/**
 *	获取手机型号
 *
 *	@return return value description
 */
+ (NSString *)deviceType;
+ (NSString *)deviceTypeName;
+ (NSString *)deviceTypeNameWithType:(NSString *)deviceType;
/**
 *	根据 maxOrgSize (像素单位) 缩放图片
 *
 *	@param image      image description
 *	@param maxOrgSize 最大像素尺寸
 *	@param isResized  isResized description
 *
 *	@return return value description
 */
+ (UIImage *)resizeUIImage:(UIImage *)image withMaxSize:(CGSize)maxSize andIsResized:(BOOL*)isResized;

+ (NSData *)dataFromHexFile:(NSString *)path;
+ (NSString *)HexStringFromBytes:(const void *)bytes andLength:(NSUInteger)length;
/**
 *	系统大版本号， 如5、6、7
 *
 *	@return return value description
 */
+ (NSInteger)systemVersionNumber;
/**
 *	app版本号
 *
 *	@return app版本号string
 */
+ (NSString *)appSimpleVersion;
/**
 *	系统大版本号， 如5、6、7
 *
 *	@return return value description
 */
+ (NSString *)systemVersion;
+ (NSInteger)clientDeviceType;
+ (NSInteger)clientAppType;

+ (NSDictionary *)partitionString:(NSString *)orgString
					   withString:(NSString *)keyString
				   AndIgnoredCase:(BOOL)ignoreCase;

+ (BOOL)appendCustomData:(id)customDate withName:(NSString *)name;
+ (NSArray *)getCustomDatasWithName:(NSString *)name;

+ (NSArray *)custom:(BOOL)custom getCustomDatasWithName:(NSString *)name;
+ (BOOL)custom:(BOOL)custom appendCustomData:(id)customDate withName:(NSString *)name;

+ (BOOL)removeCustomData:(id)customDate withName:(NSString *)name;
+ (BOOL)custom:(BOOL)custom removeCustomData:(id)customDate withName:(NSString *)name;
/**
 *	根据文件路径创建其父文件夹
 *
 *	@param filePath 带文件名的路径
 *
 *	@return return value description
 */
+ (NSError *)touchDirForFilePath:(NSString *)filePath;
/**
 *	根据指定的 key 进行升降序排列内容后返回数组
 *
 *	@param set set description
 *	@param key key description
 *	@param asc asc description
 *
 *	@return return value description
 */
+ (NSArray *)sortNSSet:(NSSet *)set withKey:(NSString *)key ascending:(BOOL)asc;

/**
 *	遍历查找 obj 对象， 若其dict里的key与所查找的对相匹配了， 则将值整理成数组返回
 *
 *	@param obj obj description  NSSet, NSArray, NSDictionary
 *	@param key key description， 主要是 nsstring
 *
 *	@return return value description  nil=未找到
 */
+ (NSArray *)searchObj:(id)obj forKey:(id)key;
/**
 *	json转obj对象，遍历查找 obj 对象， 若其dict里的key与所查找的对相匹配了， 则将值整理成数组返回
 *
 *	@param json  NSSet, NSArray, NSDictionary
 *	@param key key description， 主要是 nsstring
 *
 *	@return return value description  nil=未找到
 */
+ (NSArray *)searchJson:(NSString *)json forKey:(id)key;

+ (NSString *)getWifiBSSID;
+ (NSDictionary *)fetchSSIDInfo;

/**
 *	从用户目录下取key对应的对象
 *
 *	@param key	key
 *
 *	@return id对象
 */
+ (id)objectForKey:(id)key;
/**
 *	取（用户目录或者系统目录）下key对应下的对象
 *
 *	@param key		key
 *	@param isUser	是否用户目录
 *
 *	@return id对象
 */
+ (id)objectForKey:(id)key isUser:(BOOL)isUser;
/**
 *	将对象save用户目录
 *
 *	@param obj	目标对象
 *	@param key	key
 */
+ (void)saveObject:(id)obj forKey:(NSString *)key;
/**
 *	将对象save用户目录或者系统目录下
 *
 *	@param obj		目标对象
 *	@param key		key
 *	@param isUser	是否用户目录
 */
+ (void)saveObject:(id)obj forKey:(NSString *)key isUser:(BOOL)isUser;

+ (void)setMark:(id)mark forName:(NSString *)name;
+ (id)markForName:(NSString *)name;
/**
 *	系统时区的时间转字符串（默认系统时区）
 *
 *	@param date		时间
 *	@param format	时间格式
 *
 *	@return 时间字符串
 */
+ (NSString *)stringFromDate:(NSDate *)date andFormat:(NSString *)format;
/**
 *	8时区的时间转字符串
 *
 *	@param date		时间
 *	@param format	时间格式
 *
 *	@return 时间字符串
 */
+ (NSString *)stringFromDate:(NSDate *)date andGMT8Format:(NSString *)format;
/**
 *	指定时区的时间转字符串
 *
 *	@param date			时间
 *	@param format		时间格式
 *	@param timeZone		指定时区
 *
 *	@return 字符串
 */
+ (NSString *)stringFromDate:(NSDate *)date andFormat:(NSString *)format withTimeZone:(NSTimeZone *)timeZone;
/**
 *	字符串转系统时区的时间（默认系统时区）
 *
 *	@param dateStr	时间字符串
 *	@param format	时间格式
 *
 *	@return 系统时区的date
 */
+ (NSDate *)dateFromString:(NSString *)dateStr withFormatter:(NSString *)format;
/**
 *	字符串转8时区的时间
 *
 *	@param dateStr	字符串
 *	@param format	时间格式
 *
 *	@return 8时区的时间
 */
+ (NSDate *)dateFromString:(NSString *)dateStr andGMT8Format:(NSString *)format;
/**
 *	字符串转指定时区的时间
 *
 *	@param dateStr	字符传
 *	@param format		时间格式
 *	@param timeZone	指定时区
 *
 *	@return 指定时区的date
 */
+ (NSDate *)dateFromString:(NSString *)dateStr withFormatter:(NSString *)format withTimeZone:(NSTimeZone *)timeZone;
/**
 *	字符串直接转成零时区时间，例：@"08:00" --> 零时区8点
 *
 *	@param dateStr	需要转零时区的字符串
 *	@param format	时间格式
 *
 *	@return 零时区的date
 */
+ (NSDate *)dateZeroFromString:(NSString *)dateStr withFormatter:(NSString *)format;
/**
 *	将集（数组字典集合）对象变成可修改型, 主要用于 从文件读取 对象, 然后改值并写入
 *
 *	@param obj obj description
 *
 *	@return return value description
 */
+ (id)mutableForCollention:(id)obj;

+ (NSURL *)urlByReplaceUrl:(NSURL *)oldURL withNewHost:(NSString *)newHost;

+ (NSDictionary *)messageDictFromUIArg:(NSDictionary *)orgDict;

#pragma mark - image get

+ (BOOL)getIconImage:(UIImage **)image forObject:(NSManagedObject *)object withOption:(NSString *)option andCallback:(MOACallback)callback;
/**
 *	检测文件的类型
 *	"unknwon"		//未识别
 *	"directory"	//目录
 *	"blank"		//空文件
 *	"image/png.jpg.jpg2.bmp.gif.tif.tif2"
 *
 *	@param filePath filePath description
 *
 *	@return return value description
 */
+ (NSString *)fileTypeForFile:(NSString *)filePath;
+ (NSString *)probeFileExtension:(NSData *)data;

/**
 *    是否为video
 *
 *    @param filePath    文件路径
 *
 *    @return bool
 */
+ (BOOL) isVideoOfFilePath:(NSString *)filePath;

/**
 *	是否为gif图片
 *
 *	@param filePath	文件路径
 *
 *	@return bool
 */
+ (BOOL)isGifOfFilePath:(NSString *)filePath;

+ (MOACallback)switchCompletionHandleWithMainThread:(MOACallback)callback;
+ (NSString *)pathWithIMAttachment;
+ (NSURL *)getURLForTmpCache;
+ (NSURL *)getURLForTmpFileUse:(NSString *)fileName isDir:(BOOL)isDir;
+ (NSURL *)getURLForDocumentSubDir:(NSString *)subDir;
/**
 *	对象解固化，data==nil返回nil
 *
 *	@param data	data
 *	@param key	key，默认为sanfor
 *
 *	@return obj对象
 */
+ (id)objFromArchiverData:(NSData *)data withKey:(NSString *)key;
/**
 *	对象归档固化，obj==nil返回nil
 *
 *	@param obj	目标对象
 *	@param key	key，默认为sanfor
 *
 *	@return data
 */
+ (NSData *)archiverDataFromObj:(id)obj withKey:(NSString *)key;
/**
 *	将对象（数组，集合，对象）转成数组
 *
 *	@param objs	目标对象
 *
 *	@return array
 */
+ (NSArray *)arrayFromObjs:(id)objs;
/**
 *	将对象（数组，集合，对象）转成集合set
 *
 *	@param objs	目标对象
 *
 *	@return set
 */
+ (NSSet *)setFromObjs:(id)objs;
/**
 *	计算 n 里 在二进制编码中 1 的个数
 *
 *	@param n
 *
 *	@return return value description
 */
+ (NSInteger)bitCount:(NSInteger)n;
/**
 *	当前navigation中的所有viewControllers
 *
 *	@return viewControllers数组
 */
+ (NSArray *)currentViewControllers;

+ (NSString *)cutString:(NSString *)orgString intoBytesCount:(NSInteger)count andFillWithZero:(BOOL)fill;
+ (void)deleteCacheFilesBeforeDate:(NSDate *)date;
+ (NSInteger)deleteFilesAtPath:(NSString *)path beforeUnaccessDate:(NSDate *)unaccessDate;

/**
 *	将指定时间内的日志拷贝的上传文件夹中
 *
 *	@param fromDate	起始时间
 *	@param toDate	结束时间
 */
+ (void)prepareUpLoadLogFileFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate;


+ (BOOL)isJailBreak;
+ (NSString *)bundleIdentifier;
+ (NSDictionary *)getDeviceInfo;

/**
 *	确认本地存在图片包，目前只报销用
 *
 *	@return 返回filekey和图片名组成的NSDictionary
 */
+ (NSDictionary *)getReimburseLocalImage;

+ (NSString *)classContentDescription:(NSString *)clsName;

+ (uint64_t)deviceFreeSpace;

@end
