//
//  MMXlog.m
//  MMXlogDemo
//
//  Created by 李扬 on 2019/7/26.
//  Copyright © 2019 李扬. All rights reserved.
//

#import "MMXlog.h"

@implementation MMXlog

+ (void)uploadXlogFile
{
    [self uploadXlogFileWithDate:[MMXlogUtil currentDate]];
}

+ (void)uploadXlogFileWithDate:(NSString *)date
{
    [MMXlogUtil filePathForDate:date block:^(NSString *filePath) {
        if (filePath == nil)
        {
            return;
        }
        NSString *urlStr = [NSString stringWithFormat:@"http://127.0.0.1:4000/logupload?name=%@", [filePath lastPathComponent]];
        NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlStr] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60];
        [req setHTTPMethod:@"POST"];
        [req addValue:@"binary/octet-stream" forHTTPHeaderField:@"Content-Type"];
        NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
        NSURLSessionUploadTask *task = [[NSURLSession sharedSession] uploadTaskWithRequest:req fromFile:fileUrl completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            if (error == nil)
            {
                NSLog(@"上传完成");
            }
            else
            {
                NSLog(@"上传失败 error:%@", error);
            }
        }];
        [task resume];
    }];
}

@end
