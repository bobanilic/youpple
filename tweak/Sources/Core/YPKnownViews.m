#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "YPGlass.h"

static const void *kYPOriginalLayoutKey = &kYPOriginalLayoutKey;
static const void *kYPKnownKindKey = &kYPKnownKindKey;

static Class YPHookedClassForObject(id object) {
    Class cls = object_getClass(object);
    while (cls) {
        if (objc_getAssociatedObject(cls, kYPOriginalLayoutKey)) return cls;
        cls = class_getSuperclass(cls);
    }
    return Nil;
}

static void YPStyleKnownView(UIView *view, NSString *kind) {
    if (![view isKindOfClass:UIView.class] || !view.window) return;

    if ([kind isEqualToString:@"navigation"]) {
        view.backgroundColor = UIColor.clearColor;
        YPInstallGlassBackdrop(view, MIN(26.0, MAX(16.0, view.bounds.size.height * 0.30)), @"known-navigation");
    } else if ([kind isEqualToString:@"miniplayer"]) {
        view.backgroundColor = UIColor.clearColor;
        YPInstallGlassBackdrop(view, MIN(24.0, MAX(14.0, view.bounds.size.height * 0.26)), @"known-miniplayer");
    } else if ([kind isEqualToString:@"search"]) {
        YPInstallGlassBackdrop(view, MIN(22.0, MAX(12.0, view.bounds.size.height * 0.45)), @"known-search");
    }
}

static void YPKnownLayoutSubviews(id self, SEL _cmd) {
    Class hookedClass = YPHookedClassForObject(self);
    NSValue *originalValue = hookedClass ? objc_getAssociatedObject(hookedClass, kYPOriginalLayoutKey) : nil;
    IMP original = originalValue.pointerValue;
    if (original) ((void (*)(id, SEL))original)(self, _cmd);

    NSString *kind = hookedClass ? objc_getAssociatedObject(hookedClass, kYPKnownKindKey) : nil;
    if (kind && [self isKindOfClass:UIView.class]) {
        YPStyleKnownView((UIView *)self, kind);
    }
}

static void YPHookViewClass(NSString *className, NSString *kind) {
    Class cls = NSClassFromString(className);
    if (!cls || ![cls isSubclassOfClass:UIView.class]) return;
    if (objc_getAssociatedObject(cls, kYPOriginalLayoutKey)) return;

    SEL selector = @selector(layoutSubviews);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return;

    IMP original = class_getMethodImplementation(cls, selector);
    objc_setAssociatedObject(cls, kYPOriginalLayoutKey, [NSValue valueWithPointer:original], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cls, kYPKnownKindKey, kind, OBJC_ASSOCIATION_COPY_NONATOMIC);

    const char *types = method_getTypeEncoding(method);
    if (!class_addMethod(cls, selector, (IMP)YPKnownLayoutSubviews, types)) {
        class_replaceMethod(cls, selector, (IMP)YPKnownLayoutSubviews, types);
    }

    NSLog(@"[youpple] installed %@ hook on %@", kind, className);
}

__attribute__((constructor)) static void YPInstallKnownYouTubeViewHooks(void) {
    @autoreleasepool {
        YPHookViewClass(@"YTPivotBarView", @"navigation");
        YPHookViewClass(@"YTWatchFloatingMiniplayerWithPersistentControlsView", @"miniplayer");
        YPHookViewClass(@"YTWatchMiniBarView", @"miniplayer");
        YPHookViewClass(@"YTSearchBarView", @"search");
    }
}
