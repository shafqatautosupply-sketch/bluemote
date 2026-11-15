#import "PairViewController.h"
#import "UIHelpers.h"

#define TAG_RENAME 1
#define TAG_FORGET_ALL 2

enum { SecStatus = 0, SecDevices = 1, SecPairing = 2 };
enum { RowPair = 0, RowDisconnect = 1, RowPasskey = 2, RowForgetAll = 3 };

@implementation PairViewController

- (id)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Devices";
        titleView = [[StatusTitleView alloc] initWithTitle:@"Devices"];
    }
    return self;
}

- (void)dealloc {
    [timer invalidate];
    [timer release];
    [titleView release];
    [lastSignature release];
    [selectedAddr release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.titleView = titleView;
}

- (void)setStatus:(NSString *)status connected:(BOOL)connected {
    [titleView setStatus:status connected:connected];
}

- (void)tick {
    BOOL connected;
    NSString *text = BTStatusText(&connected);
    [titleView setStatus:text connected:connected];
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self tick];
    [timer invalidate];
    [timer release];
    timer = [[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(tick) userInfo:nil repeats:YES] retain];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [timer invalidate];
    [timer release];
    timer = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return o == UIInterfaceOrientationPortrait; }
- (BOOL)shouldAutorotate { return NO; }
- (NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }

/* ---------------------------------------------------------------- data */

- (NSString *)statusText {
    return [NSString stringWithUTF8String:bluemote_status()];
}

- (NSString *)addrAtIndex:(int)i {
    return [NSString stringWithUTF8String:bluemote_saved_addr(i)];
}

- (int)indexForAddr:(NSString *)addr {
    int n = bluemote_saved_count();
    for (int i = 0; i < n; i++) if ([[self addrAtIndex:i] isEqualToString:addr]) return i;
    return -1;
}

/* reload only when something visible changed (the table is refreshed twice a second) */
- (void)refresh {
    NSMutableString *sig = [NSMutableString string];
    [sig appendFormat:@"%@|%d|%d|%@|", [self statusText], bluemote_pairing_mode(), bluemote_io_mode(),
        [NSString stringWithUTF8String:bluemote_connected_addr()]];
    int n = bluemote_saved_count();
    for (int i = 0; i < n; i++) {
        NSString *a = [self addrAtIndex:i];
        [sig appendFormat:@"%@=%@;", a, BTDeviceDisplayName(a)];
    }
    if (![sig isEqualToString:lastSignature]) {
        [lastSignature release];
        lastSignature = [sig copy];
        [self.tableView reloadData];
    }
}

