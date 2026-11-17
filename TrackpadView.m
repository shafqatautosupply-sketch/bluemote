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
    BOOL showHelp, tabHelp;
}
- (void)setShowHelp:(BOOL)show;
- (void)setTabHelp:(BOOL)on;
@end

@implementation TrackpadSurface

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.multipleTouchEnabled = YES;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;
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

- (void)setTabHelp:(BOOL)on {
    tabHelp = on;
    if (showHelp) [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    BTDrawEtchedBox(self.bounds, 10.0f, YES);                       /* the pad: its own etched section of the body */
    if (showHelp) {
        NSString *t = @"Drag: move the cursor\nTap: click\nTwo-finger tap: right click / Back\nTwo-finger drag: scroll in any direction\nTap, then touch and drag: drag & drop";
        if (tabHelp) t = [t stringByAppendingString:@"\nLeft tab: drag up / down to scroll"];
        BTDrawHelpCard(self.bounds, t);
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
            bluemote_send("MB 1");
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
            bluemote_sendf("W %d", natural ? sv : -sv);     /* wheel: + = up */
            scrollAccY -= sv * 10.0f;
        }
        int sh = (int)(scrollAccX / 10.0f);
        if (sh != 0) {
            bluemote_sendf("HW %d", natural ? -sh : sh);    /* pan: + = right */
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
        if (ix != 0 || iy != 0) bluemote_sendf("M %d %d", ix, iy);
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
        bluemote_send("MB 0");
        dragging = NO;
        lastTapEnd = 0;
        return;
    }
    BOOL tapOK = allowTap && !moved && (multi ? (dur < 0.45 && stagger < 0.6) : (dur < 0.3));
    if (tapOK) {
        if (maxTouches == 1) {
            bluemote_send("CLICK 1");
            lastTapEnd = now;
        } else if (maxTouches == 2) {
            bluemote_send("CLICK 2");
            lastTapEnd = 0;
        } else {
            bluemote_send("CLICK 4");
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

/* ---------- scroll tab ---------- */

/* A strip along the left edge of the pad. It is nearly invisible until it is touched, then it lights up and a finger
   dragging along it sends wheel scrolling. It only reacts to a finger that LANDS on it: a finger that is steering the
   cursor and slides across it keeps steering the cursor (UIKit keeps delivering that touch to the pad), and a finger
   resting on the tab is never counted by the pad, so it cannot move the cursor or click. */

#define TAB_IDLE_ALPHA 0.22f
#define TAB_STEP       7.0f         /* points of finger travel per wheel step */
#define TAB_PILL_W     40.0f        /* width of the visible tab (pill + its shadow room) */
#define TAB_HIT_RIGHT  8.0f         /* extra touch area to the right of the visible tab */

/* The touch area is bigger than the drawn tab: it reaches from the very left edge of the screen (the strip of aluminium
   frame to the left of the pad, where a thumb naturally lands) to a little past the right side of the pill. The pill itself
   is drawn where it always was, padLeft points from the left edge of this view. */
@interface TrackpadScrollTab : UIView {
    BOOL active;
    CGFloat lastY, acc;
    CGFloat padLeft;            /* invisible touch area to the left of the drawn pill */
}
- (void)setPadLeft:(CGFloat)p;
@end

@implementation TrackpadScrollTab

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;
        self.multipleTouchEnabled = NO;
        self.alpha = TAB_IDLE_ALPHA;
    }
    return self;
}

- (void)setPadLeft:(CGFloat)p {
    if (p < 0.0f) p = 0.0f;
    if (p == padLeft) return;
    padLeft = p;
    [self setNeedsDisplay];
}

- (void)setActive:(BOOL)a {
    if (a == active) return;
    active = a;
    [self setNeedsDisplay];
}

- (void)fadeTo:(CGFloat)alpha duration:(NSTimeInterval)d {
    [UIView animateWithDuration:d delay:0.0
        options:(UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut)
        animations:^{ self.alpha = alpha; }
        completion:nil];
}

- (void)fadeOut {
    if (!active) [self fadeTo:TAB_IDLE_ALPHA duration:0.6];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
    lastY = [t locationInView:self].y;
    acc = 0;
    [self setActive:YES];
    [self fadeTo:1.0f duration:0.12];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!active) return;
    UITouch *t = [touches anyObject];
    CGFloat y = [t locationInView:self].y;
    acc += y - lastY;
    lastY = y;
    int steps = (int)(acc / TAB_STEP);
    if (steps != 0) {
        BOOL natural = [[NSUserDefaults standardUserDefaults] boolForKey:kPrefNaturalScroll];
        bluemote_sendf("W %d", natural ? steps : -steps);           /* same direction rule as the two-finger scroll: wheel + = up */
        acc -= steps * TAB_STEP;
    }
}

- (void)finish {
    [self setActive:NO];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
    [self performSelector:@selector(fadeOut) withObject:nil afterDelay:0.7];     /* stays lit for a moment, then fades */
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event { [self finish]; }
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event { [self finish]; }

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [super dealloc];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGRect pill = CGRectMake(padLeft + 6.0f, 3.0f, 28.0f, self.bounds.size.height - 8.0f);
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:pill cornerRadius:14.0f];

    CGContextSaveGState(c);                                          /* soft shadow so the tab lifts off the metal */
    CGContextSetShadowWithColor(c, CGSizeMake(0, 1.5f), 3.0f, [UIColor colorWithWhite:0.0f alpha:0.5f].CGColor);
    [[UIColor colorWithWhite:0.6f alpha:1.0f] setFill];
    [p fill];
    CGContextRestoreGState(c);

    CGContextSaveGState(c);                                          /* face: a sheen across the width, like a rounded metal bar */
    [p addClip];
    CGFloat comps[12] = { 0.72f, 0.73f, 0.77f, 1.0f,  0.99f, 0.99f, 1.00f, 1.0f,  0.70f, 0.71f, 0.75f, 1.0f };
    CGFloat locs[3] = { 0.0f, 0.45f, 1.0f };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, locs, 3);
    CGContextDrawLinearGradient(c, g, CGPointMake(pill.origin.x, 0), CGPointMake(CGRectGetMaxX(pill), 0), 0);
    CGGradientRelease(g);
    if (active) {                                                    /* pressed: a little darker */
        [[UIColor colorWithWhite:0.0f alpha:0.14f] setFill];
        CGContextFillRect(c, pill);
    }
    CGContextRestoreGState(c);
    [[UIColor colorWithWhite:0.33f alpha:1.0f] setStroke];
    [p setLineWidth:1.0f];
    [p stroke];

    CGFloat midX = CGRectGetMidX(pill), midY = CGRectGetMidY(pill);
    for (int i = -3; i <= 3; i++) {                                  /* grip ridges: a dark groove with a light line under it */
        CGFloat y = floorf(midY + i * 6.0f);
        CGContextSetLineWidth(c, 1.0f);
        CGContextSetRGBStrokeColor(c, 1, 1, 1, 0.85f);
        CGContextMoveToPoint(c, midX - 7.0f, y + 1.0f);
        CGContextAddLineToPoint(c, midX + 7.0f, y + 1.0f);
        CGContextStrokePath(c);
        CGContextSetRGBStrokeColor(c, 0.28f, 0.29f, 0.33f, 0.85f);
        CGContextMoveToPoint(c, midX - 7.0f, y);
        CGContextAddLineToPoint(c, midX + 7.0f, y);
        CGContextStrokePath(c);
    }
    if (pill.size.height > 100.0f) {                                 /* small up / down arrows near the ends */
        CGContextSetRGBFillColor(c, 0.28f, 0.29f, 0.33f, 0.8f);
        CGFloat ty = pill.origin.y + 13.0f, by = CGRectGetMaxY(pill) - 13.0f;
        CGContextBeginPath(c);
        CGContextMoveToPoint(c, midX, ty - 3.5f);
        CGContextAddLineToPoint(c, midX - 4.5f, ty + 2.5f);
        CGContextAddLineToPoint(c, midX + 4.5f, ty + 2.5f);
        CGContextClosePath(c);
        CGContextMoveToPoint(c, midX, by + 3.5f);
        CGContextAddLineToPoint(c, midX - 4.5f, by - 2.5f);
        CGContextAddLineToPoint(c, midX + 4.5f, by - 2.5f);
        CGContextClosePath(c);
        CGContextFillPath(c);
    }
    CGColorSpaceRelease(cs);
}

