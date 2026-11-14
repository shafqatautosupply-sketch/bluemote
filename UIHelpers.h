#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include "btcombo_core.h"

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
void BTDrawPanel(CGRect rect, CGFloat radius);                                                   /* brushed metal pad */
void BTDrawEngravedText(NSString *text, CGRect rect, UIFont *font, NSTextAlignment align);

NSString *BTDeviceDisplayName(NSString *addr);                                                   /* alias / name / fallback */

void BTDrawDarkPanel(CGRect rect, CGFloat radius);                                               /* remote-control body */
void BTDrawHelpCard(CGRect rect, NSString *text);                                                /* "i" instructions card */
NSString *BTStatusText(BOOL *connected);                                                         /* status line for the title */

#define BTShowKeyboardNotification @"BTShowKeyboardNotification"
#define BTPasteStateNotification   @"BTPasteStateNotification"
#define kPrefMediaPadMode   @"mediaPadMode"      /* 0 = D-pad, 1 = trackpad */
#define kPrefReelsOn        @"reelsOn"
#define kPrefReelsMethod    @"reelsMethod"       /* 0 = keys, 1 = wheel, 2 = drag */
#define kPrefReelsSwap      @"reelsSwap"
#define kPrefNaturalScroll  @"naturalScroll"
#define kPrefBaseMode       @"baseMode"          /* 0 = trackpad, 1 = media */

int BTActiveCount(NSSet *all);
CGPoint BTCentroid(NSSet *all, UIView *v);
