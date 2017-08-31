//
//  SoundsPlayer.h
//  MOA
//
//  Created by neo on 13-12-4.
//  Copyright (c) 2013年 moa. All rights reserved.
//

typedef enum eSoundType {
	eSoundTypeShort = 0,//短声音, 小于30秒
	eSoundTypeMusic,//背景音乐式, 大于30秒
}SoundType;

#import <Foundation/Foundation.h>

@interface SoundsPlayer : NSObject
- (BOOL)registerName:(NSString *)name forSoundWithPath:(id)path andType:(SoundType)type;
- (BOOL)playSoundWithRegisterName:(NSString *)name;
+ (SoundsPlayer *)defaultInstance;
@end
