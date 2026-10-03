#import "YPScanner.h"

// v0.2: the scanner is diagnostic only. It must never mutate arbitrary
// YouTube views; visual changes are performed by explicit class adapters.

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
    return !view.hidden && view.alpha > 0.03 &&
        view.bounds.size.width > 30.0 && view.bounds.size.height > 20.0;
}

static void YPInspectCandidate(UIView *view, UIWindow *window) {
    if (!YPUsefulGeometry(view)) return;

    NSString *name = NSStringFromClass(view.class);
    CGRect rect = YPRectInWindow(view, window);
    CGSize win = window.bounds.size;
    if (win.width <= 0 || win.height <= 0) return;

    BOOL wide = rect.size.width >= win.width * 0.55;
    BOOL bottom = CGRectGetMaxY(rect) >= win.height - 180.0;
    BOOL compactHeight = rect.size.height >= 30.0 && rect.size.height <= 160.0;

    if (wide && bottom && compactHeight &&
        YPContainsAny(name, @[@"pivot", @"tabbar", @"bottomnavigation", @"bottomnav",
                              @"miniplayer", @"mini_player", @"miniplayerbar"])) {
        NSLog(@"[youpple][diagnostic] bottom candidate: %@ %@", name, NSStringFromCGRect(rect));
        return;
    }

    BOOL nearTop = CGRectGetMinY(rect) <= 220.0;
    BOOL searchGeometry = rect.size.height >= 30.0 && rect.size.height <= 90.0 &&
        rect.size.width >= win.width * 0.40;
    if (nearTop && searchGeometry &&
        YPContainsAny(name, @[@"searchbar", @"searchfield", @"searchbox"])) {
        NSLog(@"[youpple][diagnostic] search candidate: %@ %@", name, NSStringFromCGRect(rect));
    }
}

static void YPWalk(UIView *view, UIWindow *window, NSUInteger depth) {
    if (!view || depth > 28) return;
    YPInspectCandidate(view, window);
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            pending = NO;
            YPScanVisibleWindows();
        });
    });
}
