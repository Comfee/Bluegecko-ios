//
//  SILRetailBeaconAppViewController.m
//  SiliconLabsApp
//
//  Created by Colden Prime on 1/20/15.
//  Copyright (c) 2015 SiliconLabs. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>
#import "SILRetailBeaconAppViewController.h"
#import "SILApp.h"
#import "SILBeacon.h"
#import "SILBeaconRegistry.h"
#import "SILBeaconRegistryEntry.h"
#import "SILBeaconRegistryEntryViewModel.h"
#import "SILRSSIMeasurementTable.h"
#import "SILSettings.h"
#import "UIView+SILAnimations.h"
#import "SILBeaconViewModel.h"
#import "SILBeaconRegistryEntryCell.h"
#import "UITableViewCell+SILHelpers.h"
#import "SILDoubleKeyDictionaryPair.h"
#import "SiliconLabsApp-Swift.h"

#define IS_IOS_8_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)

CGFloat const SILRetailBeaconAppRefreshRate = 2.0;

CGFloat const kIBeaconMajorNumber = 34987.0f;
CGFloat const kIBeaconMinorNumber = 1025.0f;
CGFloat const kAltBeaconMfgId = 0x0047;

CGFloat const kBeaconListTableViewCellRowHeight = 80.0;

NSString * const kIBeaconUUIDString = @"E2C56DB5-DFFB-48D2-B060-D0F5A71096E0";
NSString * const kAltBeaconUUIDString = @"511AB500511AB500511AB500511AB500";
NSString * const kIBeaconIdentifier = @"com.silabs.retailbeacon";

@interface SILRetailBeaconAppViewController () <CBCentralManagerDelegate, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate, EddystoneScannerDelegate>

@property (nonatomic, strong) SILBeaconRegistry *beaconRegistry;
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CLBeaconRegion *beaconRegion;
@property (nonatomic, strong) CLLocationManager *locationManager;

@property (nonatomic, assign) BOOL isScanning;
@property (nonatomic, strong) NSTimer *reloadDataTimer;
@property (nonatomic, strong) SILBeaconRegistryEntryCell *sizingRegistryEntryCell;

@property (weak, nonatomic) IBOutlet UIView *loadingView;
@property (weak, nonatomic) IBOutlet UILabel *bottomScanningLabel;
@property (weak, nonatomic) IBOutlet UITableView *beaconListTableView;
@property (weak, nonatomic) IBOutlet UIImageView *loadingImageView;
@property (weak, nonatomic) IBOutlet UIImageView *bottomScanningImageView;
@property (strong, nonatomic) EddystoneScanner *eddystoneScanner;

@end

@implementation SILRetailBeaconAppViewController

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = self.app.title;
    self.beaconRegistry = [[SILBeaconRegistry alloc] init];
    [self startScanningImages];
    
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                               queue:nil];
    self.eddystoneScanner = [[EddystoneScanner alloc] init];
    self.eddystoneScanner.delegate = self;
    [self setUpBeaconMonitoring];
    [self setUpTable];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self startTimers];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self stopTimers];
}

- (void)dealloc {
    [self.reloadDataTimer invalidate];
}

#pragma mark - Set Up

- (void)setUpBeaconMonitoring {
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    NSUUID *iBeaconUUID = [[NSUUID alloc] initWithUUIDString:kIBeaconUUIDString];
    
    self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:iBeaconUUID major:kIBeaconMajorNumber minor:kIBeaconMinorNumber identifier:kIBeaconIdentifier];
    if (IS_IOS_8_OR_LATER) {
        [self.locationManager requestAlwaysAuthorization];
    }
    [self.locationManager startRangingBeaconsInRegion:self.beaconRegion];
}

- (void)setUpTable {
    NSString *beaconRegistryEntryCellClassString = NSStringFromClass([SILBeaconRegistryEntryCell class]);
    [self.beaconListTableView registerNib:[UINib nibWithNibName:beaconRegistryEntryCellClassString bundle:nil] forCellReuseIdentifier:beaconRegistryEntryCellClassString];
    self.sizingRegistryEntryCell = [[[UINib nibWithNibName:beaconRegistryEntryCellClassString bundle:nil] instantiateWithOwner:nil options:nil] firstObject];
    
    self.beaconListTableView.rowHeight = UITableViewAutomaticDimension;
    self.beaconListTableView.estimatedRowHeight = kBeaconListTableViewCellRowHeight;
}

#pragma mark - Configure

