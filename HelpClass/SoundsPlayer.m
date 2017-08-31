//
//  SoundsPlayer.m
//  MOA
//
//  Created by neo on 13-12-4.
//  Copyright (c) 2013年 moa. All rights reserved.
//

#import "SoundsPlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import "MOASetInfo.h"
#import "EntrysOperateHelper.h"

@interface SoundsPlayer ()
@property (nonatomic, strong) NSMutableDictionary *soundConfig;

@end
static NSMutableSet *s_soundPlayingSet = nil;
static NSDate *lastPlaySoudDate;
@implementation SoundsPlayer

- (id)init
{
	self = [super init];
	if (self) {
		[self registerName:kMuteSound forSoundWithPath:kMuteSound andType:eSoundTypeShort];
	}
	return self;
}

+ (SoundsPlayer *)defaultInstance
{
	static SoundsPlayer *player = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		player = [[SoundsPlayer alloc] init];
		[player registerName:kIMSound forSoundWithPath:kIMSound andType:eSoundTypeShort];
		[player registerName:kIMSoundInIM forSoundWithPath:kIMSoundInIM andType:eSoundTypeShort];
        [player registerName:kUntreatedSound forSoundWithPath:kUntreatedSound andType:eSoundTypeShort];
        [player registerName:kNoticeSound forSoundWithPath:kNoticeSound andType:eSoundTypeShort];
        [player registerName:kSignInSound forSoundWithPath:kSignInSound andType:eSoundTypeShort];
        [player registerName:kWorkAttendanceSound forSoundWithPath:kWorkAttendanceSound andType:eSoundTypeShort];
        [player registerName:kProcessSound forSoundWithPath:kProcessSound andType:eSoundTypeShort];
        [player registerName:kAutoSignSuccessedSound forSoundWithPath:kAutoSignSuccessedSound andType:eSoundTypeShort];
	});
	return player;
}

//save for sound config
/*
 NSString:@{@"ID":NSNumber, @"type":NSNumber}
 */
- (NSMutableDictionary *)soundConfig
{
	if (_soundConfig == nil) {
		_soundConfig = [[NSMutableDictionary alloc] init];
	}
	return _soundConfig;
}
+ (NSMutableSet *)soundPlayingSet
{
	if (s_soundPlayingSet == nil) {
		s_soundPlayingSet = [NSMutableSet set];
	}
	return s_soundPlayingSet;
}
- (void)dealloc
{
	NSArray *allKeys = [self.soundConfig allKeys];
	for (NSString *key in allKeys) {
		NSInteger type = [self.soundConfig[key][@"type"] integerValue];
		if (type == eSoundTypeShort) {
			NSNumber *systemID = self.soundConfig[key][@"ID"];
			AudioServicesDisposeSystemSoundID([systemID integerValue]);
		}else{
			NSLogToFile(@"Bug: unsupport type: %@", self.soundConfig[key]);
		}
	}
	
	if (s_soundPlayingSet != nil) {
		s_soundPlayingSet = nil;
	}
}
/**
 *  注册声音文件 path 为 name
 *  @param name 需要注册的名字
 *  @param path NSString(bundle) > NSString(path) > NSURL(NSURL),
 *  @param type type description
 *
 *  @return return value description
 */
- (BOOL)registerName:(NSString *)name forSoundWithPath:(id)path andType:(SoundType)type
{
	//name=nil ==> default
	if (name == nil) {
		name = @"";
	}
	NSString *filePath = [SoundsPlayer pathWithNameOrPathOrURL:path];
	if (filePath == nil) {
		return NO;
	}
	if (type == eSoundTypeShort) {
		SystemSoundID systemID = 0;
		AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:filePath], &systemID);
		if (self.soundConfig[name] != nil) {
			NSNumber *oldSystemID = self.soundConfig[name][@"ID"];
			AudioServicesDisposeSystemSoundID([oldSystemID integerValue]);
			[self.soundConfig removeObjectForKey:name];
		}
		self.soundConfig[name] = @{
								   @"ID":[NSNumber numberWithInteger:systemID],
								   @"type":[NSNumber numberWithInteger:type]
								   };
	}else{
		NSLogToFile(@"Warn: unsupport sound type:%d", type);
	}
	
	return YES;
}

