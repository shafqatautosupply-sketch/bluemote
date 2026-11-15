#import "MainViewController.h"
#import "StatusTitleView.h"
#import "TrackpadView.h"
#import "MediaView.h"
#import "KeyboardView.h"
#import "SettingsViewController.h"
#import "UIHelpers.h"

/* The bar icon PNGs are solid black; recolor them to match the white "Trackpad" title text. */
static UIColor *BTBarIconColor(void) { return [UIColor whiteColor]; }

static UIImage *BTBarIcon(NSString *name) {
    UIImage *img = [UIImage imageNamed:name];
    if (!img) return nil;
    CGRect r = CGRectMake(0, 0, img.size.width, img.size.height);
    UIGraphicsBeginImageContextWithOptions(img.size, NO, img.scale);
    CGContextRef c = UIGraphicsGetCurrentContext();
    [img drawInRect:r];
    CGContextSetBlendMode(c, kCGBlendModeSourceIn); /* keep the glyph's shape, replace its color */
    [BTBarIconColor() setFill];
    CGContextFillRect(c, r);
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out;
}

@implementation MainViewController

- (UIBarButtonItem *)barItemImage:(NSString *)image action:(SEL)action {
    return [[UIBarButtonItem alloc] initWithImage:BTBarIcon(image)
        style:UIBarButtonItemStyleBordered target:self action:action];
}

- (id)init {
    self = [super init];
    if (self) {
        self.title = @"Remote";
        baseMode = (int)[[NSUserDefaults standardUserDefaults] integerForKey:kPrefBaseMode];
        if (baseMode != 1) baseMode = 0;

        titleView = [[StatusTitleView alloc] initWithTitle:@"Trackpad"];
        switchItem = [self barItemImage:@"bar_media.png" action:@selector(switchMode)];
        settingsItem = [self barItemImage:@"bar_gear.png" action:@selector(openSettings)];
        dropItem = [self barItemImage:@"bar_dropdown.png" action:@selector(hideKeyboard)];
        pasteItem = [[UIBarButtonItem alloc] initWithTitle:@"Paste" style:UIBarButtonItemStyleBordered
            target:self action:@selector(pasteTapped)];
        /* the bar is dark grey now, so its buttons are a slightly lighter grey instead of blue */
        switchItem.tintColor = settingsItem.tintColor = dropItem.tintColor = pasteItem.tintColor = BTBarButtonTintColor();

        kbSegment = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Arrows", @"F-Keys", nil]];
        kbSegment.segmentedControlStyle = UISegmentedControlStyleBar;
        kbSegment.tintColor = BTBarButtonTintColor();
        kbSegment.selectedSegmentIndex = 0;
        kbSegment.frame = CGRectMake(0, 0, 150, 30);
        [kbSegment addTarget:self action:@selector(layoutChanged:) forControlEvents:UIControlEventValueChanged];

        self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Back"
            style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease];
        self.navigationItem.backBarButtonItem.tintColor = BTBarButtonTintColor();

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showKeyboard)
            name:BTShowKeyboardNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pasteStateChanged)
            name:BTPasteStateNotification object:nil];

        /* iOS 6 can shift views around when the system keyboard rises; re-pin the sheet every time */
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(repinKeyboard)
            name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(repinKeyboard)
            name:UIKeyboardDidShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(repinKeyboard)
            name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [timer invalidate];
    [timer release];
    [titleView release];
    [kbSegment release];
    [switchItem release];
    [settingsItem release];
    [dropItem release];
    [pasteItem release];
    [kbBar release];
    [keyboard release];
    [super dealloc];
}

