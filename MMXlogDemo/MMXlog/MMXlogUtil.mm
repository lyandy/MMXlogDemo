//
//  MMXlogUtil.m
//  MMXlogDemo
//
//  Created by 李扬 on 2019/7/26.
//  Copyright © 2019 李扬. All rights reserved.
//

#import "MMXlogUtil.h"
#import <sys/xattr.h>
#import <mars/xlog/xloggerbase.h>
#import <mars/xlog/xlogger.h>
#import <mars/xlog/appender.h>

static NSUInteger g_processID = 0;

// 接口文档：https://github.com/Tencent/mars/wiki/Mars-iOS%EF%BC%8FOS-X-接口详细说明
@implementation MMXlogUtil

+ (void)initLog
{
    [self initLogWithPubKey:@""];
}

+ (void)initLogWithPubKey:(NSString *)pub_key
{
    NSString* logPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/MMXlog"];
    
    // set do not backup for logpath
    // 禁止 iOS 系统备份此目录
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    setxattr([logPath UTF8String], attrName, &attrValue, sizeof(attrValue), 0, 0);
    
    // init xlog
    appender_open(kAppednerAsync, [logPath UTF8String], "MMXlog", [pub_key UTF8String]);
    
#if DEBUG
    [self setLogLevel:kLevelInfo];
    [self setConsoleLogEnabled:true];
#else
    [self setLogLevel:kLevelInfo];
    [self setConsoleLogEnabled:false];
#endif
    
}

+ (void)setLogLevel:(TLogLevel)level
{
    xlogger_SetLevel(level);
}

+ (void)setConsoleLogEnabled:(BOOL)enabled
{
    appender_set_console_log(enabled);
}

+ (void)logWithLevel:(TLogLevel)logLevel moduleName:(const char*)moduleName fileName:(const char*)fileName lineNumber:(int)lineNumber funcName:(const char*)funcName message:(NSString *)message {
    XLoggerInfo info;
    info.level = logLevel;
    info.tag = moduleName;
    info.filename = fileName;
    info.func_name = funcName;
    info.line = lineNumber;
    gettimeofday(&info.timeval, NULL);
    info.tid = (uintptr_t)[NSThread currentThread];
    info.maintid = (uintptr_t)[NSThread mainThread];
    info.pid = g_processID;
    xlogger_Write(&info, message.UTF8String);
    appender_flush();
}

+ (void)logWithLevel:(TLogLevel)logLevel moduleName:(const char*)moduleName fileName:(const char*)fileName lineNumber:(int)lineNumber funcName:(const char*)funcName format:(NSString *)format, ... {
    if ([self shouldLog:logLevel]) {
        va_list argList;
        va_start(argList, format);
        NSString* message = [[NSString alloc] initWithFormat:format arguments:argList];
        [self logWithLevel:logLevel moduleName:moduleName fileName:fileName lineNumber:lineNumber funcName:funcName message:message];
        va_end(argList);
    }
}

+ (BOOL)shouldLog:(TLogLevel)level {
    
    if (level >= xlogger_Level()) {
        return YES;
    }
    
    return NO;
}

+ (void)appender_close
{
    appender_close();
}


@end
