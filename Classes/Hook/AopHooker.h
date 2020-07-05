//
//  AopHooker.h
//  FTUIKit
//
//  Created by fltx on 2018/8/28.
//  Copyright © 2018年 www.apple.cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol HookControllerProtocol

+ (void)aop_viewDidLoad:(UIViewController *)controller;

@optional
+ (void)aop_viewWillAppear:(UIViewController *)controller;
+ (void)aop_viewWillDisappear:(UIViewController *)controller;
+ (void)aop_didReceiveMemoryWarning:(UIViewController *)controller;
+ (void)aop_dealloc:(UIViewController *)controller;

@end

@interface AopHooker : NSObject

@property (class, readonly, strong) AopHooker *instance;
@property (nonatomic, strong) NSMapTable<NSString *, id<HookControllerProtocol>> *delegates;


/**
 add delegate for key

 @param delgate must conform HookControllerProtocol
 @param key string type
 */
- (void)appendDelegate:(id<HookControllerProtocol>)delgate forKey:(NSString *)key;


/**
 remove delegate for key

 @param key string type
 */
- (void)removeDelegateForKey:(NSString *)key;

@end
