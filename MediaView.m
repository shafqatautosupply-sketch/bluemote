#import "MediaView.h"
#import "UIHelpers.h"
#import <QuartzCore/QuartzCore.h>
#include <math.h>

/* ======================================================================== remote glyphs */

enum { GBack, GHome, GMenu, GMute, GPrev, GNext, GRew, GFfwd, GPlay, GStop, GMin, GMax, GPadDpad, GPadTrack };

static void RTri(CGContextRef c, CGFloat cx, CGFloat cy, CGFloat s, BOOL right) {
    CGContextBeginPath(c);
    if (right) {
        CGContextMoveToPoint(c, cx - s * 0.8f, cy - s);
        CGContextAddLineToPoint(c, cx + s * 0.9f, cy);
        CGContextAddLineToPoint(c, cx - s * 0.8f, cy + s);
    } else {
        CGContextMoveToPoint(c, cx + s * 0.8f, cy - s);
        CGContextAddLineToPoint(c, cx - s * 0.9f, cy);
        CGContextAddLineToPoint(c, cx + s * 0.8f, cy + s);
    }
    CGContextClosePath(c);
    CGContextFillPath(c);
}

/* draws a glyph with the CURRENT fill and stroke colours */
static void RemoteGlyph(CGContextRef c, int g, CGRect r) {
    CGFloat mx = CGRectGetMidX(r), my = CGRectGetMidY(r);
    CGFloat s = MIN(r.size.width, r.size.height) * 0.22f;
    CGContextSetLineWidth(c, 2.4f);
    CGContextSetLineCap(c, kCGLineCapRound);
    CGContextSetLineJoin(c, kCGLineJoinRound);
    switch (g) {
        case GBack:
            CGContextBeginPath(c);
            CGContextMoveToPoint(c, mx + 0.9f * s, my - 1.1f * s);
            CGContextAddLineToPoint(c, mx - 0.9f * s, my);
            CGContextAddLineToPoint(c, mx + 0.9f * s, my + 1.1f * s);
            CGContextClosePath(c);
            CGContextStrokePath(c);
            break;
        case GHome:
            CGContextStrokeEllipseInRect(c, CGRectMake(mx - 1.15f * s, my - 1.15f * s, 2.3f * s, 2.3f * s));
            break;
        case GMenu:
            for (int k = -1; k <= 1; k++) {
                CGContextMoveToPoint(c, mx - 1.2f * s, my + k * 0.85f * s);
                CGContextAddLineToPoint(c, mx + 1.2f * s, my + k * 0.85f * s);
            }
            CGContextStrokePath(c);
            break;
        case GMute:
            CGContextBeginPath(c);
            CGContextMoveToPoint(c, mx - 1.5f * s, my - 0.55f * s);
            CGContextAddLineToPoint(c, mx - 0.7f * s, my - 0.55f * s);
            CGContextAddLineToPoint(c, mx + 0.3f * s, my - 1.25f * s);
            CGContextAddLineToPoint(c, mx + 0.3f * s, my + 1.25f * s);
            CGContextAddLineToPoint(c, mx - 0.7f * s, my + 0.55f * s);
            CGContextAddLineToPoint(c, mx - 1.5f * s, my + 0.55f * s);
            CGContextClosePath(c);
            CGContextFillPath(c);
            CGContextSetLineWidth(c, 2.0f);
            CGContextMoveToPoint(c, mx + 0.85f * s, my - 0.6f * s);
            CGContextAddLineToPoint(c, mx + 1.7f * s, my + 0.6f * s);
            CGContextMoveToPoint(c, mx + 1.7f * s, my - 0.6f * s);
            CGContextAddLineToPoint(c, mx + 0.85f * s, my + 0.6f * s);
            CGContextStrokePath(c);
            break;
        case GPrev:
            CGContextFillRect(c, CGRectMake(mx - 1.75f * s, my - s, 0.38f * s, 2.0f * s));
            RTri(c, mx - 0.45f * s, my, 0.9f * s, NO);
            RTri(c, mx + 0.85f * s, my, 0.9f * s, NO);
            break;
        case GNext:
            RTri(c, mx - 0.85f * s, my, 0.9f * s, YES);
            RTri(c, mx + 0.45f * s, my, 0.9f * s, YES);
            CGContextFillRect(c, CGRectMake(mx + 1.37f * s, my - s, 0.38f * s, 2.0f * s));
            break;
        case GRew:
            RTri(c, mx - 0.7f * s, my, s, NO);
            RTri(c, mx + 0.7f * s, my, s, NO);
            break;
        case GFfwd:
            RTri(c, mx - 0.7f * s, my, s, YES);
            RTri(c, mx + 0.7f * s, my, s, YES);
            break;
        case GPlay:
            RTri(c, mx - 0.85f * s, my, s, YES);
            CGContextFillRect(c, CGRectMake(mx + 0.55f * s, my - s, 0.45f * s, 2.0f * s));
            CGContextFillRect(c, CGRectMake(mx + 1.3f * s, my - s, 0.45f * s, 2.0f * s));
            break;
        case GStop:
            CGContextFillRect(c, CGRectMake(mx - s, my - s, 2.0f * s, 2.0f * s));
            break;
        case GMin:                                       /* minimize: a bold bar low in the key, like a window's minimize */
            CGContextSetLineWidth(c, 3.2f);
            CGContextBeginPath(c);
            CGContextMoveToPoint(c, mx - 1.3f * s, my + 0.75f * s);
            CGContextAddLineToPoint(c, mx + 1.3f * s, my + 0.75f * s);
            CGContextStrokePath(c);
            break;
        case GMax:                                       /* maximize: a square outline */
            CGContextSetLineWidth(c, 2.6f);
            CGContextStrokeRect(c, CGRectMake(mx - 1.15f * s, my - 1.15f * s, 2.3f * s, 2.3f * s));
            break;
        case GPadDpad: {                                 /* D-pad logo: a ring with four arrows and a centre button */
            CGFloat R = 1.55f * s;
            CGContextSetLineWidth(c, 2.0f);
            CGContextStrokeEllipseInRect(c, CGRectMake(mx - R, my - R, 2 * R, 2 * R));
            CGContextStrokeEllipseInRect(c, CGRectMake(mx - 0.42f * s, my - 0.42f * s, 0.84f * s, 0.84f * s));
            static const float dxs[4] = { 0, 0, -1, 1 }, dys[4] = { -1, 1, 0, 0 };
            for (int k = 0; k < 4; k++) {
                CGFloat dx = dxs[k], dy = dys[k];                    /* unit direction; (-dy, dx) is the sideways unit */
                CGFloat px = mx + dx * 1.02f * s, py = my + dy * 1.02f * s;
                CGContextBeginPath(c);
                CGContextMoveToPoint(c, px + dx * 0.34f * s, py + dy * 0.34f * s);
                CGContextAddLineToPoint(c, px - dx * 0.22f * s - dy * 0.40f * s, py - dy * 0.22f * s + dx * 0.40f * s);
                CGContextAddLineToPoint(c, px - dx * 0.22f * s + dy * 0.40f * s, py - dy * 0.22f * s - dx * 0.40f * s);
                CGContextClosePath(c);
                CGContextFillPath(c);
            }
            break;
        }
        case GPadTrack: {                                /* trackpad logo: a rounded pad with the click bar along its bottom */
            CGRect pr = CGRectMake(mx - 1.45f * s, my - 1.15f * s, 2.9f * s, 2.3f * s);
            CGContextSetLineWidth(c, 2.0f);
            UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:pr cornerRadius:0.55f * s];
            [p stroke];
            CGContextBeginPath(c);
            CGContextMoveToPoint(c, pr.origin.x, CGRectGetMaxY(pr) - 0.7f * s);
            CGContextAddLineToPoint(c, CGRectGetMaxX(pr), CGRectGetMaxY(pr) - 0.7f * s);
            CGContextMoveToPoint(c, mx, CGRectGetMaxY(pr) - 0.7f * s);
            CGContextAddLineToPoint(c, mx, CGRectGetMaxY(pr));
            CGContextStrokePath(c);
            break;
        }
        default: break;
    }
}

