//
//  FTKitDefine.h
//  FTKitDemo
//
//  Created by neo on 2018/9/29.
//  Copyright © 2018年 Neo. All rights reserved.
//

#ifndef FTKitDefine_h
#define FTKitDefine_h


#ifdef DEBUG
#define FTLog(...) NSLog(__VA_ARGS__)
#else
#define FTLog(...)
#endif

typedef void (^cleanupBlock_t)(void);
static inline void executeCleanupBlock (__strong cleanupBlock_t * block) {
    (*block)();
}

/**
 * Returns A and B concatenated after full macro expansion.
 */
#define meta_join_(A, B) A ## B

#if DEBUG
#define keywordify autoreleasepool {}
#else
#define keywordify try {} @catch (...) {}
#endif

#define scopeExit \
keywordify \
__strong cleanupBlock_t meta_join_(ft_exitBlock_, __LINE__) __attribute__((cleanup(executeCleanupBlock), unused)) = ^


#endif /* FTKitDefine_h */
