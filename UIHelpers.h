#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include "bluemote_core.h"

/* ---- iOS 6 "skeuomorphic" skin: glossy buttons and brushed-metal panels, all drawn with Core Graphics ---- */

typedef enum {
    BTStyleGray = 0,    /* light grey bar-button look */
    BTStyleBlue,        /* selected / active */
    BTStyleRed,         /* destructive / stop */
    BTStyleKey,         /* iOS keyboard key */
    BTStyleDark         /* black glossy */
} BTButtonStyle;

UIButton *BTMakeButton(NSString *title, id target, SEL action);                                  /* gray */
UIButton *BTMakeStyledButton(NSString *title, BTButtonStyle style, id target, SEL action);
void BTSetButtonStyle(UIButton *b, BTButtonStyle style);
void BTSetButtonToggle(UIButton *b, BOOL on, BTButtonStyle offStyle);                            /* on = blue */
void BTSetButtonOn(UIButton *b, BOOL on);

UIColor *BTLinenColor(void);                                                                     /* native iOS 6 linen */
void BTDrawPanel(CGRect rect, CGFloat radius);                                                   /* vertically brushed aluminium slab with etched border (cached) */
void BTDrawEngravedText(NSString *text, CGRect rect, UIFont *font, NSTextAlignment align);

void BTDrawUnibody(CGRect rect, CGFloat radius);                                                 /* brushed slab, no built-in border: sections are etched into it */
void BTDrawBrushedFill(CGRect rect);                                                             /* full-bleed brushed aluminium (keyboard sheet background) */
void BTDrawEtchedBox(CGRect rect, CGFloat radius, BOOL recessed);                                /* etched section border (groove + light line), optional soft recess */

/* ---- machined aluminium key: square, round corners, smooth face on a dark side wall. Used by every key in the app. ---- */
#define BT_KEY_RADIUS 10.0f
#define BT_KEY_DEPTH  3.0f
void BTKeyFrames(CGRect bounds, CGRect *wall, CGRect *face, BOOL down);
void BTKeyDrawWall(CGContextRef c, CGColorSpaceRef cs, CGRect wall, BOOL blue);
void BTKeyDrawFace(CGContextRef c, CGColorSpaceRef cs, CGRect face, BOOL down, BOOL blue);

@interface BTKeyButton : UIButton {
    BOOL toggled;
}
- (void)setToggled:(BOOL)t;                                                                      /* anodised blue when on */
@end
UIButton *BTMakeKeyButton(NSString *title, id target, SEL action);

NSString *BTDeviceDisplayName(NSString *addr);                                                   /* alias / name / fallback */

void BTDrawDarkPanel(CGRect rect, CGFloat radius);                                               /* remote-control body */
void BTDrawHelpCard(CGRect rect, NSString *text);                                                /* "i" instructions card */
NSString *BTStatusText(BOOL *connected);
#define kPrefOkMode         @"okMode"            /* 0 = Select (remote OK / DPAD_CENTER), 1 = Enter (keyboard) */
void BTSendOK(int phase);                                                                        /* 0 = tap, 1 = key down, 2 = key up (hold = long press) */                                                         /* status line for the title */

#define BTShowKeyboardNotification @"BTShowKeyboardNotification"
#define BTPasteStateNotification   @"BTPasteStateNotification"
#define kPrefMediaPadMode   @"mediaPadMode"      /* 0 = D-pad, 1 = trackpad */
#define kPrefReelsOn        @"reelsOn"
#define kPrefReelsMethod    @"reelsMethod"       /* 0 = keys, 1 = wheel, 2 = drag */
#define kPrefReelsSwap      @"reelsSwap"
#define kPrefNaturalScroll  @"naturalScroll"
#define kPrefBaseMode       @"baseMode"          /* 0 = trackpad, 1 = media */
#define kPrefMediaExpanded  @"mediaPadExpanded"  /* 1 = Media trackpad expanded (remote collapsed to Back / Home / Menu) */

int BTActiveCount(NSSet *all);
CGPoint BTCentroid(NSSet *all, UIView *v);
