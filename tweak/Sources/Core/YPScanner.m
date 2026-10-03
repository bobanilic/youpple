#import "YPScanner.h"
#import "YPGlass.h"

static BOOL YPContainsAny(NSString *haystack, NSArray<NSString *> *needles) {
    NSString *lower = haystack.lowercaseString;
    for (NSString *needle in needles) {
        if ([lower containsString:needle]) return YES;
    }
    return NO;
}

static CGRect YPRectInWindow(UIView *view, UIWindow *window) {
    return [view convertRect:view.bounds toView:window];
}

static BOOL YPUsefulGeometry(UIView *view) {
    return !view.hidden && view.alpha > 0.03 && view.bounds.size.width > 30.0 && view.bounds.size.height > 20.0;
}

static void YPGlassifyCandidate(UIView *view, UIWindow *window) {
    if (!YPUsefulGeometry(view)) return;

    NSString *name = NSStringFromClass(view.class);
    CGRect rect = YPRectInWindow(view, window);
    CGSize win = window.bounds.size;
    if (win.width <= 0 || win.height <= 0) return;

    BOOL wide = rect.size.width >= win.width * 0.55;
    BOOL bottom = CGRectGetMaxY(rect) >= win.height - 170.0;
    BOOL compactHeight = rect.size.height >= 35.0 && rect.size.height <= 150.0;

    if (wide && bottom && compactHeight &&
        YPContainsAny(name, @[@"pivot", @"tabbar", @"bottomnavigation", @"bottomnav"])) {
        YPInstallGlassBackdrop(view, MIN(28.0, rect.size.height * 0.32), @"navigation");
        NSLog(@"[youpple] glass navigation candidate: %@ %@", name, NSStringFromCGRect(rect));
        return;
    }

    if (wide && bottom && compactHeight &&
        YPContainsAny(name, @[@"miniplayer", @"mini_player", @"miniplayerbar"])) {
        YPInstallGlassBackdrop(view, MIN(24.0, rect.size.height * 0.28), @"miniplayer");
        NSLog(@"[youpple] glass mini-player candidate: %@ %@", name, NSStringFromCGRect(rect));
        return;
    }

    BOOL nearTop = CGRectGetMinY(rect) <= 220.0;
    BOOL searchGeometry = rect.size.height >= 30.0 && rect.size.height <= 90.0 && rect.size.width >= win.width * 0.40;
    if (nearTop && searchGeometry && YPContainsAny(name, @[@"searchbar", @"searchfield", @"searchbox"])) {
        YPInstallGlassBackdrop(view, MIN(22.0, rect.size.height * 0.45), @"search");
        NSLog(@"[youpple] glass search candidate: %@ %@", name, NSStringFromCGRect(rect));
    }
}

static void YPWalk(UIView *view, UIWindow *window, NSUInteger depth) {
    if (!view || depth > 28) return;
    YPGlassifyCandidate(view, window);
    for (UIView *subview in view.subviews) {
        YPWalk(subview, window, depth + 1);
    }
}

void YPScanVisibleWindows(void) {
    NSSet<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes;
    for (UIScene *scene in scenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState == UISceneActivationStateUnattached) continue;
        for (UIWindow *window in windowScene.windows) {
            if (window.hidden || window.alpha <= 0.03) continue;
            YPWalk(window, window, 0);
        }
    }
}

void YPScheduleViewScan(void) {
    static BOOL pending = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (pending) return;
        pending = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            pending = NO;
            YPScanVisibleWindows();
        });
    });
}
