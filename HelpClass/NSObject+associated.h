//
//  NSObject+associated.h
//  MOA
//
//  Created by luqizhou on 17/1/11.
//  Copyright © 2017年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (associated)

- (id)associatedObjForKey:(const char *)key forceCreate:(BOOL)forceCreate createBlock:(id(^)())createBlock;

- (void)removeAssociatedObjForKey:(const char *)key;

@end
