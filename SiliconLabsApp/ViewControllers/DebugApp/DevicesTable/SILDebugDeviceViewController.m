//
//  SILDebugViewController.m
//  SiliconLabsApp
//
//  Created by Eric Peterson on 9/30/15.
//  Copyright © 2015 SiliconLabs. All rights reserved.
//

#import "SILApp.h"
#import "SILCentralManager.h"
#import "SILDebugDeviceViewController.h"
#import "SILDebugDeviceTableViewCell.h"
#import "SILDebugHeaderView.h"
#import "SILDiscoveredPeripheral.h"
#import "SILRSSIMeasurementTable.h"
#import "UIColor+SILColors.h"
#import "SILDebugServicesViewController.h"
#import "SILDebugAdvDetailsViewController.h"
#import "SILDebugAdvDetailsCollectionView.h"
#import "SILDebugAdvDetailCollectionViewCell.h"
#import "SILAdvertisementDataModel.h"
#import "SILDiscoveredPeripheralDisplayDataViewModel.h"
#import "UIView+NibInitable.h"
#import <WYPopoverController/WYPopoverController.h>
#import "WYPopoverController+SILHelpers.h"
#import "SILAlertBarView.h"
#import "UITableViewCell+SILHelpers.h"
#import "SILActivityBarViewController.h"
#import "UIViewController+Containment.h"
#import <PureLayout/PureLayout.h>
#import "SILDiscoveredPeripheralDisplayData.h"
#import "SILAdvertisementDataViewModel.h"

const float kScanInterval = 15.0f;
const float kTableRefreshInterval = 2.0f;
static NSInteger const kTableViewEdgePadding = 36;

@interface SILDebugDeviceViewController () <UITableViewDataSource, UITableViewDelegate, CBPeripheralDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, DebugDeviceCellDelegate, SILDebugPopoverViewControllerDelegate, WYPopoverControllerDelegate, SILActivityBarViewControllerDelegate>

@property (weak, nonatomic) IBOutlet SILAlertBarView *failedConnectionAlertBarView;
@property (weak, nonatomic) IBOutlet UIView *activityBarViewControllerContainer;
@property (weak, nonatomic) IBOutlet UILabel *backgroundMessageLabel;
@property (weak, nonatomic) IBOutlet UILabel *backgroundStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *failedConnectionLabel;
@property (weak, nonatomic) IBOutlet UITableView *devicesTableView;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImageView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *failedConnectionBarHideConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *failedConnectionBarRevealConstraint;

@property (strong, nonatomic) SILDebugDeviceTableViewCell *sizingTableCell;
@property (strong, nonatomic) SILDebugAdvDetailCollectionViewCell *sizingCollectionCell;

@property (nonatomic) BOOL isConnecting;
@property (nonatomic) BOOL isAnimatingFailedBar;
@property (nonatomic) BOOL isObserving;
@property (strong, nonatomic) CBPeripheral *connectedPeripheral;
@property (strong, nonatomic) NSArray *discoveredPeripherals;
@property (strong, nonatomic) NSArray *displayPeripheralViewModels;
@property (strong, nonatomic) NSTimer *scanTimer;
@property (strong, nonatomic) NSTimer *tableRefreshTimer;
@property (strong, nonatomic) NSIndexPath *connectingCellIndexPath;
@property (strong, nonatomic) SILCentralManager *centralManager;
@property (strong, nonatomic) WYPopoverController *peripheralPopoverController;
@property (strong, nonatomic) SILActivityBarViewController *activityBarViewController;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *devicesTableViewLeadingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *devicesTableViewTrailingConstraint;

@end

@implementation SILDebugDeviceViewController

#pragma mark - UIViewController 

- (void)viewDidLoad {
    [super viewDidLoad];
    [self registerNibs];
    [self setupActivityBar];
    [self setupCentralManager];
    [self setupDeviceTable];
    [self setupNavigationBar];
    [self setupBackgroundForScanning:YES];
    [self setUpDevicesTableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self scanForInterval:kScanInterval];
    [self registerForBluetoothControllerNotifications];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self unregisterForBluetoothControllerNotifications];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.connectedPeripheral) {
        NSString *message = [NSString stringWithFormat:@"Disconnected from %@", self.connectedPeripheral.name];
        [self.failedConnectionAlertBarView revealAlertBarWithMessage:message revealTime:0.4f displayTime:3.0f];
    }
    self.connectedPeripheral = nil;
}

