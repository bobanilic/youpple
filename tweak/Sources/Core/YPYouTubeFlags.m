#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static BOOL YPAlwaysEnableLiquidGlass(id self, SEL _cmd) {
    return YES;
}

static void YPForceBooleanSelector(Class cls, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        NSLog(@"[youpple] YouTube glass flag missing: %@", selectorName);
        return;
    }

    const char *encoding = method_getTypeEncoding(method);
    class_replaceMethod(cls, selector, (IMP)YPAlwaysEnableLiquidGlass, encoding);
    NSLog(@"[youpple] forced YouTube glass flag: %@", selectorName);
}

__attribute__((constructor)) static void YPEnableYouTubeNativeGlass(void) {
    @autoreleasepool {
        Class coldConfig = NSClassFromString(@"YTColdConfig");
        if (!coldConfig) {
            NSLog(@"[youpple] YTColdConfig unavailable; custom glass fallbacks remain active");
            return;
        }

        YPForceBooleanSelector(coldConfig, @"mainAppCoreClientIos27EnableLiquidGlass");
        YPForceBooleanSelector(coldConfig, @"enableLiquidGlassEffect");
    }
}
