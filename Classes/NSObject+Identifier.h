//
//  NSObject+Identifier.h
//  FTUIKit
//
//  Created by fltx on 2018/8/8.
//  Copyright © 2018年 www.apple.cn. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (Identifier)

typedef void (^CompletionHandler)(BOOL isFinish,id args);

/**
 self id
 */
@property (nonatomic, copy, readonly)NSString *identifier;


/**
 call when task finished
 */
@property (nonatomic, copy)CompletionHandler completionHandler;


/**
 Force update the exist object by id

 @param identifier id
 */
- (void)updateIdentifier:(NSString *)identifier;


/**
 bind object by id
 */
@property (nonatomic, readonly)NSHashTable<NSString *> *bindIdentifiers;


- (BOOL)canAppendIdentifier:(NSString *)identifier;

@end
