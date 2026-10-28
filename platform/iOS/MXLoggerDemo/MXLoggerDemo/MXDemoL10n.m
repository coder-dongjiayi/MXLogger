//
//  MXDemoL10n.m
//  MXLoggerDemo
//

#import "MXDemoL10n.h"

NSNotificationName const MXDemoLanguageDidChangeNotification = @"MXDemoLanguageDidChangeNotification";

static NSString * const kMXDemoLanguageKey = @"MXDemoLanguage";
static NSString * const kMXDemoLanguageEN = @"en";
static NSString * const kMXDemoLanguageZH = @"zh-Hans";

@implementation MXDemoL10n

+ (NSString *)currentLanguage {
    NSString *language = [[NSUserDefaults standardUserDefaults] stringForKey:kMXDemoLanguageKey];
    return [language isEqualToString:kMXDemoLanguageZH] ? kMXDemoLanguageZH : kMXDemoLanguageEN;
}

+ (BOOL)isChinese {
    return [[self currentLanguage] isEqualToString:kMXDemoLanguageZH];
}

+ (void)toggleLanguage {
    NSString *next = [self isChinese] ? kMXDemoLanguageEN : kMXDemoLanguageZH;
    [[NSUserDefaults standardUserDefaults] setObject:next forKey:kMXDemoLanguageKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:MXDemoLanguageDidChangeNotification object:nil];
}

+ (NSBundle *)languageBundle {
    static NSMutableDictionary<NSString *, NSBundle *> *bundles;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ bundles = [NSMutableDictionary dictionary]; });

    NSString *language = [self currentLanguage];
    NSBundle *bundle = bundles[language];
    if (!bundle) {
        NSString *path = [[NSBundle mainBundle] pathForResource:language ofType:@"lproj"];
        bundle = path ? [NSBundle bundleWithPath:path] : [NSBundle mainBundle];
        bundles[language] = bundle;
    }
    return bundle;
}

+ (NSString *)stringForKey:(NSString *)key {
    return [[self languageBundle] localizedStringForKey:key value:key table:nil];
}

+ (NSString *)switchButtonTitle {
    return [self isChinese] ? @"English" : @"中文";
}

@end
