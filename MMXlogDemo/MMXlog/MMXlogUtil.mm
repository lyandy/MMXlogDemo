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

static NSUInteger g_processID = 0;

static uint32_t __max_upload_reversed_date; // 日志上传文件最大过期时间
static NSString *__xlog_upload_dir; // 日志上传文件夹

@interface MMXlogUtil ()
{
    NSTimeInterval _lastCheckFreeSpace;
}

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
    appender_open(kAppednerAsync, [xlogLogPath UTF8String], "MMXlog", [pub_key UTF8String]);
    
    // 根据不同编译条件设定不同的 TLogLevel 和 是否需要控制台打印日志
#if DEBUG
    [self setLogLevel:kLevelDebug];
    [self setConsoleLogEnabled:true];
#else
    [self setLogLevel:kLevelInfo];
    [self setConsoleLogEnabled:false];
#endif
    
    __xlog_upload_dir = @"xlog_upload"; // xlog 上传日志文件夹
    __max_upload_reversed_date = 7; // 日志上传文件最大过期时间 七天
    // 删除过期的 xlog_upload 文件夹下的e文件
    [self deleteOutdatedUploadFiles];
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
    if ([self hasFreeSpece] == NO) return;
    if ([MMXlogUtil shouldLog:logLevel] == NO) return;
    
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

+ (void)xlogFlush
{
    [[MMXlogUtil sharedUtil] flush];
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

+ (void)uploadXlogFile
{
    // 1. 将当前的 mmap 的数据刷入文件
    appender_flush_sync();
    //2. 在 xlogQueue 队列通过 apply 将 MMXlog 根目录下的所有日志文件 移动到 xlog_upload 目录
    NSString *fromDir = [self xlogLogDirectory];
    NSString *toDir = [self xlogUploadDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager createDirectoryAtPath:toDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSArray *fromFileNamesArr = [[[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self xlogLogDirectory] error:nil] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] '.xlog'"]] sortedArrayUsingSelector:@selector(compare:)]; //[c]不区分大小写 , [d]不区分发音符号即没有重音符号 , [cd]既不区分大小写，也不区分发音符号
    dispatch_apply(fromFileNamesArr.count, [MMXlogUtil sharedUtil].xlogQueue, ^(size_t index) {
        NSString *fileName = fromFileNamesArr[index];
        NSString *fromFullpath = [fromDir stringByAppendingPathComponent:fileName];
        NSString *toFileName = [NSString stringWithFormat:@"%@_%lld.%@", [fileName stringByDeletingPathExtension], @([[NSDate date] timeIntervalSince1970]).longLongValue, fileName.pathExtension];
        NSString *toFullpath = [toDir stringByAppendingPathComponent:toFileName];
        // 剪切
        [fileManager moveItemAtPath:fromFullpath toPath:toFullpath error:nil];
    });
    
    // 3. 遍历数据上传文件
    NSArray *uploadFileNamesArr = [[fileManager contentsOfDirectoryAtPath:toDir error:nil] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] '.xlog'"]];
    // 根据待上传文件个数开启线程，最多5个线程同时上传
    NSUInteger maxThreadCount = uploadFileNamesArr.count <= 5 ? uploadFileNamesArr.count : 5;
    AndyGCDQueue *contextQueue = [[AndyGCDQueue alloc] initWithQOS:NSQualityOfServiceUtility queueCount:maxThreadCount];
    [uploadFileNamesArr enumerateObjectsUsingBlock:^(id  _Nonnull fileName, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *filePath = [toDir stringByAppendingPathComponent:fileName];
        NSString *urlStr = [NSString stringWithFormat:@"http://127.0.0.1:4000/logupload?name=%@", [filePath lastPathComponent]];
        NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlStr] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60];
        [req setHTTPMethod:@"POST"];
        [req addValue:@"binary/octet-stream" forHTTPHeaderField:@"Content-Type"];
        NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
        [contextQueue execute:^{
            NSURLSessionUploadTask *task = [[NSURLSession sharedSession] uploadTaskWithRequest:req fromFile:fileUrl completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
                if (error == nil)
                {
                    // 4. 上传成功后删除本地 xlog_upload 目录下文件
                    [self deleteXlogUploadFile:fileName];
                }
            }];
            [task resume];
        }];
    }];
}

// 删除过期文件
+ (void)deleteOutdatedUploadFiles
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *uploadFileNamesArr = [[fileManager contentsOfDirectoryAtPath:[self xlogUploadDirectory] error:nil] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] '.xlog'"]];
    __block NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    NSString *dateFormatString = @"yyyyMMdd";
    [formatter setDateFormat:dateFormatString];
    [uploadFileNamesArr enumerateObjectsUsingBlock:^(NSString *_Nonnull fileName, NSUInteger idx, BOOL *_Nonnull stop) {
        NSArray *tempStrsArr = [[fileName stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
        if (tempStrsArr.count != 3) return;

        NSString *dateStr = tempStrsArr[1];
        // 检查长度
        if (dateStr.length != (dateFormatString.length))
        {
            [self deleteXlogUploadFile:fileName];
            return;
        }
        
        // 转化为日期
        dateStr = [dateStr substringToIndex:dateFormatString.length];
        NSDate *date = [formatter dateFromString:dateStr];
        NSString *todayStr = [self currentDate];
        NSDate *todayDate = [formatter dateFromString:todayStr];
        if (!date || [self getDaysFrom:date To:todayDate] >= __max_upload_reversed_date)
        {
            // 删除过期文件
            [self deleteXlogUploadFile:fileName];
        }
    }];
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

+ (NSInteger)getDaysFrom:(NSDate *)serverDate To:(NSDate *)endDate
{
    NSCalendar *gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    NSDate *fromDate;
    NSDate *toDate;
    [gregorian rangeOfUnit:NSCalendarUnitDay startDate:&fromDate interval:NULL forDate:serverDate];
    [gregorian rangeOfUnit:NSCalendarUnitDay startDate:&toDate interval:NULL forDate:endDate];
    NSDateComponents *dayComponents = [gregorian components:NSCalendarUnitDay fromDate:fromDate toDate:toDate options:0];
    return dayComponents.day;
}

// 日志上传目录
+ (NSString *)xlogUploadDirectory
{
    static NSString *dir = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dir = [[self xlogLogDirectory] stringByAppendingPathComponent:__xlog_upload_dir];
        
        [self disableAppMobileBackupWithDir:dir];
    });
    return dir;
}

// 日志目录
+ (NSString *)xlogLogDirectory
{
    static NSString *dir = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/MMXlog"];
        
        [self disableAppMobileBackupWithDir:dir];
    });
    return dir;
}

// 删除日志上传目录日志文件
+ (void)deleteXlogUploadFile:(NSString *)name
{
    dispatch_async([MMXlogUtil sharedUtil].xlogQueue, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager removeItemAtPath:[[self xlogUploadDirectory] stringByAppendingPathComponent:name] error:nil];
    });
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
