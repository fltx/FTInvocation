//
//  InvocationKit.m
//  FTUIKit
//
//  Created by fltx on 2018/8/01.
//  Copyright © 2018年 www.apple.cn. All rights reserved.
//

#import "InvocationKit.h"
#import <pthread.h>
#import "NSObject+Identifier.h"
#import "RuntimeInvoker.h"
#import "AopHooker.h"

@interface InvocationKit()<HookControllerProtocol>

/**
 instance pool is a container to maintain object instance
 */
@property (class, strong, readonly)FTHashTable *instancePool;

/**
 observer pool is a container to maintain notification objects
 */
@property (class, strong, readonly)NSHashTable<NSMapTable<NSString *, FTHashTable *> *> *observerPool;


/**
 task queue
 */
@property (class, nonatomic, strong, readonly, nonnull) dispatch_queue_t instanceQueue;

/**
 task queue
 */
@property (class, nonatomic, strong, readonly, nonnull) dispatch_queue_t observerQueue;

@end

#define PureMaxCount 30
@implementation InvocationKit

int poolPureCount = 0;
int observersPureCount = 0;

static NSHashTable *_instances = nil;
static NSHashTable *_observers = nil;
static pthread_mutex_t _instanceLock;
static pthread_mutex_t _observersLock;
static dispatch_queue_t _instanceQueue = nil;
static dispatch_queue_t _observerQueue = nil;

#define Lock(lock) pthread_mutex_trylock(&lock) == 0
#define UnLock(lock) pthread_mutex_unlock(&lock);

#define SLock(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define SUnLock(lock) dispatch_semaphore_signal(lock);

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [AopHooker.instance appendDelegate:(id<HookControllerProtocol>)[self class] forKey:@"InvocationKitDelegate"];
    });
}

+ (void)aop_viewDidLoad:(UIViewController *)controller{
    // append into pool
    [InvocationKit addTargetInPool: controller];
}

+ (FTHashTable *)instancePool
{
    if (!_instances) {
        pthread_mutex_init(&_instanceLock, NULL);
        _instances = [NSHashTable hashTableWithOptions: NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
    }
    return _instances;
}

+ (NSHashTable<NSMapTable<NSString *,FTHashTable *> *> *)observerPool
{
    if (!_observers) {
        pthread_mutex_init(&_observersLock, NULL);
        _observers = [NSHashTable hashTableWithOptions: NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
    }
    return _observers;
}

+ (dispatch_queue_t)instanceQueue{
    if (!_instanceQueue) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT_WITH_AUTORELEASE_POOL, QOS_CLASS_UTILITY, 0);
        _instanceQueue = dispatch_queue_create("com.ft.invocation.instance.queue.manager.processing", attr);
    }
    return _instanceQueue;
}

+ (dispatch_queue_t)observerQueue{
    if (!_observerQueue) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
        _observerQueue = dispatch_queue_create("com.ft.invocation.observer.queue.manager.processing", attr);
    }
    return _observerQueue;
}

#pragma mark - dynamic initialize object

+ (id)initializeWithName:(NSString *)className{
    return [self initializeWithName:className selector:nil args:nil];
}

+ (id)initializeWithName:(NSString *)className selector:(NSString *)selector{
    return [self initializeWithName:className selector:selector args:nil];
}

+ (id)initializeWithName:(NSString *)className selector:(NSString *)selector args:(id)args{
    return [self initializeWithName:className selector:selector args:args identifier:nil];
}

+ (id)initializeWithName:(NSString *)className selector:(NSString *)selector args:(id)args identifier:(NSString *)identifier{
    Class class = NSClassFromString(className);
    NSObject *object = nil;
    object = [[class alloc] init];
    
    // add into pool
    NSString *uid = identifier;
    if (!identifier) {
        uid = object.identifier;
    }
    [self addTargetInPool:object withIdentifier:uid];
    if (selector && [object respondsToSelector:NSSelectorFromString(selector)]){
        if (args) {
            if ([args isKindOfClass:[NSArray class]])
            {
                return [object invoke:selector arguments:(NSArray *)args];
            }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                return [object performSelector:NSSelectorFromString(selector) withObject:args];
#pragma clang diagnostic pop
            }
            
        }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            return [object performSelector:NSSelectorFromString(selector)];
#pragma clang diagnostic pop
        }
    }
    return object;
}

