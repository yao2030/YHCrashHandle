//
//  WYScript.m
//  MOA
//
//  Created by neo on 14-5-30.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import "WYScript.h"
#import "HttpServer.h"
#import <objc/runtime.h>

#ifndef __OPTIMIZE__
	#ifndef kFlagDebug
		#define kFlagDebug			YES
	#endif
#else
	#ifndef kFlagDebug
		#define kFlagDebug			NO
	#endif
#endif

@interface WYScript ()
@property (nonatomic, strong) NSMutableArray *variatesStack;
@end

@implementation WYScript

#pragma mark - init
+ (instancetype)defaultInstance
{
	static WYScript *s_wyscript = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		s_wyscript = [[WYScript alloc] init];
		s_wyscript.variatesStack = [NSMutableArray array];
		[s_wyscript.variatesStack addObject:[NSMutableDictionary dictionary]];//默认顶层堆栈
	});
	NSAssert(s_wyscript != nil, nil);
	return s_wyscript;
}

#pragma mark - output api
/**
 *	执行语句
 *
 *	@param command command description
 *
 *	@return YES=成功。 NO=运行失败
 */
+ (void)runCommand:(NSString *)command withCallback:(MOACallback)callback
{
	callback = [MOAModelManager switchCompletionHandleWithMainThread:callback];
	dispatch_async(dispatch_get_main_queue(), ^{
		NSError *error = nil;
		id result = nil;
		@try {
			result = [self runCommand:command error:&error];
		}
		@catch (NSException *exception) {
			result = exception;
		}
		@finally {
			
		}
		
		if (callback) {
			callback([NSString stringWithFormat:@"%@\n%@", result, error?error:@""]);
		}
	});
}
+ (NSString *)runCommand:(NSString *)command error:(NSError **)error
{
	static BOOL recordCache = NO;
	NSString *result = nil;
	if ([command hasPrefix:@":"]) {//命令
		eCommandState state = [self runInfoCommand:command];
		switch (state) {
			case eCommandStateStartRecordCache:
				recordCache = YES;
				break;
			case eCommandStateEndRecordCache:
				recordCache = NO;
				break;
			default:
				break;
		}
	}else {
		if (recordCache) {
			[self addCacheWithString:command];
			return nil;
		}
		NSError *error = nil;
		result = [self runObjectCCommand:command error:&error];
		if (error) {
			return [NSString stringWithFormat:@"Error: failed to run command:%@ \nwithResult:%@\nandError:%@", command, result, error];
		}
	}
	return result;
}
/**
 *	执行命令
 *
 *	@param command command description
 *
 *	@return return value description
 */
typedef enum eCommandState{
	eCommandStateUnknown,//未知命令
	eCommandStateNormal,//已执行
	eCommandStateStartRecordCache,//开始记录Cache
	eCommandStateEndRecordCache,//停止记录
	eCommandStateRunCache,//运行cache
	eCommandStateDelLastLineCache,//删除cache的上条记录
} eCommandState;
+ (eCommandState)runInfoCommand:(NSString *)command
{
	NSAssert([command hasPrefix:@":"], nil);
	//空格唯一化
	
	command = [self stringByReplacingString:command OccurrencesOfString:@"\r" withString:@"" andBlind:YES];
	command = [self stringByReplacingString:command OccurrencesOfString:@"\n" withString:@"" andBlind:YES];
	command = [self stringByReplacingString:command OccurrencesOfString:@"\t" withString:@" " andBlind:YES];
	command = [self uniquifyString:command withChars:[NSCharacterSet characterSetWithCharactersInString:@" "] andBlind:YES];
	NSString *realCommand = [self removeSpaceHeadAndEnd:[command substringFromIndex:1]];
	if (realCommand.length == 0 || [realCommand isEqualToString:@"?"]) {//help
		[self showHelpInfo];
		
	}else if ([realCommand isEqualToString:@"resetStack"]) {//清除 stack
		[self resetStack];
		
	}else if ([realCommand isEqualToString:@"l"]) {
		[self printCache];
	}else if ([realCommand isEqualToString:@"startCache"]) {
		return eCommandStateStartRecordCache;
	}else if ([realCommand isEqualToString:@"endCache"]) {
		return eCommandStateEndRecordCache;
	}else if ([realCommand isEqualToString:@"cleanCache"]) {
		[self resetCache];
    }else if ([realCommand isEqualToString:@"http server"]) {
        [[HttpServer instance] restart:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"http server start" message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
            [alert show];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [alert dismissWithClickedButtonIndex:0 animated:YES];
            });
        });
    }else if ([realCommand isEqualToString:@"file browser"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UINavigationController *nav = (UINavigationController *)[UIApplication sharedApplication].keyWindow.rootViewController;
            if([nav isKindOfClass:[UINavigationController class]]) {
                UIViewController *vc = [[NSClassFromString(@"FileBrowserViewController") alloc] init];
                if(vc) {
                    [nav pushViewController:vc animated:YES];
                }
            }
        });
    }else if ([realCommand isEqualToString:@"run"]) {
		[self runCache];
		return eCommandStateEndRecordCache;
		
		
		
	}else if ([realCommand hasPrefix:@"p "]) {
		NSString *var = [self removeSpaceHeadAndEnd:[realCommand substringFromIndex:2]];
		NSAssert(var.length > 0, @"space has been removed already!");
		[self showVariate:var];
	}else{
		NSLogToFile(@"Error: unknown info command:%@", realCommand);
		return eCommandStateUnknown;
	}
	return eCommandStateNormal;
}
/**
 *	运行 object c 的语句
 *
 *	@param command command description
 *
 *	@return return value description
 */
+ (NSString *)runObjectCCommand:(NSString *)command error:(NSError **)error
{
	
	// 1. 格式化 command
	//NSLog(@"before Format:%@", command);
	command  = [self formatObjectCCommand:command];
	//NSLog(@"Format:%@", command);
	if (! command) {
		if (error) {
			*error = MOAErrorMakeOther(@"formatObjectCCommand failed", command, 0);
		}
		return nil;
	}
	
	// 2. 分解成句子  ;
	NSArray *commandArray = [self componentsSeparatedByString:@";" forBlindString:command];
		
	// 3. 运行每条语句
	NSString *finalResult = nil;
	for (NSString *elem in commandArray) {
		if (elem.length == 0) {
			continue ;
		}
		NSError *errorElem = nil;
		finalResult = [self runEqualStatement:elem error:&errorElem];
		if (errorElem) {
			NSLogToFile(@"Error: failed to run statement:%@", elem);
			if (error) {
				*error = errorElem;
			}
			break;
		}
	}
	return finalResult;
}

#pragma mark -- command cache
static NSMutableData *s_cacheData = nil;
+ (NSMutableData *)commandCache
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		s_cacheData = [[NSMutableData alloc] init];
	});
	NSAssert(s_cacheData, nil);
	return s_cacheData;
}
+ (void)printCache
{
	NSMutableData *cache = [self commandCache];
	NSString *cacheString = [[NSString alloc] initWithData:cache encoding:NSUTF8StringEncoding];
	NSLog(@"\nCache:\n%@\n", cacheString);
}
+ (void)resetCache
{
	NSMutableData *cache = [self commandCache];
	[cache setLength:0];
}
+ (void)runCache
{
	NSMutableData *cache = [self commandCache];
	NSString *cacheString = [[NSString alloc] initWithData:cache encoding:NSUTF8StringEncoding];
	[self runObjectCCommand:cacheString error:nil];
}
+ (void)addCacheWithString:(NSString *)line
{
	NSMutableData *cache = [self commandCache];
	[cache appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
}
#pragma mark - info command
+ (void)showHelpInfo
{
	NSLog(@"Todo: show help infos ...");
}
+ (void)showVariate:(NSString *)variate
{
	NSAssert(variate.length > 0, nil);
	static NSMutableCharacterSet *variateCharSet = nil;
	static NSMutableCharacterSet *numberCharSet = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		variateCharSet = [[NSMutableCharacterSet alloc] init];
		NSRange range = NSMakeRange((unsigned int)'a', 26);//小写字母
		[variateCharSet addCharactersInRange:range];
		range = NSMakeRange((unsigned int)'A', 26);//大写字母
		[variateCharSet addCharactersInRange:range];
		range = NSMakeRange((unsigned int)'_', 1);//下划线
		[variateCharSet addCharactersInRange:range];
		
		range = NSMakeRange((unsigned int)'0', 10);//数字
		[numberCharSet addCharactersInRange:range];
	});
	
	// 1. 判断是否有空格
	NSArray *elems = [self componentsSeparatedByString:@" " forBlindString:variate];
	if (elems.count > 2) {
		NSLogToFile(@"Error: unsupport command of <%@>", variate);
		return;
	}
	NSUInteger stack = 0;
	
	NSString *realVarString = elems[0];
	if (elems.count == 2) {
		unichar startChar = [variate characterAtIndex:0];
		if ([numberCharSet characterIsMember:startChar]) {
			stack = [(NSString *)elems[0] integerValue];
			realVarString = elems[1];
		}else{
			NSLogToFile(@"Error: unsupport command of <%@>", variate);
			return;
		}
	}
	unichar startChar = [realVarString characterAtIndex:0];
	if ([variateCharSet characterIsMember:startChar]) {
		NSDictionary *varDict = [self variateForName:realVarString aboveStack:stack];
		if ([varDict[@"type"] integerValue] == eStringUnknown) {
			NSLogToFile(@"Error: variate of <%@> not exist.", realVarString);
			return ;
		}
		NSString *typeString = [self typeStringOfVariate:varDict];
		NSLog(@"Name(%zd):%@\nType:%@\nValue:%@", stack, realVarString, typeString, varDict[@"value"]);
	}
}
#pragma mark - stack
+ (NSString *)newVariate
{
	static NSUInteger lastNum = 0;
	lastNum ++;
	return [NSString stringWithFormat:@"_wyretain%04zd", lastNum];
}

