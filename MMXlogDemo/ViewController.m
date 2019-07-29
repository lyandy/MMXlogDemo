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

- (IBAction)uploadClicked:(UIButton *)sender
{
    uploadFilePath(MMXLOG_CURRENT_DATE(), ^(NSString * _Nullable filePath) {
        if (filePath == nil) {
            return;
        }
        NSString *urlStr = @"http://10.9.101.54:4000/logupload";
        NSURL *url = [NSURL URLWithString:urlStr];
        NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60];
        [req setHTTPMethod:@"POST"];
        [req addValue:@"binary/octet-stream" forHTTPHeaderField:@"Content-Type"];
        NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
        NSURLSessionUploadTask *task = [[NSURLSession sharedSession] uploadTaskWithRequest:req fromFile:fileUrl completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            if (error == nil) {
                NSLog(@"上传完成");
            } else {
                NSLog(@"上传失败 error:%@", error);
            }
        }];
        [task resume];
    });
}

@end