#pragma mark - instance pool
+ (void)addTargetInPool:(NSObject *)classObject{
    [self addTargetInPool:classObject withIdentifier:classObject.identifier];
}

+ (void)addTargetInPool:(NSObject *)classObject withIdentifier:(NSString *)identifier{
    if (!classObject || !identifier) {
        return;
    }
    dispatch_barrier_async(InvocationKit.instanceQueue, ^{
        //not exist
        NSMapTable *mapTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality];
        [mapTable setObject:classObject forKey:identifier];
        [self _addInInstancePool:mapTable];
        poolPureCount ++;
        if (poolPureCount > PureMaxCount) {
            poolPureCount = 0;
            [self clearEmptyInstances];
        }
        //FTLog(@"objects in pool %@ \n with-current-thread %@",InvocationKit.instancePool, [NSThread currentThread]);
    });
}

+ (void)appendUpdateTarget:(NSObject *)classObject withIdentifier:(NSString *)identifier isNew:(BOOL)isNew{
    if (!classObject || !identifier) {
        return;
    }
    
    dispatch_barrier_async(InvocationKit.instanceQueue, ^{
        BOOL isExistClass = !isNew;
        if (!isExistClass) {
            for (NSMapTable *mapTable in InvocationKit.instancePool) {
                @autoreleasepool {
                    for (NSObject *value in mapTable.objectEnumerator.allObjects) {
                        if ([value isEqual:classObject]) {
                            isExistClass = true;
                        }
                    }
                }
                if (isExistClass) {
                    break;
                }
            }
        }
        
        //not exist
        if (!isExistClass) {
            NSMapTable *mapTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality];
            [mapTable setObject:classObject forKey:identifier];
            //        CommonIdBlock bl;
            //        [mapTable setObject:bl forKey:@""];
            //        NSMutableArray *aa;
            //        [aa appendObject:bl];
            [self _addInInstancePool:mapTable];
        }else{
            [self updateTarget:classObject identifier:identifier];
        }
        
        [self clearEmptyInstances];
    });
    
    //FTLog(@"objects in pool %@",InvocationKit.instancePool);
}

+ (void)updateTarget:(NSObject *)classObject identifier:(NSString *)identifier{
    if (!classObject || !identifier) {
        return;
    }
    
    dispatch_barrier_async(InvocationKit.instanceQueue, ^{
        NSHashTable *instancePool = [[self class].instancePool copy];
        [self _removeInstancePool];
        for (NSMapTable *mapTable in instancePool) {
            BOOL isExist = false;
            for (NSObject *value in mapTable.objectEnumerator.allObjects) {
                if ([value isEqual:classObject]) {
                    NSMapTable *newTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality];
                    [newTable setObject:classObject forKey:identifier];
                    [self _addInInstancePool:newTable];
                    isExist = true;
                }
            }
            if (!isExist) {
                isExist = false;
                [self _addInInstancePool:mapTable];
            }
        }
        instancePool = nil;
    });
}

+ (void)targetWithIdentifier:(NSString *)identifier completion:(InvocationObjectBlock)block{
    if(!identifier)
        return;
    dispatch_async(InvocationKit.instanceQueue, ^{
        NSHashTable *instancePool = [self class].instancePool;
        NSObject *target;
        for (NSMapTable *mapTable in instancePool) {
            @autoreleasepool {
                NSObject *object = [mapTable objectForKey:identifier];
                if (object){
                    target = object;
                    break;
                }
            }
        }
        FTLog(@"current thread =====%@",[NSThread currentThread]);
        block == nil ? : block(target);
    });
}

///celar the empty table
+ (void)clearEmptyInstances{
    dispatch_barrier_async(InvocationKit.instanceQueue, ^{
        NSHashTable *instancePool = [[self class].instancePool copy];
        [self _removeInstancePool];
        for (NSMapTable *mapTable in instancePool) {
            if ([mapTable objectEnumerator].allObjects.count > 0) {
                [self _addInInstancePool:mapTable];
            }
        }
        instancePool = nil;
    });
}

+ (void)_addInInstancePool:(NSMapTable *)mapTable{
    [[self class].instancePool addObject:mapTable];
}

+ (void)_removeInstancePool{
    [[self class].instancePool removeAllObjects];
}

+ (void)_addInObserverPool:(NSMapTable *)mapTable{
    [[self class].observerPool addObject:mapTable];
}