+ (NSMutableArray *)globleVariates
{
	return [[self defaultInstance] variatesStack];
}
+ (void)push
{
	NSMutableArray *globleVariates = [self globleVariates];
	[globleVariates addObject:[NSMutableDictionary dictionary]];
}
+ (void)pop
{
	NSMutableArray *globleVariates = [self globleVariates];
	NSAssert(globleVariates.count > 1, nil);
	if (globleVariates.count > 1) {
		[globleVariates removeLastObject];
	}
}

+ (void)resetStack
{
	((WYScript *)[self defaultInstance]).variatesStack = [NSMutableArray array];
	[((WYScript *)[self defaultInstance]).variatesStack addObject:[NSMutableDictionary dictionary]];//默认顶层堆栈;
}
+ (NSDictionary *)variateForName:(NSString *)name
{
	return [self variateForName:name aboveStack:0];
}
+ (NSDictionary *)variateForName:(NSString *)name aboveStack:(NSUInteger)stack
{
	NSDictionary *result = @{@"type":[NSNumber numberWithInteger:eStringUnknown]};
	NSAssert([name isKindOfClass:[NSString class]], @"name must be nsstring");
	name = [self removeSpaceHeadAndEnd:name];
	// 1. 判断是否有不支持的特殊字符
	NSMutableCharacterSet *unsupportCharSet = [[NSMutableCharacterSet alloc] init];
	[unsupportCharSet addCharactersInString:@"~!#$%^&*-+=|\\;:'<>?/"];
	NSRange unsupportRange = [name rangeOfCharacterFromSet:unsupportCharSet];
	if (unsupportRange.location != NSNotFound) {
		NSLogToFile(@"Error: variate is valid of <%@> with:%c", name, [name characterAtIndex:unsupportRange.location]);
		return result;
	}
	// 2. 判断是否有 . , 若有。 则自动转换成 get 方法
	NSArray *compsPoint = [name componentsSeparatedByString:@"."];//get 方法
	NSArray *compsSub = [name componentsSeparatedByString:@"["];//下标
	if (compsPoint.count > 1 || compsSub.count > 1) {
		[self push];
		NSString *statement = [self getMethodPointSubString:name];
		if (! statement) {
			[self pop];
			return result;
		}
		result = [self valueFromID:statement];
		[self pop];
	}else{
		// 3. 直接读取变量
		NSMutableArray *globleVariates = [self globleVariates];
		NSAssert(stack <= globleVariates.count - 1, nil);
		if (stack > globleVariates.count - 1) {
			NSLogToFile(@"Error: stack level error with current:%zd and arg:%zd", globleVariates.count - 1, stack);
			return result;
		}
		BOOL found = NO;
		for (NSInteger i = globleVariates.count - 1 - stack; i >= 0; i--) {
			NSMutableDictionary *stackDict = [globleVariates objectAtIndex:i];
			if (stackDict[name]) {
				result = stackDict[name];
				found = YES;
				break ;
			}
		}
		if (! found) {
			//NSLogToFile(@"Error: cant found variates with name:%@ and above %d", name, stack);
		}

	}

	return result;
}
+ (BOOL)setVariatesValue:(NSDictionary *)value forName:(NSString *)name
{
	return [self setVariatesValue:value forName:name aboveStack:0];
}
+ (BOOL)setVariatesValue:(NSDictionary *)value forName:(NSString *)name aboveStack:(NSUInteger)stack
{
	NSAssert([value isKindOfClass:[NSDictionary class]], nil);
	NSAssert([name isKindOfClass:[NSString class]], @"name must be nsstring");
	NSMutableArray *globleVariates = [self globleVariates];
	NSAssert(stack <= globleVariates.count - 1, nil);
	if (stack > globleVariates.count - 1) {
		NSLogToFile(@"Error: stack level error with current:%zd and arg:%zd", globleVariates.count - 1, stack);
		return NO;
	}
	for (NSInteger i = globleVariates.count - 1 - stack; i >= 0; i--) {
		NSMutableDictionary *stackDict = [globleVariates objectAtIndex:i];
		if (stackDict[name]) {
			stackDict[name] = value;
			return YES;
		}
	}
	NSLogToFile(@"Error: cant found variate of name:%@", name);
	return NO;
}
+ (BOOL)addVariatesValue:(NSDictionary *)value withName:(NSString *)name
{
	return [self addVariatesValue:value withName:name aboveStack:0];
}
+ (BOOL)addVariatesValue:(NSDictionary *)value withName:(NSString *)name aboveStack:(NSUInteger)stack
{
	NSAssert([value isKindOfClass:[NSDictionary class]], nil);
	NSAssert([name isKindOfClass:[NSString class]], @"name must be nsstring");
	
	//检查当前是否已有此变量, 若有， 报冲突
	NSDictionary *tmpValueDict = [self variateForName:name aboveStack:stack];
	if ([tmpValueDict[@"type"] integerValue] != eStringUnknown) {
		NSLogToFile(@"Error: reduplicative variate：%@, old:%@ = (%@)%@", name, name, [self typeStringOfVariate:tmpValueDict], tmpValueDict[@"value"]);
		return NO;
	}
	
	NSMutableArray *globleVariates = [self globleVariates];
	
	
	NSAssert(stack <= globleVariates.count - 1, nil);
	if (stack > globleVariates.count - 1) {
		NSLogToFile(@"Error: stack level error with current:%zd and arg:%zd", globleVariates.count - 1, stack);
		return NO;
	}

	NSMutableDictionary *stackDict = [globleVariates objectAtIndex:globleVariates.count - 1 - stack];
	NSAssert(! stackDict[name], nil);
	stackDict[name] = value;
	return YES;
}
+ (void)addNewVariates:(NSString *)variateString withName:(NSString *)name
{
	NSAssert([name isKindOfClass:[NSString class]], @"name must be nsstring");
	NSMutableArray *globleVariates = [self globleVariates];
	NSMutableDictionary *lastStack = [globleVariates lastObject];
	lastStack[name] = [self variateFromString:variateString];
}
#pragma mark - type define
typedef enum eStringtype{
	eStringUnknown,
	eStringVoid,
	eStringPoint,
	eStringInteger,
	eStringFloat,
	eStringChars,
	eStringNSObject,
	eStringNSString,
	eStringNSNumber,
	eStringNSNumberMore,
	eStringNSArray,
	eStringNSDictionary,
	eStringID, // 需要计算获得的
	eStringNil,// nil
	eStringVariate,// 已存在的变量
} eStringtype;

+ (NSString *)typeStringOfVariate:(NSDictionary *)dict
{
	NSInteger typeNum = 0;
	if (dict) {
		NSAssert([dict isKindOfClass:[NSDictionary class]], nil);
		typeNum = [(NSNumber *)(dict[@"type"]) integerValue];
	}
	
	NSString *result = @"<Unknown>";
	switch (typeNum) {
		case eStringVoid:
			result = @"<Void>";
			break;
		case eStringPoint:
			result = @"<Point>";
			break;
		case eStringInteger:
			result = @"<Integer>";
			break;
		case eStringFloat:
			result = @"<Float>";
			break;
		case eStringChars:
			result = @"<Char *>";
			break;
		case eStringNSObject:
			if (dict[@"value"]) {
				result = [NSString stringWithFormat:@"%@", [dict[@"value"] class]];
			}else{
				result = @"<nil>";
			}
			break;
			
		default:
			NSAssert(NO, @"unsupport");
			break;
	}
	return result;
}
#pragma mark - variate deal
+ (id)objectValueOfVariate:(NSDictionary *)dict
{
	NSAssert([dict isKindOfClass:[NSDictionary class]], nil);
	eStringtype type = (eStringtype)[dict[@"type"] integerValue];
	NSAssert(type != eStringUnknown, nil);
	id result = nil;
	switch (type) {
		case eStringNSObject:
			result = dict[@"value"];
			break;
			
		default:
			NSAssert(NO, @"should be nsobject");
			break;
	}
	return result;
}
#pragma mark - advanced string deal
/**
 *	识别字符串string， 并获取其中的值
 *
 *	@param string string description
 *
 *	@return 内部NSDictionary 结构
 */
