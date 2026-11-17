#import <UIKit/UIKit.h>

@class TrackpadSurface;

@interface TrackpadView : UIView {
    TrackpadSurface *surface;
    UIControl *clickKey;    /* joined Left | Right click key */
    UIButton *backB;
    UIButton *homeB;
    UIButton *infoB;
    UIView *scrollTab;      /* scroll strip along the left edge of the pad (Settings: Scroll tab) */
    BOOL helpOn;
    CGRect buttonBox;       /* etched section around the key row, drawn on the unibody */
}
- (void)reloadSettings;      /* shows / hides the "i" button (Settings) */
@end
