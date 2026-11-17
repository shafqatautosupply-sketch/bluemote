#import "SettingsViewController.h"
#import "PairViewController.h"
#import "UIHelpers.h"

enum { SecBluetooth = 0, SecMedia = 1, SecTrackpad = 2, SecInterface = 3, SecAbout = 4 };
enum { TagPadMode = 1, TagNatural = 4, TagOkMode = 5, TagShowInfo = 6, TagScrollTab = 7 };

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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 5; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    if (section == SecBluetooth) return 1;
    if (section == SecMedia) return 2;
    if (section == SecTrackpad) return 2;                       /* natural scrolling, scroll tab */
    if (section == SecAbout) return 4;                          /* version, developer, source code, BTstack credit */
    return 1;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section {
    if (section == SecBluetooth) return @"Bluetooth";
    if (section == SecMedia) return @"Media remote";
    if (section == SecTrackpad) return @"Trackpad";
    if (section == SecAbout) return @"About";
    return @"Interface";
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    if (section == SecMedia)
        return @"OK button: Select works like a real TV remote (picks the highlighted keyboard suggestion); use Enter only if your TV ignores Select.";
    if (section == SecTrackpad)
        return @"Scroll tab: a strip along the left edge of the trackpad. Drag it up or down to scroll; it fades out when not touched.";
    if (section == SecAbout)
        return @"Bluemote is free software (MIT), made by Daniyal. Bluetooth stack: BTstack by BlueKitchen GmbH.";
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
        UITableViewCellStyle st = (ip.section == SecBluetooth) ? UITableViewCellStyleSubtitle
                                : (ip.section == SecAbout)     ? UITableViewCellStyleValue1
                                : UITableViewCellStyleDefault;
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
    } else if (ip.section == SecAbout) {
        if (ip.row == 0) {
            cell.textLabel.text = @"Version";
            cell.detailTextLabel.text = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        } else if (ip.row == 1) {
            cell.textLabel.text = @"Developer";
            cell.detailTextLabel.text = @"Daniyal";
        } else {
            cell.textLabel.text = (ip.row == 2) ? @"Source code" : @"Bluetooth stack";
            cell.detailTextLabel.text = (ip.row == 2) ? @"GitHub" : @"BTstack";
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if (ip.section == SecInterface) {
        cell.textLabel.text = @"Show info (i) button";
        cell.accessoryView = [self switchOn:BTInfoButtonEnabled() tag:TagShowInfo];
    } else if (ip.row == 0) {
        cell.textLabel.text = @"Natural scrolling";
        cell.accessoryView = [self switchOn:[d boolForKey:kPrefNaturalScroll] tag:TagNatural];
    } else {
        cell.textLabel.text = @"Scroll tab";
        cell.accessoryView = [self switchOn:BTScrollTabEnabled() tag:TagScrollTab];
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == SecAbout) {
        NSString *u = (ip.row == 2) ? @"https://github.com/shafqatautosupply-sketch/bluemote" : ((ip.row == 3) ? @"https://github.com/bluekitchen/btstack" : nil);
        if (u) [[UIApplication sharedApplication] openURL:[NSURL URLWithString:u]];
        return;
    }
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
    else if (sw.tag == TagScrollTab) [d setBool:sw.on forKey:kPrefScrollTab];
}

@end
