#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@class MediaPanel, DPadView, RemoteButton, RemoteRocker;

/* Media page: a pad (D-pad, or a gesture pad for trackpad style) above a remote-control button block, both
   etched into one aluminium unibody. */
@interface MediaView : UIView {
    MediaPanel *panel;
    DPadView *dpad;
    UIView *chassis;        /* one aluminium unibody behind the pad and the remote */
    UIView *padBox;         /* etched, recessed section the D-pad / gesture pad sits in */
    UIView *remoteBox;      /* etched section around the remote buttons */
    UIView *remoteBody;
    UIButton *infoB;
    BOOL expanded;          /* the saved choice (persisted): YES = remote minimized to Back / Home / Menu, pad grown */
    CGFloat collapseT;      /* 0 = full remote, 1 = minimized (the final state; the move itself is a Core Animation) */
    BOOL collapseAnimating; /* a minimize / maximize move is running */
    BOOL skipAlpha;         /* set while that move lays out, so the extra keys are faded by their own, separate animation */
    int animGen;            /* bumped for every move, so an interrupted move's completion is ignored */
    RemoteRocker *volR;
    RemoteRocker *chR;
    RemoteButton *padB;     /* D-pad / trackpad switch, bottom-right of the remote */
    RemoteButton *sizeB;    /* minimize / maximize, bottom-left of the remote (where Mute used to be) */
    NSMutableArray *centerButtons;
    BOOL helpOn;
}
- (void)reloadSettings;      /* re-reads the pad type (after Settings changed) */
@end