#pragma mark - Setup

- (void)registerNibs {
    NSString *cellClassString = NSStringFromClass([SILDebugDeviceTableViewCell class]);
    [self.devicesTableView registerNib:[UINib nibWithNibName:cellClassString bundle:nil] forCellReuseIdentifier:cellClassString];
}

- (void)setupCentralManager {
    self.centralManager = [[SILCentralManager alloc] initWithServiceUUIDs:@[]];
}

- (void)setupDeviceTable {
    self.devicesTableView.rowHeight = UITableViewAutomaticDimension;
    self.devicesTableView.estimatedRowHeight = 150;
    self.devicesTableView.sectionHeaderHeight = 40;
    self.devicesTableView.hidden = YES;
    
    NSString *tableCellClassName = NSStringFromClass([SILDebugDeviceTableViewCell class]);
    self.sizingTableCell = (SILDebugDeviceTableViewCell *)[self.view initWithNibNamed:tableCellClassName];
    
    
    NSString *collectionCellClassName = NSStringFromClass([SILDebugAdvDetailCollectionViewCell class]);
    self.sizingCollectionCell = (SILDebugAdvDetailCollectionViewCell *)[self.view initWithNibNamed:collectionCellClassName];
}

- (void)setupNavigationBar {
    self.title = self.app.title;
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@" "
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self.navigationController
                                                                            action:@selector(popNavigationItemAnimated:)];
}

- (void)setUpDevicesTableView {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.devicesTableViewLeadingConstraint.constant = kTableViewEdgePadding;
        self.devicesTableViewTrailingConstraint.constant = kTableViewEdgePadding;
    } else {
        self.devicesTableViewLeadingConstraint.constant = 0;
        self.devicesTableViewTrailingConstraint.constant = 0;
    }
    self.devicesTableView.backgroundColor = [UIColor sil_bgGreyColor];
}

- (void)setupActivityBar {
    self.activityBarViewController = [[SILActivityBarViewController alloc] init];
    self.activityBarViewController.delegate = self;
    [self ip_addChildViewController:self.activityBarViewController toView:self.activityBarViewControllerContainer];
    [self.activityBarViewController.view autoPinEdgesToSuperviewEdges];
    [self.failedConnectionAlertBarView configureLabel:self.failedConnectionLabel revealConstraint:self.failedConnectionBarRevealConstraint hideConstraint:self.failedConnectionBarHideConstraint];
}

- (void)setupBackgroundForScanning:(BOOL)scanning {
    NSString *backgroundMessage = scanning ? @"Looking for nearby devices..." : @"No devices found";
    NSString *imageName = scanning ? @"debug_scanning" : @"debug_not_found";
    self.backgroundMessageLabel.text = backgroundMessage;
    self.backgroundImageView.image = [UIImage imageNamed:imageName];
    self.backgroundStatusLabel.hidden = scanning;
}

#pragma mark - Notifications

// TODO: Move this to a category.
- (void)registerForBluetoothControllerNotifications {
    if (!self.isObserving) {
        self.isObserving = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didConnectPeripheralNotifcation:)
                                                     name:SILCentralManagerDidConnectPeripheralNotification
                                                   object:self.centralManager];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didDisconnectPeripheralNotification:)
                                                     name:SILCentralManagerDidDisconnectPeripheralNotification
                                                   object:self.centralManager];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didFailToConnectPeripheralNotification:)
                                                     name:SILCentralManagerDidFailToConnectPeripheralNotification
                                                   object:self.centralManager];

    }
}

- (void)unregisterForBluetoothControllerNotifications {
    if (self.isObserving) {
        self.isObserving = NO;
        [self.centralManager removeScanForPeripheralsObserver:self];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:SILCentralManagerDidConnectPeripheralNotification
                                                      object:self.centralManager];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:SILCentralManagerDidDisconnectPeripheralNotification
                                                      object:self.centralManager];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:SILCentralManagerDidFailToConnectPeripheralNotification
                                                      object:self.centralManager];
    }
}

#pragma mark - Notifcation Methods

- (void)didConnectPeripheralNotifcation:(NSNotification *)notification {
    [self.centralManager removeScanForPeripheralsObserver:self];
    self.connectedPeripheral = notification.userInfo[SILCentralManagerPeripheralKey];
    SILDebugServicesViewController *servicesViewController = [[SILDebugServicesViewController alloc] init];
    servicesViewController.peripheral = self.connectedPeripheral;
    servicesViewController.centralManager = self.centralManager;
    self.isConnecting = NO;
    [self updateCellsWithConnecting];
    [self.activityBarViewController configureActivityBarWithState:SILActivityBarStateResting];
    [self removeUnfiredTimers];
    [self.navigationController pushViewController:servicesViewController animated:YES];
}