+ (NSDictionary *)variateFromString:(NSString *)string
{
	return [self variateFromString:string withPure:NO];
}
+ (NSDictionary *)variateFromString:(NSString *)string withPure:(BOOL)pure
{
	string = [self removeSpaceHeadAndEnd:string];
	if (string.length == 0) {
		return @{@"type":[NSNumber numberWithInteger:eStringUnknown]};
	}
	
	//循环查找
	[self push];
	if (! pure) {
		while (YES) {
			NSArray *keys = [self loopSearchKeysForString:string];
			if (keys.count == 0) {
				break;
			}
			//替换
			NSString *newString = string;
			NSInteger lastOffset = 0;
			NSInteger nextIndex = 0;
			for (NSValue *key in keys) {
				NSRange range = [key rangeValue];
				NSAssert(range.length > 0, nil);
				NSAssert(range.location >= nextIndex, nil);//这里下一个都应该在上一个的后面， 否则下面替换字符串就会有问题
				NSDictionary *keyValue = [self variateFromString:[string substringWithRange:range] withPure:YES];
				if ([keyValue[@"type"] integerValue] == eStringUnknown) {
					[self pop];
					NSLogToFile(@"Error: invalid statement of <%@>", key);
					return @{@"type":[NSNumber numberWithInteger:eStringUnknown]};
				}
				NSString *newKeyName = [self newVariate];
				[self addVariatesValue:keyValue withName:newKeyName];
				NSRange toReplace = NSMakeRange(range.location + lastOffset, range.length);
				NSAssert([[string substringWithRange:range] isEqualToString:[newString substringWithRange:toReplace]], nil);//应该是同一处string
				newString = [newString stringByReplacingCharactersInRange:toReplace withString:newKeyName];
				lastOffset = lastOffset + newKeyName.length - range.length;
				nextIndex = range.location + range.length;
			}
			string = newString;
		}
	}
	
	
	eStringtype type = [self variateTypeFromString:string];
	NSAssert(type == eStringNSString || type == eStringUnknown || [[self blindString:string] isEqualToString:string], nil);//前面已经完全处理了这种带""的情况 loop...
	NSDictionary *result = [self variatesFromString:string andType:type];

	NSAssert([result[@"type"] integerValue] == eStringUnknown
			 || [result[@"type"] integerValue] == eStringVoid
			 || [result[@"type"] integerValue] == eStringPoint
			 || [result[@"type"] integerValue] == eStringNSObject
			 || [result[@"type"] integerValue] == eStringInteger
			 || [result[@"type"] integerValue] == eStringFloat
			 || [result[@"type"] integerValue] == eStringChars, nil);
	NSAssert([result isKindOfClass:[NSDictionary class]], nil);
	[self pop];
	return result;
}

/**
 *	分解 =, 前后不能有 =
 *
 *	@param id id description
 *
 *	@return return value description
 */
+ (NSString *)runEqualStatement:(NSString *)command error:(NSError **)error
{
	if (error) {
		*error = nil;
	}
	id runResult = nil;
	NSAssert([[self blindString:command] rangeOfString:@";"].location == NSNotFound, nil);
	NSArray *tmpComps = [command componentsSeparatedByString:@"="];
	NSMutableArray *comps = [NSMutableArray arrayWithCapacity:tmpComps.count];
	for (NSString *elem in tmpComps) {
		NSString *elemNew = [self removeSpaceHeadAndEnd:elem];
		if (elemNew.length > 0) {
			[comps addObject:elemNew];
		}
	}
	if (comps.count > 2) {
		NSLogToFile(@"Error: runEqualStatement failed with command:%@", command);
		if (error) {
			*error = MOAErrorMakeOther(@"runEqualStatement failed with command", command, 0);
		}
		return nil;
	}
	
	if (comps.count == 1) {//只有一行执行语句
		runResult = [self variateFromString:comps[0]];
	}else{
		NSAssert(comps.count == 2, nil);
		[self push];
		// 1. 先计算右侧的值
		NSString *rightValueName = [self newVariate];
		NSDictionary *rightValue = [self variateFromString:comps[1]];
		if ([rightValue[@"type"] integerValue] == eStringUnknown) {
			NSLogToFile(@"Error: right value is invalid");
			[self pop];
			if (error) {
				NSString *msgValue = [NSString stringWithFormat:@"right value is invalid:%@", rightValue];
				*error = MOAErrorMakeOther(msgValue, command, 0);
			}
			return nil;
		}
		NSAssert([rightValue isKindOfClass:[NSDictionary class]], @"must return a dictionary");
		if (! [self addVariatesValue:rightValue withName:rightValueName]) {
			[self pop];
			if (error) {
				NSString *msgValue = [NSString stringWithFormat:@"must return a dictionary:%@", rightValue];
				*error = MOAErrorMakeOther(msgValue, command, 0);
			}
			return nil;
		}
		runResult = rightValue;
		// 2. 将右侧的计算结果赋值给左侧
		// 检测左侧是否是 point 属性
		BOOL isNewValue = NO;
		NSString *newValueName = nil;
		NSArray *parts = [self analysisLeftString:comps[0] andIsNewValue:&isNewValue];
		if (parts.count == 0) {
			[self pop];
		}else if (parts.count == 1) {//属于变量
			newValueName = parts[0];
			if (! isNewValue) {
				if([self setVariatesValue:rightValue forName:newValueName aboveStack:1] == NO) {
					[self pop];
					if (error) {
						NSString *msgValue = [NSString stringWithFormat:@"asign right value to left failed:%@ <- %@", newValueName, rightValue];
						*error = MOAErrorMakeOther(msgValue, command, 0);
					}
					return nil;
				}
			}else{
				if (! [self addVariatesValue:rightValue withName:newValueName aboveStack:1]) {
					[self pop];
					if (error) {
						NSString *msgValue = [NSString stringWithFormat:@"asign right value to left failed:%@ <- %@", newValueName, rightValue];
						*error = MOAErrorMakeOther(msgValue, command, 0);
					}
					return nil;
				}
			}
		}else if (parts.count == 2) {//属于变量的点值
			NSAssert(newValueName == nil, nil);
			newValueName = [self newVariate];
			NSDictionary *pointReciever = [self variateFromString:parts[0]];
			if (! [self addVariatesValue:pointReciever withName:newValueName]) {
				[self pop];
				if (error) {
					NSString *msgValue = [NSString stringWithFormat:@"asign value failed:%@ <- %@", newValueName, pointReciever];
					*error = MOAErrorMakeOther(msgValue, command, 0);
				}
				return nil;
			}
			if (! [self setMethod:parts[1] withReciever:newValueName andNewValueName:rightValueName]) {
				[self pop];
				if (error) {
					NSString *msgValue = [NSString stringWithFormat:@"asign value failed:%@ <- %@", newValueName, rightValueName];
					*error = MOAErrorMakeOther(msgValue, command, 0);
				}
				return nil;
			}
		}
		[self pop];
		
	}
	return runResult;
}
#pragma mark - org string to value
// 123
+ (NSNumber *)valueFromInteger:(NSString *)value
{
	return [NSNumber numberWithInteger:[value integerValue]];
}
// 10.56
+ (NSNumber *)valueFromFloat:(NSString *)value
{
	return [NSNumber numberWithFloat:[value floatValue]];
}
// @"string"
+ (NSString *)valueFromNSString:(NSString *)value
{
	NSAssert([value hasPrefix:@"@\""] && [value hasSuffix:@"\""] && value.length >= 3, nil);
	return [value substringWithRange:NSMakeRange(2, value.length - 3)];
}
// @100
+ (NSNumber *)valueFromNSNumber:(NSString *)value
{
	NSAssert([value hasPrefix:@"@"] && value.length >= 2, nil);
	NSString *realValue = [value substringFromIndex:1];
	eStringtype type = [self variateTypeFromString:realValue];
	NSAssert(type == eStringInteger || type == eStringFloat, nil);
	if (type == eStringInteger) {
		return [self valueFromInteger:realValue];
	}else if (type == eStringFloat) {
		return [self valueFromFloat:realValue];
	}else{
		NSLogToFile(@"Bug: invalid arg:%@", value);
		return @0;
	}
}
// @(100)
+ (NSNumber *)valueFromNSNumberMore:(NSString *)value
{
	NSAssert([value hasPrefix:@"@("] && [value hasSuffix:@")"] && value.length >= 3, nil);
	NSString *realValue = [NSString stringWithFormat:@"@%@", [value substringWithRange:NSMakeRange(2, value.length - 3)]];
	return [self valueFromNSNumber:realValue];
}
// @[a, b]
+ (NSArray *)valueFromNSArray:(NSString *)value
{
	NSAssert([value hasPrefix:@"@["] && [value hasSuffix:@"]"] && value.length >= 3, nil);
	NSString *content = [value substringWithRange:NSMakeRange(2, value.length - 3)];
	//NSArray *comps = [content componentsSeparatedByString:@","];
	NSArray *comps = [self componentsSeparatedByString:@"," forBlindString:content];
	NSMutableArray *arrayElems = [NSMutableArray arrayWithCapacity:comps.count];
	for (NSString *elem in comps) {
		NSString *effectElem = [self removeSpaceHeadAndEnd:elem];
		if (! effectElem) {
			continue;
		}
		NSDictionary * variate = [self variateFromString:effectElem];
		NSAssert([variate isKindOfClass:[NSDictionary class]], nil);
		id objectValue = [self objectValueOfVariate:variate];
		if (objectValue) {
			NSAssert([objectValue isKindOfClass:[NSObject class]], nil);
			[arrayElems addObject:objectValue];
		}else{
			break;
		}
	}
	
	return [NSArray arrayWithArray:arrayElems];
}

