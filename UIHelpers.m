#import "UIHelpers.h"
#include <string.h>

/* ------------------------------------------------------------------ buttons */

static UIImage *BTButtonImage(BTButtonStyle style, BOOL pressed) {
    static UIImage *cache[5][2];
    UIImage *cached = cache[style][pressed ? 1 : 0];
    if (cached) return cached;

    const CGFloat w = 24.0f, h = 30.0f, radius = 9.0f;
    CGFloat top[3], bottom[3], border[3];
    BOOL gloss = NO;
    switch (style) {
        case BTStyleBlue: {
            CGFloat t[3] = {0.47f, 0.64f, 0.93f}, b[3] = {0.13f, 0.37f, 0.78f}, e[3] = {0.06f, 0.20f, 0.46f};
            memcpy(top, t, sizeof(t)); memcpy(bottom, b, sizeof(b)); memcpy(border, e, sizeof(e)); gloss = YES; break; }
        case BTStyleRed: {
            CGFloat t[3] = {0.94f, 0.48f, 0.46f}, b[3] = {0.76f, 0.12f, 0.12f}, e[3] = {0.42f, 0.05f, 0.05f};
            memcpy(top, t, sizeof(t)); memcpy(bottom, b, sizeof(b)); memcpy(border, e, sizeof(e)); gloss = YES; break; }
        case BTStyleDark: {
            CGFloat t[3] = {0.42f, 0.44f, 0.48f}, b[3] = {0.10f, 0.11f, 0.13f}, e[3] = {0.0f, 0.0f, 0.0f};
            memcpy(top, t, sizeof(t)); memcpy(bottom, b, sizeof(b)); memcpy(border, e, sizeof(e)); gloss = YES; break; }
        case BTStyleKey: {
            CGFloat t[3] = {1.0f, 1.0f, 1.0f}, b[3] = {0.80f, 0.82f, 0.86f}, e[3] = {0.42f, 0.44f, 0.49f};
            memcpy(top, t, sizeof(t)); memcpy(bottom, b, sizeof(b)); memcpy(border, e, sizeof(e)); break; }
        default: {
            CGFloat t[3] = {0.99f, 0.99f, 1.0f}, b[3] = {0.76f, 0.78f, 0.82f}, e[3] = {0.35f, 0.37f, 0.42f};
            memcpy(top, t, sizeof(t)); memcpy(bottom, b, sizeof(b)); memcpy(border, e, sizeof(e)); break; }
    }
    if (pressed) {
        for (int i = 0; i < 3; i++) { top[i] *= 0.80f; bottom[i] *= 0.80f; }
    }

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(w, h), NO, 0.0f);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

    CGRect r = CGRectMake(0.5f, 0.5f, w - 1.0f, h - 2.0f);          /* last point row is the white "lip" below the button */
    UIBezierPath *lip = [UIBezierPath bezierPathWithRoundedRect:CGRectOffset(r, 0, 1.0f) cornerRadius:radius];
    [[UIColor colorWithWhite:1.0f alpha:0.55f] setFill];
    [lip fill];

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];
    CGContextSaveGState(c);
    [path addClip];
    CGFloat comps[8] = { top[0], top[1], top[2], 1.0f, bottom[0], bottom[1], bottom[2], 1.0f };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, NULL, 2);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, r.origin.y), CGPointMake(0, CGRectGetMaxY(r)), 0);
    CGGradientRelease(g);
    if (gloss) {                                                      /* glass highlight on the upper half */
        CGFloat gc[8] = { 1, 1, 1, 0.38f, 1, 1, 1, 0.06f };
        CGGradientRef gg = CGGradientCreateWithColorComponents(cs, gc, NULL, 2);
        CGContextDrawLinearGradient(c, gg, CGPointMake(0, r.origin.y), CGPointMake(0, r.origin.y + r.size.height * 0.5f), 0);
        CGGradientRelease(gg);
    }
    CGContextSetRGBStrokeColor(c, 1, 1, 1, pressed ? 0.12f : 0.60f);  /* inner top highlight */
    CGContextSetLineWidth(c, 1.0f);
    CGContextMoveToPoint(c, r.origin.x + radius, r.origin.y + 1.5f);
    CGContextAddLineToPoint(c, CGRectGetMaxX(r) - radius, r.origin.y + 1.5f);
    CGContextStrokePath(c);
    CGContextRestoreGState(c);

    CGContextSetRGBStrokeColor(c, border[0], border[1], border[2], 1.0f);
    [path setLineWidth:1.0f];
    [path stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGColorSpaceRelease(cs);
    img = [img resizableImageWithCapInsets:UIEdgeInsetsMake(h / 2.0f - 1.0f, w / 2.0f - 1.0f, h / 2.0f - 1.0f, w / 2.0f - 1.0f)];
    cache[style][pressed ? 1 : 0] = [img retain];
    return img;
}