/* the glyph engraved into the metal: a white highlight one point below a dark grey cut.
   dark = NO draws a white face with a dark shadow instead (used on the blue anodised key) */
static void RemoteDrawGlyphEngraved(CGContextRef c, int g, CGRect r, BOOL dark) {
    CGContextSaveGState(c);
    CGContextTranslateCTM(c, 0, 1.0f);
    if (dark) { CGContextSetRGBFillColor(c, 1, 1, 1, 0.90f); CGContextSetRGBStrokeColor(c, 1, 1, 1, 0.90f); }
    else      { CGContextSetRGBFillColor(c, 0, 0, 0, 0.55f); CGContextSetRGBStrokeColor(c, 0, 0, 0, 0.55f); }
    RemoteGlyph(c, g, r);
    CGContextRestoreGState(c);
    if (dark) { CGContextSetRGBFillColor(c, 0.28f, 0.29f, 0.33f, 1.0f); CGContextSetRGBStrokeColor(c, 0.28f, 0.29f, 0.33f, 1.0f); }
    else      { CGContextSetRGBFillColor(c, 1, 1, 1, 0.96f); CGContextSetRGBStrokeColor(c, 1, 1, 1, 0.96f); }
    RemoteGlyph(c, g, r);
}

static void BTDrawTriangle(CGContextRef c, CGPoint p, int dir, CGFloat s) {
    CGContextBeginPath(c);
    switch (dir) {
        case 0:  CGContextMoveToPoint(c, p.x, p.y - s);   CGContextAddLineToPoint(c, p.x - s, p.y + s * 0.7f); CGContextAddLineToPoint(c, p.x + s, p.y + s * 0.7f); break;
        case 1:  CGContextMoveToPoint(c, p.x, p.y + s);   CGContextAddLineToPoint(c, p.x - s, p.y - s * 0.7f); CGContextAddLineToPoint(c, p.x + s, p.y - s * 0.7f); break;
        case 2:  CGContextMoveToPoint(c, p.x - s, p.y);   CGContextAddLineToPoint(c, p.x + s * 0.7f, p.y - s); CGContextAddLineToPoint(c, p.x + s * 0.7f, p.y + s); break;
        default: CGContextMoveToPoint(c, p.x + s, p.y);   CGContextAddLineToPoint(c, p.x - s * 0.7f, p.y - s); CGContextAddLineToPoint(c, p.x - s * 0.7f, p.y + s); break;
    }
    CGContextClosePath(c);
    CGContextFillPath(c);
}

/* ======================================================================== remote body (aluminium) */

