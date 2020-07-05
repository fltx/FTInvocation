//
//  SwizzleHelper.m
//  FTUIKit
//
//  Created by fltx on 2018/8/28.
//  Copyright © 2018年 www.apple.cn. All rights reserved.
//

#import "SwizzleHelper.h"
#import <objc/runtime.h>

@implementation SwizzleHelper

////exchange implementation of two methods
+ (BOOL)swizzleClass:(Class)aClass instanceMethod:(SEL)origSel withMethod:(SEL)newSel error:(NSError *)error{
    Method origMethod = class_getInstanceMethod(aClass, origSel);
    if (!origMethod) {
        NSLog(@" %@  original method %@ not found for class %@", error, NSStringFromSelector(origSel), [aClass class]);
        return NO;
    }
    
    Method altMethod = class_getInstanceMethod(aClass, newSel);
    if (!altMethod) {
        NSLog(@" %@  alternate method %@ not found for class %@", error, NSStringFromSelector(newSel), [aClass class]);
        return NO;
    }
    
    // 注意：一定要对该方法在该类中是否存在进行判断。如果我们替换的不是系统的方法，而是自定义的方法A。该类是有实现方法A的，但是该类的子类不一定实现了方法A。所以说如果在该类的子类中进行方法交换，那么一旦子类没有实现该方法，就会强行去父类中去寻找该方法进行方法交换，这样就违背了我们的本意而随意篡改了父类的方法。
    //class_addMethod will fail if original method already exists
    BOOL didAddMethod = class_addMethod(aClass, origSel, class_getMethodImplementation(aClass,newSel), method_getTypeEncoding(altMethod));
    if (didAddMethod) {
        // 原本该方法的作用是什么，就让原始方法的实现去指向这个改方法的名称（替换该方法的指针）
        class_replaceMethod(aClass, newSel, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    }else{
        
        class_addMethod(aClass,
                        origSel,
                        class_getMethodImplementation(aClass, origSel),
                        method_getTypeEncoding(origMethod));
        class_addMethod(aClass,
                        newSel,
                        class_getMethodImplementation(aClass, newSel),
                        method_getTypeEncoding(altMethod));
        
        method_exchangeImplementations(class_getInstanceMethod(aClass, origSel),
                                       class_getInstanceMethod(aClass, newSel));
    }
    
    return YES;
}


+ (BOOL)swizzleClass:(Class)aClass classMethod:(SEL)originalSel with:(SEL)newSel{
    Class class = object_getClass(aClass);
    Method originalMethod = class_getInstanceMethod(class, originalSel);
    Method newMethod = class_getInstanceMethod(class, newSel);
    if (!originalMethod || !newMethod) return NO;
    method_exchangeImplementations(originalMethod, newMethod);
    return YES;
}


@end



