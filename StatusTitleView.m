#import "StatusTitleView.h"

@implementation StatusTitleView

- (UILabel *)makeLabelFont:(UIFont *)font {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.backgroundColor = [UIColor clearColor];
    l.font = font;
    l.textAlignment = NSTextAlignmentCenter;
    l.lineBreakMode = NSLineBreakByTruncatingTail;
    l.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.55f];
    l.shadowOffset = CGSizeMake(0, -1);
    [self addSubview:l];
    [l release];
    return l;
}

- (id)initWithTitle:(NSString *)title {
    self = [super initWithFrame:CGRectMake(0, 0, 200, 44)];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        titleL = [self makeLabelFont:[UIFont boldSystemFontOfSize:18.0f]];
        titleL.textColor = [UIColor whiteColor];
        titleL.text = title;
        titleL.frame = CGRectMake(0, 2, 200, 22);
        statusL = [self makeLabelFont:[UIFont systemFontOfSize:11.0f]];
        statusL.frame = CGRectMake(0, 25, 200, 15);
        statusL.adjustsFontSizeToFitWidth = YES;
        statusL.minimumScaleFactor = 0.75f;
        statusL.textColor = [UIColor colorWithWhite:0.85f alpha:1.0f];
    }
    return self;
}

- (void)setPageTitle:(NSString *)title {
    titleL.text = title;
}

- (void)setStatus:(NSString *)status connected:(BOOL)connected {
    statusL.text = [NSString stringWithFormat:@"%@ %@", connected ? @"\u25CF" : @"\u25CB", status];
    statusL.textColor = connected ? [UIColor colorWithRed:0.62f green:1.0f blue:0.62f alpha:1.0f]
                                  : [UIColor colorWithRed:1.0f green:0.86f blue:0.55f alpha:1.0f];
}

@end