- (void)loadView {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 416)];
    v.backgroundColor = BTBackdropColor();
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view = v;
    [v release];

    CGRect b = v.bounds;
    trackpad = [[TrackpadView alloc] initWithFrame:b];
    media = [[MediaView alloc] initWithFrame:b];
    trackpad.autoresizingMask = media.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    trackpad.hidden = (baseMode != 0);
    media.hidden = (baseMode != 1);
    [v addSubview:trackpad];
    [v addSubview:media];
    [trackpad release];
    [media release];

    keyboard = [[KeyboardView alloc] initWithFrame:CGRectMake(0, b.size.height, b.size.width, b.size.height)];
    keyboard.hidden = YES; /* owned by this controller; added to the window over the whole screen when shown */

    kbBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    kbBar.tintColor = BTBarTintColor();                     /* same dark grey as the main bar */
    UINavigationItem *ki = [[UINavigationItem alloc] initWithTitle:@""];
    ki.titleView = kbSegment; /* [ Arrows | F-Keys ] */
    ki.leftBarButtonItem = dropItem;
    ki.rightBarButtonItem = pasteItem;
    [kbBar pushNavigationItem:ki animated:NO];
    [ki release];
    [keyboard setTopBar:kbBar];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self applyNavAnimated:NO];
    timer = [[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(tick)
        userInfo:nil repeats:YES] retain];
    [self tick];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [media reloadSettings]; /* Settings may have changed the media pad */
}

/* ---------------------------------------------------------------- top bar */

- (void)applyNavAnimated:(BOOL)animated {
    UINavigationItem *ni = self.navigationItem;
    [titleView setPageTitle:(baseMode == 0 ? @"Trackpad" : @"Media")];
    switchItem.image = BTBarIcon(baseMode == 0 ? @"bar_media.png" : @"bar_trackpad.png");
    ni.titleView = titleView;
    [ni setLeftBarButtonItem:switchItem animated:animated];
    [ni setRightBarButtonItem:settingsItem animated:animated];
}

- (void)switchMode {
    UIView *from = (baseMode == 0) ? (UIView *)trackpad : (UIView *)media;
    UIView *to = (baseMode == 0) ? (UIView *)media : (UIView *)trackpad;
    UIViewAnimationOptions opts = UIViewAnimationOptionShowHideTransitionViews |
        (baseMode == 0 ? UIViewAnimationOptionTransitionFlipFromRight : UIViewAnimationOptionTransitionFlipFromLeft);
    baseMode = 1 - baseMode;
    [[NSUserDefaults standardUserDefaults] setInteger:baseMode forKey:kPrefBaseMode];
    [media reloadSettings];
    [UIView transitionFromView:from toView:to duration:0.55 options:opts completion:nil];
    [self applyNavAnimated:YES];
}

- (void)openSettings {
    SettingsViewController *s = [[SettingsViewController alloc] init];
    [self.navigationController pushViewController:s animated:YES];
    [s release];
}

/* ---------------------------------------------------------------- keyboard panel */

/* The keyboard is one solid sheet (its own top bar + keys) that slides over the whole screen.
   Order: slide up first, then the iOS keyboard appears. Closing: iOS keyboard drops first, then the sheet slides down.

   The sheet lives in the WINDOW (not the navigation controller's view) and is given an explicit frame that
   starts directly under the status bar. That way it can never be dragged up under the status bar when iOS 6
   moves things around as the system keyboard appears, and its top bar lines up exactly with the real
   Trackpad / Media navigation bar. */

- (UIView *)keyboardHost {
    UIWindow *w = self.view.window;
    return w ? (UIView *)w : (UIView *)[[UIApplication sharedApplication] keyWindow];
}

/* Frame of the sheet when fully shown, in the host (window) coordinate space. */
- (CGRect)keyboardShownFrame {
    UIApplication *app = [UIApplication sharedApplication];
    CGRect sb = app.statusBarFrame;
    CGFloat top = app.statusBarHidden ? 0.0f : MIN(sb.size.width, sb.size.height);
    CGRect wb = [self keyboardHost].bounds;
    return CGRectMake(0, top, wb.size.width, wb.size.height - top);
}

/* Called when the iOS keyboard shows / status bar changes: snap the sheet back to where it belongs. */
- (void)repinKeyboard {
    if (keyboardShown && !keyboardAnimating && keyboard.superview) {
        keyboard.frame = [self keyboardShownFrame];
    }
}