+ (void)_removeInObserverPool{
    [[self class].observerPool removeAllObjects];
}

#pragma mark - notication pool
+ (void)addNotificationTargetInPool:(NSObject *)classObject withNoticationName:(NSString *)notificationName selector:(NSString *)selector{
    if (!classObject || !notificationName || !selector) {
        return;
    }
    //@[@{@"notificationName" : @[@{@"classobject" : @"selector"}]}]
    
    __block NSString *sel = selector;
    dispatch_barrier_async(InvocationKit.observerQueue, ^{
        //not exist
        NSHashTable *hashTable;
        NSMapTable *mapTable;
        for (NSMapTable *_mapTable in InvocationKit.observerPool) {
            hashTable = [_mapTable objectForKey: notificationName];
            if (hashTable) {
                mapTable = _mapTable;
                break;
            }
        }
        if (!hashTable) {
            hashTable = [NSHashTable hashTableWithOptions: NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
            mapTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
        }
        //@[@{@"notificationName" : @[@{@"classobject" : @"selector"}]}]
        NSMapTable *childTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
        [childTable setObject:sel forKey:classObject];
        
        [hashTable addObject: childTable];
        [mapTable setObject:hashTable forKey:notificationName];
        [self _addInObserverPool:mapTable];
        
        observersPureCount ++;
        
        if (observersPureCount < PureMaxCount) {
            observersPureCount = 0;
            [self clearEmptyObservers];
        }
    });
}

+ (void)addNotificationTargetInPool:(NSObject *)classObject withNoticationName:(NSString *)notificationName selector:(NSString *)selector isNew:(BOOL)isNew{
    if (!classObject || !notificationName || !selector) {
        return;
    }
    //@[@{@"notificationName" : @[@{@"classobject" : @"selector"}]}]
    
    __block NSString *sel = selector;
    dispatch_barrier_async(InvocationKit.observerQueue, ^{
        BOOL isExistClass = !isNew;
        if (!isExistClass) {
            for (NSMapTable *mapTable in InvocationKit.observerPool) {
                @autoreleasepool {
                    NSHashTable *hashTable = [mapTable objectForKey: notificationName];
                    for (NSMapTable *_table in hashTable.allObjects) {
                        for (NSObject *value in _table.keyEnumerator.allObjects) {
                            if ([value isEqual: classObject]) {
                                isExistClass = true;
                            }
                        }
                    }
                }
                if (isExistClass) {
                    break;
                }
            }
        }
        
        //not exist
        if (!isExistClass) {
            NSHashTable *hashTable;
            NSMapTable *mapTable;
            for (NSMapTable *_mapTable in InvocationKit.observerPool) {
                hashTable = [_mapTable objectForKey: notificationName];
                if (hashTable) {
                    mapTable = _mapTable;
                    break;
                }
            }
            if (!hashTable) {
                hashTable = [NSHashTable hashTableWithOptions: NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
                mapTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
            }
            //@[@{@"notificationName" : @[@{@"classobject" : @"selector"}]}]
            NSMapTable *childTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
            [childTable setObject:sel forKey:classObject];
            
            [hashTable addObject: childTable];
            [mapTable setObject:hashTable forKey:notificationName];
            [self _addInObserverPool:mapTable];
            
            observersPureCount ++;
        }
        
        if (observersPureCount < PureMaxCount) {
            observersPureCount = 0;
            [self clearEmptyObservers];
        }
    });
    
    //FTLog(@"objects in pool %@",InvocationKit.observerPool);
}

///celar the empty table
+ (void)clearEmptyObservers{
    dispatch_barrier_async(InvocationKit.observerQueue, ^{
        NSHashTable *pool = [[self class].observerPool copy];
        [[self class].observerPool removeAllObjects];
        for (NSMapTable *mapTable in pool) {
            @autoreleasepool{
                NSMapTable *copyMapTable = [mapTable mutableCopy];
                if ([mapTable objectEnumerator].allObjects.count > 0) {
                    for (NSString *key in mapTable.keyEnumerator.allObjects) {
                        NSHashTable *hashTable = [mapTable objectForKey:key];
                        NSHashTable *copyHashTable = [hashTable mutableCopy];
                        for (NSMapTable *childTable in hashTable) {
                            if (childTable.objectEnumerator.allObjects.count < 1) {
                                [copyHashTable removeObject:childTable];
                            }
                        }
                        if (copyHashTable.objectEnumerator.allObjects.count > 0) {
                            [copyMapTable setObject:copyHashTable forKey:copyMapTable.keyEnumerator.allObjects.firstObject];
                        }else{
                            [copyMapTable removeObjectForKey:key];
                        }
                    }
                    if ([mapTable objectEnumerator].allObjects.count > 0) {
                        [self _addInObserverPool:copyMapTable];
                    }
                }
            }
        }
        pool = nil;
    });
}

+ (void)targetWithNotification:(NSString *)notificationName complete:(InvocationHashBlock)block{
    if(!notificationName)
        return;
    dispatch_async(InvocationKit.observerQueue, ^{
        NSHashTable *pool = InvocationKit.observerPool;
        NSHashTable *table;
        for (NSMapTable *mapTable in pool) {
            @autoreleasepool {
                NSHashTable *_hashTable = [mapTable objectForKey: notificationName];
                if (_hashTable) {
                    table = _hashTable;
                    break;
                }
            }
        }
        block == nil ? : block(table);
    });
}


#pragma mark - notification method

void postNotification(NSString *notificatioName, id args){
    [InvocationKit targetWithNotification:notificatioName complete:^(NSHashTable *hashTable) {
        for (NSMapTable *mapTable in hashTable) {
            @autoreleasepool{
                NSObject *object = mapTable.keyEnumerator.allObjects.firstObject;
                NSString *selector = mapTable.objectEnumerator.allObjects.firstObject;
                if (object) {
                    performTarget(object, selector, args);
                    break;
                }
            }
        }
    }];
}

void addNotification(NSObject *target, NSString *notificatioName, NSString * _Nonnull selector){
    [InvocationKit addNotificationTargetInPool:target withNoticationName:notificatioName selector:selector];
}


#pragma mark - class method overloadable perform class selector args

__attribute__((overloadable)) void performClass(NSString *className, NSString * _Nonnull selector){
    performClassResultWithArgs(className, selector, nil, false, nil);
}

__attribute__((overloadable)) void performClass(NSString *className, NSString * _Nonnull selector,id args){
    performClassResultWithArgs(className, selector, args, false, nil);
}

__attribute__((overloadable)) void performClassResult(NSString *className, NSString * _Nonnull selector, InvocationResultBlock completionBlock){
    performClassResultWithArgs(className, selector, nil, true, completionBlock);
}

__attribute__((overloadable)) void performClassResult(NSString *className, NSString * _Nonnull selector,id args, InvocationResultBlock completionBlock){
    performClassResultWithArgs(className, selector, args, true, completionBlock);
}

__attribute__((overloadable)) void performClassResultWithArgs(NSString *className, NSString * _Nonnull selector, id args, BOOL isReturn, InvocationResultBlock completionBlock){
    Class aClass = NSClassFromString(className);
    if (!aClass) {
        FTLog(@"-------> Perform class is nil or Does Not Recognize Selector");
        return;
    }
    performSelectorOnMainWithIdentifierArgs(aClass, selector, args, true, isReturn, completionBlock);
}


#pragma mark - instance method overloadable perform target selector args

__attribute__((overloadable)) void performTarget(NSObject *target, NSString * _Nonnull selector){
    NSString *identifier = target.identifier;
    performTargetResultWithIdentifierArgs(identifier, selector, nil, false, nil);
}

__attribute__((overloadable)) void performTarget(NSObject *target, NSString * _Nonnull selector, id args){
    NSString *identifier = target.identifier;
    performTargetResultWithIdentifierArgs(identifier, selector, args, false, nil);
}

__attribute__((overloadable)) void performTargetWithIdentifier(NSString * _Nonnull identifier, NSString * _Nonnull selector){
    performTargetResultWithIdentifierArgs(identifier, selector, nil, false, nil);
}

__attribute__((overloadable)) void performTargetWithIdentifier(NSString * _Nonnull identifier, NSString * _Nonnull selector, id args){
    performTargetResultWithIdentifierArgs(identifier, selector, args, false, nil);
}

__attribute__((overloadable)) void performTargetResult(NSObject *target, NSString * _Nonnull selector, InvocationResultBlock completionBlock){
    NSString *identifier = target.identifier;
    performTargetResultWithIdentifierArgs(identifier, selector, nil, true, completionBlock);
}

__attribute__((overloadable)) void performTargetResult(NSObject *target, NSString * _Nonnull selector, id args, InvocationResultBlock completionBlock){
    NSString *identifier = target.identifier;
    performTargetResultWithIdentifierArgs(identifier, selector, args, true, completionBlock);
}

__attribute__((overloadable)) void performTargetResultWithIdentifier(NSString * _Nonnull identifier, NSString * _Nonnull selector, InvocationResultBlock completionBlock){
    performTargetResultWithIdentifierArgs(identifier, selector, nil, true, completionBlock);
}

__attribute__((overloadable)) void performTargetResultWithIdentifier(NSString * _Nonnull identifier, NSString * _Nonnull selector, id args, InvocationResultBlock completionBlock){
    performTargetResultWithIdentifierArgs(identifier, selector, args, true, completionBlock);
}

__attribute__((overloadable)) void performTargetOnMainThread(NSObject * _Nonnull target, NSString * _Nonnull selector,id args, InvocationResultBlock completionBlock){
    NSString *identifier = target.identifier;
    performTargetOnMainThread(identifier, selector, args, completionBlock);
}

__attribute__((overloadable)) void performTargetOnMainThread(NSString * _Nonnull identifier, NSString * _Nonnull selector,id args, InvocationResultBlock completionBlock){
    /*
     // main thread main queue
     if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0) {
     performTargetWithIdentifierArgs(identifier, selector, args);
     }
     */
    if (pthread_main_np()){
        performTargetResultWithIdentifierArgs(identifier, selector, args, false, completionBlock);
    }else{
        dispatch_async(dispatch_get_main_queue(), ^{
            performTargetResultWithIdentifierArgs(identifier, selector, args, false, completionBlock);
        });
    }
}


#pragma mark - instance method invoke in background

__attribute__((overloadable)) void performTargetInBackground(NSString * _Nonnull identifier, NSString * _Nonnull selector){
    performTargetInBackground(identifier, selector, nil);
}

__attribute__((overloadable)) void performTargetInBackground(NSObject * _Nonnull target, NSString * _Nonnull selector, id args){
    NSString *identifier = target.identifier;
    performTargetInBackground(identifier, selector, args);
}

__attribute__((overloadable)) void performTargetInBackground(NSString * _Nonnull identifier, NSString * _Nonnull selector, id args){
    
    if (!identifier || !selector) {
        return;
    }
    [InvocationKit targetWithIdentifier:identifier completion:^(NSObject * object) {
        performSelectorWithArgsCompletion(object, selector, args, false, false, nil);
    }];
}

__attribute__((overloadable)) void performTargetResultInBackground(NSString * _Nonnull identifier, NSString * _Nonnull selector, InvocationResultBlock completionBlock){
    performTargetResultInBackground(identifier, selector, nil, completionBlock);
}

__attribute__((overloadable)) void performTargetResultInBackground(NSString * _Nonnull identifier, NSString * _Nonnull selector, id args, InvocationResultBlock completionBlock){
    
    if (!identifier || !selector) {
        return;
    }
    /*
     // main thread main queue
     if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0) {
     performTargetWithIdentifierArgs(identifier, selector, args);
     }
     
     if (pthread_main_np()){
     
     }
     */
    [InvocationKit targetWithIdentifier:identifier completion:^(NSObject * object) {
        performSelectorWithArgsCompletion(object, selector, args, false, true, ^(id result) {
            if (result && completionBlock) {
                //return result;
                completionBlock(result);
            }
        });
    }];
}

void performTargetDelayWithIdentifierArgs(NSString * _Nonnull identifier,NSString * _Nonnull selector, id args, NSTimeInterval afterDelay){
    [InvocationKit targetWithIdentifier:identifier completion:^(NSObject * object) {
        if (object && [object respondsToSelector:NSSelectorFromString(selector)]){
            [object performSelector:NSSelectorFromString(selector) withObject:args afterDelay:afterDelay inModes:@[NSDefaultRunLoopMode]];
        }
    }];
}

void performTargetDelayWithIdentifierArgsRunLoopMode(NSString * _Nonnull identifier,NSString * _Nonnull selector, id args, NSTimeInterval afterDelay, NSArray<NSRunLoopMode> *inModels){
    [InvocationKit targetWithIdentifier:identifier completion:^(NSObject * object) {
        if (object && [object respondsToSelector:NSSelectorFromString(selector)]){
            [object performSelector:NSSelectorFromString(selector) withObject:args afterDelay:afterDelay inModes:inModels];
        }}
     ];
}


#pragma mark - perform target by callback
/*
 B call completionHandler -> trigger to call A method
 */

void performTargetTriggerWithIdentifierCompletionHandler(NSObject * _Nonnull origin, NSString * _Nonnull selector, NSString * _Nonnull targetIdentifier){
    if (!origin || !targetIdentifier || !selector) {
        return;
    }
    [InvocationKit targetWithIdentifier:targetIdentifier completion:^(NSObject *target) {
        if (![target canAppendIdentifier:targetIdentifier]) {
            //return;
        }
        performTargetTriggerWithCompletionHandler(origin, selector, target);
    }];
}

void performTargetTriggerWithCompletionHandler(NSObject * _Nonnull origin, NSString * _Nonnull selector, NSObject * _Nonnull target){
    
    if (!origin || !target || !selector) {
        return;
    }
    if( [origin respondsToSelector:NSSelectorFromString(selector)]){
        // if exist
        __weak __typeof__ (target) weakTarget = target;
        target.completionHandler = ^(BOOL isFinish, id args) {
            if (isFinish) {
                __strong __typeof (weakTarget) strongTarget = weakTarget;
                if (strongTarget) {
                    for (NSString *identifier in strongTarget.bindIdentifiers) {
                        [InvocationKit targetWithIdentifier:identifier completion:^(NSObject * target) {
                            performTarget(target, selector, args);
                        }];
                    }
                }
            }
        };
    }
}


#pragma mark - base method perform target selector args

void performTargetResultWithIdentifierArgs(NSString * _Nonnull identifier, NSString * _Nonnull selector,id args,BOOL isReturn, InvocationResultBlock completionBlock){
    if (!identifier || !selector) {
        return;
    }
    [InvocationKit targetWithIdentifier:identifier completion:^(NSObject * object) {
        performSelectorOnMainWithIdentifierArgs(object, selector, args, false, isReturn, ^(id result) {
            if (result && completionBlock) {
                //return result;
                completionBlock(result);
            }
        });
    }];
}


void performSelectorOnMainWithIdentifierArgs(id _Nonnull object, NSString * _Nonnull selector, id args, BOOL isClass,BOOL isReturn, InvocationResultBlock completionBlock){
    if (pthread_main_np()){
        performSelectorWithArgsCompletion(object, selector, args, isClass, isReturn, completionBlock);
    } else {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            performSelectorWithArgsCompletion(object, selector, args, isClass, isReturn, completionBlock);
        }];
    }
}


