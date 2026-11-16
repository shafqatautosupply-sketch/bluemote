#import "SettingsViewController.h"
#import "PairViewController.h"
#import "UIHelpers.h"

enum { SecBluetooth = 0, SecMedia = 1, SecTrackpad = 2, SecInterface = 3 };
enum { TagPadMode = 1, TagNatural = 4, TagOkMode = 5, TagShowInfo = 6 };

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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 4; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    if (section == SecBluetooth) return 1;
    if (section == SecMedia) return 2;
    return 1;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section {
    if (section == SecBluetooth) return @"Bluetooth";
    if (section == SecMedia) return @"Media remote";
    if (section == SecTrackpad) return @"Trackpad";
    return @"Interface";
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    if (section == SecMedia)
        return @"OK button: Select works like a real TV remote (picks the highlighted keyboard suggestion); use Enter only if your TV ignores Select.";
    return nil;
}

- (UISegmentedControl *)segmentWithItems:(NSArray *)items selected:(NSInteger)sel tag:(int)tag width:(CGFloat)w {
    UISegmentedControl *s = [[[UISegmentedControl alloc] initWithItems:items] autorelease];
    s.segmentedControlStyle = UISegmentedControlStyleBar;      /* native height is 30 pt, so the end caps are not stretched */
    s.tintColor = BTBarButtonTintColor();                      /* same grey as the nav bar buttons */
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
        int n = bluemote_saved_count();
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
            cell.textLabel.text = @"OK button";
            cell.accessoryView = [self segmentWithItems:[NSArray arrayWithObjects:@"Select", @"Enter", nil]
                                               selected:[d integerForKey:kPrefOkMode] tag:TagOkMode width:170];
        }
    } else if (ip.section == SecInterface) {
        cell.textLabel.text = @"Show info (i) button";
        cell.accessoryView = [self switchOn:BTInfoButtonEnabled() tag:TagShowInfo];
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
    else if (s.tag == TagOkMode) [d setInteger:s.selectedSegmentIndex forKey:kPrefOkMode];
}

- (void)switchChanged:(UISwitch *)sw {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (sw.tag == TagNatural) [d setBool:sw.on forKey:kPrefNaturalScroll];
    else if (sw.tag == TagShowInfo) [d setBool:sw.on forKey:kPrefShowInfo];
}

@end
