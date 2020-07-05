//
//  AopHooker.m
//  FTUIKit
//
//  Created by fltx on 2018/8/28.
//  Copyright © 2018年 www.apple.cn. All rights reserved.
//

#import "AopHooker.h"
#import "SwizzleHelper.h"

@implementation AopHooker

static AopHooker *_instance = nil;

+ (AopHooker *)instance{
    if (!_instance) {
        _instance = [[AopHooker alloc] init];
    }
    return _instance;
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error;
        //------------viewDidLoad------------
        //        [UIViewController aspect_hookSelector:@selector(viewDidLoad) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo>aspectInfo) {
        //            UIViewController *viewController = aspectInfo.instance;
        //            [[AopHooker instance] aop_viewDidLoad:viewController];
        //        } error:&error];
        
        [SwizzleHelper swizzleClass:UIViewController.class instanceMethod:NSSelectorFromString(@"viewDidLoad") withMethod:NSSelectorFromString(@"aop_viewDidLoad") error:NULL];
        
        [SwizzleHelper swizzleClass:UIViewController.class instanceMethod:NSSelectorFromString(@"viewWillAppear:") withMethod:NSSelectorFromString(@"aop_viewWillAppear:") error:NULL];
        
        [SwizzleHelper swizzleClass:UIViewController.class instanceMethod:NSSelectorFromString(@"viewWillDisappear:") withMethod:NSSelectorFromString(@"aop_viewWillDisappear:") error:NULL];
        
        [SwizzleHelper swizzleClass:UIViewController.class instanceMethod:NSSelectorFromString(@"didReceiveMemoryWarning") withMethod:NSSelectorFromString(@"aop_didReceiveMemoryWarning") error:NULL];
        
        [SwizzleHelper swizzleClass:UIViewController.class instanceMethod:NSSelectorFromString(@"dealloc") withMethod:NSSelectorFromString(@"aop_dealloc") error:error];
        
        //------------dealloc------------
        //        [UIViewController aspect_hookSelector:NSSelectorFromString(@"dealloc") withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo>aspectInfo) {
        //            debugLog(@"dealloc %@",aspectInfo.instance);
        //            [[AopHooker instance] aop_dealloc];
        //        } error:&error]; 
    });
    
}

- (NSMapTable<NSString *,id<HookControllerProtocol>> *)delegates
{
    if (!_delegates) {
        _delegates = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality] ;
    }
    return _delegates;
}

- (void)appendDelegate:(id<HookControllerProtocol>)delgate forKey:(NSString *)key{
    if (!key) {
        return;
    }
    if (![self.delegates.keyEnumerator.allObjects containsObject:key]) {
        [self.delegates setObject:delgate forKey:key];
    }
}

- (void)removeDelegateForKey:(NSString *)key{
    if (!key) {
        return;
    }
    [self.delegates removeObjectForKey:key];
}

- (void)clearDelegates{
    [self.delegates removeAllObjects];
}

@end