- (void)showKeyboard {
    if (keyboardShown || keyboardAnimating) return;
    keyboardShown = YES;
    keyboardAnimating = YES;

    UIView *host = [self keyboardHost];
    CGRect shown = [self keyboardShownFrame];
    if (keyboard.superview != host) [host addSubview:keyboard];
    keyboard.frame = CGRectOffset(shown, 0, shown.size.height); /* start fully below the screen */
    keyboard.hidden = NO;
    [host bringSubviewToFront:keyboard];
    [self pasteStateChanged];

    [UIView animateWithDuration:0.32 delay:0.0 options:UIViewAnimationOptionCurveEaseOut
        animations:^{ keyboard.frame = shown; }
        completion:^(BOOL finished) {
            keyboardAnimating = NO;
            if (keyboardShown) {
                keyboard.frame = [self keyboardShownFrame];
                [keyboard activate]; /* only now does the iOS keyboard rise */
            }
        }];
}

- (void)hideKeyboard {
    if (!keyboardShown || keyboardAnimating) return;
    keyboardShown = NO;
    keyboardAnimating = YES;
    [keyboard deactivate]; /* iOS keyboard drops first ... */
    [self performSelector:@selector(slideKeyboardDown) withObject:nil afterDelay:0.30];
}

- (void)slideKeyboardDown { /* ... then the sheet slides away */
    CGRect shown = [self keyboardShownFrame];
    CGRect off = CGRectOffset(shown, 0, shown.size.height);
    [UIView animateWithDuration:0.28 delay:0.0 options:UIViewAnimationOptionCurveEaseIn
        animations:^{ keyboard.frame = off; }
        completion:^(BOOL finished) {
            keyboardAnimating = NO;
            if (!keyboardShown) keyboard.hidden = YES;
        }];
}

- (void)layoutChanged:(UISegmentedControl *)seg {
    [keyboard showLayout:(int)seg.selectedSegmentIndex];
}

- (void)pasteTapped {
    [keyboard togglePaste];
}

- (void)pasteStateChanged {
    BOOL pasting = [keyboard isPasting];
    pasteItem.title = pasting ? @"Stop" : @"Paste";
    pasteItem.tintColor = pasting ? [UIColor colorWithRed:0.78f green:0.12f blue:0.12f alpha:1.0f] : BTBarButtonTintColor();
}

/* ---------------------------------------------------------------- status and PIN */

- (void)tick {
    BOOL connected;
    NSString *text = BTStatusText(&connected);
    [titleView setStatus:text connected:connected];

    /* the TV asked for a PIN / passkey: prompt on whatever screen we are on */
    int req = bluemote_pin_request();
    if (req != 0 && pinAlert == nil) {
        [self showPinAlert:req];
    } else if (req == 0 && pinAlert != nil) {
        pinAutoDismiss = YES; /* request ended by itself (timeout / pairing finished) */
        [pinAlert dismissWithClickedButtonIndex:[pinAlert cancelButtonIndex] animated:NO];
    }
}

- (void)showPinAlert:(int)kind {
    NSString *title = (kind == 2) ? @"Enter passkey" : @"Enter PIN";
    NSString *msg = (kind == 2)
        ? @"Type the passkey shown on the TV, then tap Pair."
        : @"Type the PIN shown on the TV, then tap Pair. If the TV shows no PIN, try 0000.";
    pinAutoDismiss = NO;
    pinAlert = [[UIAlertView alloc] initWithTitle:title message:msg delegate:self
        cancelButtonTitle:@"Cancel" otherButtonTitles:@"Pair", nil];
    pinAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField *tf = [pinAlert textFieldAtIndex:0];
    tf.keyboardType = UIKeyboardTypeNumberPad;
    tf.placeholder = @"PIN";
    tf.text = (kind == 1) ? @"0000" : @"";
    [pinAlert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView != pinAlert || pinAutoDismiss) return;
    if (buttonIndex == [alertView cancelButtonIndex]) {
        bluemote_send("PINCANCEL");
        return;
    }
    NSString *code = [[[alertView textFieldAtIndex:0] text]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([code length] == 0) bluemote_send("PINCANCEL");
    else bluemote_sendf("PIN %s", [code UTF8String]);
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (alertView == pinAlert) {
        [pinAlert release];
        pinAlert = nil;
        if (keyboardShown && !keyboardAnimating) [keyboard activate];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return o == UIInterfaceOrientationPortrait; }
- (BOOL)shouldAutorotate { return NO; }
- (NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }

@end
