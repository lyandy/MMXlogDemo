//
//  MMXlogUtil.m
//  MMXlogDemo
//
//  Created by 李扬 on 2019/7/26.
//  Copyright © 2019 李扬. All rights reserved.
//

#import "MMXlogUtil.h"
#import <sys/xattr.h>
#import <sys/time.h>
#include <sys/mount.h>
#import <mars/xlog/xloggerbase.h>
#import <mars/xlog/xlogger.h>
#import <mars/xlog/appender.h>

#import "AndyGCD.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

static NSUInteger const g_processID = 0;
static NSString * const log_file_prefix = @"MMXlog";

@interface MMXlogUtil ()
{
    NSTimeInterval _lastCheckFreeSpace;
}

#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong) dispatch_queue_t xlogQueue;
#else
@property (nonatomic, assign) dispatch_queue_t xlogQueue;
#endif

@end

// 接口文档：https://github.com/Tencent/mars/wiki/Mars-iOS%EF%BC%8FOS-X-接口详细说明
@implementation MMXlogUtil

+ (void)initLog
{
    [self initLogWithPubKey:@""];
}

+ (void)initLogWithPubKey:(NSString *)pub_key
{
    // "MMXlog" xlog 写日志目录
    NSString* xlogLogPath = [self xlogLogDirectory];
    
    // 初始化 xlog：1、初始化控制台打印 2、将 mmap 里的数据会写到日志文件中
    // kAppednerAsync：异步写入xlog日志，不要使用 kAppednerSync ，可能会造成卡顿
    appender_open(kAppednerAsync, [xlogLogPath UTF8String], [log_file_prefix UTF8String], [pub_key UTF8String]);
    
    // 根据不同编译条件设定不同的 TLogLevel 和 是否需要控制台打印日志
#if DEBUG
    [self setLogLevel:kLevelDebug];
    [self setConsoleLogEnabled:true];
#else
    [self setLogLevel:kLevelInfo];
    [self setConsoleLogEnabled:false];
#endif
    
}

+ (instancetype)sharedUtil
{
    static MMXlogUtil *instance = nil;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        instance = [[MMXlogUtil alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    if (self = [super init])
    {
        _xlogQueue = dispatch_queue_create("com.maimai.xlog", DISPATCH_QUEUE_SERIAL);
        dispatch_async(self.xlogQueue, ^{
            [self addNotification];
        });
    }
    return self;
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

- (void)logWithLevel:(TLogLevel)logLevel moduleName:(const char*)moduleName fileName:(const char*)fileName lineNumber:(int)lineNumber funcName:(const char*)funcName message:(NSString *)message
{
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
    dispatch_async(self.xlogQueue, ^{
        xlogger_Write(&info, message.UTF8String); // 记录 xlog 日志
    });
}

- (void)logWithLevel:(TLogLevel)logLevel moduleName:(const char*)moduleName fileName:(const char*)fileName lineNumber:(int)lineNumber funcName:(const char*)funcName format:(NSString *)format, ...
{
    if ([self hasFreeSpece] == NO) return; // 没有足够的磁盘空间
    if ([MMXlogUtil shouldLog:logLevel] == NO) return; // 是否达到了日志记录级别
    
    va_list argList;
    va_start(argList, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:argList];
    [self logWithLevel:logLevel moduleName:moduleName fileName:fileName lineNumber:lineNumber funcName:funcName message:message];
    va_end(argList);
}

// 判断当前 TLogLevel 是否满足日志记录条件
+ (BOOL)shouldLog:(TLogLevel)level
{
    if (level >= xlogger_Level())
    {
        return YES;
    }
    
    return NO;
}

// xlog s初始化
+ (void)appender_close
{
    appender_close();
}

#pragma mark - notification
- (void)addNotification
{
    // App Extension
    if ( [[[NSBundle mainBundle] bundlePath] hasSuffix:@".appex"] )
    {
        return ;
    }
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
#else
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground) name:NSApplicationWillBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:NSApplicationDidResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate) name:NSApplicationWillTerminateNotification object:nil];
#endif
    
}

- (void)appDidEnterBackground
{
    [self flush];
}

- (void)appWillEnterForeground
{
    [self flush];
}

- (void)appWillTerminate
{
    [self flush];
}

- (void)flush
{
    dispatch_async(self.xlogQueue, ^{
        [self flushInQueue];
    });
}