+ (NSDictionary *)valueFromNSDictionary:(NSString *)value
{
	NSAssert([value hasPrefix:@"@{"] && [value hasSuffix:@"}"] && value.length >= 3, nil);
	NSAssert([[self blindString:value] isEqualToString:value], nil);//前面已经完全处理了这种带""的情况 loop...
	
	NSString *body = [value substringWithRange:NSMakeRange(2, value.length - 3)];
	NSArray *elems = [body componentsSeparatedByString:@","];
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:elems.count];
	for (NSString *orgElem in elems) {
		NSString *elem = [self removeSpaceHeadAndEnd:orgElem];
		if (elem.length == 0) {
			continue;
		}
		NSArray *keyValue = [elem componentsSeparatedByString:@":"];
		if (keyValue.count != 2) {
			NSLogToFile(@"Error: invalid pair for NSDictionary of <%@>", elem);
			return nil;
		}
		NSString *keyString = [self removeSpaceHeadAndEnd:keyValue[0]];
		NSString *valueString = [self removeSpaceHeadAndEnd:keyValue[1]];
		NSDictionary *key = [self variateFromString:keyString];
		if ([key[@"type"] integerValue] != eStringNSObject || key[@"value"] == nil) {
			NSLogToFile(@"Error: invalid pair for NSDictionary of <%@>", elem);
			return nil;
		}
		NSDictionary *value = [self variateFromString:valueString];
		if ([value[@"type"] integerValue] != eStringNSObject || value[@"value"] == nil) {
			NSLogToFile(@"Error: invalid pair for NSDictionary of <%@>", elem);
			return nil;
		}
		result[key[@"value"]] = value[@"value"];
		
	}
	
	return [NSDictionary dictionaryWithDictionary:result];
}
// [reciever method:arg and:arg2]
+ (NSDictionary *)valueFromPureID:(NSString *)orgValue
{
	NSDictionary *result = @{@"type": [NSNumber numberWithInteger:eStringUnknown],
							 };
	
	NSString *command = orgValue;
	NSAssert([command hasPrefix:@"["] && [command hasSuffix:@"]"] && command.length > 2, @"such as '[[class alloc] init]'");
	//NSLog(@"Start command:%@", command);
	command = [self removeSpaceHeadAndEnd:[command substringWithRange:NSMakeRange(1, command.length-2)]];
	
	
	NSRange range  = [command rangeOfString:@" "];
	if (range.location == NSNotFound) {
		NSLog(@"space cant be found for message receiver:%@", orgValue);
		return result;
	}
	NSString *reciver = [command substringToIndex:range.location];
	if (reciver.length == 0) {
		NSLog(@"space cant be found for message receiver:%@", orgValue);
		return result;
	}
	NSString *methodArgs = [command substringFromIndex:range.location + 1];
	NSString *blindMethodArgs = [self blindString:methodArgs];
	if ([blindMethodArgs rangeOfString:@"["].location != NSNotFound
		|| [blindMethodArgs rangeOfString:@"]"].location != NSNotFound) {
		NSLog(@"space cant be found for message receiver:%@", orgValue);
		return result;
	}
	
	
	
	
	//NSArray *blindMethodArgsComp = [blindMethodArgs componentsSeparatedByString:@":"];
	//NSArray *methodArgsComp = [self divisionString:methodArgs likeArray:blindMethodArgsComp];
	NSArray *methodArgsComp = [self componentsSeparatedByString:@":" forBlindString:methodArgs];
	
	NSMutableString *methodName = [NSMutableString string];
	NSMutableArray *args = [NSMutableArray arrayWithCapacity:methodArgsComp.count];
	NSUInteger index = 0;
	for (NSString *elem in methodArgsComp) {
		NSAssert(elem.length > 0, nil);
		if (elem.length > 0) {
			NSRange spaceRange = [elem rangeOfString:@" " options:NSBackwardsSearch];//反向查找， 第一个空格
			if (spaceRange.location != NSNotFound && index != (methodArgsComp.count - 1)) {
				NSAssert(index != 0, nil);
				[methodName appendString:[elem substringFromIndex:spaceRange.location+1]];
				[methodName appendString:@":"];
				[args addObject:[elem substringToIndex:spaceRange.location]];
			}else{
				if (methodName.length == 0) {
					[methodName appendString:elem];
					if (methodArgsComp.count != 1) {
						[methodName appendString:@":"];
					}
				}else{
					NSAssert(index != 0, nil);
					[args addObject:elem];
				}
				
			}
			index ++;
		}
	}
	//3. 翻译参数
	NSMutableArray *tmpArgs = [NSMutableArray array];
	for (NSString *elem in args) {
		//特判: 判断 elem 是否是多个对象， 只处理
		//		[NSString stringWithFormat:(NSString *), ...]
		//		[NSArray arrayWithObjects:(id), ..., nil]
		//		[NSSet setWithObjects:(id), ..., nil]
		if (args.count == 1) {
			NSString *blindArgs = [self blindString:elem];
			if ([blindArgs rangeOfString:@","].location != NSNotFound) {
				NSArray *elemComps = [self componentsSeparatedByString:@"," forBlindString:elem];
				if (elemComps.count <= 1) {
					NSLogToFile(@"Error: invalid args (%@) for variable parameter function:[%@ %@...]", args, reciver, methodName);
					return result;
				}
				NSMutableArray *tmpArgs = [NSMutableArray arrayWithCapacity:elemComps.count];
				for (NSString *argTmp in elemComps) {
					NSDictionary *argTmpValue = [self variateFromString:argTmp];
					if ([argTmpValue[@"type"] integerValue] != eStringNSObject) {
						NSLogToFile(@"Error: invalid arg (%@, type<%zd>) for variable parameter function:[%@ %@...]", argTmp, [argTmpValue[@"type"] integerValue], reciver, methodName);
						return result;
					}
					if (! argTmpValue[@"value"]) {//非 NSString, 则出现了 nil 则直接停止
						if ([reciver isEqualToString:@"NSString"]) {
							[tmpArgs addObject:[NSNull null]];
						}else{
							break;
						}
						
					}else{
						[tmpArgs addObject:argTmpValue[@"value"]];
					}
					
				}
				id elemValue = nil;
				if (([reciver isEqualToString:@"NSString"] || [reciver isEqualToString:@"NSMutableString"])
					&& [methodName isEqualToString:@"stringWithFormat:"]) {
					NSMutableArray *argList = [NSMutableArray arrayWithArray:tmpArgs];
					[argList removeObjectAtIndex:0];
					elemValue = [self stringWithFormat:tmpArgs[0] array:argList];
				}else if (([reciver isEqualToString:@"NSArray"] || [reciver isEqualToString:@"NSMutableArray"])
						  && [methodName isEqualToString:@"arrayWithObjects:"]) {
					elemValue = [NSClassFromString(reciver) arrayWithArray:tmpArgs];
				}else if (([reciver isEqualToString:@"NSSet"] || [reciver isEqualToString:@"NSMutableSet"])
						  && [methodName isEqualToString:@"setWithObjects:"]) {
					elemValue = [NSClassFromString(reciver) setWithArray:tmpArgs];
				}else{
					NSLogToFile(@"Error: invalid args for variable parameter function:[%@ %@...]", reciver, methodName);
					return result;
				}
				NSAssert(elemValue, @"Shouldnt be nil");
				return @{@"type":[NSNumber numberWithInteger:eStringNSObject],
						 @"value":elemValue};
				
			}
		}
		
		NSDictionary *argValue = [self variateFromString:elem];
		if ([argValue[@"type"] integerValue] == eStringUnknown) {
			return result;
		}
		[tmpArgs addObject:argValue];
	}
	args = tmpArgs;
	tmpArgs = nil;
	
	NSAssert(methodName.length > 0, nil);
	SEL sel = NSSelectorFromString(methodName);
	// 1. 先找变量
	NSDictionary *reciverDict = [self variateForName:reciver];
	BOOL isIntance = NO;
	Method method = NULL;
	id orgClass = nil;
	@try {
		if ([reciverDict[@"type"] integerValue] == eStringUnknown) {//找不到
			orgClass = NSClassFromString(reciver);
			method = class_getClassMethod(orgClass, sel);
		}else{
			NSAssert([reciverDict[@"value"] isKindOfClass:[NSObject class]], nil);
			isIntance = YES;
			orgClass = reciverDict[@"value"];
			if (orgClass) {
				method = class_getInstanceMethod([orgClass class], sel);
			}
			
		}
	}
	@catch (NSException *exception) {
		NSLogToFile(@"Error: [%@] cant response to <%@>", orgClass, methodName);;
		return result;
	}
	@finally {
		
	}
	if (orgClass == nil) {
		NSLogToFile(@"Error: <%@> not exist", reciver);
		return result;
	}
	
	if (method != NULL){
		//if (class_getClassMethod(NSClassFromString(reciver), @selector(methodName)) != NULL) {
		//if ([NSClassFromString(reciver) respondsToSelector:@selector(methodName)]) {
		//[NSClassFromString(reciver) performSelector:@selector(methodName)];
		
		//NSMethodSignature *mySignature = [NSMutableArray instanceMethodSignatureForSelector:sel];
		NSMethodSignature *mySignature = [orgClass methodSignatureForSelector:sel];
		NSInvocation *myInvovation = [NSInvocation invocationWithMethodSignature:mySignature];
		[myInvovation setTarget:orgClass];
		[myInvovation setSelector:sel];
		//设置参数
		NSUInteger index = 2;
		for (NSDictionary *obj in args) {
			NSAssert([obj isKindOfClass:[NSDictionary class]], nil);
			eStringtype type = (eStringtype)[obj[@"type"] integerValue];
			NSUInteger length = 4;
			if (obj[@"length"]) {
				length = [obj[@"length"] integerValue];
			}
			switch (type) {
				case eStringNSObject:
				{
					id value = obj[@"value"];
					[myInvovation setArgument:(void *)&value atIndex:index];
					break;
				}
				case eStringInteger:
				{
					void *value = malloc(length);
					NSAssert([obj[@"value"] isKindOfClass:[NSNumber class]], nil);
					uint64_t tmpValue = [obj[@"value"] longLongValue];
					memcpy(value, &tmpValue, length);
					[myInvovation setArgument:(void *)value atIndex:index];
					free(value);
					break;
				}
				case eStringFloat:
				{
					if (length == 4) {
						float value = [obj[@"value"] floatValue];
						[myInvovation setArgument:(void *)&value atIndex:index];
					}else{
						NSAssert(length == 8, nil);
						double value = [obj[@"value"] doubleValue];
						[myInvovation setArgument:(void *)&value atIndex:index];
					}
					break;
				}
				case eStringChars:
				{
					NSAssert([obj[@"value"] isKindOfClass:[NSString class]], nil);
					const char *value = [(NSString *)obj[@"value"] UTF8String];
					[myInvovation setArgument:(void *)value atIndex:index];
					break;
				}
				case eStringPoint:
				{
					NSAssert([obj[@"value"] isKindOfClass:[NSValue class]], nil);
					const void *value = [(NSValue *)obj[@"value"] pointerValue];
					[myInvovation setArgument:(void *)&value atIndex:index];
					break;
				}
				default:
					NSAssert(NO, @"This should not be happened!");
					break;
			}
			index ++;
		}
		@try {
			[myInvovation invoke];
		}
		@catch (NSException *exception) {
			NSLogToFile(@"Error: %@", exception);
			return result;
		}
		
		const char *returnType = [mySignature methodReturnType];
		NSUInteger returnLength = [mySignature methodReturnLength];
		switch (*returnType) {
			case '@':
			{
				__unsafe_unretained id tmpWeakResult = nil;
				[myInvovation getReturnValue:&tmpWeakResult];
				id tmpResult = tmpWeakResult;
				if (tmpResult) {
					result = @{@"type":[NSNumber numberWithInteger:eStringNSObject],
							   @"value":tmpResult};
				}else{
					result = @{@"type":[NSNumber numberWithInteger:eStringNSObject],
							   };
				}
				
				break;
			}
			case 'v':
			{
				result = @{@"type":[NSNumber numberWithInteger:eStringVoid]};
				break;
			}
			case '*':
			{
				char *tmpResult = nil;
				[myInvovation getReturnValue:&tmpResult];
				if (*tmpResult) {
					result = @{@"type":[NSNumber numberWithInteger:eStringChars],
							   @"value":[NSString stringWithUTF8String:tmpResult]};
				}else{
					result = @{@"type":[NSNumber numberWithInteger:eStringChars],
							   @"value":[NSNull null]};
				}
				break;
			}
			case 'Q'://uint64_t
			case 'q'://int64_t
			case 's'://short
			case 'S'://unsigned short
			case 'c'://char
			case 'C'://unsigned char
			case 'i'://int
			case 'I'://unsigned int
			{
				uint64_t tmpResult = 0;
				[myInvovation getReturnValue:&tmpResult];
				if (returnLength == 1) {
					result = @{@"type":[NSNumber numberWithInteger:eStringInteger],
							   @"value":[NSNumber numberWithChar:(char)tmpResult],
							   @"length":[NSNumber numberWithInteger:returnLength]};
				}else if (returnLength == 2) {
					result = @{@"type":[NSNumber numberWithInteger:eStringInteger],
							   @"value":[NSNumber numberWithShort:(short)tmpResult],
							   @"length":[NSNumber numberWithInteger:returnLength]};
				}else if (returnLength == 4) {
					result = @{@"type":[NSNumber numberWithInteger:eStringInteger],
							   @"value":[NSNumber numberWithInt:(int32_t)tmpResult],
							   @"length":[NSNumber numberWithInteger:returnLength]};
				}else if (returnLength == 8) {
					result = @{@"type":[NSNumber numberWithInteger:eStringInteger],
							   @"value":[NSNumber numberWithLong:(int64_t)tmpResult],
							   @"length":[NSNumber numberWithInteger:returnLength]};
				}
				break;
			}
			case 'f':
			case 'd':
			{
				double tmpResult = 0;
				[myInvovation getReturnValue:&tmpResult];
				if (returnLength == 4) {
					result = @{@"type":[NSNumber numberWithInteger:eStringFloat],
							   @"value":[NSNumber numberWithFloat:(float)tmpResult],
							   @"length":[NSNumber numberWithInteger:returnLength]};
				}else if (returnLength == 8) {
					result = @{@"type":[NSNumber numberWithInteger:eStringInteger],
							   @"value":[NSNumber numberWithDouble:(double)tmpResult],
							   @"length":[NSNumber numberWithInteger:returnLength]};
				}
				break;
			}
			case '^':
			{
				void *tmpResult = nil;
				[myInvovation getReturnValue:&tmpResult];
				result = @{@"type":[NSNumber numberWithInteger:eStringPoint],
						   @"value":[NSValue valueWithPointer:tmpResult],
						   @"length":[NSNumber numberWithInteger:returnLength]};
				break;
			}
			default:
				NSLog(@"unsupport:%c", *returnType);
				break;
		}
		//
	}else{
		NSLogToFile(@"Error: class(%@) cant response to selector:(%@)", reciver, methodName);
	}
	return result;
}
+ (NSDictionary *)valueFromID:(NSString *)value
{
	NSString *command = value;
	NSAssert([command hasPrefix:@"["] && [command hasSuffix:@"]"] && command.length > 2, @"such as '[[class alloc] init]'");
	//NSAssert([command characterAtIndex:1] != ' ' && [command characterAtIndex:command.length - 2], @"the space should be removed before");
	//NSLog(@"Start command:%@", command);
	id result = nil;
	[self push];
	
	// 0. 替换特殊字符
	// \符号替换, 及引号内数据盲化
	unichar *buff = malloc(command.length*sizeof(unichar));
	BOOL startQuot = NO;
	for (NSUInteger i = 0; i < command.length; i++) {
		unichar uchar = [command characterAtIndex:i];
		if (uchar == '\\') {
			buff[i] = 'a';
			if (i + 1 < command.length) {
				buff[i+1] = 'b';
				i++;
			}
		}else if (uchar == '"' || startQuot) {
			if (uchar == '"' && startQuot) {
				startQuot = NO;
				buff[i] = '"';
			}else if (uchar == '"' && (!startQuot)) {
				buff[i] = '"';
				startQuot = YES;
			}else{
				NSAssert(uchar != '"' && startQuot, nil);
				buff[i] = 'd';
			}
		}else{
			buff[i] = uchar;
		}
	}
	
	NSString *effect = [NSString stringWithCharacters:buff length:command.length];
	
	free(buff);
	//NSLog(@"Tips: effct:%@", effect);
	// 1. 迭代处理 []
	while (YES) {
		NSRange firstEnd = [effect rangeOfString:@"]"];
		if (firstEnd.location != NSNotFound) {
			NSRange lastStart = [effect rangeOfString:@"[" options:NSBackwardsSearch range:NSMakeRange(0, firstEnd.location + 1)];
			NSAssert(lastStart.location != NSNotFound, @"[ must exist because of ]");
			NSAssert(lastStart.location < firstEnd.location, nil);
			NSRange subCommandRange = NSMakeRange(lastStart.location, firstEnd.location - lastStart.location + 1);
			BOOL isPureID = YES;
			if ([effect characterAtIndex:lastStart.location - 1] == '@') {//数组
				subCommandRange = NSMakeRange(lastStart.location - 1, firstEnd.location + 1 - lastStart.location + 1);
				isPureID = NO;
			}
			NSString *subCommand = [command substringWithRange:subCommandRange];
			//NSLog(@"Tips: subcommand:%@", subCommand);
			NSString *variteName = [self newVariate];
			if (isPureID) {
				NSDictionary *variatesValue = [self valueFromPureID:subCommand];
				NSAssert([variatesValue isKindOfClass:[NSDictionary class]], nil);
				if ([variatesValue[@"type"] integerValue] == eStringUnknown) {
					NSLogToFile(@"Error: exec:%@ failed", subCommand);
					return variatesValue;
				}
				[self addVariatesValue:variatesValue withName:variteName];
			}else{
				[self addNewVariates:subCommand withName:variteName];
			}
			effect = [effect stringByReplacingCharactersInRange:subCommandRange withString:variteName];
			command = [command stringByReplacingCharactersInRange:subCommandRange withString:variteName];
		}else{
			NSAssert([effect rangeOfString:@"["].location == NSNotFound, nil);
			break;//已清除
		}
	}
	//NSLog(@"Tips: last name:%@", command);
	result = [self variateForName:command];
	[self pop];
	return result;
}
#pragma mark - string deal helpers