void BTSetButtonStyle(UIButton *b, BTButtonStyle style) {
    [b setBackgroundImage:BTButtonImage(style, NO) forState:UIControlStateNormal];
    [b setBackgroundImage:BTButtonImage(style, YES) forState:UIControlStateHighlighted];
    BOOL light = (style == BTStyleGray || style == BTStyleKey);
    UIColor *text = light ? [UIColor colorWithWhite:0.16f alpha:1.0f] : [UIColor whiteColor];
    [b setTitleColor:text forState:UIControlStateNormal];
    [b setTitleColor:text forState:UIControlStateHighlighted];
    [b setTitleShadowColor:(light ? [UIColor colorWithWhite:1.0f alpha:0.85f] : [UIColor colorWithWhite:0.0f alpha:0.55f])
                  forState:UIControlStateNormal];
    b.titleLabel.shadowOffset = light ? CGSizeMake(0, 1) : CGSizeMake(0, -1);
}

UIButton *BTMakeStyledButton(NSString *title, BTButtonStyle style, id target, SEL action) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:14.0f];
    b.titleLabel.adjustsFontSizeToFitWidth = YES;
    b.titleLabel.minimumScaleFactor = 0.7f;
    [b setTitle:title forState:UIControlStateNormal];
    BTSetButtonStyle(b, style);
    if (target) [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

UIButton *BTMakeButton(NSString *title, id target, SEL action) {
    return BTMakeStyledButton(title, BTStyleGray, target, action);
}

void BTSetButtonToggle(UIButton *b, BOOL on, BTButtonStyle offStyle) {
    BTSetButtonStyle(b, on ? BTStyleBlue : offStyle);
}

void BTSetButtonOn(UIButton *b, BOOL on) {
    BTSetButtonToggle(b, on, BTStyleGray);
}

/* ------------------------------------------------------------------ panels and text */

UIColor *BTLinenColor(void) {
    return [UIColor groupTableViewBackgroundColor];          /* the real iOS 6 linen */
}

/* ---- brushed aluminium slab (trackpad, media pad, D-pad backdrop) ----
   Drawn once per size into a cached image (deterministic grain, so it never shimmers), then just blitted.
   Vertical brushing: a base metal gradient with a bright sheen band, one random tone per pixel column, thousands of
   short vertical streaks, darker left / right edges, a bright top bevel, a shaded bottom lip and a soft drop shadow,
   plus an etched line border close to the edge (dark groove with a light line under it) that gives the slab look.
   tools/preview_slab.py renders the same algorithm off-device. */

static CGFloat BTRnd(unsigned int *s) {                        /* tiny LCG: same sequence every time */
    *s = (*s) * 1664525u + 1013904223u;
    return (CGFloat)((*s >> 8) & 0xFFFF) / 65535.0f;
}

static UIImage *BTBrushedSlabImage(CGSize size, CGFloat radius) {
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGFloat px = 1.0f / scale;
    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

    CGRect r = CGRectMake(2.0f, 2.0f, size.width - 4.0f, size.height - 5.0f);   /* room for the shadow */
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];

    CGContextSaveGState(c);                                    /* drop shadow */
    CGContextSetShadowWithColor(c, CGSizeMake(0, 1.5f), 4.0f, [UIColor colorWithWhite:0.0f alpha:0.45f].CGColor);
    [[UIColor colorWithWhite:0.75f alpha:1.0f] setFill];
    [p fill];
    CGContextRestoreGState(c);

    CGContextSaveGState(c);
    [p addClip];

    CGFloat metal[16] = { 0.90f, 0.91f, 0.93f, 1.0f,           /* top */
                          0.97f, 0.97f, 0.985f, 1.0f,          /* sheen band */
                          0.80f, 0.81f, 0.84f, 1.0f,
                          0.66f, 0.67f, 0.71f, 1.0f };         /* bottom */
    CGFloat metalLoc[4] = { 0.0f, 0.22f, 0.52f, 1.0f };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, metal, metalLoc, 4);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, r.origin.y), CGPointMake(0, CGRectGetMaxY(r)), 0);
    CGGradientRelease(g);

    unsigned int seed = 0x5EED1234u;
    for (CGFloat x = r.origin.x; x < CGRectGetMaxX(r); x += px) {            /* one random tone per pixel column */
        CGFloat v = BTRnd(&seed) * 2.0f - 1.0f;
        if (v > 0) CGContextSetRGBFillColor(c, 1, 1, 1, v * 0.09f);
        else       CGContextSetRGBFillColor(c, 0, 0, 0, -v * 0.07f);
        CGContextFillRect(c, CGRectMake(x, r.origin.y, px, r.size.height));
    }
    int streaks = (int)(r.size.width * r.size.height / 60.0f);               /* short bright / dark scratches */
    for (int i = 0; i < streaks; i++) {
        CGFloat t = BTRnd(&seed);
        CGFloat len = 8.0f + t * t * 170.0f;
        CGFloat y = r.origin.y - len * 0.5f + BTRnd(&seed) * (r.size.height + len * 0.5f);
        CGFloat sx = r.origin.x + floorf(BTRnd(&seed) * r.size.width * scale) * px;
        CGFloat a = 0.04f + BTRnd(&seed) * 0.09f;
        if (BTRnd(&seed) > 0.5f) CGContextSetRGBFillColor(c, 1, 1, 1, a);
        else                     CGContextSetRGBFillColor(c, 0, 0, 0, a);
        CGContextFillRect(c, CGRectMake(sx, y, px, len));
    }

    CGFloat edge[8] = { 0, 0, 0, 0.12f, 0, 0, 0, 0.0f };                     /* darker left / right edges */
    CGGradientRef eg = CGGradientCreateWithColorComponents(cs, edge, NULL, 2);
    CGContextDrawLinearGradient(c, eg, CGPointMake(r.origin.x, 0), CGPointMake(r.origin.x + 22.0f, 0), 0);
    CGContextDrawLinearGradient(c, eg, CGPointMake(CGRectGetMaxX(r), 0), CGPointMake(CGRectGetMaxX(r) - 22.0f, 0), 0);
    CGGradientRelease(eg);

    CGFloat hi[8] = { 1, 1, 1, 0.70f, 1, 1, 1, 0.0f };                       /* bright bevel along the top */
    CGGradientRef hg = CGGradientCreateWithColorComponents(cs, hi, NULL, 2);
    CGContextDrawLinearGradient(c, hg, CGPointMake(0, r.origin.y), CGPointMake(0, r.origin.y + 2.0f), 0);
    CGGradientRelease(hg);

    CGFloat lo[8] = { 0, 0, 0, 0.22f, 0, 0, 0, 0.0f };                       /* shaded lip along the bottom */
    CGGradientRef lg = CGGradientCreateWithColorComponents(cs, lo, NULL, 2);
    CGContextDrawLinearGradient(c, lg, CGPointMake(0, CGRectGetMaxY(r)), CGPointMake(0, CGRectGetMaxY(r) - 8.0f), 0);
    CGGradientRelease(lg);

    /* etched border close to the edge: a light line under a dark groove */
    CGRect br = CGRectInset(r, 6.0f, 6.0f);
    UIBezierPath *bp = [UIBezierPath bezierPathWithRoundedRect:br cornerRadius:MAX(radius - 6.0f, 3.0f)];
    [bp setLineWidth:1.0f];
    CGContextSaveGState(c);
    CGContextTranslateCTM(c, 0, 1.0f);
    [[UIColor colorWithWhite:1.0f alpha:0.85f] setStroke];
    [bp stroke];
    CGContextRestoreGState(c);
    [[UIColor colorWithWhite:0.22f alpha:0.55f] setStroke];
    [bp stroke];

    CGContextRestoreGState(c);

    [[UIColor colorWithWhite:0.30f alpha:1.0f] setStroke];                   /* outer edge */
    [p setLineWidth:1.0f];
    [p stroke];

    CGColorSpaceRelease(cs);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

