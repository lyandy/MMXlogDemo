//
//  MMXlog.h
//  MMXlogDemo
//
//  Created by 李扬 on 2019/7/26.
//  Copyright © 2019 李扬. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMXlogUtil.h"
#import <mars/xlog/xloggerbase.h>

#define __FILENAME__ (strrchr(__FILE__,'/')+1)

/**
 *  Module Logging
 */
#define MMXLOG_ERROR(module, format, ...) LogInternal(kLevelError, module, __FILENAME__, __LINE__, __FUNCTION__, @"Error:", format, ##__VA_ARGS__)
#define MMXLOG_WARNING(module, format, ...) LogInternal(kLevelWarn, module, __FILENAME__, __LINE__, __FUNCTION__, @"Warning:", format, ##__VA_ARGS__)
#define MMXLOG_INFO(module, format, ...) LogInternal(kLevelInfo, module, __FILENAME__, __LINE__, __FUNCTION__, @"Info:", format, ##__VA_ARGS__)
#define MMXLOG_DEBUG(module, format, ...) LogInternal(kLevelDebug, module, __FILENAME__, __LINE__, __FUNCTION__, @"Debug:", format, ##__VA_ARGS__)

#define MMXLOG_APPENDER_CLOSE() [MMXlogUtil appender_close]

#define MMXLOG_INIT() [MMXlogUtil initLog];
#define MMXLOG_INIT_PUB_KEY(...) [MMXlogUtil initLog:##__VA_ARGS__]

#define MMXLOG_SET_LOG_LEVEL_ALL() [MMXlogUtil setLogLevel:kLevelAll]
#define MMXLOG_SET_LOG_LEVEL_VERBOSE() [MMXlogUtil setLogLevel:kLevelVerbose]
#define MMXLOG_SET_LOG_LEVEL_DEBUG() [MMXlogUtil setLogLevel:kLevelDebug]
#define MMXLOG_SET_LOG_LEVEL_INFO() [MMXlogUtil setLogLevel:kLevelInfo]
#define MMXLOG_SET_LOG_LEVEL_WARN() [MMXlogUtil setLogLevel:kLevelWarn]
#define MMXLOG_SET_LOG_LEVEL_ERROR() [MMXlogUtil setLogLevel:kLevelError]
#define MMXLOG_SET_LOG_LEVEL_FATAL() [MMXlogUtil setLogLevel:kLevelFatal]
#define MMXLOG_SET_LOG_LEVEL_NONE() [MMXlogUtil setLogLevel:kLevelNone]

#define MMXLOG_SET_CONSOLE_LOG_ENABLED() [MMXlogUtil setConsoleLogEnabled:true]
#define MMXLOG_SET_CONSOLE_LOG_DISABLED() [MMXlogUtil setConsoleLogEnabled:false]

static const char *kModuleViewController = "ViewController";
static const char *kNetwork = "Network";

@interface MMXlog : NSObject

@end


