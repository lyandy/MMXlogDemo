//
//  ViewController.m
//  MMXlogDemo
//
//  Created by 李扬 on 2019/7/25.
//  Copyright © 2019 李扬. All rights reserved.
//

#import "ViewController.h"
#import "MMXlog.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 页面加载 kLevelInfo 级别
    MMXLOG_INFO(kModuleViewController, @"页面加载");
}

- (IBAction)btnClicked:(UIButton *)sender
{
    // 模拟记录日志请求 kLevelDebug 级别
    MMXLOG_DEBUG(kModuleNetwork, @"网络请求");
}


@end