void performSelectorWithArgsCompletion(id _Nonnull object, NSString * _Nonnull selector, id args, BOOL isClass,BOOL isReturn, InvocationResultBlock completionBlock){
    if (!object || !selector || ![object respondsToSelector:NSSelectorFromString(selector)]){
        FTLog(@"%@  %@-------> Perform target is nil or Does Not Recognize Selector",object,selector);
        return;
    }
    if (args){
        if ([args isKindOfClass:[NSArray class]]) {
            if (isClass) {
                if (isReturn) {
                    id result = [object invokeClass:selector arguments:args];
                    completionBlock == nil ? : completionBlock(result);
                }
                [object invokeClass:selector arguments:args];
            }else{
                if (isReturn) {
                    id result = [object invoke:selector arguments:(NSArray *)args];
                    completionBlock == nil ? : completionBlock(result);
                }
                [object invoke:selector arguments:(NSArray *)args];
            }
        }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            if (isReturn) {
                id result = [object performSelector:NSSelectorFromString(selector) withObject:args];
                completionBlock == nil ? : completionBlock(result);
            }
            [object performSelector:NSSelectorFromString(selector) withObject:args];
#pragma clang diagnostic pop
        }
    }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        if (isReturn) {
            id result = [object invoke:selector];
            completionBlock == nil ? : completionBlock(result);
            //return [object performSelector:NSSelectorFromString(selector)];
        }
        [object performSelector:NSSelectorFromString(selector)];
    }
}

- (void)dealloc
{
    [_instances removeAllObjects];
    [_observers removeAllObjects];
    
    pthread_mutex_destroy(&_instanceLock);
    pthread_mutex_destroy(&_observersLock);
}

@end
