//
//  SwizzleHelper.h
//  FTUIKit
//
//  Created by fltx on 2018/8/28.
//  Copyright © 2018年 www.apple.cn. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SwizzleHelper : NSObject

+ (BOOL)swizzleClass:(Class)aClass
      instanceMethod:(SEL)origSel
          withMethod:(SEL)newSel
               error:(NSError *)error;


+ (BOOL)swizzleClass:(Class)aClass
         classMethod:(SEL)originalSel
                with:(SEL)newSel;

@end


