//
//  ViewController.m
//  testCrash
//
//  Created by yanghao on 2017/5/13.
//  Copyright © 2017年 justlike. All rights reserved.
//

#import "ViewController.h"
#import "YHCatchProxy.h"
#import "YHCatchFree.h"

@class YHTestCrash;
@protocol YHTestCrashDelegate <NSObject>
- (void)callout:(YHTestCrash *)request;
@end

@interface YHTestCrash : NSObject
@property (nonatomic,strong) NSTimer *timer;
@property (nonatomic,assign) id<YHTestCrashDelegate> delegate;//模拟iOS9以前的delegate用assign修饰的情况
@end

@implementation YHTestCrash

- (void)foo {
	// self被delegate持有
	[self.delegate callout:self]; // 外部释放了这个对象
	
	__weak typeof(self) weakself = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[weakself.delegate callout:weakself];
	});
	
	//	self.timer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(ddd) userInfo:nil repeats:NO];
	//	NSRunLoop *runloop = [NSRunLoop currentRunLoop];
	//	[runloop addTimer:self.timer forMode:NSRunLoopCommonModes];
	
}

- (void)ddd
{
	//	__strong typeof(self) weakself = self;
	[self.delegate callout:self]; // 外部释放了这个对象
	//	[self.timer invalidate];
}

@end


@interface YHTestCrashA : NSObject<YHTestCrashDelegate>
@property (nonatomic, strong) YHTestCrash *request;
@end
@implementation YHTestCrashA

- (void)foo
{
	self.request = [[YHTestCrash alloc]init];
	self.request.delegate = self;
	[self.request foo];
}
- (void)callout:(YHTestCrash *)request
{
	//	self.request = nil;
	NSLog(@"callout: %@",request);
}

@end


@interface ViewController ()
//@property (nonatomic, strong) YHTestCrashA *request;
@property (nonatomic, strong) NSMutableArray *array;
@end

@implementation ViewController


- (void)viewDidLoad {
	[super viewDidLoad];
	
	id obj = [[UIView alloc] init];
	__unsafe_unretained id obj1 = obj;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		NSLog(@"%@",obj1);
		if (!obj1) {
			return ;
		}
		[obj1 setNeedsLayout];
		//		[obj1 count];
	});
	
	
	for (int i = 0; i < 10000; i++) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			self.array = [[NSMutableArray alloc] init];
		});
	}
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	YHTestCrashA *request = [[YHTestCrashA alloc]init];
	[request foo];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (void)dealloc
{
	
}

@end







