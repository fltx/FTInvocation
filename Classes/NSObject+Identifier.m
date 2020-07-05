//
//  NSObject+Identifier.m
//  FTUIKit
//
//  Created by fltx on 2018/8/8.
//  Copyright © 2018年 www.apple.cn. All rights reserved.
//

#import "NSObject+Identifier.h"
#import <objc/runtime.h>
#import "InvocationKit.h"

@implementation NSObject (Identifier)

- (NSString *)identifier{
    NSString *identifier = objc_getAssociatedObject(self, _cmd);
    if (!identifier)
    {
        identifier = [NSUUID UUID].UUIDString;
        objc_setAssociatedObject(self, @selector(identifier), identifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return identifier;
}

- (void)updateIdentifier:(NSString *)identifier{
    objc_setAssociatedObject(self, @selector(identifier), identifier, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [InvocationKit updateTarget:self identifier:identifier];
}

- (CompletionHandler)completionHandler{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setCompletionHandler:(CompletionHandler)completionHandler{
    objc_setAssociatedObject(self, @selector(completionHandler), completionHandler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSHashTable<NSString *> *)bindIdentifiers
{
    NSHashTable *identifiers = objc_getAssociatedObject(self, _cmd);
    if (!identifiers) {
        identifiers = [NSHashTable weakObjectsHashTable];
        objc_setAssociatedObject(self, _cmd, identifiers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return identifiers;
}

- (BOOL)canAppendIdentifier:(NSString *)identifier
{
    if ([self.bindIdentifiers containsObject:identifier]) {
        return false;
    }
    dispatch_semaphore_t _lock = dispatch_semaphore_create(1);
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    
    [self.bindIdentifiers addObject:identifier];
    
    dispatch_semaphore_signal(_lock);
    return true;
}

@end
