//
//  NSObject+Swizzle.h
//  MMXlogDemo
//
//  Created by 李扬 on 2019/7/25.
//  Copyright © 2019 李扬. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (Swizzle)

+ (void)swizzlingInClass:(Class)cls originalSelector:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector;

@end

NS_ASSUME_NONNULL_END
