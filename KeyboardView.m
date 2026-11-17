#import "KeyboardView.h"
#import "UIHelpers.h"

typedef struct { const char *title; int usage; } KeyDef;

/* Arrows layout (HID keyboard usages) */
static const KeyDef kArrow1[] = { {"Esc",0x29}, {"PgUp",0x4b}, {"PgDn",0x4e}, {"Insert",0x49} };
static const KeyDef kArrow3[] = { {"Tab",0x2b}, {"\xE2\x96\xB2",0x52}, {"Delete",0x4c} };                       /* Tab  ^  Delete */
static const KeyDef kArrow4[] = { {"\xE2\x97\x84",0x50}, {"\xE2\x96\xBC",0x51}, {"\xE2\x96\xBA",0x4f} };       /* <  v  >        */
/* F-Keys layout */
static const KeyDef kF1[] = { {"F1",0x3a}, {"F2",0x3b},  {"F3",0x3c},  {"F4",0x3d} };
static const KeyDef kF2[] = { {"F5",0x3e}, {"F6",0x3f},  {"F7",0x40},  {"F8",0x41} };
static const KeyDef kF3[] = { {"F9",0x42}, {"F10",0x43}, {"F11",0x44}, {"F12",0x45} };
static const KeyDef kF4[] = { {"Home",0x4a}, {"PrintScrn",0x46}, {"End",0x4d} };

#define PASTE_MAX_CHARS 300000
#define KB_RADIUS_SCALE 0.8f               /* keys a little squarer than the app default */

/* Converts clipboard text to plain ASCII the keyboard can type. Counts what had to be skipped. */
static void BTAppendStr(NSMutableData *d, const char *s) {
    [d appendBytes:s length:strlen(s)];
}

static NSData *BTSanitize(NSString *s, int *skipped) {
    NSUInteger n = [s length];
    if (n > PASTE_MAX_CHARS) n = PASTE_MAX_CHARS;
    NSMutableData *d = [NSMutableData dataWithCapacity:n + 16];
    int skip = 0;
    for (NSUInteger i = 0; i < n; i++) {
        unichar c = [s characterAtIndex:i];
        char one;
        if (c == '\r') {
            if (i + 1 < n && [s characterAtIndex:i + 1] == '\n') continue;
            one = '\n';
            [d appendBytes:&one length:1];
        } else if (c == '\n' || c == '\t' || (c >= 0x20 && c < 0x7f)) {
            one = (char)c;
            [d appendBytes:&one length:1];
        } else {
            switch (c) {
                case 0x2018: case 0x2019: case 0x201A: case 0x2032: BTAppendStr(d, "'"); break;
                case 0x201C: case 0x201D: case 0x201E: case 0x2033: BTAppendStr(d, "\""); break;
                case 0x2013: case 0x2014: case 0x2212: BTAppendStr(d, "-"); break;
                case 0x2026: BTAppendStr(d, "..."); break;
                case 0x00A0: case 0x2002: case 0x2003: case 0x2009: case 0x200A: case 0x202F: BTAppendStr(d, " "); break;
                case 0x2022: case 0x00B7: BTAppendStr(d, "*"); break;
                case 0x2028: case 0x2029: case 0x0085: case 0x000B: case 0x000C: {   /* Unicode line / paragraph breaks */
                    one = '\n';
                    [d appendBytes:&one length:1];
                    break;
                }
                case 0x200B: case 0x200C: case 0x200D: case 0xFEFF: break;
                default: skip++; break;
            }
        }
    }
    if (skipped) *skipped = skip;
    return d;
}

/* One triangle drawn four ways (rotated), so up / down / left / right arrows have exactly the same size and weight.
   Text triangles (the unicode glyphs) come in different sizes per direction, which is why they looked uneven. */