- (BOOL)playSoundWithRegisterName:(NSString *)registerName
{
    NSTimeInterval interval = 0;
    if (lastPlaySoudDate) {
        interval = [[NSDate date]timeIntervalSinceDate:lastPlaySoudDate];
    }
    //较小时间间隔内不重复播放声音。正常情况interval不会小于0,除非用户修改了系统时间
    if (interval>0&&interval<0.5) {
        return YES;
    }
    lastPlaySoudDate = [NSDate date];
	__weak typeof(self) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		NSNumber *shouldSound = [MOASetInfo objectForKey:@"Sound"];
		NSNumber *shouldVibrate = [MOASetInfo objectForKey:@"Shake"];
		NSString *name = registerName;
		if (name == nil) {
			name = @"";
		}
		if (weakSelf.soundConfig[name] == nil) {
			NSLogToFile(@"Warn: name(%@) hadnt been register for play sound", name);
			return ;
		}
		NSInteger type = [self.soundConfig[name][@"type"] integerValue];
		
		
		
		if (type == eSoundTypeShort) {
			
			//检查是否需要震动
			if ([shouldVibrate isEqualToNumber:@YES]) {
				AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
			}
			
			//检查是否需要声音
			if ([shouldSound isEqualToNumber:@NO]) {
				return ;
			}
			
			//读取对应的sound ID
			NSInteger systemID = [weakSelf.soundConfig[name][@"ID"] integerValue];
			AudioServicesPlaySystemSound(systemID);
			
			//播放测试声音
			NSInteger muteID = [weakSelf.soundConfig[kMuteSound][@"ID"] integerValue];
			AudioServicesPlaySystemSound(muteID);
			
			static NSInteger soundPlayIndex = 0;
			soundPlayIndex ++;
			NSInteger currentIndex = soundPlayIndex;
			
			[[SoundsPlayer soundPlayingSet] addObject:[NSNumber numberWithInteger:currentIndex]];
			
			// Register the sound completion callback.
			//NSLog(@"Add %d", currentIndex);
			OSStatus state = AudioServicesAddSystemSoundCompletion(
												  muteID,
												  NULL, // uses the main run loop
												  NULL, // uses kCFRunLoopDefaultMode
												  soundCompletePlayingCallback, // the name of our custom callback function
												  (void *)currentIndex // for user data, but we don't need to do that in this case, so we just pass NULL
												  );
			if (state != 0) {
				NSString *errString = [EntrysOperateHelper FormatError:state];
				NSLog(@"failed to register:%zd, %@", state, errString);
				return;
			}
			static float time = 0.5f;
			//NSLog(@"%f", time);
			// fire the timer
			[NSTimer scheduledTimerWithTimeInterval:time
											 target:weakSelf
										   selector:@selector(timerFireMethod:)
										   userInfo:@{@"ID":[NSNumber numberWithInteger:muteID],
													  @"Index":[NSNumber numberWithInteger:currentIndex]}
											repeats:NO];

			
						
		}

	});
	
	return YES;
}
void soundCompletePlayingCallback(SystemSoundID soundID, void* userData)
{
	AudioServicesRemoveSystemSoundCompletion(soundID);
	
	NSInteger soundPlayIndex = (NSInteger)userData;
	//NSLog(@"CompletePlayingCallback:%d", soundPlayIndex);
	[[SoundsPlayer soundPlayingSet] removeObject:[NSNumber numberWithInteger:soundPlayIndex]];
}

- (void)timerFireMethod:(NSTimer *)timer
{
	//NSLog(@"timerFireMethod");
	NSDictionary *soundCOnfig = timer.userInfo;
	if (soundCOnfig == nil) {
		return;
	}
	NSInteger soundID = [soundCOnfig[@"ID"] integerValue];
	NSNumber *soundIndex = soundCOnfig[@"Index"];
	//NSLog(@"recv index:%@", soundIndex);
	//检查是否已播放, 若, 则振动
	if ([[SoundsPlayer soundPlayingSet] containsObject:soundIndex]) {
		//NSLog(@"contain");
		NSNumber *shouldSound = [MOASetInfo objectForKey:@"Sound"];
		if ([shouldSound isEqual:@YES]) {
			AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
		}
		AudioServicesRemoveSystemSoundCompletion(soundID);
		[[SoundsPlayer soundPlayingSet] removeObject:soundIndex];
	}
}
/**
 *  根据path转换成有效地path, 若不存在则返回nil.
 *
 *  @param path NSString(bundle) > NSString(path) > NSURL(NSURL),
 *
 *  @return return value description
 */
+ (NSString *)pathWithNameOrPathOrURL:(id)path
{
	if (path == nil) {
		return nil;
	}
	if ([path isKindOfClass:[NSString class]]) {
		//bundle
		NSString *bundlePath = [[NSBundle mainBundle] pathForResource:path ofType:nil];
		if(bundlePath != nil){
			path = bundlePath;
		}
	}else if ([path isKindOfClass:[NSURL class]]) {
		path = [(NSURL*)path path];
	}else{
		NSLogToFile(@"Bug: unknown arg class:(%@) for registerSoundWithPath", path);
		return nil;
	}
	//check if exist
	if (! [[NSFileManager defaultManager] fileExistsAtPath:path]) {
		NSLogToFile(@"Warn: file path (%@) dont exist", path);
		return nil;
	}
	return path;
}
@end