@end

/* ---------- joined Left / Right click key ---------- */

/* One wide machined key split in the middle by a groove, like the click bar in mobile mouse apps: the left half is the
   left click, the right half is the right click. Only the half under the finger dips; it fires when the finger lifts
   inside that same half (sliding off, or across to the other half, cancels it). */

@interface TrackpadClickKey : UIControl {
    int downHalf;               /* -1 none, 0 left half pressed, 1 right half pressed */
}
@end

@implementation TrackpadClickKey

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        downHalf = -1;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;
        self.multipleTouchEnabled = NO;
    }
    return self;
}

- (int)halfAt:(CGPoint)p {
    if (p.x < 0 || p.y < 0 || p.x > self.bounds.size.width || p.y > self.bounds.size.height) return -1;
    return (p.x < self.bounds.size.width * 0.5f) ? 0 : 1;
}

- (void)setDownHalf:(int)h {
    if (h == downHalf) return;
    downHalf = h;
    [self setNeedsDisplay];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [self setDownHalf:[self halfAt:[touch locationInView:self]]];
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    int h = [self halfAt:[touch locationInView:self]];
    if (h != downHalf) [self setDownHalf:-1];                       /* slid off the pressed half: cancel */
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    int h = downHalf;
    [self setDownHalf:-1];
    if (h == 0) bluemote_send("CLICK 1");                           /* left click */
    else if (h == 1) bluemote_send("CLICK 2");                      /* right click */
}