- (SILBeaconRegistryEntryViewModel *)beaconRegistryEntryViewModelForEntry:(SILBeaconRegistryEntry *)entry {
    return [[SILBeaconRegistryEntryViewModel alloc] initWithBeaconRegistryEntry:entry];
}

- (void)updateBeaconList {
    [self.beaconListTableView reloadData];
}

- (void)configureCell:(SILBeaconRegistryEntryCell *)registryEntryCell forIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = indexPath.row;
    if (row == 0) {
        registryEntryCell.beaconSeparatorView.hidden = true;
    }
    
    NSArray* entries = [self.beaconRegistry beaconRegistryEntries];
    if (row < entries.count) {
        SILBeaconRegistryEntry *entry = entries[row];
        SILBeaconRegistryEntryViewModel *entryViewModel = [self beaconRegistryEntryViewModelForEntry:entry];
        [registryEntryCell configureWithViewModel:entryViewModel];
    }
    [registryEntryCell setNeedsLayout];
    [registryEntryCell layoutIfNeeded];
}

- (void)reloadData {
    BOOL beaconFound = [self.beaconRegistry beaconRegistryEntries].count > 0;
    
    if (beaconFound) {
        self.loadingView.alpha = 0.0;
        [self updateBeaconList];
    } else {
        self.loadingView.alpha = 1.0;
    }
}

- (void)startScanningImages {
    [self.loadingView.superview bringSubviewToFront:self.loadingView];
    [UIView addContinuousRotationAnimationToLayer:self.loadingImageView.layer withFullRotationDuration:2 forKey:@"rotationAnimation"];
    [UIView addContinuousRotationAnimationToLayer:self.bottomScanningImageView.layer withFullRotationDuration:2 forKey:@"rotationAnimation"];
}

#pragma mark - ReloadDataTimer

- (void)startTimers {
    [self.reloadDataTimer invalidate];
    self.reloadDataTimer = [NSTimer scheduledTimerWithTimeInterval:SILRetailBeaconAppRefreshRate
                                                            target:self
                                                          selector:@selector(reloadData)
                                                          userInfo:nil
                                                           repeats:YES];
}

- (void)stopTimers {
    [self.reloadDataTimer invalidate];
    self.reloadDataTimer = nil;
}

#pragma mark - Scanning

- (void)startScanning {
    if (!self.isScanning) {
        self.isScanning = YES;
        [self.centralManager scanForPeripheralsWithServices:nil
                                                    options:@{
                                                              CBCentralManagerScanOptionAllowDuplicatesKey : @YES,
                                                              }];
        [self.eddystoneScanner scanForEddystoneBeacons];
    }
}

- (void)stopScanning {
    if (self.isScanning) {
        self.isScanning = NO;
        [self.centralManager stopScan];
        [self.eddystoneScanner stopScanningForEddystoneBeacons];
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if ([central state] == CBCentralManagerStatePoweredOn) {
        [self startScanning];
    } else {
        [self stopScanning];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    if (advertisementData[CBAdvertisementDataManufacturerDataKey] != nil) {
        NSString *name = peripheral.name;
        [self.beaconRegistry updateWithAdvertisment:advertisementData name:name RSSI:RSSI];
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    [self.locationManager startRangingBeaconsInRegion:self.beaconRegion];
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    [self.locationManager stopRangingBeaconsInRegion:self.beaconRegion];
    if ([self.beaconRegion isEqual:region]) {
        [self.beaconRegistry removeIBeaconEntriesWithUUID:self.beaconRegion.proximityUUID];
    }
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray<CLBeacon *> *)beacons inRegion:(CLBeaconRegion *)region {
    for (CLBeacon *foundBeacon in beacons) {
        [self.beaconRegistry updateWithIBeacon:foundBeacon];
    }
}

#pragma mark - UITableViewDataSourceDelegate

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.beaconRegistry beaconRegistryEntries].count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    SILBeaconRegistryEntryCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([SILBeaconRegistryEntryCell class]) forIndexPath:indexPath];
    [self configureCell:cell forIndexPath:indexPath];
    return cell;
}

#pragma mark - UITableViewDelegate

//Included for compat with iOS7
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    [self configureCell:self.sizingRegistryEntryCell forIndexPath:indexPath];
    return [self.sizingRegistryEntryCell autoLayoutHeight];
}

#pragma mark - EddystoneScannerDelegate

- (void)eddystoneScanner:(EddystoneScanner *)eddystoneScanner didFindBeacons:(NSArray<EddystoneBeacon *> *)beacons {
    for (EddystoneBeacon *foundBeacon in beacons) {
        [self.beaconRegistry updateWithEddystoneBeacon:foundBeacon];
    }
}

@end
