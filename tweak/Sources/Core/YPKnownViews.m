#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
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

static id YPObjectGetter(id object, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!object || ![object respondsToSelector:selector]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static void YPStylePivotBar(UIView *view) {
    view.backgroundColor = UIColor.clearColor;

    // Current YouTube builds expose the material as YTPivotBarView.blurView.
    // Prefer replacing that existing effect instead of adding another blur layer.
    id candidate = YPObjectGetter(view, @"blurView");
    if ([candidate isKindOfClass:UIVisualEffectView.class]) {
        UIVisualEffectView *blurView = (UIVisualEffectView *)candidate;
        blurView.hidden = NO;
        blurView.effect = YPPreferredGlassEffect();
        blurView.clipsToBounds = YES;
        CGFloat height = MAX(blurView.bounds.size.height, view.bounds.size.height);
        blurView.layer.cornerRadius = MIN(30.0, MAX(18.0, height * 0.38));
        if ([blurView.layer respondsToSelector:@selector(setCornerCurve:)]) {
            blurView.layer.cornerCurve = kCACornerCurveContinuous;
        }

        id separator = YPObjectGetter(view, @"separatorView");
        if ([separator isKindOfClass:UIView.class]) {
            ((UIView *)separator).hidden = YES;
        }
        return;
    }

    YPInstallGlassBackdrop(view,
                           MIN(28.0, MAX(18.0, view.bounds.size.height * 0.34)),
                           @"known-navigation-fallback");
}

static void YPStyleKnownView(UIView *view, NSString *kind) {
    if (![view isKindOfClass:UIView.class] || !view.window) return;

    if ([kind isEqualToString:@"navigation"]) {
        YPStylePivotBar(view);
    } else if ([kind isEqualToString:@"miniplayer"]) {
        view.backgroundColor = UIColor.clearColor;
        YPInstallGlassBackdrop(view,
                               MIN(24.0, MAX(14.0, view.bounds.size.height * 0.26)),
                               @"known-miniplayer");
    } else if ([kind isEqualToString:@"search-box"]) {
        view.backgroundColor = UIColor.clearColor;
        YPInstallGlassBackdrop(view,
                               MIN(24.0, MAX(14.0, view.bounds.size.height * 0.48)),
                               @"known-search-box");
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
    objc_setAssociatedObject(cls,
                             kYPOriginalLayoutKey,
                             [NSValue valueWithPointer:original],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cls,
                             kYPKnownKindKey,
                             kind,
                             OBJC_ASSOCIATION_COPY_NONATOMIC);

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
        YPHookViewClass(@"YTSearchBoxView", @"search-box");

        // YTSearchBarView is a UITextField subclass on current builds. We intentionally
        // leave it to the generic scanner instead of inserting a backdrop into the text field.
    }
}
