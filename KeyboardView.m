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
static const KeyDef kF4[] = { {"Home",0x4a}, {"Print Screen",0x46}, {"End",0x4d} };

#define PASTE_MAX_CHARS 300000
#define DEFAULT_STATUS @"Type with the iOS keyboard. Ctrl / Win / Alt / Shift apply to the next key."

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
                case 0x200B: case 0x200C: case 0x200D: case 0xFEFF: break;
                default: skip++; break;
            }
        }
    }
    if (skipped) *skipped = skip;
    return d;
}

@implementation KeyboardView

/* ---------------------------------------------------------------- building */

- (UIButton *)keyButton:(const KeyDef *)def {
    UIButton *b = BTMakeStyledButton([NSString stringWithUTF8String:def->title], BTStyleKey, nil, NULL);
    b.tag = def->usage;
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
    UIButton *b = BTMakeStyledButton(title, BTStyleKey, self, @selector(modPressed:));
    b.tag = mask;                      /* tag == HID modifier bit */
    return b;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = BTLinenColor();
        self.clipsToBounds = YES;

        /* off-screen text field that captures the iOS keyboard */
        field = [[UITextField alloc] initWithFrame:CGRectMake(-300, -100, 100, 30)];
        field.delegate = self;
        field.text = @" ";             /* sentinel so Backspace always reaches the delegate */
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.spellCheckingType = UITextSpellCheckingTypeNo;
        field.keyboardAppearance = UIKeyboardAppearanceAlert;
        field.returnKeyType = UIReturnKeyDefault;
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

        status = [[UILabel alloc] initWithFrame:CGRectZero];
        status.backgroundColor = [UIColor clearColor];
        status.textColor = [UIColor colorWithWhite:0.30f alpha:1.0f];
        status.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.85f];
        status.shadowOffset = CGSizeMake(0, 1);
        status.font = [UIFont systemFontOfSize:11.0f];
        status.textAlignment = NSTextAlignmentCenter;
        status.adjustsFontSizeToFitWidth = YES;
        status.minimumScaleFactor = 0.7f;
        status.text = DEFAULT_STATUS;
        [self addSubview:status];
        [status release];
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

- (void)layoutRows:(NSArray *)rows width:(CGFloat)w {
    CGFloat pad = 6.0f, gap = 5.0f, rowH = 38.0f, y = 0.0f;
    for (NSArray *row in rows) {
        int cnt = (int)[row count];
        CGFloat bw = (w - 2 * pad - (cnt - 1) * gap) / cnt;
        for (int i = 0; i < cnt; i++) {
            ((UIButton *)[row objectAtIndex:i]).frame = CGRectMake(pad + i * (bw + gap), y, bw, rowH);
        }
        y += rowH + gap;
    }
}

- (void)layoutSubviews {
    CGFloat w = self.bounds.size.width;
    CGRect paneFrame = CGRectMake(0, 6, w, 172);
    arrowPane.frame = paneFrame;
    fkeyPane.frame = paneFrame;
    [self layoutRows:arrowRows width:w];
    [self layoutRows:fkeyRows width:w];
    status.frame = CGRectMake(10, 180, w - 20, 16);
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
    btcombo_sendf("KEY %d %d", (int)b.tag, m);
    [self stopRepeat];
    repeatUsage = (int)b.tag;
    /* hold a key: after 0.45 s it repeats about 11 times a second */
    repeatTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:0.45]
                                           interval:0.09 target:self selector:@selector(repeatFire)
                                           userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:repeatTimer forMode:NSRunLoopCommonModes];
}

- (void)keyUp:(UIButton *)b { [self stopRepeat]; }

- (void)repeatFire { btcombo_sendf("KEY %d 0", repeatUsage); }

/* ---------------------------------------------------------------- paste / stop paste */

- (BOOL)isPasting { return btcombo_paste_active() != 0; }

- (void)notifyPasteState {
    [[NSNotificationCenter defaultCenter] postNotificationName:BTPasteStateNotification object:nil];
}

- (void)togglePaste {
    if (btcombo_paste_active()) {
        btcombo_paste_cancel();
        status.text = @"Stopping...";
        return;
    }
    if (!btcombo_is_connected()) {
        status.text = @"Not connected to a device. Pair or reconnect first.";
        return;
    }
    NSString *clip = [[UIPasteboard generalPasteboard] string];
    if ([clip length] == 0) {
        status.text = @"The iOS clipboard has no text.";
        return;
    }
    int skipped = 0;
    NSData *d = BTSanitize(clip, &skipped);
    if ([d length] == 0) {
        status.text = @"Nothing in the clipboard can be typed (only unsupported characters).";
        return;
    }
    if (btcombo_paste_begin((const char *)[d bytes], (int)[d length]) != 0) {
        status.text = @"Paste is busy, try again in a moment.";
        return;
    }
    pasteSkipped = skipped;
    [pasteTimer invalidate];
    [pasteTimer release];
    pasteTimer = [[NSTimer scheduledTimerWithTimeInterval:0.15 target:self selector:@selector(pasteTick)
                                                 userInfo:nil repeats:YES] retain];
    [self notifyPasteState];
    [self pasteTick];
}

- (void)pasteTick {
    int total = btcombo_paste_total();
    int pos = btcombo_paste_progress();
    int pct = total > 0 ? (int)((long long)pos * 100 / total) : 0;
    NSString *skipNote = pasteSkipped > 0
        ? [NSString stringWithFormat:@" (%d unsupported skipped)", pasteSkipped] : @"";
    if (btcombo_paste_active()) {
        status.text = [NSString stringWithFormat:@"Pasting %d%%  (%d / %d)%@", pct, pos, total, skipNote];
    } else {
        [pasteTimer invalidate];
        [pasteTimer release];
        pasteTimer = nil;
        if (pos >= total && total > 0) status.text = [NSString stringWithFormat:@"Paste finished (%d characters).%@", total, skipNote];
        else status.text = [NSString stringWithFormat:@"Paste stopped at %d%% (%d / %d).", pct, pos, total];
        [self notifyPasteState];
    }
}

/* ---------------------------------------------------------------- iOS keyboard typing */

- (BOOL)textField:(UITextField *)tf shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    int m = [self takeMods];
    if ([string length] == 0) {
        btcombo_sendf("KEY 42 %d", m);          /* Backspace */
    } else {
        NSString *clean = [string stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        clean = [clean stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        const char *u = [clean UTF8String];
        if (u && u[0]) btcombo_sendf("TYPEMOD %d %s", m, u);
    }
    return NO;                                  /* keep the sentinel, never store text */
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    int m = [self takeMods];
    btcombo_sendf("KEY 40 %d", m);              /* Enter */
    return NO;
}

@end