/**
 *	以 字符串seq 分割 字符串string ， 其中string会被致盲 - ""中的字符串会被忽略
 *
 *	@param seq    seq description
 *	@param string string description
 *
 *	@return return value description
 */
+ (NSString *)stringWithFormat:(NSString *)format array:(NSArray *)arguments
{
	void *argList = malloc(sizeof(NSObject *) * arguments.count);
    [arguments getObjects:(__unsafe_unretained id *)argList range:NSMakeRange(0, arguments.count)];
    NSString *result = [[NSString alloc] initWithFormat:format arguments:argList];
	free(argList);
    return result;
}
+ (NSArray *)componentsSeparatedByString:(NSString *)seq forBlindString:(NSString *)string
{
	NSString *blind = [self blindString:string];
	
	NSArray *blindComp = [blind componentsSeparatedByString:seq];
	return [self divisionString:string likeArray:blindComp];
}
/**
 *	以 字符串seq 分割 字符串string ， 其中string会被致盲 - ""中的字符串会被忽略
 *
 *	@param seq    seq description
 *	@param string string description
 *
 *	@return return value description
 */
+ (NSString *)stringByReplacingString:(NSString *)orgString
				  OccurrencesOfString:(NSString *)target
						   withString:(NSString *)replacement
							 andBlind:(BOOL)blind
{
	if (! blind) {
		return [orgString stringByReplacingOccurrencesOfString:target withString:replacement];
	}
	NSString *blindString = [self blindString:orgString];
	NSArray *blindComps = [blindString componentsSeparatedByString:target];
	NSArray *comps = [self divisionString:orgString likeArray:blindComps withInterspaceSize:target.length];
	NSMutableString *result = [NSMutableString stringWithCapacity:orgString.length - (comps.count - 1)*(target.length - replacement.length)];
	NSUInteger index = 0;
	for (NSString *elem in comps) {
		[result appendString:elem];
		if (index != comps.count - 1) {
			[result appendString:replacement];
		}
		index ++;
	}
	return [NSString stringWithString:result];
}
/**
 *	移出字符串两头的空格
 *
 *	@param value value description
 *
 *	@return return value description
 */
