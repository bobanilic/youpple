#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "YPGlass.h"

// youpple v0.2 presentation layer.
// The goal is Apple Music-style geometry: compact floating materials with
// YouTube's own controls remaining responsible for navigation and playback.

static const void *kYPOriginalLayoutKey = &kYPOriginalLayoutKey;
static const void *kYPKnownKindKey = &kYPKnownKindKey;
static const void *kYPPivotGlassKey = &kYPPivotGlassKey;
static const void *kYPMiniGlassKey = &kYPMiniGlassKey;
static const void *kYPSearchGlassKey = &kYPSearchGlassKey;
static const void *kYPTabPillKey = &kYPTabPillKey;

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

static BOOL YPBoolGetter(id object, NSString *selectorName, BOOL fallback) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!object || ![object respondsToSelector:selector]) return fallback;
    return ((BOOL (*)(id, SEL))objc_msgSend)(object, selector);
}

static UIVisualEffectView *YPGlassForOwner(UIView *owner, const void *key) {
    UIVisualEffectView *glass = objc_getAssociatedObject(owner, key);
    if (glass) return glass;

    glass = [[UIVisualEffectView alloc] initWithEffect:YPPreferredGlassEffect()];
    glass.userInteractionEnabled = NO;
    glass.backgroundColor = UIColor.clearColor;
    glass.clipsToBounds = YES;
    if ([glass.layer respondsToSelector:@selector(setCornerCurve:)]) {
        glass.layer.cornerCurve = kCACornerCurveContinuous;
    }
    objc_setAssociatedObject(owner, key, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return glass;
}

static void YPPlaceGlassInside(UIView *owner,
                               const void *key,
                               CGRect frame,
                               CGFloat radius,
                               NSString *identifier) {
    if (CGRectIsEmpty(frame) || frame.size.width < 20.0 || frame.size.height < 20.0) return;
    UIVisualEffectView *glass = YPGlassForOwner(owner, key);
    if (glass.superview != owner) {
        [glass removeFromSuperview];
        [owner insertSubview:glass atIndex:0];
    } else if (owner.subviews.firstObject != glass) {
        [owner sendSubviewToBack:glass];
    }
    glass.hidden = NO;
    glass.frame = CGRectIntegral(frame);
    glass.layer.cornerRadius = radius;
    glass.accessibilityIdentifier = identifier;
}

static void YPHideYouTubePivotMaterial(UIView *view) {
    id blur = YPObjectGetter(view, @"blurView");
    if ([blur isKindOfClass:UIView.class]) {
        UIView *blurView = (UIView *)blur;
        blurView.hidden = YES;
        blurView.alpha = 0.0;
    }

    id separator = YPObjectGetter(view, @"separatorView");
    if ([separator isKindOfClass:UIView.class]) {
        ((UIView *)separator).hidden = YES;
    }
}

static CGRect YPPivotGlassFrame(UIView *view) {
    CGRect bounds = view.bounds;
    if (CGRectIsEmpty(bounds)) return CGRectZero;

    // YTPivotBarView normally includes the bottom safe area. Do not glass that
    // region; Apple Music leaves the home-indicator area visually open.
    CGFloat safeBottom = MAX(0.0, view.safeAreaInsets.bottom);
    CGFloat usableHeight = MAX(0.0, CGRectGetHeight(bounds) - safeBottom);

    CGFloat height = MIN(56.0, MAX(48.0, usableHeight - 4.0));
    CGFloat horizontalInset = 10.0;
    CGFloat width = MAX(0.0, CGRectGetWidth(bounds) - horizontalInset * 2.0);
    CGFloat y = MAX(2.0, (usableHeight - height) * 0.5);

    return CGRectMake(horizontalInset, y, width, height);
}

static void YPStylePivotBar(UIView *view) {
    if (!view.window || CGRectIsEmpty(view.bounds)) return;

    view.backgroundColor = UIColor.clearColor;
    view.opaque = NO;
    view.clipsToBounds = NO;
    YPHideYouTubePivotMaterial(view);

    CGRect frame = YPPivotGlassFrame(view);
    CGFloat radius = CGRectGetHeight(frame) * 0.5;
    YPPlaceGlassInside(view,
                       kYPPivotGlassKey,
                       frame,
                       radius,
                       @"youpple.chrome.navigation");
}

static BOOL YPTabItemSelected(UIView *view) {
    if (YPBoolGetter(view, @"isSelected", NO) || YPBoolGetter(view, @"selected", NO)) {
        return YES;
    }

    id navigationButton = YPObjectGetter(view, @"navigationButton");
    if ([navigationButton isKindOfClass:UIControl.class] && ((UIControl *)navigationButton).selected) {
        return YES;
    }

    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:UIControl.class] && ((UIControl *)subview).selected) {
            return YES;
        }
    }
    return NO;
}

