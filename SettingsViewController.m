#import "SettingsViewController.h"
#import "PairViewController.h"
#import "UIHelpers.h"

enum { SecBluetooth = 0, SecMedia = 1, SecTrackpad = 2 };
enum { TagPadMode = 1, TagReelsMethod = 2, TagReelsSwap = 3, TagNatural = 4 };

@implementation SettingsViewController

- (id)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) self.title = @"Settings";
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return o == UIInterfaceOrientationPortrait; }
- (BOOL)shouldAutorotate { return NO; }
- (NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];                  /* the device count may have changed */
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    if (section == SecBluetooth) return 1;
    if (section == SecMedia) return 3;
    return 1;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section {
    if (section == SecBluetooth) return @"Bluetooth";
    if (section == SecMedia) return @"Media remote";
    return @"Trackpad";
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    if (section == SecMedia)
        return @"Reels turns the media pad into a plain pad: tap = next video, double-tap = previous. If it goes the wrong way swap the direction; if nothing happens try another method.";
    return nil;
}

- (UISegmentedControl *)segmentWithItems:(NSArray *)items selected:(NSInteger)sel tag:(int)tag width:(CGFloat)w {
    UISegmentedControl *s = [[[UISegmentedControl alloc] initWithItems:items] autorelease];
    s.frame = CGRectMake(0, 0, w, 30);
    s.selectedSegmentIndex = sel;
    s.tag = tag;
    [s addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    return s;
}

- (UISwitch *)switchOn:(BOOL)on tag:(int)tag {
    UISwitch *sw = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
    sw.on = on;
    sw.tag = tag;
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    return sw;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    NSString *ident = [NSString stringWithFormat:@"s%d_%d", (int)ip.section, (int)ip.row];
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];
    if (!cell) {
        UITableViewCellStyle st = (ip.section == SecBluetooth) ? UITableViewCellStyleSubtitle : UITableViewCellStyleDefault;
        cell = [[[UITableViewCell alloc] initWithStyle:st reuseIdentifier:ident] autorelease];
    }
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    if (ip.section == SecBluetooth) {                                   /* pairing logic lives in its own cell */
        int n = btcombo_saved_count();
        cell.textLabel.text = @"Pairing & Devices";
        cell.detailTextLabel.text = n == 0 ? @"No paired devices"
                                           : [NSString stringWithFormat:@"%d paired device%@", n, n == 1 ? @"" : @"s"];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (ip.section == SecMedia) {
        if (ip.row == 0) {
            cell.textLabel.text = @"Media pad";
            cell.accessoryView = [self segmentWithItems:[NSArray arrayWithObjects:@"D-pad", @"Trackpad", nil]
                                               selected:[d integerForKey:kPrefMediaPadMode] tag:TagPadMode width:170];
        } else if (ip.row == 1) {
            cell.textLabel.text = @"Reels method";
            cell.accessoryView = [self segmentWithItems:[NSArray arrayWithObjects:@"Keys", @"Wheel", @"Drag", nil]
                                               selected:[d integerForKey:kPrefReelsMethod] tag:TagReelsMethod width:170];
        } else {
            cell.textLabel.text = @"Swap Reels direction";
            cell.accessoryView = [self switchOn:[d boolForKey:kPrefReelsSwap] tag:TagReelsSwap];
        }
    } else {
        cell.textLabel.text = @"Natural scrolling";
        cell.accessoryView = [self switchOn:[d boolForKey:kPrefNaturalScroll] tag:TagNatural];
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == SecBluetooth) {
        PairViewController *p = [[PairViewController alloc] init];
        [self.navigationController pushViewController:p animated:YES];
        [p release];
    }
}

/* every choice is saved at once and remembered */
- (void)segmentChanged:(UISegmentedControl *)s {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (s.tag == TagPadMode) [d setInteger:s.selectedSegmentIndex forKey:kPrefMediaPadMode];
    else if (s.tag == TagReelsMethod) [d setInteger:s.selectedSegmentIndex forKey:kPrefReelsMethod];
}

- (void)switchChanged:(UISwitch *)sw {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (sw.tag == TagReelsSwap) [d setBool:sw.on forKey:kPrefReelsSwap];
    else if (sw.tag == TagNatural) [d setBool:sw.on forKey:kPrefNaturalScroll];
}

@end