- (void)cancelTrackingWithEvent:(UIEvent *)event {
    [self setDownHalf:-1];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGRect wall, face, faceDown, dummy;
    BTKeyFrames(self.bounds, &wall, &face, NO);
    BTKeyFrames(self.bounds, &dummy, &faceDown, YES);
    CGFloat midX = CGRectGetMidX(face);

    BTKeyDrawWall(c, cs, wall, NO);
    BTKeyDrawFace(c, cs, face, NO, NO);

    /* the pressed half is redrawn dished, clipped to its own side of the key */
    if (downHalf >= 0) {
        CGContextSaveGState(c);
        CGRect half = (downHalf == 0)
            ? CGRectMake(face.origin.x - 2.0f, face.origin.y - 2.0f, midX - face.origin.x + 2.0f, face.size.height + 6.0f)
            : CGRectMake(midX, face.origin.y - 2.0f, CGRectGetMaxX(face) - midX + 2.0f, face.size.height + 6.0f);
        CGContextClipToRect(c, half);
        BTKeyDrawFace(c, cs, faceDown, YES, NO);
        CGContextRestoreGState(c);
    }

    /* groove down the middle: dark line with a light line beside it, running the full height of the face */
    CGContextSaveGState(c);
    UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(face, 0.5f, 0.5f) cornerRadius:BTKeyRadius(face)];
    [shape addClip];
    CGFloat gx = floorf(midX);
    [[UIColor colorWithWhite:0.30f alpha:0.85f] setFill];
    CGContextFillRect(c, CGRectMake(gx - 0.5f, face.origin.y, 1.0f, face.size.height));
    [[UIColor colorWithWhite:1.0f alpha:0.75f] setFill];
    CGContextFillRect(c, CGRectMake(gx + 0.5f, face.origin.y, 1.0f, face.size.height));
    CGContextRestoreGState(c);

    CGColorSpaceRelease(cs);
}

@end

/* ---------- icon keys (Back / Home) ---------- */