/* transparent holder for the remote buttons; the metal behind it is drawn once by the page (see AluminiumBlock) */
@interface RemoteBody : UIView
@end
@implementation RemoteBody
- (id)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}
@end

/* The single aluminium block behind everything on the page. Its frame is always the whole page and the metal is always
   inset 4 pt. It is a full-page unibody exactly like the main Trackpad page, for the D-pad and for the gesture pad
   alike: the pad and the remote are separate sections etched into it. Its size never changes, so the brushed finish
   stays put while the etched sections on top of it grow and shrink. */
@interface AluminiumBlock : UIView
@end
@implementation AluminiumBlock
- (id)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    BTDrawUnibody(CGRectInset(self.bounds, 4.0f, 4.0f), 14.0f);
}
@end

/* ======================================================================== round remote button */

@interface RemoteButton : UIControl {
    int glyph;
    BOOL toggled;
}
- (id)initWithGlyph:(int)g;
- (void)setToggled:(BOOL)t;
- (void)setGlyph:(int)g;
@end

@implementation RemoteButton

- (id)initWithGlyph:(int)g {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        glyph = g;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;      /* Back / Home / Menu change width: redraw, never stretch */
    }
    return self;
}

- (void)setGlyph:(int)g { glyph = g; [self setNeedsDisplay]; }
- (void)setToggled:(BOOL)t { toggled = t; [self setNeedsDisplay]; }
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self setNeedsDisplay]; }

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    BOOL down = self.highlighted;
    CGRect wall, face;
    BTKeyFrames(self.bounds, &wall, &face, down);

    BTKeyDrawWall(c, cs, wall, toggled);
    BTKeyDrawFace(c, cs, face, down, toggled);

    RemoteDrawGlyphEngraved(c, glyph, face, !toggled);
    CGColorSpaceRelease(cs);
}

@end

/* ======================================================================== volume / channel rocker */

@interface RemoteRocker : UIControl {
    NSString *label;
    const char *upCmd;
    const char *downCmd;
    int half;                 /* 0 none, 1 top pressed, 2 bottom pressed */
    NSTimer *repeatTimer;
}
- (id)initWithLabel:(NSString *)l up:(const char *)up down:(const char *)down;
@end

@implementation RemoteRocker

- (id)initWithLabel:(NSString *)l up:(const char *)up down:(const char *)down {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        label = [l copy];
        upCmd = up;
        downCmd = down;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}

- (void)dealloc {
    [repeatTimer invalidate];
    [repeatTimer release];
    [label release];
    [super dealloc];
}

- (void)fire { bluemote_send(half == 1 ? upCmd : downCmd); }

- (void)stopRepeat {
    [repeatTimer invalidate];
    [repeatTimer release];
    repeatTimer = nil;
}

- (BOOL)beginTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    CGPoint p = [t locationInView:self];
    half = (p.y < self.bounds.size.height / 2.0f) ? 1 : 2;
    [self fire];
    [self stopRepeat];
    repeatTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:0.4]
                                           interval:0.12 target:self selector:@selector(fire) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:repeatTimer forMode:NSRunLoopCommonModes];
    [self setNeedsDisplay];
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e {
    [self stopRepeat];
    half = 0;
    [self setNeedsDisplay];
}

- (void)cancelTrackingWithEvent:(UIEvent *)e {
    [self stopRepeat];
    half = 0;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGRect wall, r;
    BTKeyFrames(self.bounds, &wall, &r, NO);                                 /* the rocker face stays level; only the pressed half dips */
    UIBezierPath *cap = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(r, 0.5f, 0.5f) cornerRadius:BTKeyRadius(r)];

    BTKeyDrawWall(c, cs, wall, NO);
    BTKeyDrawFace(c, cs, r, NO, NO);

    if (half != 0) {                                                       /* pressed half is dished like a pressed key */
        CGRect hr = r;
        hr.size.height = r.size.height / 2.0f;
        if (half == 2) hr.origin.y += hr.size.height;
        CGContextSaveGState(c);
        [cap addClip];
        CGContextClipToRect(c, hr);
        CGFloat dn[8] = { 0.60f, 0.61f, 0.66f, 1.0f, 0.86f, 0.87f, 0.90f, 1.0f };
        CGGradientRef g = CGGradientCreateWithColorComponents(cs, dn, NULL, 2);
        CGContextDrawLinearGradient(c, g, CGPointMake(0, hr.origin.y), CGPointMake(0, CGRectGetMaxY(hr)), 0);
        CGGradientRelease(g);
        CGContextRestoreGState(c);
        [[UIColor colorWithWhite:0.33f alpha:1.0f] setStroke];
        [cap setLineWidth:1.0f];
        [cap stroke];
    }

    CGFloat midY = CGRectGetMidY(r), cx = CGRectGetMidX(r);
    CGContextSetLineWidth(c, 1.0f);                                        /* engraved groove between the halves */
    CGContextSetRGBStrokeColor(c, 1, 1, 1, 0.85f);
    CGContextMoveToPoint(c, r.origin.x + 8.0f, midY + 1.0f);
    CGContextAddLineToPoint(c, CGRectGetMaxX(r) - 8.0f, midY + 1.0f);
    CGContextStrokePath(c);
    CGContextSetRGBStrokeColor(c, 0.30f, 0.32f, 0.37f, 0.9f);
    CGContextMoveToPoint(c, r.origin.x + 8.0f, midY);
    CGContextAddLineToPoint(c, CGRectGetMaxX(r) - 8.0f, midY);
    CGContextStrokePath(c);

    CGFloat s = 6.5f;                                                      /* engraved plus and minus */
    CGFloat topY = r.origin.y + r.size.height * 0.25f, botY = r.origin.y + r.size.height * 0.75f;
    for (int pass = 0; pass < 2; pass++) {
        CGContextSaveGState(c);
        if (pass == 0) { CGContextTranslateCTM(c, 0, 1.0f); CGContextSetRGBStrokeColor(c, 1, 1, 1, 0.90f); }
        else CGContextSetRGBStrokeColor(c, 0.28f, 0.29f, 0.33f, 1.0f);
        CGContextSetLineWidth(c, 3.0f);
        CGContextSetLineCap(c, kCGLineCapRound);
        CGContextMoveToPoint(c, cx - s, topY); CGContextAddLineToPoint(c, cx + s, topY);
        CGContextMoveToPoint(c, cx, topY - s); CGContextAddLineToPoint(c, cx, topY + s);
        CGContextMoveToPoint(c, cx - s, botY); CGContextAddLineToPoint(c, cx + s, botY);
        CGContextStrokePath(c);
        CGContextRestoreGState(c);
    }
    BTDrawEngravedText(label, CGRectMake(r.origin.x, midY + 3.0f, r.size.width, 12.0f),
                       [UIFont boldSystemFontOfSize:9.0f], NSTextAlignmentCenter);
    CGColorSpaceRelease(cs);
}

