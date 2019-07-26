//
//  main.m
//  MMXlogDemo
//
//  Created by 李扬 on 2019/7/25.
//  Copyright © 2019 李扬. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "MMXlog.h"

#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        
        MMXLOG_INIT();
        
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