static UIImage *KBArrowImage(int usage) {
    CGFloat angle = 0;
    switch (usage) {
        case 0x52: angle = 0; break;                 /* up    */
        case 0x4f: angle = (CGFloat)M_PI_2; break;   /* right */
        case 0x51: angle = (CGFloat)M_PI; break;     /* down  */
        case 0x50: angle = -(CGFloat)M_PI_2; break;  /* left  */
        default: return nil;
    }
    CGSize sz = CGSizeMake(22, 22);
    UIGraphicsBeginImageContextWithOptions(sz, NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    for (int pass = 0; pass < 2; pass++) {          /* pass 0: light engraving edge 1 pt below, pass 1: the arrow */
        CGContextSaveGState(c);
        CGContextTranslateCTM(c, sz.width / 2, sz.height / 2 + (pass == 0 ? 1.0f : 0.0f));
        CGContextRotateCTM(c, angle);
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(0, -6.5f)];
        [p addLineToPoint:CGPointMake(7.0f, 5.5f)];
        [p addLineToPoint:CGPointMake(-7.0f, 5.5f)];
        [p closePath];
        p.lineJoinStyle = kCGLineJoinRound;
        p.lineWidth = 1.5f;
        UIColor *col = pass == 0 ? [UIColor colorWithWhite:1.0f alpha:0.90f] : [UIColor colorWithWhite:0.22f alpha:1.0f];
        [col setFill];
        [col setStroke];
        [p fill];
        [p stroke];
        CGContextRestoreGState(c);
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

/* The sheet's background: full-bleed brushed aluminium with the key section etched into it. */
@interface KBBackdrop : UIView {
    CGRect pocket;
}
- (void)setPocket:(CGRect)r;
@end
@implementation KBBackdrop
- (id)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    if (self) {
        self.backgroundColor = BTBackdropColor();
        self.opaque = YES;
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}
- (void)setPocket:(CGRect)r { if (!CGRectEqualToRect(r, pocket)) { pocket = r; [self setNeedsDisplay]; } }
- (void)drawRect:(CGRect)rect {
    BTDrawBrushedFill(self.bounds);
    if (pocket.size.width > 0) BTDrawEtchedBox(pocket, 10.0f, NO);
}
@end

@implementation KeyboardView

/* ---------------------------------------------------------------- building */

- (UIButton *)keyButton:(const KeyDef *)def {
    UIButton *b = BTMakeKeyButton([NSString stringWithUTF8String:def->title], nil, NULL);
    b.tag = def->usage;
    [(BTKeyButton *)b setRadiusScale:KB_RADIUS_SCALE];
    UIImage *arrow = KBArrowImage(def->usage);
    if (arrow) {
        [b setTitle:@"" forState:UIControlStateNormal];
        [b setImage:arrow forState:UIControlStateNormal];
        [b setImage:arrow forState:UIControlStateHighlighted];
    }
    [b addTarget:self action:@selector(keyDown:) forControlEvents:UIControlEventTouchDown];
    [b addTarget:self action:@selector(keyUp:)
        forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel)];
    return b;
}

- (NSArray *)rowFrom:(const KeyDef *)defs count:(int)n pane:(UIView *)pane {
    NSMutableArray *row = [NSMutableArray array];
    for (int i = 0; i < n; i++) {
        UIButton *b = [self keyButton:&defs[i]];
        [pane addSubview:b];
        [row addObject:b];
    }
    return row;
}

- (UIButton *)modButton:(NSString *)title mask:(int)mask {
    UIButton *b = BTMakeKeyButton(title, self, @selector(modPressed:));
    b.tag = mask;                      /* tag == HID modifier bit */
    [(BTKeyButton *)b setRadiusScale:KB_RADIUS_SCALE];
    return b;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = BTBackdropColor();        /* solid, so nothing behind the panel ever shows through */
        self.opaque = YES;
        self.clipsToBounds = YES;

        backdrop = [[KBBackdrop alloc] initWithFrame:CGRectZero];
        [self addSubview:backdrop];
        [backdrop release];

        /* off-screen text field that captures the iOS keyboard */
        field = [[UITextField alloc] initWithFrame:CGRectMake(-300, -100, 100, 30)];
        field.delegate = self;
        field.text = @" ";             /* sentinel so Backspace always reaches the delegate */
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.spellCheckingType = UITextSpellCheckingTypeNo;
        field.keyboardAppearance = UIKeyboardAppearanceAlert;
        field.returnKeyType = UIReturnKeyDefault;
        [field addTarget:self action:@selector(fieldChanged:) forControlEvents:UIControlEventEditingChanged];
        [self addSubview:field];
        [field release];

        arrowPane = [[UIView alloc] initWithFrame:CGRectZero];
        fkeyPane  = [[UIView alloc] initWithFrame:CGRectZero];
        [self addSubview:arrowPane];
        [self addSubview:fkeyPane];
        [arrowPane release];
        [fkeyPane release];
        fkeyPane.hidden = YES;

        /* Esc PgUp PgDn Insert / Ctrl Win Alt Shift / Tab ^ Delete / < v > */
        arrowRows = [[NSMutableArray alloc] init];
        [arrowRows addObject:[self rowFrom:kArrow1 count:4 pane:arrowPane]];
        ctrlB  = [self modButton:@"Ctrl"  mask:1];
        winB   = [self modButton:@"Win"   mask:8];
        altB   = [self modButton:@"Alt"   mask:4];
        shiftB = [self modButton:@"Shift" mask:2];
        NSArray *mods = [NSArray arrayWithObjects:ctrlB, winB, altB, shiftB, nil];
        for (UIButton *b in mods) [arrowPane addSubview:b];
        [arrowRows addObject:mods];
        [arrowRows addObject:[self rowFrom:kArrow3 count:3 pane:arrowPane]];
        [arrowRows addObject:[self rowFrom:kArrow4 count:3 pane:arrowPane]];

        fkeyRows = [[NSMutableArray alloc] init];
        [fkeyRows addObject:[self rowFrom:kF1 count:4 pane:fkeyPane]];
        [fkeyRows addObject:[self rowFrom:kF2 count:4 pane:fkeyPane]];
        [fkeyRows addObject:[self rowFrom:kF3 count:4 pane:fkeyPane]];
        [fkeyRows addObject:[self rowFrom:kF4 count:3 pane:fkeyPane]];
    }
    return self;
}

