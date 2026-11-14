#import "TrackpadView.h"
#import "UIHelpers.h"
#include <math.h>

/* ---------- touch surface ---------- */

/* Two-finger scroll direction.
   default: like a mouse wheel / scrollbar: drag down = scroll down, drag right = scroll right
   Settings > Trackpad > Natural scrolling: the content follows your fingers */

@interface TrackpadSurface : UIView {
    BOOL gestureActive, moved, dragging;
    int maxTouches, lastN;
    CGPoint startC, lastC;
    NSTimeInterval startTime, lastBeganTime, lastTapEnd;
    float remX, remY, scrollAccX, scrollAccY;
    NSMutableDictionary *startPoints;     /* where each individual finger started */
    BOOL showHelp;
}
- (void)setShowHelp:(BOOL)show;
@end

@implementation TrackpadSurface

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.multipleTouchEnabled = YES;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        startPoints = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc {
    [startPoints release];
    [super dealloc];
}

- (void)setShowHelp:(BOOL)show {
    showHelp = show;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    BTDrawPanel(self.bounds, 14.0f);
    if (showHelp) {
        BTDrawHelpCard(self.bounds, @"Drag: move the cursor\nTap: click\nTwo-finger tap: right click / Back\nTwo-finger drag: scroll in any direction\nTap, then touch and drag: drag & drop");
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    NSSet *all = [event touchesForView:self];
    int n = BTActiveCount(all);
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    for (UITouch *t in touches) {
        [startPoints setObject:[NSValue valueWithCGPoint:[t locationInView:self]]
                        forKey:[NSValue valueWithNonretainedObject:t]];
    }
    lastBeganTime = now;                  /* time the newest finger landed */
    if (!gestureActive) {
        gestureActive = YES;
        moved = NO;
        dragging = NO;
        maxTouches = 0;
        remX = remY = scrollAccX = scrollAccY = 0;
        startTime = now;
        startC = BTCentroid(all, self);
        if (n == 1 && (now - lastTapEnd) < 0.3) {
            dragging = YES;
            btcombo_send("MB 1");
        }
    }
    if (n > maxTouches) maxTouches = n;
    lastN = n;
    lastC = BTCentroid(all, self);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!gestureActive) return;
    NSSet *all = [event touchesForView:self];
    int n = BTActiveCount(all);
    if (n == 0) return;

    /* "moved" is judged per finger against where THAT finger landed. (The centroid of two fingers jumps when the
       second finger lands, which used to count as movement and cancelled the tap.) */
    if (!moved) {
        float thr = (maxTouches >= 2) ? 14.0f : 8.0f;
        for (UITouch *t in all) {
            if (t.phase == UITouchPhaseEnded || t.phase == UITouchPhaseCancelled) continue;
            NSValue *sv = [startPoints objectForKey:[NSValue valueWithNonretainedObject:t]];
            if (!sv) continue;
            CGPoint sp = [sv CGPointValue];
            CGPoint p = [t locationInView:self];
            if (hypotf(p.x - sp.x, p.y - sp.y) > thr) { moved = YES; break; }
        }
    }

    CGPoint c = BTCentroid(all, self);
    if (n != lastN) {                     /* finger count changed: re-anchor, avoid a jump */
        lastN = n;
        lastC = c;
        return;
    }
    float dx = c.x - lastC.x;
    float dy = c.y - lastC.y;
    lastC = c;

    if (n >= 2 && !dragging) {
        /* scroll along the dominant axis only, so a mostly vertical drag does not wobble sideways */
        if (fabsf(dx) > fabsf(dy)) { scrollAccX += dx; scrollAccY = 0; }
        else                       { scrollAccY += dy; scrollAccX = 0; }
        BOOL natural = [[NSUserDefaults standardUserDefaults] boolForKey:kPrefNaturalScroll];
        int sv = (int)(scrollAccY / 10.0f);
        if (sv != 0) {
            btcombo_sendf("W %d", natural ? sv : -sv);     /* wheel: + = up */
            scrollAccY -= sv * 10.0f;
        }
        int sh = (int)(scrollAccX / 10.0f);
        if (sh != 0) {
            btcombo_sendf("HW %d", natural ? -sh : sh);    /* pan: + = right */
            scrollAccX -= sh * 10.0f;
        }
    } else if (n == 1 && maxTouches == 1) {
        float d = sqrtf(dx * dx + dy * dy);
        float gain = 1.2f + d * 0.15f;
        if (gain > 4.0f) gain = 4.0f;
        float fx = dx * gain + remX;
        float fy = dy * gain + remY;
        int ix = (int)fx;
        int iy = (int)fy;
        remX = fx - ix;
        remY = fy - iy;
        if (ix != 0 || iy != 0) btcombo_sendf("M %d %d", ix, iy);
    }
}