- (void)flushInQueue
{
    appender_flush();
}

- (BOOL)hasFreeSpece
{
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now > (_lastCheckFreeSpace + 60))
    {
        _lastCheckFreeSpace = now;
        // 每隔至少1分钟，检查一下剩余空间
        long long freeDiskSpace = [self freeDiskSpaceInBytes];
        if (freeDiskSpace <= 5 * 1024 * 1024)
        {
            // 剩余空间不足5m时，不再写入
            return NO;
        }
    }
    return YES;
}

- (long long)freeDiskSpaceInBytes
{
    struct statfs buf;
    long long freespace = -1;
    if (statfs("/var", &buf) >= 0)
    {
        freespace = (long long)(buf.f_bsize * buf.f_bfree);
    }
    return freespace;
}

+ (NSArray *)localFilesArray
{
    return [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self xlogLogDirectory] error:nil] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] '.xlog'"]]; //[c]不区分大小写 , [d]不区分发音符号即没有重音符号 , [cd]既不区分大小写，也不区分发音符号。
}

+ (NSString *)logFilePathWithFileName:(NSString *)fileName
{
    return [[self xlogLogDirectory] stringByAppendingPathComponent:fileName];
}

+ (NSDictionary *)allFilesInfoDict
{
    NSArray *allFileNamesArr = [self localFilesArray];
    NSMutableDictionary *infoDic = [NSMutableDictionary dictionary];
    for (NSString *fileName in allFileNamesArr) {
        unsigned long long gzFileSize = [self fileSizeAtPath:[self logFilePathWithFileName:fileName]];
        NSString *size = [NSString stringWithFormat:@"%llu", gzFileSize];
        [infoDic setObject:size forKey:fileName];
    }
    return infoDic;
}

+ (NSString *)allFilesInfo
{
    NSDictionary *dict = [self allFilesInfoDict];
    NSMutableString *str = [[NSMutableString alloc] init];
    for (NSString *k in dict.allKeys) {
        [str appendFormat:@"文件名称 %@，大小 %@byte\n", k, [dict objectForKey:k]];
    }
    
    return [str copy];
}

+ (unsigned long long)fileSizeAtPath:(NSString *)filePath
{
    if (filePath.length == 0)
    {
        return 0;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isExist = [fileManager fileExistsAtPath:filePath];
    if (isExist)
    {
        return [[fileManager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
    else
    {
        return 0;
    }
}

+ (void)filePathForDate:(NSString *)date block:(xlogFilePathBlock)filePathBlock
{
    __block NSString *uploadFilePath = nil;
    NSString *filePath = nil;
    NSString *fileName = [log_file_prefix stringByAppendingString:[NSString stringWithFormat:@"_%@.xlog", date]];
    if (date.length > 0)
    {
        NSArray *allFiles = [self localFilesArray];
        if ([allFiles containsObject:fileName])
        {
            filePath = [self logFilePathWithFileName:fileName];
            if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
            {
                uploadFilePath = filePath;
            }
        }
    }
    
    if (uploadFilePath.length > 0)
    {
        if ([date isEqualToString:[self currentDate]])
        {
            dispatch_async([MMXlogUtil sharedUtil].xlogQueue, ^{
                uploadFilePath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@.temp.xlog", log_file_prefix, date]];
                [self todayFilePatch:filePathBlock uploadFilePath:uploadFilePath filePath:filePath];
            });
            return;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        filePathBlock(uploadFilePath);
    });
}

+ (void)todayFilePatch:(xlogFilePathBlock)filePathBlock uploadFilePath:(NSString *)uploadFilePath filePath:(NSString *)filePath
{
    appender_flush_sync();
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:uploadFilePath error:&error];
    if (![[NSFileManager defaultManager] copyItemAtPath:filePath toPath:uploadFilePath error:&error])
    {
        uploadFilePath = nil;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        filePathBlock(uploadFilePath);
    });
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
    return [dateFormatter stringFromDate:[NSDate new]];
}

// 日志目录
+ (NSString *)xlogLogDirectory
{
    static NSString *dir = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:log_file_prefix];
        
        [self disableAppMobileBackupWithDir:dir];
    });
    return dir;
}

// 禁止 iOS 系统备份目录
+ (void)disableAppMobileBackupWithDir:(NSString *)dir
{
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    setxattr([dir UTF8String], attrName, &attrValue, sizeof(attrValue), 0, 0);
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