- (void)dealloc {
    [pasteTimer invalidate];
    [pasteTimer release];
    [repeatTimer invalidate];
    [repeatTimer release];
    [arrowRows release];
    [fkeyRows release];
    [super dealloc];
}

/* ---------------------------------------------------------------- layout */

/* aluminium keys on an even grid: 10 pt border at the sides, 11 pt on top and 6 pt at the bottom (each key frame already leaves ~5 pt of shadow room under its face, so top and bottom look even),
   8 pt between keys in a row, 6 pt between rows. Row height fills whatever height the pane has. */
- (void)layoutRows:(NSArray *)rows width:(CGFloat)w height:(CGFloat)h {
    CGFloat pad = 10.0f, padTop = 11.0f, padBottom = 6.0f, gap = 8.0f, vgap = 6.0f, y = padTop;
    int nrows = (int)[rows count];
    CGFloat rowH = floorf((h - padTop - padBottom - (nrows - 1) * vgap) / nrows);   /* 40 pt at 195 pt pane height */
    for (NSArray *row in rows) {
        int cnt = (int)[row count];
        CGFloat bw = (w - 2 * pad - (cnt - 1) * gap) / cnt;
        for (int i = 0; i < cnt; i++) {
            ((UIButton *)[row objectAtIndex:i]).frame = CGRectMake(pad + i * (bw + gap), y, bw, rowH);
        }
        y += rowH + vgap;
    }
}

- (void)layoutSubviews {
    CGFloat w = self.bounds.size.width;
    const CGFloat barH = 44.0f, side = 8.0f;
    backdrop.frame = self.bounds;
    topBar.frame = CGRectMake(0, 0, w, barH);
    CGRect paneFrame = CGRectMake(side, barH + 4.0f, w - 2 * side, 195.0f);   /* the etched key section */
    [(KBBackdrop *)backdrop setPocket:paneFrame];
    arrowPane.frame = paneFrame;
    fkeyPane.frame = paneFrame;
    [self layoutRows:arrowRows width:paneFrame.size.width height:paneFrame.size.height];
    [self layoutRows:fkeyRows width:paneFrame.size.width height:paneFrame.size.height];
}

- (void)showLayout:(int)index {
    if (index == layoutIndex) return;
    layoutIndex = index;
    UIView *from = (index == 1) ? arrowPane : fkeyPane;
    UIView *to   = (index == 1) ? fkeyPane : arrowPane;
    [UIView transitionFromView:from toView:to duration:0.25
                       options:(UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionShowHideTransitionViews)
                    completion:nil];
}