- (void)finishAllowTap:(BOOL)allowTap {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    BOOL multi = (maxTouches >= 2);
    /* several fingers: the tap is measured from when the LAST finger landed, and the fingers may land up to
       0.6 s apart; one finger: measured from the touch down as before */
    NSTimeInterval dur = now - (multi ? lastBeganTime : startTime);
    NSTimeInterval stagger = lastBeganTime - startTime;
    gestureActive = NO;
    [startPoints removeAllObjects];
    if (dragging) {
        btcombo_send("MB 0");
        dragging = NO;
        lastTapEnd = 0;
        return;
    }
    BOOL tapOK = allowTap && !moved && (multi ? (dur < 0.45 && stagger < 0.6) : (dur < 0.3));
    if (tapOK) {
        if (maxTouches == 1) {
            btcombo_send("CLICK 1");
            lastTapEnd = now;
        } else if (maxTouches == 2) {
            btcombo_send("CLICK 2");
            lastTapEnd = 0;
        } else {
            btcombo_send("CLICK 4");
            lastTapEnd = 0;
        }
    } else {
        lastTapEnd = 0;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!gestureActive) return;
    NSSet *all = [event touchesForView:self];
    int n = BTActiveCount(all);
    if (n > 0) {
        lastN = n;
        lastC = BTCentroid(all, self);
        return;
    }
    [self finishAllowTap:YES];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    if (gestureActive) [self finishAllowTap:NO];
}

@end

/* ---------- page container ---------- */

@implementation TrackpadView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = BTLinenColor();
        surface = [[TrackpadSurface alloc] initWithFrame:CGRectZero];
        [self addSubview:surface];
        [surface release];

        infoB = [UIButton buttonWithType:UIButtonTypeInfoDark];                 /* small "i": show / hide the instructions */
        [infoB addTarget:self action:@selector(infoTapped) forControlEvents:UIControlEventTouchUpInside];
        [surface addSubview:infoB];

        kbB = BTMakeStyledButton(nil, BTStyleGray, self, @selector(keyboardTapped));   /* small keyboard button */
        [kbB setImage:[UIImage imageNamed:@"glyph_keyboard.png"] forState:UIControlStateNormal];
        [surface addSubview:kbB];

        leftB  = BTMakeButton(@"Left",  self, @selector(leftTapped));
        rightB = BTMakeButton(@"Right", self, @selector(rightTapped));
        backB  = BTMakeButton(@"Back",  self, @selector(backTapped));
        homeB  = BTMakeButton(@"Home",  self, @selector(homeTapped));
        [self addSubview:leftB];
        [self addSubview:rightB];
        [self addSubview:backB];
        [self addSubview:homeB];
    }
    return self;
}

- (void)layoutSubviews {
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    CGFloat pad = 8.0f, bh = 44.0f;
    surface.frame = CGRectMake(pad, pad, w - 2 * pad, h - 3 * pad - bh);
    infoB.frame = CGRectMake(6, 6, 30, 30);
    kbB.frame = CGRectMake(surface.bounds.size.width - 6 - 42, 8, 42, 30);
    CGFloat bw = (w - 5 * pad) / 4.0f;
    CGFloat y = h - pad - bh;
    leftB.frame  = CGRectMake(pad, y, bw, bh);
    rightB.frame = CGRectMake(2 * pad + bw, y, bw, bh);
    backB.frame  = CGRectMake(3 * pad + 2 * bw, y, bw, bh);
    homeB.frame  = CGRectMake(4 * pad + 3 * bw, y, bw, bh);
    [surface setNeedsDisplay];
}

- (void)infoTapped {
    helpOn = !helpOn;
    [surface setShowHelp:helpOn];
}

- (void)keyboardTapped {
    [[NSNotificationCenter defaultCenter] postNotificationName:BTShowKeyboardNotification object:nil];
}

- (void)leftTapped  { btcombo_send("CLICK 1"); }
- (void)rightTapped { btcombo_send("CLICK 2"); }
- (void)backTapped  { btcombo_send("MEDIA back"); }
- (void)homeTapped  { btcombo_send("MEDIA home"); }

@end