void BTDrawPanel(CGRect rect, CGFloat radius) {
    static NSMutableDictionary *cache = nil;
    if (cache == nil) cache = [[NSMutableDictionary alloc] init];
    NSString *key = [NSString stringWithFormat:@"%.1fx%.1f@%.0f/%.0f", rect.size.width, rect.size.height,
                     [[UIScreen mainScreen] scale], radius];
    UIImage *img = [cache objectForKey:key];
    if (img == nil) {
        if ([cache count] > 8) [cache removeAllObjects];          /* sizes only change with rotation / expand */
        img = BTBrushedSlabImage(rect.size, radius);
        if (img) [cache setObject:img forKey:key];
    }
    [img drawAtPoint:rect.origin];
}

void BTDrawEngravedText(NSString *text, CGRect rect, UIFont *font, NSTextAlignment align) {
    [[UIColor colorWithWhite:1.0f alpha:0.85f] set];
    [text drawInRect:CGRectOffset(rect, 0, 1.0f) withFont:font lineBreakMode:NSLineBreakByWordWrapping alignment:align];
    [[UIColor colorWithWhite:0.28f alpha:1.0f] set];
    [text drawInRect:rect withFont:font lineBreakMode:NSLineBreakByWordWrapping alignment:align];
}


void BTDrawDarkPanel(CGRect rect, CGFloat radius) {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGRect r = CGRectInset(rect, 1.0f, 1.0f);
    r.size.height -= 1.0f;
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];
    CGContextSaveGState(c);
    CGContextTranslateCTM(c, 0, 1.0f);
    [[UIColor colorWithWhite:1.0f alpha:0.7f] setFill];
    [p fill];
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    [p addClip];
    CGFloat body[8] = { 0.36f, 0.37f, 0.40f, 1.0f, 0.13f, 0.13f, 0.15f, 1.0f };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, body, NULL, 2);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, r.origin.y), CGPointMake(0, CGRectGetMaxY(r)), 0);
    CGGradientRelease(g);
    CGFloat gl[8] = { 1, 1, 1, 0.20f, 1, 1, 1, 0.02f };                 /* plastic sheen on the upper part */
    CGGradientRef gg = CGGradientCreateWithColorComponents(cs, gl, NULL, 2);
    CGContextDrawLinearGradient(c, gg, CGPointMake(0, r.origin.y), CGPointMake(0, r.origin.y + r.size.height * 0.45f), 0);
    CGGradientRelease(gg);
    CGContextRestoreGState(c);
    [[UIColor colorWithWhite:0.0f alpha:0.85f] setStroke];
    [p setLineWidth:1.0f];
    [p stroke];
    CGColorSpaceRelease(cs);
}

