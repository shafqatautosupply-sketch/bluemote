#import <UIKit/UIKit.h>
#import "StatusTitleView.h"

/* Settings-style (grouped table) screen: status, paired devices, pairing actions. */
@interface PairViewController : UITableViewController <UIActionSheetDelegate, UIAlertViewDelegate> {
    StatusTitleView *titleView;
    NSString *lastSignature;
    NSString *selectedAddr;
    NSTimer *timer;
}
- (void)setStatus:(NSString *)status connected:(BOOL)connected;
- (void)refresh;
@end