- (void)didDisconnectPeripheralNotification:(NSNotification *)notification {
    self.isConnecting = NO;
    [self updateCellsWithConnecting];
}

- (void)didFailToConnectPeripheralNotification:(NSNotification *)notification {
    NSDictionary *notificationInfo = notification.userInfo;
    CBPeripheral *failedConnectionPeripheral = notificationInfo[SILCentralManagerPeripheralKey];
    self.isConnecting = NO;
    [self updateCellsWithConnecting];
    [self revealFailedConnectionBar:failedConnectionPeripheral];
}

#pragma mark - Scanning

- (void)scanForInterval:(float)interval {
    [self.centralManager addScanForPeripheralsObserver:self selector:@selector(didReceiveScanForPeripheralChange)];
    [self.activityBarViewController scanningAnimationWithMessage:@"Stop Scanning"];
    self.activityBarViewController.allowsStopActivity = YES;
    self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                      target:self
                                                    selector:@selector(scanIntervalTimerFired)
                                                    userInfo:nil
                                                     repeats:NO];
    self.tableRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:kTableRefreshInterval
                                                              target:self
                                                            selector:@selector(tableRefreshTimerFired)
                                                            userInfo:nil
                                                             repeats:YES];
    self.devicesTableView.hidden = YES;
    [self setupBackgroundForScanning:YES];
}

- (void)scanIntervalTimerFired {
    [self stopScanningForDevices];
}

- (void)stopScanningForDevices {
    [self.centralManager removeScanForPeripheralsObserver:self];
    [self removeUnfiredTimers];
    [self.activityBarViewController configureActivityBarWithState:SILActivityBarStateResting];
    self.activityBarViewController.allowsStopActivity = NO;
    if (self.displayPeripheralViewModels == 0) {
        [self setupBackgroundForScanning:NO];
    }
    self.discoveredPeripherals = self.centralManager.discoveredPeripherals;
    [self refreshTable];
}

- (void)tableRefreshTimerFired {
    if (!self.isConnecting && self.discoveredPeripherals.count > 0) {
        self.devicesTableView.hidden = NO;
        [self refreshTable];
    }
}

- (void)refreshTable {
    [self displayPeripheralModelsFromDiscovered];
    [self.devicesTableView reloadData];
    [self workaroundHeaderJumpingIssue];
}

- (void)workaroundHeaderJumpingIssue {
    // This is a workaround for the header jumping on a timer fire.
    // Reproduction case without this fix (It helps to increase the scan intervals):
    // 1. Start a scan
    // 2. After any timer fires scroll the table view down any amount.
    // 3. After the next timer fires observe the header view has shifted down.
    // There is no apparent frame change happening here and this fix seems to workaround that issue.
    [self.devicesTableView layoutSubviews];
}

- (void)didReceiveScanForPeripheralChange {
    self.discoveredPeripherals = self.centralManager.discoveredPeripherals;
}

- (void)displayPeripheralModelsFromDiscovered {
    NSMutableArray *peripheralViewModels = [[NSMutableArray alloc] init];
    NSMutableArray *namedViewModels = [NSMutableArray new];
    NSMutableArray *unnamedViewModels = [NSMutableArray new];
    for (SILDiscoveredPeripheral *peripheral in self.discoveredPeripherals) {
        if ([self.centralManager canConnectToDiscoveredPeripheral:peripheral]) {
            SILDiscoveredPeripheralDisplayData *discoveredPeripheralDisplayData = [[SILDiscoveredPeripheralDisplayData alloc] initWithDiscoveredPeripheral:peripheral];
            SILDiscoveredPeripheralDisplayDataViewModel *peripheralViewModel = [[SILDiscoveredPeripheralDisplayDataViewModel alloc] initWithDiscoveredPeripheralDisplayData:discoveredPeripheralDisplayData];
            if (peripheral.advertisedLocalName) {
                [namedViewModels addObject:peripheralViewModel];
            } else {
                [unnamedViewModels addObject:peripheralViewModel];
            }
        }
    }
    
    NSArray *descriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"discoveredPeripheralDisplayData.discoveredPeripheral.RSSIMeasurementTable.lastRSSIMeasurement" ascending:NO]];
    [peripheralViewModels addObjectsFromArray:namedViewModels];
    [peripheralViewModels addObjectsFromArray:unnamedViewModels];
    [peripheralViewModels sortUsingDescriptors:descriptors];
    self.displayPeripheralViewModels = [peripheralViewModels copy];
}

