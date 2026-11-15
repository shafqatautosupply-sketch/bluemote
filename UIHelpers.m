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

void BTDrawPanel(CGRect rect, CGFloat radius) {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGRect r = CGRectInset(rect, 1.0f, 1.0f);
    r.size.height -= 1.0f;
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];

    CGContextSaveGState(c);                                   /* white lip under the pad */
    CGContextTranslateCTM(c, 0, 1.0f);
    [[UIColor colorWithWhite:1.0f alpha:0.75f] setFill];
    [p fill];
    CGContextRestoreGState(c);

    CGContextSaveGState(c);
    [p addClip];
    CGFloat metal[8] = { 0.92f, 0.93f, 0.95f, 1.0f, 0.71f, 0.73f, 0.77f, 1.0f };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, metal, NULL, 2);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, r.origin.y), CGPointMake(0, CGRectGetMaxY(r)), 0);
    CGGradientRelease(g);
    for (CGFloat y = r.origin.y; y < CGRectGetMaxY(r); y += 2.0f) {   /* fine brushed lines */
        int odd = ((int)(y / 2.0f)) % 2;
        CGContextSetRGBFillColor(c, odd ? 1.0f : 0.0f, odd ? 1.0f : 0.0f, odd ? 1.0f : 0.0f, 0.035f);
        CGContextFillRect(c, CGRectMake(r.origin.x, y, r.size.width, 1.0f));
    }
    CGFloat shade[8] = { 0, 0, 0, 0.30f, 0, 0, 0, 0.0f };           /* inner shadow along the top edge */
    CGGradientRef sg = CGGradientCreateWithColorComponents(cs, shade, NULL, 2);
    CGContextDrawLinearGradient(c, sg, CGPointMake(0, r.origin.y), CGPointMake(0, r.origin.y + 16.0f), 0);
    CGGradientRelease(sg);
    CGContextRestoreGState(c);

    [[UIColor colorWithWhite:0.30f alpha:1.0f] setStroke];
    [p setLineWidth:1.0f];
    [p stroke];
    CGColorSpaceRelease(cs);
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
