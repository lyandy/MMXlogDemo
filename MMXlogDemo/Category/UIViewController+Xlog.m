//
//  UIViewController+Xlog.m
//  MMXlogDemo
//
//  Created by 李扬 on 2019/7/25.
//  Copyright © 2019 李扬. All rights reserved.
//

#import "UIViewController+Xlog.h"
#import <objc/runtime.h>
#import "NSObject+Swizzle.h"
#import "LogUtil.h"

@implementation UIViewController (Xlog)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        SEL originalSelector1 = @selector(viewDidLoad);
        SEL swizzledSelector1 = @selector(xl_viewDidLoad);
        [self swizzlingInClass:[self class] originalSelector:originalSelector1 swizzledSelector:swizzledSelector1];
        
        SEL originalSelector2 = @selector(viewWillAppear:);
        SEL swizzledSelector2 = @selector(xl_viewWillAppear:);
        [self swizzlingInClass:[self class] originalSelector:originalSelector2 swizzledSelector:swizzledSelector2];
        
        SEL originalSelector3 = @selector(viewDidAppear:);
        SEL swizzledSelector3 = @selector(xl_viewDidAppear:);
        [self swizzlingInClass:[self class] originalSelector:originalSelector3 swizzledSelector:swizzledSelector3];
        
        SEL originalSelector4 = @selector(viewWillDisappear:);
        SEL swizzledSelector4 = @selector(xl_viewWillDisappear:);
        [self swizzlingInClass:[self class] originalSelector:originalSelector4 swizzledSelector:swizzledSelector4];
        
        SEL originalSelector5 = @selector(viewDidDisappear:);
        SEL swizzledSelector5 = @selector(xl_viewDidDisappear:);
        [self swizzlingInClass:[self class] originalSelector:originalSelector5 swizzledSelector:swizzledSelector5];
    });
}

#pragma mark - Method Swizzling
- (void)xl_viewDidLoad
{
    LOG_INFO("Page", @"%@-%s",  NSStringFromClass([self class]), __func__);
    [self xl_viewDidLoad];
}

- (void)xl_viewWillAppear:(BOOL)animated
{
    LOG_INFO("Page", @"%@-%s",  NSStringFromClass([self class]), __func__);
    [self xl_viewWillAppear:animated];
}

- (void)xl_viewDidAppear:(BOOL)animated
{
    LOG_INFO("Page", @"%@-%s",  NSStringFromClass([self class]), __func__);
    [self xl_viewDidAppear:animated];
}

- (void)xl_viewWillDisappear:(BOOL)animated
{
    LOG_INFO("Page", @"%@-%s",  NSStringFromClass([self class]), __func__);
    [self xl_viewWillDisappear:animated];
}

- (void)xl_viewDidDisappear:(BOOL)animated
{
    LOG_INFO("Page", @"%@-%s",  NSStringFromClass([self class]), __func__);
    [self xl_viewDidDisappear:animated];
}

- (BOOL)shouldRecord
{
    CGRect mainRect = [UIScreen mainScreen].bounds;
    CGRect vcRect =  [self.view convertRect:self.view.bounds toView:[(id)[UIApplication sharedApplication].delegate valueForKey:@"window"]];
    //TO-DO： 这个范围应当缩小，现在没有缩小
    // UPDATE: 此方法已不再使用
    return CGRectIntersectsRect(mainRect, vcRect);
}


@end
