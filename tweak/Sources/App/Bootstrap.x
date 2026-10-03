#import <UIKit/UIKit.h>
#import "Core/YPScanner.h"

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    YPScheduleViewScan();
}

%end

%ctor {
    @autoreleasepool {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"";
        NSLog(@"[youpple] %@ loaded into %@ (%@)", @YP_VERSION, NSBundle.mainBundle.bundlePath, bundleID);

        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidBecomeActiveNotification
            object:nil
            queue:NSOperationQueue.mainQueue
            usingBlock:^(__unused NSNotification *note) {
                YPScheduleViewScan();
            }];

        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIWindowDidBecomeVisibleNotification
            object:nil
            queue:NSOperationQueue.mainQueue
            usingBlock:^(__unused NSNotification *note) {
                YPScheduleViewScan();
            }];
    }
}
