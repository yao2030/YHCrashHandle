//
//  MOAGifMaker.m
//  MOA
//
//  Created by neo on 14-10-11.
//  Copyright (c) 2014年 moa. All rights reserved.
//

#import "MOAGifMaker.h"
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

static UIImage *frameImage(CGSize size, CGFloat radians)
{
	UIGraphicsBeginImageContextWithOptions(size, YES, 1); {
		[[UIColor whiteColor] setFill];
		UIRectFill(CGRectInfinite);
		CGContextRef gc = UIGraphicsGetCurrentContext();
		CGContextTranslateCTM(gc, size.width / 2, size.height / 2);
		CGContextRotateCTM(gc, radians);
		CGContextTranslateCTM(gc, size.width / 4, 0);
		[[UIColor redColor] setFill];
		CGFloat w = size.width / 10;
		CGContextFillEllipseInRect(gc, CGRectMake(-w / 2, -w / 2, w, w));
	}
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

static void makeAnimatedGif(void)
{
	static NSUInteger kFrameCount = 16;
 
	NSDictionary *fileProperties = @{(__bridge id)kCGImagePropertyGIFDictionary: @{
            (__bridge id)kCGImagePropertyGIFLoopCount: @0, // 0 means loop forever
			}
									 };
 
	NSDictionary *frameProperties = @{
									  (__bridge id)kCGImagePropertyGIFDictionary: @{
											  (__bridge id)kCGImagePropertyGIFDelayTime: @0.02f, // a float (not double!) in seconds, rounded to centiseconds in the GIF data
											  }
									  };
 
	NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
	NSURL *fileURL = [documentsDirectoryURL URLByAppendingPathComponent:@"animated.gif"];
	
	CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)fileURL, kUTTypeGIF, kFrameCount, NULL);
	CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)fileProperties);
 
	for (NSUInteger i = 0; i < kFrameCount; i++) {
		@autoreleasepool {
			UIImage *image = frameImage(CGSizeMake(300, 300), M_PI * 2 * i / kFrameCount);
			CGImageDestinationAddImage(destination, image.CGImage, (__bridge CFDictionaryRef)frameProperties);
		}
	}
 
	if (!CGImageDestinationFinalize(destination)) {
		NSLog(@"failed to finalize image destination");
	}
	CFRelease(destination);
 
	NSLog(@"url=%@", fileURL);
}

@interface MOAGifMaker ()
@property (nonatomic, strong) NSDate *lastAddFrameTime;//上次添加 frame 的时间点
@property (nonatomic) NSInteger frameCount;//总帧数
@property (nonatomic) NSTimeInterval frameDuring;//总时长

@property (nonatomic, strong) NSMutableData *imageData;
@property (nonatomic) struct CGImageDestination *destinationRef;
@end

@implementation MOAGifMaker
+ (instancetype)shareInstance
{
	static MOAGifMaker *maker = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		maker = [[MOAGifMaker alloc] init];
	});
	return maker;
}
- (void)test
{
	makeAnimatedGif();
}
+ (NSData *)createWithOption:(NSDictionary *)option andImages:(NSArray *)images andImageTimePoints:(NSArray *)timePoints
{
	if (images.count == 0) {
		return nil;
	}
	NSAssert(images.count == timePoints.count, nil);
	NSInteger frameCount = 50;// max count = 50 Frame (1 Frame --max--> 40KB)
	if (frameCount > images.count) {
		// todo: 修正 images 帧
		frameCount = images.count;
	}
	
	
	NSDictionary *fileProperties = @{(__bridge id)kCGImagePropertyGIFDictionary: @{
            (__bridge id)kCGImagePropertyGIFLoopCount: @0, // 0 means loop forever
			}
									 };
	
	NSMutableData *imageData = [[NSMutableData alloc] init];
	
	CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)imageData, kUTTypeGIF, frameCount, NULL);
	CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)fileProperties);
	
	NSDate *lastDate = timePoints[0];
	NSDictionary *frameProperties = @{
									  (__bridge id)kCGImagePropertyGIFDictionary: [NSMutableDictionary dictionaryWithDictionary:@{
											  (__bridge id)kCGImagePropertyGIFDelayTime: @0.02f, // a float (not double!) in seconds, rounded to centiseconds in the GIF data
											  }]
									  };
	for (NSUInteger i = 0; i < frameCount; i++) {
		@autoreleasepool {
			UIImage *image = images[i];
			
			NSDate *currentDate = timePoints[i];
			if (! [image isKindOfClass:[UIImage class]]) {
				lastDate = currentDate;
				continue;
			}
			NSTimeInterval frameTime = [currentDate timeIntervalSinceDate:lastDate];
			frameProperties[(__bridge id)kCGImagePropertyGIFDictionary][(__bridge id)kCGImagePropertyGIFDelayTime] = @((CGFloat)frameTime);
			CGImageDestinationAddImage(destination, image.CGImage, (__bridge CFDictionaryRef)frameProperties);
			lastDate = currentDate;
		}
	}
	
	if (!CGImageDestinationFinalize(destination)) {
		NSLog(@"failed to finalize image destination");
	}
	CFRelease(destination);
	
	return imageData;
}

@end
