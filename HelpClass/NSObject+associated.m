//
//  NSObject+associated.m
//  MOA
//
//  Created by luqizhou on 17/1/11.
//  Copyright © 2017年 moa. All rights reserved.
//

#import "NSObject+associated.h"

@implementation NSObject (associated)

- (void)removeAssociatedObjForKey:(const char *)key {
    return objc_setAssociatedObject(self, key, nil, OBJC_ASSOCIATION_RETAIN);
}

- (id)associatedObjForKey:(const char *)key forceCreate:(BOOL)forceCreate createBlock:(id(^)())createBlock {
    if(forceCreate) {
        return createBlock();
    }
    
    id obj = objc_getAssociatedObject(self, key);
    if(obj) {
        return obj;
    }
    
    if(createBlock) {
        obj = createBlock();
        objc_setAssociatedObject(self, key, obj, OBJC_ASSOCIATION_RETAIN);
    }
    
    return obj;
}

@end
