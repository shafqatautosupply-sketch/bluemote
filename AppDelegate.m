#import "AppDelegate.h"
#import "MainViewController.h"
#import "UIHelpers.h"
#include "bluemote_core.h"
#include <sys/sysctl.h>
#include <stdlib.h>

/* ---- soft warning on untested phones / iOS versions ----
   Bluemote was built and tested on an iPhone 4s (iPhone4,1) running iOS 6.x. Anything else is allowed, but only after
   the person has been told. The Bluetooth thread (and with it the daemon, which takes the chip from iOS) is not started
   until they tap Continue. The choice is remembered per model + iOS version, so it is asked once, not every launch. */

static NSString *BTMachineName(void) {
    size_t len = 0;
    if (sysctlbyname("hw.machine", NULL, &len, NULL, 0) != 0 || len == 0 || len > 64) return @"unknown device";
    char *buf = (char *)calloc(len + 1, 1);
    if (!buf) return @"unknown device";
    NSString *name = @"unknown device";
    if (sysctlbyname("hw.machine", buf, &len, NULL, 0) == 0) name = [NSString stringWithUTF8String:buf];
    free(buf);
    return name ? name : @"unknown device";
}

static BOOL BTIsTestedSetup(NSString *machine, NSString *ios) {
    return [machine isEqualToString:@"iPhone4,1"] && [ios hasPrefix:@"6."];
}

static NSString *BTAckKey(NSString *machine, NSString *ios) {
    return [NSString stringWithFormat:@"untestedAck.%@.%@", machine, ios];
}

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    application.idleTimerDisabled = YES;          /* keep the screen on while using it as a remote */

    /* pairing keys live in the app's own private folder (not in Documents); an old key file is moved there once */
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = [dirs count] ? [dirs objectAtIndex:0] : @"/var/mobile/Library/Application Support";
    NSString *dir = [base stringByAppendingPathComponent:@"Bluemote"];

    /* coming from the old "BTCombo" app: move its pairing keys folder over once, and copy its settings */
    NSString *oldDir = [base stringByAppendingPathComponent:@"BTCombo"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:oldDir] && ![fm fileExistsAtPath:dir]) [fm moveItemAtPath:oldDir toPath:dir error:NULL];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (![ud boolForKey:@"migratedFromBTCombo"]) {
        NSDictionary *oldPrefs = [ud persistentDomainForName:@"com.btcombo.app"];
        for (NSString *k in oldPrefs) if ([ud objectForKey:k] == nil) [ud setObject:[oldPrefs objectForKey:k] forKey:k];
        [ud setBool:YES forKey:@"migratedFromBTCombo"];
        [ud synchronize];
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES
                                               attributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:0700]
                                                                                      forKey:NSFilePosixPermissions]
                                                    error:NULL];
    bluemote_set_data_dir([dir fileSystemRepresentation]);
    NSString *machine = BTMachineName();
    NSString *ios = [[UIDevice currentDevice] systemVersion];
    if (BTIsTestedSetup(machine, ios) || [ud boolForKey:BTAckKey(machine, ios)]) {
        bluemote_start();                          /* Bluetooth runs on its own thread */
    } else {
        needsWarning = YES;                        /* asked below, once the window is up; Bluetooth stays off until then */
    }

    window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    window.backgroundColor = BTBackdropColor();   /* dark graphite, not black: it shows behind the flip and the Settings push */
    [[UIBarButtonItem appearance] setTintColor:BTBarButtonTintColor()];   /* every bar button, incl. the Back buttons */
    MainViewController *main = [[[MainViewController alloc] init] autorelease];
    root = [[UINavigationController alloc] initWithRootViewController:main];
    root.view.backgroundColor = BTBackdropColor();
    root.navigationBar.tintColor = BTBarTintColor();   /* dark grey bar to go with the aluminium */
    window.rootViewController = root;
    [window makeKeyAndVisible];
    if (needsWarning) [self performSelector:@selector(showUntestedWarning) withObject:nil afterDelay:0.4];
    return YES;
}

/* automatic reconnect only runs while the app is in the foreground; coming back starts a fresh cycle */
- (void)applicationDidBecomeActive:(UIApplication *)application {
    bluemote_send("ACTIVE 1");
}

- (void)applicationWillResignActive:(UIApplication *)application {
    bluemote_send("ACTIVE 0");
}

- (void)showUntestedWarning {
    NSString *msg = [NSString stringWithFormat:
        @"Bluemote was built and tested on an iPhone 4s running iOS 6. This is %@ on iOS %@, which has not been tested.\n\n"
        @"It may not work. While it runs it takes the Bluetooth chip away from iOS, so if Bluetooth misbehaves afterwards, "
        @"restart the phone or remove Bluemote.\n\nContinue anyway?",
        BTMachineName(), [[UIDevice currentDevice] systemVersion]];
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Untested device" message:msg delegate:self
                                      cancelButtonTitle:@"Quit" otherButtonTitles:@"Continue", nil];
    a.tag = 7001;
    [a show];
    [a release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag != 7001) return;
    if (buttonIndex == [alertView cancelButtonIndex]) {
        exit(0);                                   /* nothing was started, so there is nothing to clean up */
    }
    NSString *machine = BTMachineName();
    NSString *ios = [[UIDevice currentDevice] systemVersion];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:YES forKey:BTAckKey(machine, ios)];   /* do not ask again for this model + iOS version */
    [ud synchronize];
    needsWarning = NO;
    bluemote_start();
}

- (void)dealloc {
    [root release];
    [window release];
    [super dealloc];
}

@end
