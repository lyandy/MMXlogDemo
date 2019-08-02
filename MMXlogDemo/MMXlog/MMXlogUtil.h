//
//  MMXlogUtil.h
//  MMXlogDemo
//
//  Created by 李扬 on 2019/7/26.
//  Copyright © 2019 李扬. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mars/xlog/xloggerbase.h>

// 日志打印宏定义
#define LogInternal(level, module, file, line, func, prefix, format, ...) \
if ([MMXlogUtil shouldLog:level]) { \
NSString *aMessage = [NSString stringWithFormat:@"%@%@", prefix, [NSString stringWithFormat:format, ##__VA_ARGS__, nil]]; \
[[MMXlogUtil sharedUtil] logWithLevel:level moduleName:module fileName:file lineNumber:line funcName:func message:aMessage]; \
} \

typedef void (^xlogFilePathBlock)(NSString * filePath);

@interface MMXlogUtil : NSObject

+ (instancetype)sharedUtil;

// 初始化xlog，不带加密 pub_key
+ (void)initLog;
// 初始化xlog, 带有加密 pub_key
+ (void)initLogWithPubKey:(NSString *)pub_key;

// 手动设置日志打印级别，具体参考 TLogLevel 定义。 默认 DEBUG 下为 kLevelDebug，RELEASE 下为 kLevelInfo
+ (void)setLogLevel:(TLogLevel)level;
// 手动设置控制台是否打印xlog日志。默认 DEBUG 下为 true，RELEASE 下为 false
+ (void)setConsoleLogEnabled:(BOOL)enabled;

// 日志打印oc封装方法
- (void)logWithLevel:(TLogLevel)logLevel moduleName:(const char*)moduleName fileName:(const char*)fileName lineNumber:(int)lineNumber funcName:(const char*)funcName message:(NSString *)message;
- (void)logWithLevel:(TLogLevel)logLevel moduleName:(const char*)moduleName fileName:(const char*)fileName lineNumber:(int)lineNumber funcName:(const char*)funcName format:(NSString *)format, ...;

// 根据传入的 TLogLevel 来控制不同level记录，比如传入的 TLogLevel 为 kLevelInfo，则 kLevelDebug 级别的不会打印和记录
+ (BOOL)shouldLog:(TLogLevel)level;

// 关闭日志记录，在程序退出的时候调用
+ (void)appender_close;

// 文件信息字典对应文件：@{文件名：大小}
+ (NSDictionary *)allFilesInfoDict;

// 获取文件信息
+ (NSString *)allFilesInfo;

// 当前日期字符串格式化 格式：yyMMdd，例如：20190802
+ (NSString *)currentDate;

// 根据日期获取对应上传文件的路径
+ (void)filePathForDate:(NSString *)date block:(xlogFilePathBlock)filePathBlock;

@end
