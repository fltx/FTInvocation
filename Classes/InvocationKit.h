//
//  InvocationKit.h
//  FTUIKit
//
//  Created by fltx on 2018/08/01.
//  Copyright © 2018年 www.apple.cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+Identifier.h"
#import "InvocationDefine.h"

typedef NSHashTable<NSMapTable<NSString *, NSObject *> *> FTHashTable;
typedef void (^InvocationHashBlock)(NSHashTable * _Nullable hashTable);
typedef void (^InvocationObjectBlock)(NSObject * _Nullable object);
typedef void (^InvocationResultBlock)(id _Nullable result);


@interface InvocationKit : NSObject

- (instancetype _Nonnull)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype _Nonnull)new UNAVAILABLE_ATTRIBUTE;


+ (FTHashTable *_Nonnull)instancePool;
+ (NSHashTable<NSMapTable<NSString *,FTHashTable *> *> *_Nullable)observerPool;

/**
 init an object with name
 
 @param className name
 @return id
 */
+ (id _Nullable)initializeWithName:(nonnull NSString *)className;

/**
 init an object with name
 
 @param className name
 @param selector selector
 @return id
 */
+ (id _Nonnull)initializeWithName:(nonnull NSString *)className selector:(nonnull NSString *)selector;

+ (id _Nonnull)initializeWithName:(nonnull NSString *)className selector:(NSString * _Nullable )selector args:(_Nullable id)args;

+ (id _Nonnull)initializeWithName:(nonnull NSString *)className selector:(nonnull NSString *)selector args:(_Nullable id)args identifier:(NSString * _Nullable)identifier;

+ (void)addTargetInPool:(nonnull NSObject *)classObject;

+ (void)addTargetInPool:(nonnull NSObject *)classObject withIdentifier:(nonnull NSString *)identifier;


/**
 don't sure if the targe is exist in the pool

 @param classObject target
 @param identifier id
 @param isNew is new?
 */
+ (void)appendUpdateTarget:(nonnull NSObject *)classObject withIdentifier:(nonnull NSString *)identifier isNew:(BOOL)isNew;


/**
 update the target premise that object alread exist in the pool

 @param classObject target
 @param identifier id
 */
+ (void)updateTarget:(nonnull NSObject *)classObject identifier:(nonnull NSString *)identifier;

+ (void)targetWithIdentifier:(nonnull NSString *)identifier completion:(InvocationObjectBlock _Nullable )block;

/**
 Notification Method

 @param notificatioName name
 @param args parameters
 */
void postNotification(NSString * _Nonnull notificatioName, id _Nullable args);

void addNotification(NSObject * _Nonnull target, NSString * _Nonnull notificatioName, NSString * _Nonnull selector);

/**
  Class Method
  Perform target class selector with arguments
 @param className className
 @param selector class selecotr
  param args args
 */
__attribute__((overloadable)) void performClass(NSString * _Nonnull className, NSString * _Nonnull selector);

__attribute__((overloadable)) void performClass(NSString * _Nonnull className, NSString * _Nonnull selector,id _Nullable args);

__attribute__((overloadable)) void performClassResult(NSString *  _Nonnull className, NSString * _Nonnull selector, InvocationResultBlock _Nullable completionBlock);

__attribute__((overloadable)) void performClassResult(NSString * _Nonnull className, NSString * _Nonnull selector,id _Nullable args, InvocationResultBlock _Nullable completionBlock);

/**
 Trigger A method after B's action
 
 @param origin A target
 @param selector A method
 @param targetIdentifier B target identifier
 */
void performTargetTriggerWithIdentifierCompletionHandler(NSObject * _Nonnull origin, NSString * _Nonnull selector, NSString * _Nonnull targetIdentifier);
void performTargetTriggerWithCompletionHandler(NSObject * _Nonnull origin, NSString * _Nonnull selector, NSObject * _Nonnull target);


/**
 Perform target selector with arguments
 *
 *  performTarget(@"Identifier", @"routerEvent:params:", @[@"LocationCity",@{@"this message is from pool" : @"yes"}]);
 *  performTarget([self viewController], @"headerView:didSelectedAtIndex:", @[self,@(1)]);
 
 */

__attribute__((overloadable)) void performTarget(NSObject * _Nonnull target, NSString * _Nonnull selector);

__attribute__((overloadable)) void performTarget(NSObject * _Nonnull target, NSString * _Nonnull selector, id _Nullable args);

__attribute__((overloadable)) void performTargetWithIdentifier(NSString * _Nonnull identifier, NSString * _Nonnull selector);

__attribute__((overloadable)) void performTargetWithIdentifier(NSString * _Nonnull identifier, NSString * _Nonnull selector, id _Nullable args);

__attribute__((overloadable)) void performTargetResult(NSObject * _Nonnull target, NSString * _Nonnull selector, InvocationResultBlock _Nullable completionBlock);

__attribute__((overloadable)) void performTargetResult(NSObject * _Nonnull target, NSString * _Nonnull selector, id _Nullable args, InvocationResultBlock _Nullable completionBlock);

__attribute__((overloadable)) void performTargetResultWithIdentifier(NSString * _Nonnull identifier, NSString * _Nonnull selector, InvocationResultBlock _Nullable completionBlock);

__attribute__((overloadable)) void performTargetResultWithIdentifier(NSString * _Nonnull identifier, NSString * _Nonnull selector, id _Nullable args, InvocationResultBlock _Nonnull completionBlock);

__attribute__((overloadable)) void performTargetOnMainThread(NSObject * _Nonnull target, NSString * _Nonnull selector,id _Nullable args, InvocationResultBlock _Nullable block);

__attribute__((overloadable)) void performTargetOnMainThread(NSString * _Nonnull identifier, NSString * _Nonnull selector,id _Nullable args, InvocationResultBlock _Nonnull resultBlock);

__attribute__((overloadable)) void performTargetInBackground(NSString * _Nonnull identifier, NSString * _Nonnull selector);

__attribute__((overloadable)) void performTargetInBackground(NSObject * _Nonnull target, NSString * _Nonnull selector, id _Nullable args);

__attribute__((overloadable)) void performTargetInBackground(NSString * _Nonnull identifier, NSString * _Nonnull selector, id _Nullable args);

__attribute__((overloadable)) void performTargetResultInBackground(NSString * _Nonnull identifier, NSString * _Nonnull selector, InvocationResultBlock _Nullable completionBlock);

__attribute__((overloadable)) void performTargetResultInBackground(NSString * _Nonnull identifier, NSString * _Nonnull selector, id _Nullable args, InvocationResultBlock _Nullable completionBlock);

void performTargetDelayWithIdentifierArgs(NSString * _Nonnull identifier,NSString * _Nonnull selector, id _Nullable args, NSTimeInterval afterDelay);

void performTargetDelayWithIdentifierArgsRunLoopMode(NSString * _Nonnull identifier,NSString * _Nonnull selector, id _Nullable args, NSTimeInterval afterDelay, NSArray<NSRunLoopMode> * _Nonnull inModels);

@end