@end

/* ======================================================================== D-pad */

@interface DPadView : UIView {
    int zone;                 /* -1 none, 0 up, 1 down, 2 left, 3 right, 4 OK */
    NSTimer *repeatTimer;
    BOOL showHelp;
}
- (void)setShowHelp:(BOOL)show;
@end

@implementation DPadView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        zone = -1;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;      /* redraw (not stretch) when the size changes, so corners stay round */
    }
    return self;
}

- (void)dealloc {
    [repeatTimer invalidate];
    [repeatTimer release];
    [super dealloc];
}

- (void)setShowHelp:(BOOL)show { showHelp = show; [self setNeedsDisplay]; }

- (void)setHidden:(BOOL)h {                                             /* never leave OK held down if the pad disappears */
    if (h && zone == 4) [self press:-1];
    [super setHidden:h];
}

/* geometry: the D-pad is centred in the box */
- (CGPoint)middle { return CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds)); }
- (CGFloat)outerRadius { return MIN(self.bounds.size.width, self.bounds.size.height) / 2.0f - 20.0f; }
- (CGFloat)centerRadius { return [self outerRadius] * 0.38f; }

- (int)zoneForPoint:(CGPoint)p {
    CGPoint m = [self middle];
    CGFloat dx = p.x - m.x, dy = p.y - m.y;
    CGFloat r = sqrtf(dx * dx + dy * dy);
    if (r <= [self centerRadius]) return 4;
    if (r > [self outerRadius] + 6.0f) return -1;
    if (fabsf(dx) > fabsf(dy)) return dx > 0 ? 3 : 2;
    return dy < 0 ? 0 : 1;
}

- (void)stopRepeat {
    [repeatTimer invalidate];
    [repeatTimer release];
    repeatTimer = nil;
}

- (void)sendZone {
    static const int keys[4] = { 0x52, 0x51, 0x50, 0x4f };             /* up down left right (OK is handled in press:) */
    if (zone >= 0 && zone <= 3) bluemote_sendf("KEY %d", keys[zone]);
}

