//
//  MMXlog.m
//  MMXlogDemo
//
//  Created by 李扬 on 2019/7/26.
//  Copyright © 2019 李扬. All rights reserved.
//

#import "MMXlog.h"

void uploadFilePath(NSString *date, filePathBlock block)
{
    [MMXlogUtil uploadFilePathWithName:date block:block];
}

@implementation MMXlog

@end
