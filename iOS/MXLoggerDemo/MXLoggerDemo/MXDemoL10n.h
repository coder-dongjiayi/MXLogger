//
//  MXDemoL10n.h
//  MXLoggerDemo
//
//  Demo 内置的语言管理：默认英文，可在 App 内切换中文。
//  不依赖系统语言，语言包从 en.lproj / zh-Hans.lproj 读取。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 语言切换后发出，观察者应刷新自己的文案
FOUNDATION_EXPORT NSNotificationName const MXDemoLanguageDidChangeNotification;

@interface MXDemoL10n : NSObject

/// 当前语言: "en" 或 "zh-Hans"，默认 "en"
+ (NSString *)currentLanguage;

/// 是否是中文
+ (BOOL)isChinese;

/// 切换到另一种语言并发出 MXDemoLanguageDidChangeNotification
+ (void)toggleLanguage;

/// 从当前语言包取文案，取不到时原样返回 key
+ (NSString *)stringForKey:(NSString *)key;

/// 语言切换按钮的标题：英文环境显示 "中文"，中文环境显示 "English"
+ (NSString *)switchButtonTitle;

@end

/// 取当前语言文案的便捷函数
static inline NSString *MXDemoStr(NSString *key) {
    return [MXDemoL10n stringForKey:key];
}

NS_ASSUME_NONNULL_END