- (void)removeUnfiredTimers {
    [self removeTimer:self.scanTimer];
    [self removeTimer:self.tableRefreshTimer];
}

- (void)removeTimer:(NSTimer *)timer {
    if (timer) {
        [timer invalidate];
        timer = nil;
    }
}

#pragma mark - Connecting

- (void)updateCellsWithConnecting {
    if (!self.isConnecting) {
        self.connectingCellIndexPath = nil;
        [self.activityBarViewController configureActivityBarWithState:SILActivityBarStateResting];
    }
    
    [self.devicesTableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayPeripheralViewModels.count;
}

#pragma mark - UITableViewDelegate

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SILDebugDeviceTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([SILDebugDeviceTableViewCell class]) forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    SILDiscoveredPeripheralDisplayDataViewModel *discoveredPeripheralViewModel = self.displayPeripheralViewModels[indexPath.row];
    [self configureTableViewCell:cell withDiscoveredPeripheral:discoveredPeripheralViewModel.discoveredPeripheralDisplayData.discoveredPeripheral atIndexPath:indexPath];
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    SILDebugHeaderView *headerView = (SILDebugHeaderView *)[self.view initWithNibNamed:NSStringFromClass([SILDebugHeaderView class])];
    headerView.headerLabel.text = @"DEVICES";
    return headerView;
}

//Necessary for iOS7
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    SILDiscoveredPeripheralDisplayDataViewModel *discoveredPeripheralViewModel = self.displayPeripheralViewModels[indexPath.row];
    [self configureTableViewCell:self.sizingTableCell withDiscoveredPeripheral:discoveredPeripheralViewModel.discoveredPeripheralDisplayData.discoveredPeripheral atIndexPath:indexPath];
    return [self.sizingTableCell autoLayoutHeight];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self detailsForCollectionView:collectionView].count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SILAdvertisementDataViewModel* deviceDetail = [self detailsForCollectionView:collectionView][indexPath.row];
    SILDebugAdvDetailCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([SILDebugAdvDetailCollectionViewCell class]) forIndexPath:indexPath];
    return [self configureCollectionViewCell:cell forCollectionView:collectionView forDetail:deviceDetail atIndexPath:indexPath];
}

#pragma mark - UICollectionViewFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    SILAdvertisementDataViewModel* deviceDetail = [self detailsForCollectionView:collectionView][indexPath.row];
    UICollectionViewCell *deviceCellCollectionCell = [self configureCollectionViewCell:self.sizingCollectionCell forCollectionView:collectionView forDetail:deviceDetail atIndexPath:indexPath];
    CGSize collectionCellSize = [deviceCellCollectionCell systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    return collectionCellSize;
}

#pragma mark - Collection View Helpers

- (NSArray *)detailsForCollectionView:(UICollectionView *)collectionView {
    SILDebugAdvDetailsCollectionView *detailsCollectionView = (SILDebugAdvDetailsCollectionView *)collectionView;
    SILDiscoveredPeripheralDisplayDataViewModel *deviceViewModel = self.displayPeripheralViewModels[detailsCollectionView.parentIndexPath.row];
    return deviceViewModel.advertisementDataViewModelsForDevicesTable;
}

#pragma mark - DebugDeviceCellDelegate

- (void)displayAdverisementDetails:(UITableViewCell *)cell {
    NSIndexPath *selectedIndexPath = [self.devicesTableView indexPathForCell:cell];
    if (selectedIndexPath.row < self.displayPeripheralViewModels.count) {
        SILDiscoveredPeripheralDisplayDataViewModel *selectedPeripheralViewModel = self.displayPeripheralViewModels[selectedIndexPath.row];
        SILDebugAdvDetailsViewController *advDetailsViewController = [[SILDebugAdvDetailsViewController alloc] initWithPeripheralViewModel:selectedPeripheralViewModel];
        advDetailsViewController.popoverDelegate = self;
        
        self.peripheralPopoverController = [WYPopoverController sil_presentCenterPopoverWithContentViewController:advDetailsViewController
                                                                                         presentingViewController:self
                                                                                                         delegate:self
                                                                                                         animated:YES];
    }
}

