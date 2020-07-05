//
//  UIViewController+Swizzle.m
//  FTUIKit
//
//  Created by fltx on 2018/8/30.
//  Copyright © 2018年 www.apple.cn. All rights reserved.
//

#import "UIViewController+Swizzle.h"
#import "AopHooker.h"

@implementation UIViewController (Swizzle)

- (void)aop_viewDidLoad{
    __weak __typeof__ (self) weakController = self;
    for (NSObject<HookControllerProtocol> *object in AopHooker.instance.delegates.objectEnumerator.allObjects) {
        if ([object respondsToSelector:@selector(aop_viewDidLoad:)]) {
            [object performSelector:@selector(aop_viewDidLoad:) withObject:weakController];
        }
    }
}

- (void)aop_viewWillAppear:(BOOL)animated{
    __weak __typeof__ (self) weakController = self;
    for (NSObject<HookControllerProtocol> *object in AopHooker.instance.delegates.objectEnumerator.allObjects) {
        if ([object respondsToSelector:@selector(aop_viewWillAppear:)]) {
            [object performSelector:@selector(aop_viewWillAppear:) withObject:weakController];
        }
    }
}

- (void)aop_viewWillDisappear:(BOOL)animated{
    __weak __typeof__ (self) weakController = self;
    for (NSObject<HookControllerProtocol> *object in AopHooker.instance.delegates.objectEnumerator.allObjects) {
        if ([object respondsToSelector:@selector(aop_viewWillDisappear:)]) {
            [object performSelector:@selector(aop_viewWillDisappear:) withObject:weakController];
        }
    }
}

- (void)aop_didReceiveMemoryWarning{
    __weak __typeof__ (self) weakController = self;
    for (NSObject<HookControllerProtocol> *object in AopHooker.instance.delegates.objectEnumerator.allObjects) {
        if ([object respondsToSelector:@selector(aop_didReceiveMemoryWarning:)]) {
            [object performSelector:@selector(aop_didReceiveMemoryWarning:) withObject:weakController];
        }
    }
}

- (void)aop_dealloc{
    for (NSObject<HookControllerProtocol> *object in AopHooker.instance.delegates.objectEnumerator.allObjects) {
        if ([object respondsToSelector:@selector(aop_dealloc:)]) {
            [object performSelector:@selector(aop_dealloc:) withObject:self];
        }
    }
    [self aop_dealloc];
}

@end
