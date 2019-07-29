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
    // "MMXlog" xlog 写日志目录
    NSString* logPath = [self loganLogDirectory];
    // 禁止 iOS 系统备份此目录
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    setxattr([logPath UTF8String], attrName, &attrValue, sizeof(attrValue), 0, 0);
    
    // 初始化 xlog：1、初始化控制台打印 2、将 mmap 里的数据会写到日志文件中
    // kAppednerAsync：异步写入xlog日志，不要使用 kAppednerSync ，可能会造成卡顿
    appender_open(kAppednerAsync, [logPath UTF8String], "MMXlog", [pub_key UTF8String]);
    
    // 根据不同编译条件设定不同的 TLogLevel 和 是否需要控制台打印日志
#if DEBUG
    [self setLogLevel:kLevelDebug];
    [self setConsoleLogEnabled:true];
#else
    [self setLogLevel:kLevelInfo];
    [self setConsoleLogEnabled:false];
#endif
    
}

// 手动设置日志打印级别
+ (void)setLogLevel:(TLogLevel)level
{
    xlogger_SetLevel(level);
}

// 手动设置控制台是否打印xlog日志
+ (void)setConsoleLogEnabled:(BOOL)enabled
{
    appender_set_console_log(enabled);
}

+ (void)logWithLevel:(TLogLevel)logLevel moduleName:(const char*)moduleName fileName:(const char*)fileName lineNumber:(int)lineNumber funcName:(const char*)funcName message:(NSString *)message {
    XLoggerInfo info;
    info.level = logLevel; // xlog level
    info.tag = moduleName; // 模块业务名称
    info.filename = fileName; // 文件名称
    info.func_name = funcName; // 方法名称
    info.line = lineNumber; // 代码行
    gettimeofday(&info.timeval, NULL); // 当前时间
    info.tid = (uintptr_t)[NSThread currentThread];
    info.maintid = (uintptr_t)[NSThread mainThread];
    info.pid = g_processID;
    xlogger_Write(&info, message.UTF8String); // 记录 xlog 日志
    appender_flush(); // 异步将 mmap 中的数据回写到文件中, 不要使用 同步appender_flush_sync()， 可能会造成卡顿
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

+ (NSString *)logFilePath:(NSString *)date {
    return [[self loganLogDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", date]];
}

+ (void)uploadFilePathWithName:(NSString *)date block:(filePathBlock)block
{
    NSString *uploadFilePath = nil;
    NSString *filePath = nil;
    if (date.length)
    {
        NSArray *allFiles = [self localFilesArray];
        if ([allFiles containsObject:date]) {
            filePath = [self logFilePath:date];
            if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
            {
                uploadFilePath = filePath;
            }
        }
    }
    
    if (uploadFilePath.length) {
        if ([date isEqualToString:[self currentDate]]) {
                [self todayFilePatch:block];
            return;
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        filePathBlock(uploadFilePath);
    });
}

+ (void)todayFilePatch:(filePathBlock)filePathBlock {
    appender_flush();
    NSString *uploadFilePath = [self uploadFilePath:[self currentDate]];
    NSString *filePath = [self logFilePath:[self currentDate]];
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:uploadFilePath error:&error];
    if (![[NSFileManager defaultManager] copyItemAtPath:filePath toPath:uploadFilePath error:&error]) {
        uploadFilePath = nil;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        filePathBlock(uploadFilePath);
    });
}

+ (NSArray *)localFilesArray {
    return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self loganLogDirectory] error:nil]; //[c]不区分大小写 , [d]不区分发音符号即没有重音符号 , [cd]既不区分大小写，也不区分发音符号。
}

+ (NSString *)loganLogDirectory {
    static NSString *dir = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/MMXlog"];
    });
    return dir;
}

+ (NSString *)uploadFilePath:(NSString *)date {
    return [[self loganLogDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.temp", date]];
}


// 判断当前 TLogLevel 是否满足日志记录条件
+ (BOOL)shouldLog:(TLogLevel)level {

    if (level >= xlogger_Level()) {
        return YES;
    }
    
    return NO;
}

// xlog s初始化
+ (void)appender_close
{
    appender_close();
}

+ (NSString *)currentDate
{
    NSString *key = @"XLOG_CURRENTDATE";
    NSMutableDictionary *dictionary = [[NSThread currentThread] threadDictionary];
    NSDateFormatter *dateFormatter = [dictionary objectForKey:key];
    if (!dateFormatter)
    {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dictionary setObject:dateFormatter forKey:key];
        [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        [dateFormatter setDateFormat:@"yyyyMMdd"];
        [dictionary setObject:dateFormatter forKey:key];
    }
    NSString *date = [dateFormatter stringFromDate:[NSDate new]];
    date = [[@"MMXlog_" stringByAppendingString:date] stringByAppendingString:@".xlog"];
    return date;
}

@end