- (void)didTapToConnect:(UITableViewCell *)cell {
    NSIndexPath *indexPath = [self.devicesTableView indexPathForCell:cell];
    SILDiscoveredPeripheralDisplayDataViewModel *selectedPeripheralViewModel = self.displayPeripheralViewModels[indexPath.row];
    if (selectedPeripheralViewModel.discoveredPeripheralDisplayData.discoveredPeripheral.isConnectable) {
        if ([self.centralManager canConnectToDiscoveredPeripheral:selectedPeripheralViewModel.discoveredPeripheralDisplayData.discoveredPeripheral]) {
            [self.centralManager connectToDiscoveredPeripheral:selectedPeripheralViewModel.discoveredPeripheralDisplayData.discoveredPeripheral];
            self.connectingCellIndexPath = indexPath;
            SILDebugDeviceTableViewCell *selectedPeripheralCell = [self.devicesTableView cellForRowAtIndexPath:self.connectingCellIndexPath];
            [selectedPeripheralCell startConnectionAnimation];
            self.isConnecting = YES;
            [self.activityBarViewController connectingAnimationWithMessage:@"Connecting..."];
            [self updateCellsWithConnecting];
        }
    }
}

#pragma mark - SILPopoverViewControllerDelegate

- (void)didClosePopoverViewController:(SILDebugPopoverViewController *)popoverViewController {
    [self.peripheralPopoverController dismissPopoverAnimated:YES completion:^{
        self.peripheralPopoverController = nil;
    }];
}

#pragma mark - WYPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(WYPopoverController *)popoverController {
    [self.peripheralPopoverController dismissPopoverAnimated:YES completion:nil];
    self.peripheralPopoverController = nil;
}

#pragma mark - SILActivityBarViewControllerDelegate

- (void)activityBarViewControllerDidTapActivityButton:(SILActivityBarViewController *)controller {
    [self.centralManager removeAllDiscoveredPeripherals];
    self.displayPeripheralViewModels = nil;
    [self scanForInterval:kScanInterval];
    [self.devicesTableView reloadData];
}

- (void)activityBarViewControllerDidTapStopActivityButton:(SILActivityBarViewController *)controller {
    [self stopScanningForDevices];
}

#pragma mark - Configure Cells

- (void)configureTableViewCell:(SILDebugDeviceTableViewCell *)cell withDiscoveredPeripheral:(SILDiscoveredPeripheral *)discoveredPeripheral atIndexPath:(NSIndexPath *)indexPath {
    NSString *deviceName = discoveredPeripheral.advertisedLocalName ?: @"Unknown";
    NSString *rssi = [discoveredPeripheral.RSSIMeasurementTable.lastRSSIMeasurement stringValue];
    NSString *deviceUUID = discoveredPeripheral.peripheral.identifier.UUIDString;
    cell.displayNameLabel.text = deviceName;
    cell.rssiLabel.text = rssi;
    cell.uuidLabel.text = deviceUUID;
    cell.delegate = self;
    
    if ([indexPath isEqual:self.connectingCellIndexPath]) {
        [cell startConnectionAnimation];
    } else {
        [cell stopConnectionAnimation];
    }
    
    BOOL enabled = !self.connectingCellIndexPath || [indexPath isEqual:self.connectingCellIndexPath];
    [cell configureAsOwner:self withIndexPath:indexPath];
    [cell configureAsEnabled:enabled connectable:discoveredPeripheral.isConnectable];
    [cell revealCollectionView];
}

- (UICollectionViewCell *)configureCollectionViewCell:(SILDebugAdvDetailCollectionViewCell *)cell
                      forCollectionView:(UICollectionView *)collectionView
                              forDetail:(SILAdvertisementDataViewModel *)detail
                            atIndexPath:(NSIndexPath *)indexPath {
    cell.infoLabel.text = detail.valueString;
    cell.infoNameLabel.text = detail.typeString;
    return cell;
}

- (void)revealFailedConnectionBar:(CBPeripheral *)failedPeripheral {
    NSString *failedMessage = [NSString stringWithFormat:(@"Failed connecting to %@"), failedPeripheral.name ?: @"Unknown"];
    [self.failedConnectionAlertBarView revealAlertBarWithMessage:failedMessage revealTime:0.4f displayTime:5.0f];
}

#pragma mark - Dealloc

- (void)dealloc {
    [self removeUnfiredTimers];
}

@end