- (void)press:(int)z {
    [self stopRepeat];
    int old = zone;
    zone = z;
    if (old == 4 && z != 4) BTSendOK(2);                                /* finger left OK: release the key */
    if (z == 4 && old != 4) {
        BTSendOK(1);                                                    /* OK is held down while touched: tap = click, hold = long press */
    } else if (z >= 0 && z < 4) {
        [self sendZone];
        {                                                               /* hold an arrow to repeat */
            repeatTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:0.4]
                                                   interval:0.11 target:self selector:@selector(sendZone) userInfo:nil repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:repeatTimer forMode:NSRunLoopCommonModes];
        }
    }
    [self setNeedsDisplay];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    [self press:[self zoneForPoint:[t locationInView:self]]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    int z = [self zoneForPoint:[t locationInView:self]];
    if (z != zone) [self press:z];                                      /* rolling the thumb onto another key */
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event { [self press:-1]; }
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event { [self press:-1]; }

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();                    /* the aluminium block behind is drawn by the page */
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGPoint m = [self middle];
    CGFloat R = [self outerRadius], cr = [self centerRadius];
    CGRect ring = CGRectMake(m.x - R, m.y - R, 2 * R, 2 * R);

    CGContextSaveGState(c);                                            /* drop shadow (same as before, cast by the ring; the thick side wall is gone) */
    CGContextSetShadowWithColor(c, CGSizeMake(0, 3.0f), 7.0f, [UIColor colorWithWhite:0.0f alpha:0.5f].CGColor);
    [[UIColor colorWithWhite:0.40f alpha:1.0f] setFill];
    CGContextFillEllipseInRect(c, ring);
    CGContextRestoreGState(c);

    CGContextSaveGState(c);                                            /* ring body */
    CGContextAddEllipseInRect(c, ring);
    CGContextClip(c);
    CGFloat body[8] = { 0.99f, 0.99f, 1.0f, 1.0f, 0.66f, 0.68f, 0.72f, 1.0f };
    CGGradientRef rg = CGGradientCreateWithColorComponents(cs, body, NULL, 2);
    CGContextDrawLinearGradient(c, rg, CGPointMake(0, ring.origin.y), CGPointMake(0, CGRectGetMaxY(ring)), 0);
    CGGradientRelease(rg);
    CGContextRestoreGState(c);

    if (zone >= 0 && zone <= 3) {                                      /* pressed wedge */
        static const float a0[4] = { -135, 45, 135, -45 };
        static const float a1[4] = {  -45, 135, 225,  45 };
        CGContextBeginPath(c);
        for (float a = a0[zone]; a <= a1[zone]; a += 5.0f) {
            CGFloat rad = a * (float)M_PI / 180.0f;
            CGPoint p = CGPointMake(m.x + R * cosf(rad), m.y + R * sinf(rad));
            if (a == a0[zone]) CGContextMoveToPoint(c, p.x, p.y); else CGContextAddLineToPoint(c, p.x, p.y);
        }
        for (float a = a1[zone]; a >= a0[zone]; a -= 5.0f) {
            CGFloat rad = a * (float)M_PI / 180.0f;
            CGContextAddLineToPoint(c, m.x + cr * cosf(rad), m.y + cr * sinf(rad));
        }
        CGContextClosePath(c);
        CGContextSetRGBFillColor(c, 0.0f, 0.0f, 0.1f, 0.26f);
        CGContextFillPath(c);
    }

    for (int k = 0; k < 4; k++) {                                      /* wedge separators */
        CGFloat rad = (45.0f + 90.0f * k) * (float)M_PI / 180.0f;
        CGPoint p0 = CGPointMake(m.x + cr * cosf(rad), m.y + cr * sinf(rad));
        CGPoint p1 = CGPointMake(m.x + R * cosf(rad), m.y + R * sinf(rad));
        CGContextSetLineWidth(c, 1.0f);
        CGContextSetRGBStrokeColor(c, 1, 1, 1, 0.85f);
        CGContextMoveToPoint(c, p0.x, p0.y + 1.0f); CGContextAddLineToPoint(c, p1.x, p1.y + 1.0f); CGContextStrokePath(c);
        CGContextSetRGBStrokeColor(c, 0.30f, 0.32f, 0.37f, 0.9f);
        CGContextMoveToPoint(c, p0.x, p0.y); CGContextAddLineToPoint(c, p1.x, p1.y); CGContextStrokePath(c);
    }
    [[UIColor colorWithWhite:0.33f alpha:1.0f] setStroke];
    CGContextSetLineWidth(c, 1.0f);
    CGContextStrokeEllipseInRect(c, CGRectInset(ring, 0.5f, 0.5f));

    CGFloat rr = (R + cr) / 2.0f;                                      /* arrows */
    CGPoint pts[4] = { CGPointMake(m.x, m.y - rr), CGPointMake(m.x, m.y + rr), CGPointMake(m.x - rr, m.y), CGPointMake(m.x + rr, m.y) };
    for (int i = 0; i < 4; i++) {
        [[UIColor colorWithWhite:1.0f alpha:0.9f] setFill];
        BTDrawTriangle(c, CGPointMake(pts[i].x, pts[i].y + 1.0f), i, 7.0f);
        [[UIColor colorWithWhite:(zone == i ? 0.12f : 0.34f) alpha:1.0f] setFill];
        BTDrawTriangle(c, pts[i], i, 7.0f);
    }

    CGRect center = CGRectMake(m.x - cr, m.y - cr, 2 * cr, 2 * cr);    /* centre OK button, dished */
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, center);
    CGContextClip(c);
    CGFloat dish[8]  = { 0.70f, 0.72f, 0.76f, 1.0f, 0.98f, 0.98f, 1.0f, 1.0f };
    CGFloat dishP[8] = { 0.55f, 0.57f, 0.62f, 1.0f, 0.84f, 0.85f, 0.89f, 1.0f };
    CGGradientRef cg = CGGradientCreateWithColorComponents(cs, zone == 4 ? dishP : dish, NULL, 2);
    CGContextDrawLinearGradient(c, cg, CGPointMake(0, center.origin.y), CGPointMake(0, CGRectGetMaxY(center)), 0);
    CGGradientRelease(cg);
    CGContextRestoreGState(c);
    [[UIColor colorWithWhite:0.40f alpha:1.0f] setStroke];
    CGContextStrokeEllipseInRect(c, CGRectInset(center, 0.5f, 0.5f));
    BTDrawEngravedText(@"OK", CGRectMake(center.origin.x, m.y - 10.0f, center.size.width, 22.0f),
                       [UIFont boldSystemFontOfSize:17.0f], NSTextAlignmentCenter);

    if (showHelp) BTDrawHelpCard(self.bounds, @"Tap an arrow to move, hold it to repeat.\nRoll your thumb across the ring to change direction.\nCentre: OK / select (hold = long press).");
    CGColorSpaceRelease(cs);
}

@end

/* ======================================================================== gesture pad (trackpad style) */

@interface MediaPanel : UIView {
    BOOL gestureActive, moved, longFired, volFired;
    int maxTouches, lastN;
    CGPoint startC, lastC;
    float accX, accY, volAcc;
    NSTimeInterval startTime;
    BOOL showHelp;
}
- (void)setShowHelp:(BOOL)show;
@end

