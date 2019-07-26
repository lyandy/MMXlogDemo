//
//  MMXlogUtil.h
//  MMXlogDemo
//
//  Created by 李扬 on 2019/7/26.
//  Copyright © 2019 李扬. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mars/xlog/xloggerbase.h>

#define LogInternal(level, module, file, line, func, prefix, format, ...) \
if ([MMXlogUtil shouldLog:level]) { \
NSString *aMessage = [NSString stringWithFormat:@"%@%@", prefix, [NSString stringWithFormat:format, ##__VA_ARGS__, nil]]; \
[MMXlogUtil logWithLevel:level moduleName:module fileName:file lineNumber:line funcName:func message:aMessage]; \
} \

@interface MMXlogUtil : NSObject

+ (void)initLog;
+ (void)initLogWithPubKey:(NSString *)pub_key;

+ (void)setLogLevel:(TLogLevel)level;
+ (void)setConsoleLogEnabled:(BOOL)enabled;

+ (void)logWithLevel:(TLogLevel)logLevel moduleName:(const char*)moduleName fileName:(const char*)fileName lineNumber:(int)lineNumber funcName:(const char*)funcName message:(NSString *)message;
+ (void)logWithLevel:(TLogLevel)logLevel moduleName:(const char*)moduleName fileName:(const char*)fileName lineNumber:(int)lineNumber funcName:(const char*)funcName format:(NSString *)format, ...;

+ (BOOL)shouldLog:(TLogLevel)level;


// 反初始化
+ (void)appender_close;

@end
