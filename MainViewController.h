#import <UIKit/UIKit.h>

@class TrackpadView, MediaView, KeyboardView, StatusTitleView;

/* The one main screen: Trackpad <-> Media (flip), a keyboard panel that slides up, Settings in the top bar. */
@interface MainViewController : UIViewController <UIAlertViewDelegate> {
    TrackpadView *trackpad;
    MediaView *media;
    KeyboardView *keyboard;
    StatusTitleView *titleView;
    UISegmentedControl *kbSegment;
    UIBarButtonItem *switchItem;
    UIBarButtonItem *settingsItem;
    UIBarButtonItem *dropItem;
    UIBarButtonItem *pasteItem;
    NSTimer *timer;
    UIAlertView *pinAlert;
    BOOL pinAutoDismiss;
    BOOL keyboardShown;
    BOOL keyboardAnimating;        /* the sheet is sliding: ignore further taps so animations never race */
    UINavigationBar *kbBar;        /* top bar of the keyboard sheet */
    int baseMode;                  /* 0 = trackpad, 1 = media */
}
@end
