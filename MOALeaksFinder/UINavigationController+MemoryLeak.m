//
//  UINavigationController+MemoryLeak.m
//  MOA
//
//  Created by yanghao on 16/7/27.
//  Copyright © 2016年 moa. All rights reserved.
//
#import "UINavigationController+MemoryLeak.h"
#import "NSObject+MemoryLeak.h"
#import <objc/runtime.h>

#if _INTERNAL_MLF_ENABLED

static const void *const kPoppedDetailVCKey = &kPoppedDetailVCKey;

@implementation UINavigationController (MemoryLeak)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleSEL:@selector(pushViewController:animated:) withSEL:@selector(swizzled_pushViewController:animated:)];
        [self swizzleSEL:@selector(popViewControllerAnimated:) withSEL:@selector(swizzled_popViewControllerAnimated:)];
        [self swizzleSEL:@selector(popToViewController:animated:) withSEL:@selector(swizzled_popToViewController:animated:)];
        [self swizzleSEL:@selector(popToRootViewControllerAnimated:) withSEL:@selector(swizzled_popToRootViewControllerAnimated:)];
    });
}

- (void)swizzled_pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    
    [self swizzled_pushViewController:viewController animated:animated];
}

- (UIViewController *)swizzled_popViewControllerAnimated:(BOOL)animated {
    UIViewController *poppedViewController = [self swizzled_popViewControllerAnimated:animated];
    
    if (!poppedViewController) {
        return nil;
    }
	
    // VC is not dealloced until disappear when popped using a left-edge swipe gesture
    extern const void *const kHasBeenPoppedKey;
    objc_setAssociatedObject(poppedViewController, kHasBeenPoppedKey, @(YES), OBJC_ASSOCIATION_RETAIN);
    
    return poppedViewController;
}

- (NSArray<UIViewController *> *)swizzled_popToViewController:(UIViewController *)viewController animated:(BOOL)animated {
    NSArray<UIViewController *> *poppedViewControllers = [self swizzled_popToViewController:viewController animated:animated];
    
    for (UIViewController *viewController in poppedViewControllers) {
        [viewController willDealloc];
    }
    
    return poppedViewControllers;
}

- (NSArray<UIViewController *> *)swizzled_popToRootViewControllerAnimated:(BOOL)animated {
    NSArray<UIViewController *> *poppedViewControllers = [self swizzled_popToRootViewControllerAnimated:animated];
    
    for (UIViewController *viewController in poppedViewControllers) {
        [viewController willDealloc];
    }
    
    return poppedViewControllers;
}

- (BOOL)willDealloc {
    if (![super willDealloc]) {
        return NO;
    }

	[self willReleaseChildren:self.viewControllers];
    
    return YES;
}

@end

#endif
