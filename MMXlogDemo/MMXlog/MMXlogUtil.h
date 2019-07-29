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
[MMXlogUtil logWithLevel:level moduleName:module fileName:file lineNumber:line funcName:func message:aMessage]; \
} \

typedef void (^filePathBlock)(NSString *_Nullable filePath);

@interface MMXlogUtil : NSObject

// 初始化xlog，不带加密 pub_key
+ (void)initLog;
// 初始化xlog, 带有加密 pub_key
+ (void)initLogWithPubKey:(NSString *)pub_key;

// 手动设置日志打印级别，具体参考 TLogLevel 定义。 默认 DEBUG 下为 kLevelDebug，RELEASE 下为 kLevelInfo
+ (void)setLogLevel:(TLogLevel)level;
// 手动设置控制台是否打印xlog日志。默认 DEBUG 下为 true，RELEASE 下为 false
+ (void)setConsoleLogEnabled:(BOOL)enabled;

// 日志打印oc封装方法
+ (void)logWithLevel:(TLogLevel)logLevel moduleName:(const char*)moduleName fileName:(const char*)fileName lineNumber:(int)lineNumber funcName:(const char*)funcName message:(NSString *)message;
+ (void)logWithLevel:(TLogLevel)logLevel moduleName:(const char*)moduleName fileName:(const char*)fileName lineNumber:(int)lineNumber funcName:(const char*)funcName format:(NSString *)format, ...;

// 根据传入的 TLogLevel 来控制不同level记录，比如传入的 TLogLevel 为 kLevelInfo，则 kLevelDebug 级别的不会打印和记录
+ (BOOL)shouldLog:(TLogLevel)level;

+ (void)uploadFilePathWithName:(NSString *)date block:(filePathBlock)block;

// 关闭日志记录，在程序退出的时候调用
+ (void)appender_close;

+ (NSString *)currentDate;

@end