+ (NSString *)removeSpaceHeadAndEnd:(NSString *)value
{
	if (value.length == 0) {
		//NSLogToFile(@"Error: @"" string to remove");
		return nil;
	}
	NSInteger start = value.length;
	NSInteger end = -1;
	for (int i = 0; i < value.length; i++) {
		if ([value characterAtIndex:i] != ' ') {
			start = i;
			break;
		}
	}
	for (int i = 0; i < value.length; i++) {
		if ([value characterAtIndex:value.length - 1 - i] != ' ') {
			end = value.length - 1 - i;
			break;
		}
	}
	if (end < 0 || start >= value.length || end < start) {
		return nil;
	}
	return [value substringWithRange:NSMakeRange(start, end - start + 1)];
}
/**
 *	致盲 orgString， 将 "" 中的敏感字符弱化
 *
 *	@param orgString orgString description
 *
 *	@return return value description
 */
+ (NSString *)blindString:(NSString *)orgString
{
	// 0. 替换特殊字符
	// \符号替换, 及引号内数据盲化
	NSString *tmpString = orgString;
	unichar *buff = (unichar *)malloc(tmpString.length * sizeof(unichar));
	BOOL startQuot = NO;
	for (NSUInteger i = 0; i < tmpString.length; i++) {
		unichar uchar = [tmpString characterAtIndex:i];
		if (uchar == '\\') {
			buff[i] = 'a';
			if (i + 1 < tmpString.length) {
				buff[i+1] = 'b';
				i++;
			}
		}else if (uchar == '"' || startQuot) {
			if (uchar == '"' && startQuot) {
				startQuot = NO;
				buff[i] = '"';
			}else if (uchar == '"' && (!startQuot)) {
				buff[i] = '"';
				startQuot = YES;
			}else{
				NSAssert(uchar != '"' && startQuot, nil);
				buff[i] = 'd';
			}
		}else{
			buff[i] = uchar;
		}
	}
	NSString *effect = [NSString stringWithCharacters:buff length:tmpString.length];
	free(buff);
	//NSLog(@"Tips: effct:%@", effect);
	return effect;
}
/**
 *	按照 数组model 的形式分割 字符串orgString
 *
 *	@param orgString orgString description
 *	@param model     model description
 *
 *	@return return value description
 */
+ (NSArray *)divisionString:(NSString *)orgString likeArray:(NSArray *)model
{
	return [self divisionString:orgString likeArray:model withInterspaceSize:1];
}
+ (NSArray *)divisionString:(NSString *)orgString likeArray:(NSArray *)model withInterspaceSize:(NSUInteger)size
{
	NSMutableArray *tmpResult = [NSMutableArray arrayWithCapacity:model.count];
	NSUInteger index = 0;
	for (NSString *elem in model) {
		NSRange range = NSMakeRange(index, elem.length);
		NSAssert(index + elem.length <= orgString.length, nil);
		[tmpResult addObject:[orgString substringWithRange:range]];
		index += elem.length + size;
	}
	NSAssert(index == orgString.length + size, nil);
	NSAssert(tmpResult.count == model.count, nil);
	return [NSArray arrayWithArray:tmpResult];
}


#pragma mark -- deal object c grammar
/**
 *	循环查找 orgString 里可以直接识别的 NSRange
 *
 *	@param orgString orgString description
 *
 *	@return NSArray = success, NSError = invalid, nil = done
 */
+ (NSArray *)loopSearchKeysForString:(NSString *)orgString
{
//	static NSMutableCharacterSet *variateCharSet = nil;
//	static dispatch_once_t onceToken;
//	dispatch_once(&onceToken, ^{
//		variateCharSet = [[NSMutableCharacterSet alloc] init];
//		NSRange range = NSMakeRange((unsigned int)'a', 26);//小写字母
//		[variateCharSet addCharactersInRange:range];
//		range = NSMakeRange((unsigned int)'A', 26);//大写字母
//		[variateCharSet addCharactersInRange:range];
//		range = NSMakeRange((unsigned int)'0', 10);//数字
//		[variateCharSet addCharactersInRange:range];
//		range = NSMakeRange((unsigned int)'_', 1);//下划线
//		[variateCharSet addCharactersInRange:range];
//	});
	static NSMutableCharacterSet *varStartCharSet = nil;
	static NSMutableCharacterSet *numberCharSet = nil;
	static NSMutableCharacterSet *rightCharSet = nil;
	static NSMutableCharacterSet *uncleanCharSet = nil;
	static dispatch_once_t onceToken;
	static NSDictionary *mapDict = nil;
	dispatch_once(&onceToken, ^{
		varStartCharSet = [[NSMutableCharacterSet alloc] init];
		numberCharSet = [[NSMutableCharacterSet alloc] init];
		rightCharSet = [[NSMutableCharacterSet alloc] init];
		uncleanCharSet = [[NSMutableCharacterSet alloc] init];
		
		[rightCharSet addCharactersInString:@"@])}\""];
		[uncleanCharSet addCharactersInString:@"[]@"];
		[numberCharSet addCharactersInRange:NSMakeRange((unsigned int)'0', 10)];
		
		[varStartCharSet addCharactersInRange:NSMakeRange((unsigned int)'a', 26)];
		[varStartCharSet addCharactersInRange:NSMakeRange((unsigned int)'A', 26)];
		[varStartCharSet addCharactersInRange:NSMakeRange((unsigned int)'_', 1)];
		
		mapDict = @{@"@":numberCharSet,
					@"]":@"[",//特殊的
					@")":@"@(",
					@"}":@"@{",
					@"\"":@"@\"",
					};
	});
	NSString *blindString = [self blindString:orgString];
	NSUInteger currentIndex = 0;
	NSUInteger lastSucessNextIndex = 0;
	NSMutableArray *cleanRanges = [NSMutableArray array];
	while (YES) {
		if (currentIndex >= blindString.length) {
			break ;
		}
		NSRange searchRange = NSMakeRange(currentIndex, blindString.length - currentIndex);
		NSRange rightRange = [blindString rangeOfCharacterFromSet:rightCharSet options:0 range:searchRange];
		if (rightRange.location == NSNotFound) {
			break;
		}
		NSString *currentChar = [blindString substringWithRange:NSMakeRange(rightRange.location, 1)];
		NSAssert(mapDict[currentChar] != nil, nil);
		NSAssert(rightRange.location >= currentIndex, nil);
		
		// @123  NSNumber 特殊处理
		if ([currentChar isEqualToString:@"@"]) {
			if (rightRange.location < blindString.length - 1
				&& [numberCharSet characterIsMember:[blindString characterAtIndex:rightRange.location+1]]) {
				//紧挨着属于数字, 遍历紧接着的字符，直到非数字即可， 若属于字母或_, 则为非法
				NSInteger i = 0;
				for (i = rightRange.location + 1; i < blindString.length; i++) {
					unichar checkChar = [blindString characterAtIndex:i];
					if (! [numberCharSet characterIsMember:checkChar]) {
						if ([varStartCharSet characterIsMember:checkChar]) {//紧挨着数字的是字母， 即为非法
							NSString *errMsg = [NSString stringWithFormat:@"Invalid statement of <%@> an index:%zd", orgString, i];
							NSLogToFile(@"Error: %@", errMsg);
							return nil;//[NSError errorWithDomain:errMsg code:0 userInfo:nil];
						}
						break;
					}
				}
				//能到这里说明检测完了， 属于 NSNumber
				NSAssert(i-1 > rightRange.location, nil);
				NSRange cutRange = NSMakeRange(rightRange.location, i-1 - rightRange.location + 1);
				[cleanRanges addObject:[NSValue valueWithRange:cutRange]];
				lastSucessNextIndex = cutRange.location + cutRange.length;
				currentIndex = lastSucessNextIndex;
			}else {
				currentIndex = rightRange.location + 1;
				
			}
			continue;
		}
		
		if (rightRange.location == 0) {
			currentIndex = rightRange.location + 1;
			continue;
		}
		NSRange leftSearchRange = NSMakeRange(lastSucessNextIndex, rightRange.location - lastSucessNextIndex);
		NSRange leftRange = [blindString rangeOfString:mapDict[currentChar] options:NSBackwardsSearch range:leftSearchRange];
		if (leftRange.location == NSNotFound) {
			currentIndex = rightRange.location + 1;
			continue;
		}
		NSAssert(leftRange.location < rightRange.location, nil);
		
		NSRange checkRange = NSMakeRange(leftRange.location+1, rightRange.location - leftRange.location - 1);
		NSRange checkResult = [orgString rangeOfCharacterFromSet:uncleanCharSet options:0 range:checkRange];
		if (checkResult.location == NSNotFound) {//此段为干净的
			NSRange cutRange = NSMakeRange(leftRange.location, rightRange.location - leftRange.location + 1);
			if (leftRange.location > 0 && [orgString characterAtIndex:leftRange.location-1] == '@') {
				cutRange = NSMakeRange(cutRange.location - 1, cutRange.length+1);
			}
			[cleanRanges addObject:[NSValue valueWithRange:cutRange]];
			lastSucessNextIndex = cutRange.location + cutRange.length;
		}
		currentIndex = rightRange.location + 1;
	}
	
	if (cleanRanges.count == 0) {
		return nil;
	}
	return cleanRanges;
	
}

