#import <UIKit/UIKit.h>

@class TrackpadSurface;

@interface TrackpadView : UIView {
    TrackpadSurface *surface;
    UIButton *leftB;
    UIButton *rightB;
    UIButton *backB;
    UIButton *homeB;
    UIButton *infoB;
    UIButton *kbB;
    BOOL helpOn;
    CGRect buttonBox;       /* etched section around the key row, drawn on the unibody */
}
@end
