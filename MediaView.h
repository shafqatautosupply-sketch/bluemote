#import <UIKit/UIKit.h>

@class MediaPanel, DPadView, RemoteButton, RemoteRocker;

/* Media page: a pad (D-pad, or a gesture pad for trackpad style / Reels) above a remote-control button block. */
@interface MediaView : UIView {
    MediaPanel *panel;
    DPadView *dpad;
    UIView *remoteBody;
    UIButton *infoB;
    UIButton *kbB;
    RemoteRocker *volR;
    RemoteRocker *chR;
    RemoteButton *reelsB;
    RemoteButton *muteB;
    NSMutableArray *centerButtons;
    BOOL helpOn;
    BOOL reelsOn;
}
- (void)reloadSettings;      /* re-reads pad type and Reels options (after Settings changed) */
@end