+ (NSArray *)analysisLeftString:(NSString *)orgString andIsNewValue:(BOOL *)isNew
{
	NSAssert(isNew != NULL, nil);
	NSAssert(orgString.length > 0, nil);
	*isNew = NO;
	NSRange rangePoint = [orgString rangeOfString:@"." options:NSBackwardsSearch];
	if (rangePoint.location == NSNotFound) {
		NSRange rangeSpace = [orgString rangeOfString:@" " options:NSBackwardsSearch];
		NSRange rangeStar = [orgString rangeOfString:@"*" options:NSBackwardsSearch];
		if (rangeStar.location != NSNotFound) {
			//对于 *abc = @"asf"; 暂不支持
			NSAssert(rangeStar.location > 0 && rangeStar.location < orgString.length-1, nil);
			*isNew = YES;
			NSString *result = [orgString substringFromIndex:rangeStar.location+1];
			NSAssert(result.length > 0, nil);
			return [NSArray arrayWithObject:result];
		}else if (rangeSpace.location != NSNotFound) {
			NSAssert(rangeSpace.location > 0 && rangeSpace.location < orgString.length-1, nil);
			*isNew = YES;
			NSString *result = [orgString substringFromIndex:rangeSpace.location+1];
			NSAssert(result.length > 0, nil);
			return [NSArray arrayWithObject:result];
		}else{//普通变量
			return [NSArray arrayWithObject:orgString];
		}
	}else{
		NSString *head = [orgString substringToIndex:rangePoint.location];
		NSString *end = [orgString substringFromIndex:rangePoint.location + 1];
		if (head.length == 0 || end.length == 0) {
			NSLogToFile(@"Error: Invalid left string:%@", orgString);
			return nil;
		}
		return [NSArray arrayWithObjects:head, end, nil];
	}
//	static NSMutableCharacterSet *variateCharSet = nil;
//	static dispatch_once_t onceToken;
//	dispatch_once(&onceToken, ^{
//		variateCharSet = [[NSMutableCharacterSet alloc] init];
//		NSRange range = NSMakeRange((unsigned int)'a', 26);//小写字母
//		[variateCharSet addCharactersInRange:range];
//		range = NSMakeRange((unsigned int)'A', 26);//大写字母
//		[variateCharSet addCharactersInRange:range];
//		range = NSMakeRange((unsigned int)'0', 10);//数字
//		[variateCharSet addCharactersInRange:range];
//		range = NSMakeRange((unsigned int)'_', 1);//下划线
//		[variateCharSet addCharactersInRange:range];
//	});

}

/**
 *	获取点方法的值
 *
 *	@param orgString   method description
 *
 *	@return return value description
 */
+ (NSString *)getMethodPointSubString:(NSString *)orgString
{
	NSAssert(orgString.length > 0, nil);
	NSArray *compsPoint = [orgString componentsSeparatedByString:@"."];//get 方法
	NSArray *compsSub = [orgString componentsSeparatedByString:@"["];//下标
	NSAssert(compsPoint.count > 1 || compsSub.count > 1, @"if this is point method, '.'/'[]' must exist");
	NSString *statement = nil;
	
	NSUInteger nextIndex = 0;
	NSInteger type = 0;//0=None 1=. 2=[]
	NSUInteger leftCount = 0;
	NSUInteger elemCount = 0;
	for (NSUInteger i = 0; i < orgString.length; i++) {
		unichar uchar = [orgString characterAtIndex:i];
		if (uchar == '.') {
			if (leftCount != 0) {
				NSLogToFile(@"Error: unsupport variateForName with <%@> for array[.]", orgString);
				return nil;
			}
			type = 1;
		}else if (uchar == '[') {
			leftCount ++;
			if (elemCount == 0) {
				statement = [orgString substringWithRange:NSMakeRange(nextIndex, i - nextIndex)];
				NSAssert(statement.length > 0, nil);
				elemCount ++;
			}
			nextIndex = i;
		}else if (uchar == ']') {
			if (leftCount != 1) {
				NSLogToFile(@"Error: variateForName failed with <%@> of '%c' for ungroup '['", orgString, uchar);
				return nil;
			}
			type = 2;
			leftCount = 0;
		}else if (! (uchar == '_'
					 || (uchar >= 'A'&&uchar <= 'Z')
					 || (uchar >= 'a'&&uchar <= 'z')
					 || (uchar >= '0'&&uchar <= '9')
					 || leftCount != 0)) {
			NSLogToFile(@"Error: variateForName failed with <%@> of '%c'", orgString, uchar);
			return nil;
		}
		if (type == 0 && i == orgString.length - 1) {
			NSAssert(statement.length > 0, nil);
			i++;//向后偏移一位， 统一处理
			type = 1;
		}
		if (type != 0) {
			NSString *elem = [orgString substringWithRange:NSMakeRange(nextIndex, i - (nextIndex))];
			if (type == 2) {
				elem = [orgString substringWithRange:NSMakeRange(nextIndex + 1, i - (nextIndex + 1))];
			}
			
			if (elemCount == 0) {
				statement = elem;
			}else{
				NSAssert(statement.length > 0, nil);
				if (type == 1) {//.
					statement = [NSString stringWithFormat:@"[%@ valueForKey:@\"%@\"]", statement, elem];
				}else if (type == 2) {//[]
					NSDictionary *subValue = [self variateFromString:elem];
					if ([subValue[@"type"] integerValue] == eStringNSObject) {
						statement = [NSString stringWithFormat:@"[%@ objectForKeyedSubscript:%@]", statement, elem];
					}else if ([subValue[@"type"] integerValue] == eStringInteger) {
						statement = [NSString stringWithFormat:@"[%@ objectAtIndexedSubscript:%@]", statement, elem];
					}else{
						NSLogToFile(@"Error: subIndex invalid with <%@>", elem);
						return nil;
					}
				}
			}
			nextIndex = i + 1;
			elemCount++;
			type = 0;
		}
		
		
	}
	
	
//	for (NSString *elem in compsPoint) {
//		NSAssert(elem.length > 0, @"elem should be > 0");
//		if (index == 0) {
//			statement = elem;
//		}else{
//			
//			statement = [NSString stringWithFormat:@"[%@ valueForKey:@\"%@\"]", statement, elem];
//		}
//		index ++;
//	}
	
	return statement;
}

+ (BOOL)setMethod:(NSString *)method withReciever:(NSString *)reciever andNewValueName:(NSString *)newValueName
{
	NSAssert(reciever.length > 0 && method.length > 0, nil);
	unichar firstChar = [method characterAtIndex:0];
	NSString *newMethod = nil;
	if (firstChar >= 'a' && firstChar <= 'z') {
		firstChar = firstChar + 'A' - 'a';
		newMethod = [method stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[NSString stringWithCharacters:&firstChar length:1]];
	}
	//NSString *statement = [NSString stringWithFormat:@"[%@ set%@:%@]", reciever, method, newValueName];
	NSString *statement = [NSString stringWithFormat:@"[%@ setValue:%@ forKey:@\"%@\"]", reciever, newValueName, method];
	NSDictionary *dictResult = [self valueFromPureID:statement];
	if ([dictResult[@"type"] integerValue] == eStringUnknown) {
		return NO;
	}
	NSAssert([dictResult[@"type"] integerValue] == eStringVoid, @"set should not return any value");
	return YES;
}
/**
 *	按照 object C 语法格式化字符串
 *
 *	@param command command description
 *
 *	@return return value description
 */
