#import "YPGlass.h"
#import <objc/runtime.h>
#import <objc/message.h>

static const void *kYPGlassIdentifiersKey = &kYPGlassIdentifiersKey;

static NSMutableSet<NSString *> *YPIdentifiersForView(UIView *view) {
    NSMutableSet *set = objc_getAssociatedObject(view, kYPGlassIdentifiersKey);
    if (!set) {
        set = [NSMutableSet set];
        objc_setAssociatedObject(view, kYPGlassIdentifiersKey, set, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return set;
}

BOOL YPViewAlreadyHasGlass(UIView *view, NSString *identifier) {
    return [YPIdentifiersForView(view) containsObject:identifier];
}

UIVisualEffect *YPPreferredGlassEffect(void) {
    // Keep this runtime-only so the tweak can still compile with an SDK that predates iOS 26.
    // Apple's Objective-C API is +[UIGlassEffect effectWithStyle:] and Regular is enum value 0.
    Class glassClass = NSClassFromString(@"UIGlassEffect");
    SEL factory = NSSelectorFromString(@"effectWithStyle:");
    if (glassClass && [glassClass respondsToSelector:factory]) {
        id effect = ((id (*)(id, SEL, NSInteger))objc_msgSend)(glassClass, factory, 0);
        SEL setInteractive = NSSelectorFromString(@"setInteractive:");
        if ([effect respondsToSelector:setInteractive]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(effect, setInteractive, YES);
        }
        if ([effect isKindOfClass:UIVisualEffect.class]) {
            return effect;
        }
    }

    if (@available(iOS 13.0, *)) {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
}

UIVisualEffectView *YPInstallGlassBackdrop(UIView *hostView, CGFloat cornerRadius, NSString *identifier) {
    if (!hostView || identifier.length == 0 || YPViewAlreadyHasGlass(hostView, identifier)) {
        return nil;
    }

    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:YPPreferredGlassEffect()];
    glass.userInteractionEnabled = NO;
    glass.translatesAutoresizingMaskIntoConstraints = NO;
    glass.layer.cornerRadius = cornerRadius;
    if ([glass.layer respondsToSelector:@selector(setCornerCurve:)]) {
        glass.layer.cornerCurve = kCACornerCurveContinuous;
    }
    glass.clipsToBounds = YES;
    glass.accessibilityIdentifier = [@"youpple.glass." stringByAppendingString:identifier];

    [hostView insertSubview:glass atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [glass.leadingAnchor constraintEqualToAnchor:hostView.leadingAnchor],
        [glass.trailingAnchor constraintEqualToAnchor:hostView.trailingAnchor],
        [glass.topAnchor constraintEqualToAnchor:hostView.topAnchor],
        [glass.bottomAnchor constraintEqualToAnchor:hostView.bottomAnchor],
    ]];

    [YPIdentifiersForView(hostView) addObject:identifier];
    return glass;
}