/* ---------------------------------------------------------------- table */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    if (section == SecStatus) return 1;
    if (section == SecDevices) { int n = bluemote_saved_count(); return n > 0 ? n : 1; }
    return 4;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section {
    if (section == SecStatus) return @"Status";
    if (section == SecDevices) return @"Paired devices";
    return @"Pairing";
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    if (section == SecDevices)
        return @"Tap a device to connect, rename or forget it. Only one device is connected at a time.";
    if (section == SecPairing)
        return @"To pair: tap Pair new device, then on the TV open Bluetooth settings, add a device and choose this iPhone. If the TV shows a PIN or passkey, a box opens here.";
    return nil;
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section == SecStatus) {
        CGSize sz = [[self statusText] sizeWithFont:[UIFont boldSystemFontOfSize:17.0f]
                                  constrainedToSize:CGSizeMake(250.0f, 200.0f)
                                      lineBreakMode:NSLineBreakByWordWrapping];
        return MAX(44.0f, sz.height + 24.0f);
    }
    return 44.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    int count = bluemote_saved_count();
    BOOL deviceRow = (ip.section == SecDevices && count > 0);
    BOOL switchRow = (ip.section == SecPairing && ip.row == RowPasskey);
    NSString *ident = deviceRow ? @"dev" : (switchRow ? @"sw" : @"plain");

    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];
    if (!cell) {
        UITableViewCellStyle st = deviceRow ? UITableViewCellStyleSubtitle : UITableViewCellStyleDefault;
        cell = [[[UITableViewCell alloc] initWithStyle:st reuseIdentifier:ident] autorelease];
        if (switchRow) {
            UISwitch *sw = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
            [sw addTarget:self action:@selector(passkeyChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
        }
    }
    cell.accessoryType = deviceRow ? UITableViewCellAccessoryNone : cell.accessoryType;
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.textLabel.textColor = [UIColor blackColor];
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    cell.detailTextLabel.text = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    cell.userInteractionEnabled = YES;

    if (ip.section == SecStatus) {
        BOOL connected = bluemote_is_connected();
        cell.textLabel.text = [self statusText];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.textColor = connected ? [UIColor colorWithRed:0.12f green:0.50f blue:0.12f alpha:1.0f]
                                             : [UIColor colorWithRed:0.72f green:0.42f blue:0.05f alpha:1.0f];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else if (ip.section == SecDevices) {
        if (count == 0) {
            cell.textLabel.text = @"No paired devices yet";
            cell.textLabel.textColor = [UIColor grayColor];
            cell.textLabel.font = [UIFont systemFontOfSize:17.0f];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else {
            NSString *addr = [self addrAtIndex:(int)ip.row];
            NSString *current = [NSString stringWithUTF8String:bluemote_connected_addr()];
            BOOL isCurrent = [addr isEqualToString:current];
            cell.textLabel.text = BTDeviceDisplayName(addr);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@", addr, isCurrent ? @"   \u2022   Connected" : @""];
            cell.detailTextLabel.textColor = isCurrent ? [UIColor colorWithRed:0.12f green:0.50f blue:0.12f alpha:1.0f]
                                                       : [UIColor grayColor];
            cell.accessoryType = isCurrent ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        UIColor *buttonBlue = [UIColor colorWithRed:0.22f green:0.33f blue:0.53f alpha:1.0f];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = buttonBlue;
        cell.accessoryType = UITableViewCellAccessoryNone;
        switch (ip.row) {
            case RowPair:
                cell.textLabel.text = bluemote_pairing_mode() ? @"Cancel pairing mode" : @"Pair new device";
                break;
            case RowDisconnect:
                cell.textLabel.text = @"Disconnect";
                if (!bluemote_is_connected()) {
                    cell.textLabel.textColor = [UIColor lightGrayColor];
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                }
                break;
            case RowPasskey:
                cell.textLabel.text = @"Type the TV's passkey";
                cell.textLabel.textAlignment = NSTextAlignmentLeft;
                cell.textLabel.textColor = [UIColor blackColor];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                ((UISwitch *)cell.accessoryView).on = (bluemote_io_mode() == 2);
                break;
            default:
                cell.textLabel.text = @"Forget all devices";
                cell.textLabel.textColor = [UIColor colorWithRed:0.75f green:0.1f blue:0.1f alpha:1.0f];
                break;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == SecDevices && bluemote_saved_count() > 0) {
        [selectedAddr release];
        selectedAddr = [[self addrAtIndex:(int)ip.row] copy];
        [self showDeviceSheet];
    } else if (ip.section == SecPairing) {
        switch (ip.row) {
            case RowPair:
                bluemote_send(bluemote_pairing_mode() ? "PAIRSTOP" : "PAIR");
                [self performSelector:@selector(refresh) withObject:nil afterDelay:0.2];
                break;
            case RowDisconnect:
                if (bluemote_is_connected()) bluemote_send("DISCONNECT");
                break;
            case RowForgetAll: {
                UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Forget all devices?"
                                                            message:@"All stored pairing keys will be deleted. You will need to pair again."
                                                           delegate:self cancelButtonTitle:@"Cancel"
                                                  otherButtonTitles:@"Forget", nil];
                a.tag = TAG_FORGET_ALL;
                [a show];
                [a release];
                break; }
            default: break;
        }
    }
}

- (void)passkeyChanged:(UISwitch *)sw {
    bluemote_send(sw.on ? "IOCAP 2" : "IOCAP 3");
}

/* ---------------------------------------------------------------- device actions */

- (void)showDeviceSheet {
    NSString *current = [NSString stringWithUTF8String:bluemote_connected_addr()];
    BOOL isCurrent = [selectedAddr isEqualToString:current];
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:BTDeviceDisplayName(selectedAddr)
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:@"Forget"
                                              otherButtonTitles:(isCurrent ? @"Disconnect" : @"Connect"), @"Rename", nil];
    [sheet showInView:self.view.window];
    [sheet release];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)idx {
    NSString *t = [sheet buttonTitleAtIndex:idx];
    int i = [self indexForAddr:selectedAddr];
    if ([t isEqualToString:@"Connect"]) {
        if (i >= 0) bluemote_sendf("CONNECT %d", i);
    } else if ([t isEqualToString:@"Disconnect"]) {
        bluemote_send("DISCONNECT");
    } else if ([t isEqualToString:@"Forget"]) {
        if (i >= 0) bluemote_sendf("FORGETDEV %d", i);
    } else if ([t isEqualToString:@"Rename"]) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Rename device" message:selectedAddr delegate:self
                                          cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
        a.alertViewStyle = UIAlertViewStylePlainTextInput;
        a.tag = TAG_RENAME;
        [a textFieldAtIndex:0].text = BTDeviceDisplayName(selectedAddr);
        [a textFieldAtIndex:0].autocapitalizationType = UITextAutocapitalizationTypeWords;
        [a show];
        [a release];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == [alertView cancelButtonIndex]) return;
    if (alertView.tag == TAG_RENAME) {
        NSString *text = [[[alertView textFieldAtIndex:0] text]
                          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        NSString *key = [@"alias." stringByAppendingString:selectedAddr];
        if ([text length] == 0) [d removeObjectForKey:key];
        else [d setObject:text forKey:key];
        [self refresh];
    } else if (alertView.tag == TAG_FORGET_ALL) {
        bluemote_send("FORGET");
        [self performSelector:@selector(refresh) withObject:nil afterDelay:0.2];
    }
}

@end