/* A normal machined key with an engraved glyph drawn on its face instead of a text label.
   Back = the same bold chevron the keyboard drop-down button uses, turned to point left. */

@interface TrackpadIconKey : BTKeyButton {
    int kind;                   /* 0 = back chevron, 1 = home */
}
+ (TrackpadIconKey *)keyWithKind:(int)kind target:(id)target action:(SEL)action;
@end

@implementation TrackpadIconKey

+ (TrackpadIconKey *)keyWithKind:(int)k target:(id)target action:(SEL)action {
    TrackpadIconKey *b = [TrackpadIconKey buttonWithType:UIButtonTypeCustom];
    b->kind = k;
    b.backgroundColor = [UIColor clearColor];
    b.opaque = NO;
    b.contentMode = UIViewContentModeRedraw;
    b.adjustsImageWhenHighlighted = NO;
    if (target) [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static void TPDrawGlyph(CGContextRef c, CGPoint ctr, int kind, UIColor *color) {
    CGContextSaveGState(c);
    [color setFill];
    [color setStroke];
    if (kind == 0) {
        /* bold chevron with round ends, pointing left */
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(ctr.x + 5.0f, ctr.y - 10.0f)];
        [p addLineToPoint:CGPointMake(ctr.x - 5.0f, ctr.y)];
        [p addLineToPoint:CGPointMake(ctr.x + 5.0f, ctr.y + 10.0f)];
        [p setLineWidth:5.5f];
        [p setLineCapStyle:kCGLineCapRound];
        [p setLineJoinStyle:kCGLineJoinRound];
        [p stroke];
    } else {
        /* house: roof, body and a door cut out of the body */
        UIBezierPath *roof = [UIBezierPath bezierPath];
        [roof moveToPoint:CGPointMake(ctr.x, ctr.y - 11.0f)];
        [roof addLineToPoint:CGPointMake(ctr.x + 12.5f, ctr.y - 0.5f)];
        [roof addLineToPoint:CGPointMake(ctr.x - 12.5f, ctr.y - 0.5f)];
        [roof closePath];
        [roof setLineWidth:2.0f];
        [roof setLineJoinStyle:kCGLineJoinRound];
        [roof fill];
        [roof stroke];
        UIBezierPath *body = [UIBezierPath bezierPathWithRect:CGRectMake(ctr.x - 8.0f, ctr.y - 1.0f, 16.0f, 11.5f)];
        [body appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(ctr.x - 2.5f, ctr.y + 4.0f, 5.0f, 6.5f)]];
        body.usesEvenOddFillRule = YES;
        [body fill];
    }
    CGContextRestoreGState(c);
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];                                          /* the key itself: face, rim, shadow, pressed dish */
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect wall, face;
    BTKeyFrames(self.bounds, &wall, &face, self.highlighted);
    CGPoint ctr = CGPointMake(CGRectGetMidX(face), CGRectGetMidY(face));
    TPDrawGlyph(c, CGPointMake(ctr.x, ctr.y + 1.0f), kind, [UIColor colorWithWhite:1.0f alpha:0.85f]);    /* engraved: light edge below */
    TPDrawGlyph(c, ctr, kind, [UIColor colorWithWhite:0.26f alpha:1.0f]);
}

@end

/* ---------- page container ---------- */

@implementation TrackpadView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = BTBackdropColor();
        self.contentMode = UIViewContentModeRedraw;
        surface = [[TrackpadSurface alloc] initWithFrame:CGRectZero];
        [self addSubview:surface];
        [surface release];

        infoB = [UIButton buttonWithType:UIButtonTypeInfoDark];                 /* small "i": show / hide the instructions */
        [infoB addTarget:self action:@selector(infoTapped) forControlEvents:UIControlEventTouchUpInside];
        [surface addSubview:infoB];

        clickKey = [[TrackpadClickKey alloc] initWithFrame:CGRectZero];         /* joined Left | Right click key */
        backB = [TrackpadIconKey keyWithKind:0 target:self action:@selector(backTapped)];
        homeB = [TrackpadIconKey keyWithKind:1 target:self action:@selector(homeTapped)];
        [self addSubview:clickKey];
        [clickKey release];
        [self addSubview:backB];
        [self addSubview:homeB];
        scrollTab = [[TrackpadScrollTab alloc] initWithFrame:CGRectZero];       /* above the pad, along its left edge */
        [self addSubview:scrollTab];
        [scrollTab release];
        [self reloadSettings];
    }
    return self;
}

