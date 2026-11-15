#import <UIKit/UIKit.h>

@class MainViewController;

@interface AppDelegate : NSObject <UIApplicationDelegate, UIAlertViewDelegate> {
    UIWindow *window;
    UINavigationController *root;
    BOOL needsWarning;      /* untested model / iOS: Bluetooth is only started after the person taps Continue */
}
@end