@implementation MediaPanel

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.multipleTouchEnabled = YES;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;      /* redraw (not stretch) when the size changes, so corners stay round */
    }
    return self;
}

- (void)setShowHelp:(BOOL)show {
    showHelp = show;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    if (showHelp) {                                  /* the aluminium and the etched pad are behind this view */
        BTDrawHelpCard(self.bounds,
            @"Swipe: arrow keys (keep dragging to repeat)\nTap: OK   Hold: Back\nTwo-finger tap: play / pause\nTwo-finger drag up / down: volume\nTwo-finger swipe left / right: previous / next\nTwo-finger hold: Home   Three-finger tap: mute");
    }
}

- (void)longPress {
    if (!gestureActive || moved || longFired) return;
    if (maxTouches == 1) {
        longFired = YES;
        bluemote_send("MEDIA back");
    } else if (maxTouches == 2) {
        longFired = YES;
        bluemote_send("MEDIA home");
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    NSSet *all = [event touchesForView:self];
    int n = BTActiveCount(all);
    if (!gestureActive) {
        gestureActive = YES;
        moved = longFired = volFired = NO;
        maxTouches = 0;
        accX = accY = volAcc = 0;
        startTime = [NSDate timeIntervalSinceReferenceDate];
        startC = BTCentroid(all, self);
        [self performSelector:@selector(longPress) withObject:nil afterDelay:0.55];
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
    CGPoint c = BTCentroid(all, self);
    if (n != lastN) {
        lastN = n;
        lastC = c;
        return;
    }
    float dx = c.x - lastC.x;
    float dy = c.y - lastC.y;
    lastC = c;
    if (hypotf(c.x - startC.x, c.y - startC.y) > 12.0f) moved = YES;
    if (!moved) return;

    if (n == 1 && maxTouches == 1) {
        const float STEP = 36.0f;
        accX += dx;
        accY += dy;
        if (fabsf(accX) >= STEP && fabsf(accX) >= fabsf(accY)) {
            bluemote_send(accX > 0 ? "KEY 0x4f" : "KEY 0x50");   /* right / left */
            accX = accY = 0;
        } else if (fabsf(accY) >= STEP) {
            bluemote_send(accY > 0 ? "KEY 0x51" : "KEY 0x52");   /* down / up */
            accX = accY = 0;
        }
    } else if (n == 2 && maxTouches == 2) {
        volAcc += dy;
        if (fabsf(volAcc) >= 22.0f) {
            bluemote_send(volAcc < 0 ? "MEDIA volup" : "MEDIA voldown");
            volAcc = 0;
            volFired = YES;
        }
    }
}

- (void)finishAllowAction:(BOOL)allow {
    NSTimeInterval dur = [NSDate timeIntervalSinceReferenceDate] - startTime;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(longPress) object:nil];
    gestureActive = NO;
    if (!allow || longFired) return;

    float tdx = lastC.x - startC.x;
    float tdy = lastC.y - startC.y;
    if (!moved && dur < 0.35) {
        if (maxTouches == 1) {
            BTSendOK(0);                              /* OK (Select) */
        } else if (maxTouches == 2) {
            bluemote_send("MEDIA playpause");
        } else if (maxTouches >= 3) {
            bluemote_send("MEDIA mute");
        }
    } else if (maxTouches == 2 && !volFired && fabsf(tdx) > 60.0f && fabsf(tdx) > 2.0f * fabsf(tdy)) {
        bluemote_send(tdx > 0 ? "MEDIA next" : "MEDIA prev");
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
    [self finishAllowAction:YES];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    if (gestureActive) [self finishAllowAction:NO];
}

@end

/* ======================================================================== page container */

/* tags 0-9: commands, 10: D-pad / trackpad switch, 11: minimize / maximize */
static const char *kRemoteCmds[10] = {
    "MEDIA back", "MEDIA home", "MEDIA menu", "MEDIA mute",
    "MEDIA prev", "MEDIA playpause", "MEDIA next",
    "MEDIA rewind", "MEDIA stop", "MEDIA ffwd"
};

@interface MediaView ()
- (void)applyExtrasAlpha;
- (void)stopAnimation;
- (void)animateCollapseTo:(CGFloat)target;
- (void)toggleSize;
@end

static BOOL expandedAtLaunch(void) { return [[NSUserDefaults standardUserDefaults] boolForKey:kPrefMediaExpanded]; }

@implementation MediaView

- (RemoteButton *)addRemote:(int)glyph tag:(int)tag {
    RemoteButton *b = [[RemoteButton alloc] initWithGlyph:glyph];
    b.tag = tag;
    [b addTarget:self action:@selector(remoteTapped:) forControlEvents:UIControlEventTouchUpInside];
    [remoteBody addSubview:b];
    [b release];
    return b;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = BTBackdropColor();

        chassis = [[AluminiumBlock alloc] initWithFrame:CGRectZero];            /* one block behind pad + remote */
        [self addSubview:chassis];
        [chassis release];

        padBox = [[BTEtchedBoxView alloc] initWithRadius:10.0f recessed:YES];   /* pad style: the sections are etched into the block */
        remoteBox = [[BTEtchedBoxView alloc] initWithRadius:10.0f recessed:NO];
        [self addSubview:padBox];
        [self addSubview:remoteBox];
        [padBox release];
        [remoteBox release];

        panel = [[MediaPanel alloc] initWithFrame:CGRectZero];
        dpad = [[DPadView alloc] initWithFrame:CGRectZero];
        [self addSubview:panel];
        [self addSubview:dpad];
        [panel release];
        [dpad release];

        infoB = [UIButton buttonWithType:UIButtonTypeInfoDark];                /* small "i": show / hide the instructions */
        [infoB addTarget:self action:@selector(infoTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:infoB];

        remoteBody = [[RemoteBody alloc] initWithFrame:CGRectZero];
        [self addSubview:remoteBody];
        [remoteBody release];

        volR = [[RemoteRocker alloc] initWithLabel:@"VOL" up:"MEDIA volup" down:"MEDIA voldown"];
        chR  = [[RemoteRocker alloc] initWithLabel:@"CH"  up:"MEDIA chup"  down:"MEDIA chdown"];
        [remoteBody addSubview:volR];
        [remoteBody addSubview:chR];
        [volR release];
        [chR release];

        centerButtons = [[NSMutableArray alloc] init];                         /* three rows of three */
        [centerButtons addObject:[self addRemote:GBack tag:0]];
        [centerButtons addObject:[self addRemote:GHome tag:1]];
        [centerButtons addObject:[self addRemote:GMenu tag:2]];
        [centerButtons addObject:[self addRemote:GPrev tag:4]];
        [centerButtons addObject:[self addRemote:GPlay tag:5]];
        [centerButtons addObject:[self addRemote:GNext tag:6]];
        [centerButtons addObject:[self addRemote:GRew  tag:7]];
        [centerButtons addObject:[self addRemote:GMute tag:3]];                /* Mute sits where Stop was */
        [centerButtons addObject:[self addRemote:GFfwd tag:9]];
        padB   = [self addRemote:GPadDpad tag:10];                              /* D-pad / trackpad switch */
        sizeB  = [self addRemote:(expandedAtLaunch() ? GMax : GMin) tag:11];    /* minimize / maximize, where Mute was */

        expanded = [[NSUserDefaults standardUserDefaults] boolForKey:kPrefMediaExpanded];   /* remember the last position */
        collapseT = expanded ? 1.0f : 0.0f;
        [self reloadSettings];
    }
    return self;
}

- (void)dealloc {
    [animLink invalidate];
    animLink = nil;
    [centerButtons release];
    [super dealloc];
}

static CGFloat BTLerp(CGFloat a, CGFloat b, CGFloat t) { return a + (b - a) * t; }

/* One layout for both pads. `collapseT` runs from 0 (full remote) to 1 (minimized: a single row of Back / Home / Menu
   next to the minimize / maximize key). While it animates, this runs once per display frame, so every key is redrawn at
   its true size instead of a bitmap being stretched. */
- (void)layoutSubviews {
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    CGFloat bs = 44.0f, gap = 8.0f, pad = 8.0f;
    CGFloat t = collapseT;
    const CGFloat margin = 4.0f, etch = 8.0f, section = 8.0f;

    chassis.frame = self.bounds;
    CGRect inner = CGRectInset(CGRectMake(margin, margin, w - 2 * margin, h - 2 * margin), etch, etch);
    CGFloat fullH = 3 * bs + 2 * gap + 2 * pad, oneH = bs + 2 * pad;
    CGFloat remoteH = BTLerp(fullH, oneH, t);
    CGRect remote = CGRectMake(inner.origin.x, CGRectGetMaxY(inner) - remoteH, inner.size.width, remoteH);
    CGRect box = CGRectMake(inner.origin.x, inner.origin.y, inner.size.width, remote.origin.y - section - inner.origin.y);
    padBox.frame = box;
    remoteBox.frame = remote;

    panel.frame = box;
    /* The ring keeps the size it has with the full remote and stays centred in the pad section as it grows, so it is
       never redrawn or rescaled while the section moves. */
    CGFloat fullBoxH = MAX(inner.size.height - fullH - section, 40.0f);
    dpad.bounds = CGRectMake(0, 0, box.size.width, fullBoxH);
    dpad.center = CGPointMake(CGRectGetMidX(box), CGRectGetMidY(box));
    infoB.frame = CGRectMake(box.origin.x + 6.0f, box.origin.y + 6.0f, 30.0f, 30.0f);

    remoteBody.frame = remote;
    CGFloat rw = remote.size.width;
    CGFloat gridW = 3 * bs + 2 * gap, gx = (rw - gridW) / 2.0f;
    CGFloat dy = remoteH - fullH;                                          /* keeps the other keys where they were while the block shrinks around them */
    CGFloat sw = MIN(64.0f, MAX(bs, gx - pad - gap));                      /* the side column (VOL / CH rockers and the two keys under them) takes all the room beside the centre keys */

    volR.frame = CGRectMake(pad, pad + dy, sw, 2 * bs + gap);              /* rockers span the top two rows, Minimize / the pad switch sit in the third */
    chR.frame  = CGRectMake(rw - pad - sw, pad + dy, sw, 2 * bs + gap);
    sizeB.frame  = CGRectMake(pad, pad + 2 * (bs + gap) + dy, sw, bs);     /* same spot in both states: the bottom-left corner */
    padB.frame = CGRectMake(rw - pad - sw, pad + 2 * (bs + gap) + dy, sw, bs);

    /* Minimized: Back / Home / Menu share the whole row to the right of the minimize / maximize key */
    CGFloat rowX = pad + sw + gap;
    CGFloat wb = (rw - pad - rowX - 2 * gap) / 3.0f;
    for (int i = 0; i < (int)[centerButtons count]; i++) {
        int row = i / 3, col = i % 3;
        CGRect f;
        if (i < 3) {
            f = CGRectMake(BTLerp(gx + col * (bs + gap), rowX + col * (wb + gap), t), pad, BTLerp(bs, wb, t), bs);
        } else {
            f = CGRectMake(gx + col * (bs + gap), pad + row * (bs + gap) + dy, bs, bs);
        }
        ((UIView *)[centerButtons objectAtIndex:i]).frame = f;
    }
    [self applyExtrasAlpha];
}

/* pad type is switched here (and in Settings) */
- (void)reloadSettings {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    int padMode = (int)[d integerForKey:kPrefMediaPadMode];            /* 0 = D-pad (default), 1 = trackpad */
    infoB.hidden = !BTInfoButtonEnabled();                              /* "i" button can be turned off in Settings */
    if (infoB.hidden) helpOn = NO;
    BOOL useDpad = (padMode == 0);
    dpad.hidden = !useDpad;
    panel.hidden = useDpad;
    [self stopAnimation];                                               /* settle on the saved choice */
    collapseT = expanded ? 1.0f : 0.0f;
    [sizeB setGlyph:(expanded ? GMax : GMin)];
    [self setNeedsLayout];
    [padB setGlyph:(useDpad ? GPadTrack : GPadDpad)];                    /* the logo shows the pad the key switches TO */
    [panel setShowHelp:helpOn];
    [dpad setShowHelp:helpOn];
}

/* everything in the remote block except Back / Home / Menu and the minimize / maximize key fades out when minimized,
   quickly at the start of the move, and comes back once the block has grown again */
- (void)applyExtrasAlpha {
    CGFloat a = 1.0f - MIN(1.0f, collapseT / 0.35f);
    BOOL on = (a > 0.5f);
    NSMutableArray *extras = [NSMutableArray arrayWithObjects:volR, chR, padB, nil];
    for (int i = 3; i < (int)[centerButtons count]; i++) [extras addObject:[centerButtons objectAtIndex:i]];
    for (UIView *v in extras) {
        v.alpha = a;
        v.userInteractionEnabled = on;
    }
}

- (void)stopAnimation {
    if (animLink) {
        [animLink invalidate];
        animLink = nil;
    }
}

- (void)animateCollapseTo:(CGFloat)target {
    animFrom = collapseT;
    animTo = target;
    animDur = MAX(0.15, 0.38 * fabs((double)(target - collapseT)));
    animStart = CACurrentMediaTime();
    if (animLink == nil) {
        animLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(animTick:)];
        [animLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)animTick:(CADisplayLink *)link {
    CGFloat p = (CGFloat)((CACurrentMediaTime() - animStart) / animDur);
    if (p > 1.0f) p = 1.0f;
    CGFloat e = p * p * (3.0f - 2.0f * p);                              /* ease in and out */
    collapseT = animFrom + (animTo - animFrom) * e;
    [self setNeedsLayout];
    [self layoutIfNeeded];
    if (p >= 1.0f) {
        [self stopAnimation];
        collapseT = animTo;
        [self setNeedsLayout];
        [panel setShowHelp:helpOn];                                     /* the help card is drawn, so it waits until the move is done */
    }
}

- (void)toggleSize {
    expanded = !expanded;
    [[NSUserDefaults standardUserDefaults] setBool:expanded forKey:kPrefMediaExpanded];   /* remembered for next time */
    [sizeB setGlyph:(expanded ? GMax : GMin)];
    [panel setShowHelp:NO];
    [self animateCollapseTo:(expanded ? 1.0f : 0.0f)];
}

- (void)infoTapped {
    helpOn = !helpOn;
    [panel setShowHelp:helpOn];
    [dpad setShowHelp:helpOn];
}

/* D-pad <-> trackpad flips the page the same way Trackpad <-> Media does (right when going to the trackpad, back left
   when going to the D-pad). */
- (void)flipPad {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    BOOL toTrackpad = ([d integerForKey:kPrefMediaPadMode] == 0);
    [d setInteger:(toTrackpad ? 1 : 0) forKey:kPrefMediaPadMode];
    UIViewAnimationOptions o = toTrackpad ? UIViewAnimationOptionTransitionFlipFromRight : UIViewAnimationOptionTransitionFlipFromLeft;
    [UIView transitionWithView:self duration:0.55 options:o
        animations:^{
            /* Everything is moved to its final place with animations OFF. Inside a transition the key frames would
               otherwise slide from the old layout to the new one over the length of the flip, and land with a visible
               snap when it ends. */
            [UIView setAnimationsEnabled:NO];
            [self reloadSettings];
            [self layoutIfNeeded];
            [UIView setAnimationsEnabled:YES];
        }
        completion:nil];
}

- (void)remoteTapped:(UIControl *)b {
    if (b.tag == 11) { [self toggleSize]; return; }
    if (b.tag == 10) {
        /* Start the flip on the next run loop pass: by then the tapped key has let go of its pressed look, so the flip
           never starts from (or lands on) a half-pressed key. */
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(flipPad) object:nil];
        [self performSelector:@selector(flipPad) withObject:nil afterDelay:0.0];
        return;
    }
    if (b.tag >= 0 && b.tag < 10) bluemote_send(kRemoteCmds[b.tag]);
}

@end