+ (NSString *)formatObjectCCommand:(NSString *)command
{
	NSAssert([command isKindOfClass:[NSString class]], nil);
	// 1. 去除 \r \n
	command = [self stringByReplacingString:command OccurrencesOfString:@"\r" withString:@"" andBlind:YES];
	command = [self stringByReplacingString:command OccurrencesOfString:@"\n" withString:@"" andBlind:YES];
	command = [self stringByReplacingString:command OccurrencesOfString:@"\t" withString:@" " andBlind:YES];
	command = [self uniquifyString:command withChars:[NSCharacterSet characterSetWithCharactersInString:@" "] andBlind:YES];
	
	// 2. 不可以包含 不支持的字符, 因为现在不支持
	NSString *blindCommand = [self blindString:command];
	NSMutableCharacterSet *unsupportCharSet = [[NSMutableCharacterSet alloc] init];
	[unsupportCharSet addCharactersInString:@"+-/*?|%!~^&<>"];
	NSRange unsupportRange = [blindCommand rangeOfCharacterFromSet:unsupportCharSet];
	if (unsupportRange.location != NSNotFound) {
		NSLogToFile(@"Error: cant support command with any Character of %@ for '%c'", unsupportCharSet, [blindCommand characterAtIndex:unsupportRange.location]);
		return nil;
	}
	
	// 3. 不能有 ==
	if ([blindCommand rangeOfString:@"=="].location != NSNotFound) {
		NSLogToFile(@"Error: cant support command with any Character of ==");
		return nil;
	}
	
	// 4. 唯一化 空格 和 ;
	//command = [self removeSpaceForObjectCCommand:command];
	NSMutableCharacterSet *charSet = [[NSMutableCharacterSet alloc] init];
	[charSet addCharactersInString:@" ;"];
	command = [self uniquifyString:command withChars:charSet andBlind:YES];
	
	return command;
}
+ (NSString *)removeSpaceForObjectCCommand:(NSString *)orgString
{
	// 1. 保证空格只有一个
	NSMutableCharacterSet *spaceCharSet = [[NSMutableCharacterSet alloc] init];
	[spaceCharSet addCharactersInString:@" "];
	orgString = [self uniquifyString:orgString withChars:spaceCharSet andBlind:YES];
	
	NSString *blindString = [self blindString:orgString];
	NSAssert(blindString.length == orgString.length, nil);
	
	NSMutableCharacterSet *charSet = [[NSMutableCharacterSet alloc] init];
	[charSet addCharactersInString:@"{}+-/*?|%!~^&<>"];
	[charSet addCharactersInString:@"@#$()=[]:;'\",."];
	
	
	NSString *tmpString = orgString;
	unichar *buff = (unichar *)malloc(tmpString.length * sizeof(unichar));
	BOOL isLastSpecial = NO;
	BOOL isLastSpace = NO;
	NSUInteger index = 0;
	for (NSUInteger i = 0; i < tmpString.length; i++) {
		unichar uchar = [blindString characterAtIndex:i];
		if (uchar == ' ') {
			NSAssert(isLastSpace == NO, @"space had been uniquify before");
			isLastSpace = YES;
			if (isLastSpecial) {
				isLastSpecial = NO;
				continue;
			}
			isLastSpecial = NO;
			buff[index] = uchar;
		}else if ([charSet characterIsMember:uchar]) {
			if (isLastSpace) {
				index --;
			}
			isLastSpace = NO;
			isLastSpecial = YES;
			buff[index] = uchar;
		}else{
			isLastSpecial = NO;
			isLastSpace = NO;
			buff[index] = [tmpString characterAtIndex:i];
		}
		index ++;
	}

	NSString *result = [NSString stringWithCharacters:buff length:index];
	free(buff);
	return result;
}

/**
 *	将 字符串orgString 里连续的 charSet 字符变成一个
 *
 *	@param orgString orgString description
 *	@param charSet   charSet description
 *
 *	@return return value description
 */
+ (NSString *)uniquifyString:(NSString *)orgString withChars:(NSCharacterSet *)charSet andBlind:(BOOL)blind
{
	NSAssert(! ([charSet characterIsMember:'\\']
			 || [charSet characterIsMember:'a']
			 || [charSet characterIsMember:'b']
			 || [charSet characterIsMember:'d']
			 || [charSet characterIsMember:'"']), @"function blindString use this");
	NSString *blindString = nil;
	if (blind) {
		blindString = [self blindString:orgString];
		NSAssert(blindString.length == orgString.length, nil);
	}
	unichar *newBuff = (unichar *)malloc(orgString.length * sizeof(unichar));
	unichar lastChar = 0;
	NSUInteger index = 0;
	for (NSUInteger i = 0; i < orgString.length; i++) {
		unichar elem = 0;
		if (blind) {
			elem = [blindString characterAtIndex:i];
		}else{
			elem = [orgString characterAtIndex:i];
		}
		
		if (lastChar == elem) {
			continue;
		}else{
			if ([charSet characterIsMember:elem]) {
				lastChar = elem;
			}else{
				lastChar = 0;
			}
		}
		if (blind) {
			newBuff[index] = [orgString characterAtIndex:i];
		}else{
			newBuff[index] = elem;
		}
		index ++;
	}
	NSString *result = [NSString stringWithCharacters:newBuff length:index];
	free(newBuff);
	return result;
}

#pragma mark - string detection
+ (eStringtype)typeOfVariate:(NSDictionary *)dict
{
	NSAssert([dict isKindOfClass:[NSDictionary class]], nil);
	return (eStringtype)[dict[@"type"] integerValue];
}
/**
 *	检测字符串类型
 *
 *	@param string string description
 *
 *	@return return value description
 */
+ (eStringtype)variateTypeFromString:(NSString *)string
{
	NSAssert([string isKindOfClass:[NSString class]], nil);
	unichar start = [string characterAtIndex:0];
	eStringtype type = eStringUnknown;
	if (start >= '0' && start <= '9') {//数字
		type = eStringInteger;
		for (NSInteger i = 0; i < string.length; i ++) {
			unichar theChar = [string characterAtIndex:0];
			if (theChar == '.') {
				type = eStringFloat;
			}else if (! (start >= '0' && start <= '9')){
				NSLog(@"Invalid number:%@, %zd", string, i);
				return type;
			}
		}
	}else{
		switch (start) {
			case '@':
			{
				if (string.length == 1) {
					NSLog(@"Invalid arg:%@", string);
					return type;
				}
				unichar second = [string characterAtIndex:1];
				switch (second) {
					case '[':
						if ([string characterAtIndex:string.length - 1] != ']') {
							NSLog(@"Invalid arg:%@", string);
							return type;
						}
						type = eStringNSArray;
						break;
					case '{':
						if ([string characterAtIndex:string.length - 1] != '}') {
							NSLog(@"Invalid arg:%@", string);
							return type;
						}
						type = eStringNSDictionary;
						break;
					case '(':
						if ([string characterAtIndex:string.length - 1] != ')') {
							NSLog(@"Invalid arg:%@", string);
							return type;
						}
						type = eStringNSNumberMore;
						break;
					case '"':
						if ([string characterAtIndex:string.length - 1] != '"') {
							NSLog(@"Invalid arg:%@", string);
							return type;
						}
						type = eStringNSString;
						break;
					default:
						//剩下的只有数字了
						if (! (second >= '0' && second <= '9')) {
							if ([string characterAtIndex:string.length - 1] != '"') {
								NSLog(@"Invalid arg:%@", string);
								return type;
							}
						}
						type = eStringNSNumber;
						break;
				}
				
				break;
			}
			case '[':
				if ([string characterAtIndex:string.length - 1] != ']') {
					NSLog(@"Invalid arg:%@", string);
					return type;
				}
				type = eStringID;
				break;
			default:
				if ([string isEqualToString:@"nil"]) {
					type = eStringNil;
				}else{
					//变量
					if (! (start == '_' || (start >= 'A'&&start <= 'Z') || (start >= 'a'&&start <= 'z'))) {
						type = eStringUnknown;
					}else{
						if (kFlagDebug) {
							NSDictionary *dictValue = [self variateForName:string];
							if ([dictValue[@"type"] integerValue] == eStringUnknown) {
								NSLogToFile(@"Error: undefine variate for '%@'", string);
								return type;
							}
						}
						
						type = eStringVariate;
					}
					
				}
				
				break;
		}
	}
	return type;
}

/**
 *	根据指定类别翻译字符串
 *
 *	@param string string description
 *	@param type   type description
 *
 *	@return return value description
 */
+ (NSDictionary *)variatesFromString:(NSString *)string andType:(eStringtype)type
{
	//NSAssert(type != eStringUnknown, nil);
	if (type == eStringUnknown) {
		NSLogToFile(@"Error: cant parse variate of <%@>", string);
		return @{@"type":[NSNumber numberWithInteger:eStringUnknown]};
	}
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:2];
	switch (type) {
		case eStringInteger:
			result[@"type"] = [NSNumber numberWithInteger:eStringInteger];
			result[@"value"] = [self valueFromInteger:string];
			break;
		case eStringFloat:
			result[@"type"] = [NSNumber numberWithInteger:eStringFloat];
			result[@"value"] = [self valueFromFloat:string];
			break;
		case eStringNSString:
		{
			id value = [self valueFromNSString:string];
			if (value) {
				result[@"type"] = [NSNumber numberWithInteger:eStringNSObject];
				result[@"value"] = value;
			}
			
			break;
		}
		case eStringNSNumber:
		{
			id value = [self valueFromNSNumber:string];
			if (value) {
				result[@"type"] = [NSNumber numberWithInteger:eStringNSObject];
				result[@"value"] = value;
			}
			break;
		}
		case eStringNSNumberMore:
		{
			id value = [self valueFromNSNumberMore:string];
			if (value) {
				result[@"type"] = [NSNumber numberWithInteger:eStringNSObject];
				result[@"value"] = value;
			}
			break;
		}
		case eStringNSArray:
		{
			id value = [self valueFromNSArray:string];
			if (value) {
				result[@"type"] = [NSNumber numberWithInteger:eStringNSObject];
				result[@"value"] = value;
			}
			break;
		}
		case eStringNSDictionary:
		{
			id value = [self valueFromNSDictionary:string];
			if (value) {
				result[@"type"] = [NSNumber numberWithInteger:eStringNSObject];
				result[@"value"] = value;
			}
			break;
		}
		case eStringID:
			result = (NSMutableDictionary *)[self valueFromID:string];
			break;
		case eStringNil:
			result[@"type"] = [NSNumber numberWithInteger:eStringNSObject];
			break;
		case eStringVariate:
		{
			result = (NSMutableDictionary *)[self variateForName:string];
			break;
		}
		default:
			NSAssert(NO, @"unsupport");
			break;
	}
	return [NSDictionary dictionaryWithDictionary:result];
}

#pragma mark - test


@end