- (void)reloadSettings {
    BOOL show = BTInfoButtonEnabled();
    infoB.hidden = !show;
    if (!show && helpOn) { helpOn = NO; [surface setShowHelp:NO]; }
    BOOL tabOn = BTScrollTabEnabled();                              /* Settings > Trackpad > Scroll tab */
    scrollTab.hidden = !tabOn;
    [surface setTabHelp:tabOn];
    [self setNeedsLayout];
}

/* Unibody: one brushed-aluminium block for the whole page. The pad and the key row are separate sections etched into it. */
#define TP_MARGIN 4.0f

- (void)layoutSubviews {
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    CGFloat etch = 8.0f, gap = 8.0f, bh = 44.0f, kpad = 8.0f;
    CGRect inner = CGRectInset(CGRectMake(TP_MARGIN, TP_MARGIN, w - 2 * TP_MARGIN, h - 2 * TP_MARGIN), etch, etch);
    CGFloat boxH = bh + 2 * kpad;
    CGRect box = CGRectMake(inner.origin.x, CGRectGetMaxY(inner) - boxH, inner.size.width, boxH);
    if (!CGRectEqualToRect(box, buttonBox)) { buttonBox = box; [self setNeedsDisplay]; }

    surface.frame = CGRectMake(inner.origin.x, inner.origin.y, inner.size.width, box.origin.y - gap - inner.origin.y);
    infoB.frame = CGRectMake(6, 6, 30, 30);
    CGRect sf = surface.frame;                                      /* scroll tab: left edge, below the "i" button, clear of the corners */
    CGFloat tabH = sf.size.height - 44.0f - 10.0f;
    CGFloat tabPad = sf.origin.x + 2.0f;                            /* where the drawn tab starts, measured from the left edge of this view */
    [(TrackpadScrollTab *)scrollTab setPadLeft:tabPad];
    /* touch area: from the left edge of the screen to a little right of the tab, so a finger on the very edge works */
    scrollTab.frame = CGRectMake(0.0f, sf.origin.y + 44.0f, tabPad + TAB_PILL_W + TAB_HIT_RIGHT, MAX(tabH, 0.0f));
    if (tabH < 70.0f) scrollTab.hidden = YES;
    else scrollTab.hidden = !BTScrollTabEnabled();
    CGFloat kgap = 8.0f;
    CGFloat avail = box.size.width - 2 * kpad - 2 * kgap;
    CGFloat iw = floorf(avail * 0.20f);                             /* small icon keys, the click key takes the rest */
    CGFloat cw = avail - 2 * iw;
    CGFloat y = box.origin.y + kpad;
    CGFloat x = box.origin.x + kpad;
    backB.frame = CGRectMake(x, y, iw, bh);                          /* Back far left, long joined click key in the centre, Home far right */
    clickKey.frame = CGRectMake(x + iw + kgap, y, cw, bh);
    homeB.frame = CGRectMake(x + iw + kgap + cw + kgap, y, iw, bh);
    [surface setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    BTDrawUnibody(CGRectMake(TP_MARGIN, TP_MARGIN, w - 2 * TP_MARGIN, h - 2 * TP_MARGIN), 14.0f);
    BTDrawEtchedBox(buttonBox, 10.0f, NO);                          /* the key section */
}

- (void)infoTapped {
    helpOn = !helpOn;
    [surface setShowHelp:helpOn];
}

- (void)backTapped  { bluemote_send("MEDIA back"); }
- (void)homeTapped  { bluemote_send("MEDIA home"); }

@end
