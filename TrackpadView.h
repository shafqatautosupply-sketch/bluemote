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
}
@end
