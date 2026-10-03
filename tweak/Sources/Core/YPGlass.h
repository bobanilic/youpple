#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

UIVisualEffect *YPPreferredGlassEffect(void);
UIVisualEffectView *YPInstallGlassBackdrop(UIView *hostView, CGFloat cornerRadius, NSString *identifier);
BOOL YPViewAlreadyHasGlass(UIView *view, NSString *identifier);

NS_ASSUME_NONNULL_END