void BTDrawHelpCard(CGRect rect, NSString *text) {
    UIFont *font = [UIFont systemFontOfSize:14.0f];
    CGSize sz = [text sizeWithFont:font
                 constrainedToSize:CGSizeMake(rect.size.width - 60.0f, rect.size.height - 70.0f)
                     lineBreakMode:NSLineBreakByWordWrapping];
    CGRect card = CGRectMake(0, 0, sz.width + 34.0f, sz.height + 30.0f);
    card.origin = CGPointMake(CGRectGetMidX(rect) - card.size.width / 2.0f, CGRectGetMidY(rect) - card.size.height / 2.0f);
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:card cornerRadius:12.0f];
    [[UIColor colorWithWhite:0.04f alpha:0.82f] setFill];
    [p fill];
    [[UIColor colorWithWhite:1.0f alpha:0.35f] setStroke];
    [p setLineWidth:1.0f];
    [p stroke];
    [[UIColor whiteColor] set];
    [text drawInRect:CGRectMake(card.origin.x + 17.0f, card.origin.y + 15.0f, sz.width, sz.height)
            withFont:font lineBreakMode:NSLineBreakByWordWrapping alignment:NSTextAlignmentCenter];
}

NSString *BTStatusText(BOOL *connectedOut) {
    BOOL connected = bluemote_is_connected();
    NSString *text = [NSString stringWithUTF8String:bluemote_status()];
    if (connected) {
        NSString *addr = [NSString stringWithUTF8String:bluemote_connected_addr()];
        if ([addr length]) text = [NSString stringWithFormat:@"Connected \u2013 %@", BTDeviceDisplayName(addr)];
    }
    if (connectedOut) *connectedOut = connected;
    return text;
}

/* ------------------------------------------------------------------ device names */

NSString *BTDeviceDisplayName(NSString *addr) {
    if ([addr length] == 0) return @"";
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *alias = [d stringForKey:[@"alias." stringByAppendingString:addr]];
    if ([alias length]) return alias;
    const char *u = bluemote_device_name([addr UTF8String]);
    NSString *name = (u && u[0]) ? [NSString stringWithUTF8String:u] : nil;
    NSString *nameKey = [@"name." stringByAppendingString:addr];
    if ([name length]) {                                       /* remember the name read from the device */
        if (![name isEqualToString:[d stringForKey:nameKey]]) [d setObject:name forKey:nameKey];
        return name;
    }
    name = [d stringForKey:nameKey];
    return [name length] ? name : @"Bluetooth device";
}

/* ------------------------------------------------------------------ touches */

int BTActiveCount(NSSet *all) {
    int n = 0;
    for (UITouch *t in all) {
        if (t.phase != UITouchPhaseEnded && t.phase != UITouchPhaseCancelled) n++;
    }
    return n;
}

CGPoint BTCentroid(NSSet *all, UIView *v) {
    CGFloat sx = 0, sy = 0;
    int n = 0;
    for (UITouch *t in all) {
        if (t.phase == UITouchPhaseEnded || t.phase == UITouchPhaseCancelled) continue;
        CGPoint p = [t locationInView:v];
        sx += p.x;
        sy += p.y;
        n++;
    }
    if (n == 0) return CGPointZero;
    return CGPointMake(sx / n, sy / n);
}

/* OK like a real remote: Select (DPAD_CENTER) by default, Enter if chosen in Settings. The mode is sent first, so a
   change in Settings takes effect at once; commands are processed in order. */
void BTSendOK(int phase) {
    bluemote_sendf("OKMODE %d", (int)[[NSUserDefaults standardUserDefaults] integerForKey:kPrefOkMode]);
    bluemote_send(phase == 1 ? "OKD" : (phase == 2 ? "OKU" : "OK"));
}