- (void)setTopBar:(UIView *)bar {
    [topBar removeFromSuperview];
    topBar = bar;
    if (topBar) [self addSubview:topBar];
    [self setNeedsLayout];
}

- (void)activate   { [field becomeFirstResponder]; }
- (void)deactivate { [field resignFirstResponder]; [self stopRepeat]; }

/* ---------------------------------------------------------------- keys */

- (int)takeMods {
    int m = modMask;
    modMask = 0;
    BTSetButtonToggle(ctrlB, NO, BTStyleKey);
    BTSetButtonToggle(winB, NO, BTStyleKey);
    BTSetButtonToggle(altB, NO, BTStyleKey);
    BTSetButtonToggle(shiftB, NO, BTStyleKey);
    return m;
}

- (void)modPressed:(UIButton *)b {
    modMask ^= (int)b.tag;
    BTSetButtonToggle(b, (modMask & b.tag) != 0, BTStyleKey);
}

- (void)stopRepeat {
    [repeatTimer invalidate];
    [repeatTimer release];
    repeatTimer = nil;
}

- (void)keyDown:(UIButton *)b {
    int m = [self takeMods];
    bluemote_sendf("KEY %d %d", (int)b.tag, m);
    [self stopRepeat];
    repeatUsage = (int)b.tag;
    /* hold a key: after 0.45 s it repeats about 11 times a second */
    repeatTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:0.45]
                                           interval:0.09 target:self selector:@selector(repeatFire)
                                           userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:repeatTimer forMode:NSRunLoopCommonModes];
}

- (void)keyUp:(UIButton *)b { [self stopRepeat]; }

- (void)repeatFire { bluemote_sendf("KEY %d 0", repeatUsage); }

/* ---------------------------------------------------------------- paste / stop paste */

- (BOOL)isPasting { return bluemote_paste_active() != 0; }

- (void)notifyPasteState {
    [[NSNotificationCenter defaultCenter] postNotificationName:BTPasteStateNotification object:nil];
}

- (void)togglePaste {
    if (bluemote_paste_active()) {
        bluemote_paste_cancel();
        return;
    }
    if (!bluemote_is_connected()) {
        return;
    }
    NSString *clip = [[UIPasteboard generalPasteboard] string];
    if ([clip length] == 0) {
        return;
    }
    int skipped = 0;
    NSData *d = BTSanitize(clip, &skipped);
    if ([d length] == 0) {
        return;
    }
    if (bluemote_paste_begin((const char *)[d bytes], (int)[d length]) != 0) {
        return;
    }
    [pasteTimer invalidate];
    [pasteTimer release];
    pasteTimer = [[NSTimer scheduledTimerWithTimeInterval:0.15 target:self selector:@selector(pasteTick)
                                                 userInfo:nil repeats:YES] retain];
    [self notifyPasteState];
    [self pasteTick];
}

- (void)pasteTick {
    if (!bluemote_paste_active()) {                 /* finished or stopped: tell the top bar to refresh its paste button */
        [pasteTimer invalidate];
        [pasteTimer release];
        pasteTimer = nil;
        [self notifyPasteState];
    }
}

/* ---------------------------------------------------------------- iOS keyboard typing */

- (BOOL)textField:(UITextField *)tf shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    int m = [self takeMods];
    if ([string length] == 0) {
        bluemote_sendf("KEY 42 %d", m);          /* Backspace */
    } else {
        NSString *clean = [string stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        clean = [clean stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        const char *u = [clean UTF8String];
        if (u && u[0]) bluemote_sendf("TYPEMOD %d %s", m, u);
        /* Accept the insertion. A field that refuses every change never tells the keyboard its text changed, so a
           one-shot Shift never switched off again. Accepting it lets iOS apply its normal Shift logic (one letter,
           caps lock on double tap); fieldChanged: then puts the sentinel back so no text ever piles up. */
        return YES;
    }
    return NO;                                  /* Backspace: keep the sentinel */
}

- (void)fieldChanged:(UITextField *)tf {
    if (![tf.text isEqualToString:@" "]) tf.text = @" ";   /* programmatic set: no delegate call, no loop */
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    int m = [self takeMods];
    bluemote_sendf("KEY 40 %d", m);              /* Enter */
    return NO;
}

@end
