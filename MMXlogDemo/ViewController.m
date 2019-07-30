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

@property (nonatomic, assign) int count;
@property (weak, nonatomic) IBOutlet UITextView *filesInfo;

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
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (int i = 0; i < 10000; i++) {
            //行为日志
            usleep(500000);
            MMXLOG_DEBUG(kModuleNetwork, [NSString stringWithFormat:@"网络请求 %d", self->_count++]);
        }
    });
}

- (IBAction)uploadClicked:(UIButton *)sender
{
    MMXLOG_UPLOAD_XLOG_FILE();
}

- (IBAction)allFilesInfo:(UIButton *)sender
{
    // 显示日志信息：名称和大小
    self.filesInfo.text = MMXLOG_ALL_XLOG_FILES_INFO();
}
@end
