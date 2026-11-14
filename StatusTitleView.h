#import <UIKit/UIKit.h>

/* Two-line title for the navigation bar: page title + live connection status. */
@interface StatusTitleView : UIView {
    UILabel *titleL;
    UILabel *statusL;
}
- (id)initWithTitle:(NSString *)title;
- (void)setPageTitle:(NSString *)title;
- (void)setStatus:(NSString *)status connected:(BOOL)connected;
@end