static void YPStyleTabItem(UIView *view) {
    if (!view.window || CGRectIsEmpty(view.bounds)) return;

    UIView *pill = objc_getAssociatedObject(view, kYPTabPillKey);
    if (!pill) {
        pill = [[UIView alloc] initWithFrame:CGRectZero];
        pill.userInteractionEnabled = NO;
        pill.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.11];
        if ([pill.layer respondsToSelector:@selector(setCornerCurve:)]) {
            pill.layer.cornerCurve = kCACornerCurveContinuous;
        }
        [view insertSubview:pill atIndex:0];
        objc_setAssociatedObject(view, kYPTabPillKey, pill, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (pill.superview == view) {
        [view sendSubviewToBack:pill];
    }

    CGFloat h = MIN(43.0, MAX(36.0, CGRectGetHeight(view.bounds) - 4.0));
    CGFloat w = MIN(MAX(48.0, CGRectGetWidth(view.bounds) - 4.0), 78.0);
    pill.frame = CGRectMake((CGRectGetWidth(view.bounds) - w) * 0.5,
                            (CGRectGetHeight(view.bounds) - h) * 0.5,
                            w,
                            h);
    pill.layer.cornerRadius = MIN(20.0, h * 0.46);
    pill.hidden = !YPTabItemSelected(view);
}

static CGRect YPMiniPlayerGlassFrame(UIView *view) {
    CGRect bounds = view.bounds;
    if (CGRectIsEmpty(bounds)) return CGRectZero;

    CGFloat horizontalInset = 10.0;
    CGFloat availableHeight = CGRectGetHeight(bounds);
    CGFloat height = MIN(58.0, MAX(44.0, availableHeight - 4.0));
    CGFloat y = MAX(2.0, (availableHeight - height) * 0.5);
    return CGRectMake(horizontalInset,
                      y,
                      MAX(0.0, CGRectGetWidth(bounds) - horizontalInset * 2.0),
                      height);
}

static void YPStyleMiniPlayer(UIView *view) {
    if (!view.window || CGRectIsEmpty(view.bounds)) return;

    // Do not turn a genuinely small draggable/floating video into a huge pill.
    // The docked mini-player is a wide surface; that is the one we want.
    CGFloat screenWidth = view.window.bounds.size.width;
    if (screenWidth > 0.0 && CGRectGetWidth(view.bounds) < screenWidth * 0.62) return;

    view.backgroundColor = UIColor.clearColor;
    view.opaque = NO;
    view.clipsToBounds = NO;

    CGRect frame = YPMiniPlayerGlassFrame(view);
    YPPlaceGlassInside(view,
                       kYPMiniGlassKey,
                       frame,
                       CGRectGetHeight(frame) * 0.5,
                       @"youpple.chrome.miniplayer");
}

static void YPStyleSearchBox(UIView *view) {
    if (!view.window || CGRectIsEmpty(view.bounds)) return;
    view.backgroundColor = UIColor.clearColor;
    view.opaque = NO;

    CGRect frame = CGRectInset(view.bounds, 2.0, 2.0);
    if (frame.size.height > 52.0) {
        CGFloat target = 48.0;
        frame.origin.y = (CGRectGetHeight(view.bounds) - target) * 0.5;
        frame.size.height = target;
    }
    YPPlaceGlassInside(view,
                       kYPSearchGlassKey,
                       frame,
                       CGRectGetHeight(frame) * 0.5,
                       @"youpple.chrome.search");
}

static void YPStyleKnownView(UIView *view, NSString *kind) {
    if (![view isKindOfClass:UIView.class] || !view.window) return;

    if ([kind isEqualToString:@"navigation"]) {
        YPStylePivotBar(view);
    } else if ([kind isEqualToString:@"tab-item"]) {
        YPStyleTabItem(view);
    } else if ([kind isEqualToString:@"miniplayer"]) {
        YPStyleMiniPlayer(view);
    } else if ([kind isEqualToString:@"search-box"]) {
        YPStyleSearchBox(view);
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
        YPHookViewClass(@"YTPivotBarItemView", @"tab-item");

        YPHookViewClass(@"YTWatchMiniBarView", @"miniplayer");
        YPHookViewClass(@"YTWatchFloatingMiniplayerWithPersistentControlsView", @"miniplayer");

        YPHookViewClass(@"YTSearchBoxView", @"search-box");
    }
}
