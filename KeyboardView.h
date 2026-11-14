#import <UIKit/UIKit.h>

/* The keyboard panel that slides up over the trackpad / media pad: special keys (Arrows or F-Keys layout) above
   the iOS keyboard, which types text. Paste is driven from the navigation bar. */
@interface KeyboardView : UIView <UITextFieldDelegate> {
    UITextField *field;
    UIView *arrowPane, *fkeyPane;
    NSMutableArray *arrowRows, *fkeyRows;
    UIButton *ctrlB, *winB, *altB, *shiftB;
    UILabel *status;
    UIView *topBar;                 /* the panel carries its own top bar (owned by the main controller) */
    UIView *backdrop;
    NSTimer *pasteTimer;
    NSTimer *repeatTimer;
    int repeatUsage;
    int modMask;
    int pasteSkipped;
    int layoutIndex;
}
- (void)setTopBar:(UIView *)bar;    /* bar that slides together with the panel */
- (void)activate;
- (void)deactivate;
- (void)showLayout:(int)index;      /* 0 = arrows, 1 = F-keys */
- (BOOL)isPasting;
- (void)togglePaste;                /* paste the iOS clipboard, or stop a running paste */
@end
