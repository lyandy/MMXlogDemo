//
//  UIButton+Xlog.m
//  MMXlogDemo
//
//  Created by 李扬 on 2019/7/25.
//  Copyright © 2019 李扬. All rights reserved.
//

#import "UIButton+Xlog.h"
#import "NSObject+Swizzle.h"
#import "LogUtil.h"

@implementation UIButton (Xlog)

+ (void)load
{
    SEL originalSelector1 = @selector(sendAction:to:forEvent:);
    SEL swizzledSelector1 = @selector(xl_sendAction:to:forEvent:);
    [self swizzlingInClass:[self class] originalSelector:originalSelector1 swizzledSelector:swizzledSelector1];
}

- (void)xl_sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event
{
    if (self.titleLabel.text.length > 0)
    {
        LOG_INFO("Button", @"%@,%@,%@", self.titleLabel.text, NSStringFromSelector(action), NSStringFromCGRect(self.frame));
    }
    else
    {
        LOG_INFO("Button", @"%@,%@,%@", @"no title", NSStringFromSelector(action), NSStringFromCGRect(self.frame));
    }
    
    [self xl_sendAction:action to:target forEvent:event];
}

@end
