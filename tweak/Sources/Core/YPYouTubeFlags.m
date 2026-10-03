#import <Foundation/Foundation.h>

// v0.1 forced YouTube's unfinished internal iOS 27 glass feature flags.
// That produced inconsistent stock layouts (especially on Shorts), so v0.2
// deliberately leaves YTColdConfig untouched and owns presentation itself.

__attribute__((constructor)) static void YPLeaveYouTubeNativeGlassUntouched(void) {
    @autoreleasepool {
        NSLog(@"[youpple] native YouTube liquid-glass flags left untouched; using youpple chrome");
    }
}
