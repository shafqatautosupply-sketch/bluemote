#import "AppDelegate.h"
#import "MainViewController.h"
#include "btcombo_core.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    application.idleTimerDisabled = YES;          /* keep the screen on while using it as a remote */

    /* pairing keys live in the app's own private folder (not in Documents); an old key file is moved there once */
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = [dirs count] ? [dirs objectAtIndex:0] : @"/var/mobile/Library/Application Support";
    NSString *dir = [base stringByAppendingPathComponent:@"BTCombo"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES
                                               attributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:0700]
                                                                                      forKey:NSFilePosixPermissions]
                                                    error:NULL];
    btcombo_set_data_dir([dir fileSystemRepresentation]);
    btcombo_start();                              /* Bluetooth runs on its own thread */

    window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    window.backgroundColor = [UIColor blackColor];
    MainViewController *main = [[[MainViewController alloc] init] autorelease];
    root = [[UINavigationController alloc] initWithRootViewController:main];
    root.navigationBar.tintColor = [UIColor colorWithRed:0.21f green:0.27f blue:0.37f alpha:1.0f];
    window.rootViewController = root;
    [window makeKeyAndVisible];
    return YES;
}

- (void)dealloc {
    [root release];
    [window release];
    [super dealloc];
}

@end
