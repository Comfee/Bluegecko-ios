//
//  SILDeviceServicesViewController.m
//  SiliconLabsApp
//
//  Created by Eric Peterson on 10/2/15.
//  Copyright © 2015 SiliconLabs. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "SILCentralManager.h"
#import "SILDebugServicesViewController.h"
#import "SILServiceTableModel.h"
#import "SILCharacteristicTableModel.h"
#import "SILDescriptorTableModel.h"
#import "SILDebugServiceTableViewCell.h"
#import "SILDebugCharacteristicTableViewCell.h"
#import "SILDebugProperty.h"
#import "SILDebugHeaderView.h"
#import "SILDiscoveredPeripheral.h"
#import "UIView+NibInitable.h"
#import "UIColor+SILColors.h"
#import "SILAlertBarView.h"
#import "SILBluetoothModelManager.h"
#import "SILCharacteristicFieldBuilder.h"
#import "SILEnumerationFieldRowModel.h"
#import "SILBitFieldFieldModel.h"
#import "SILBitRowModel.h"
#import "SILValueFieldRowModel.h"
#import "SILDebugCharacteristicValueFieldTableViewCell.h"
#import "SILDebugCharacteristicToggleFieldTableViewCell.h"
#import "SILDebugCharacteristicEnumerationFieldTableViewCell.h"
#import "SILDebugCharacteristicEncodingFieldTableViewCell.h"
#import "SILDebugSpacerTableViewCell.h"
#import <WYPopoverController/WYPopoverController.h>
#import "WYPopoverController+SILHelpers.h"
#import "SILCharacteristicFieldValueResolver.h"
#import "SILDebugCharacteristicEnumerationListViewController.h"
#import "SILDebugCharacteristicEncodingViewController.h"
#import "SILCharacteristicEditEnabler.h"
#import "SILValueFieldEditorViewController.h"
#import "SILEncodingPseudoFieldRowModel.h"
#import "UITableViewCell+SILHelpers.h"
#import "SILActivityBarViewController.h"
#import <Crashlytics/Crashlytics.h>
#import "UIViewController+Containment.h"
#import <PureLayout/PureLayout.h>
#import "CBPeripheral+Services.h"
#import "SILUUIDProvider.h"
#import "SILOTAUICoordinator.h"

static NSInteger const kTableViewEdgePadding = 36;
static NSString * const kSpacerCellIdentifieer = @"spacer";
static NSString * const kOTAButtonTitle = @"OTA";
static NSString * const kUnknownPeripheralName = @"Unknown";
static NSString * const kScanningForPeripheralsMessage = @"Loading...";

static float kOnPriority = 999;
static float kOffPriority = 1;
static float kTableRefreshInterval = 1;

@interface SILDebugServicesViewController () <UITableViewDelegate, UITableViewDataSource, CBPeripheralDelegate, SILDebugPopoverViewControllerDelegate, WYPopoverControllerDelegate, SILCharacteristicEditEnablerDelegate, SILOTAUICoordinatorDelegate>

@property (weak, nonatomic) IBOutlet SILAlertBarView *alertBarView;
@property (weak, nonatomic) IBOutlet UIView *activityBarViewControllerContainer;
@property (strong, nonatomic) NSMutableArray *allServiceModels;
@property (strong, nonatomic) NSArray *modelsToDisplay;
@property (nonatomic) BOOL isUpdatingFirmware;

@property (nonatomic) BOOL tableNeedsRefresh;
@property (strong, nonatomic) NSTimer *tableRefreshTimer;

@property (strong, nonatomic) SILOTAUICoordinator *otaUICoordinator;

@property (weak, nonatomic) IBOutlet UILabel *disconnectedMessageLabel;
@property (weak, nonatomic) IBOutlet UITableView *servicesTableView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *servicesTableViewTrailingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *servicesTableViewLeadingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *servicesTableViewTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *disconnectedBarHideConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *disconnectedBarRevealConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *activityBarViewControllerHideConstraint;
@property (strong, nonatomic) WYPopoverController *popoverController;

@property (strong, nonatomic) SILDebugServiceTableViewCell *sizingServiceCell;
@property (strong, nonatomic) SILDebugCharacteristicTableViewCell *sizingCharacterisiticCell;
@property (strong, nonatomic) SILDebugCharacteristicValueFieldTableViewCell *sizingCharacterisitcValueFieldCell;
@property (strong, nonatomic) SILDebugCharacteristicToggleFieldTableViewCell *sizingCharacteristicToggleCell;
@property (strong, nonatomic) SILDebugCharacteristicEnumerationFieldTableViewCell *sizingCharacteristicEnumerationCell;
@property (strong, nonatomic) SILDebugCharacteristicEncodingFieldTableViewCell *sizingCharacteristicEncodingCell;
@property (strong, nonatomic) SILActivityBarViewController *activityBarViewController;

@end

@implementation SILDebugServicesViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self registerForNotifications];
    [self registerNibsAndSetUpSizing];
    [self setupActivityBarViewController];
    [self setUpServicesTableView];
    [self setUpSubviews];
    [self startServiceSearch];
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
    if (![parent isEqual:self.parentViewController]) {
        [self.centralManager disconnectConnectedPeripheral];
    }
}

#pragma mark - setup

-(void)registerNibsAndSetUpSizing {
    NSString *serviceCellClassString = NSStringFromClass([SILDebugServiceTableViewCell class]);
    [self.servicesTableView registerNib:[UINib nibWithNibName:serviceCellClassString bundle:nil] forCellReuseIdentifier:serviceCellClassString];
    self.sizingServiceCell = (SILDebugServiceTableViewCell *)[self.view initWithNibNamed:serviceCellClassString];
    
    NSString *characteristicCellClassString = NSStringFromClass([SILDebugCharacteristicTableViewCell class]);
    [self.servicesTableView registerNib:[UINib nibWithNibName:characteristicCellClassString bundle:nil] forCellReuseIdentifier:characteristicCellClassString];
    self.sizingCharacterisiticCell = (SILDebugCharacteristicTableViewCell *)[self.view initWithNibNamed:characteristicCellClassString];
    
    NSString *characteristicValueFieldCellClassString = NSStringFromClass([SILDebugCharacteristicValueFieldTableViewCell class]);
    [self.servicesTableView registerNib:[UINib nibWithNibName:characteristicValueFieldCellClassString bundle:nil] forCellReuseIdentifier:characteristicValueFieldCellClassString];
    self.sizingCharacterisitcValueFieldCell = (SILDebugCharacteristicValueFieldTableViewCell *)[self.view initWithNibNamed:characteristicValueFieldCellClassString];
    
    NSString *characteristicToggleFieldCellClassString = NSStringFromClass([SILDebugCharacteristicToggleFieldTableViewCell class]);
    [self.servicesTableView registerNib:[UINib nibWithNibName:characteristicToggleFieldCellClassString bundle:nil] forCellReuseIdentifier:characteristicToggleFieldCellClassString];
    self.sizingCharacteristicToggleCell = (SILDebugCharacteristicToggleFieldTableViewCell *)[self.view initWithNibNamed:characteristicToggleFieldCellClassString];
    
    NSString *characteristicEnumerationFieldCellClassString = NSStringFromClass([SILDebugCharacteristicEnumerationFieldTableViewCell class]);
    [self.servicesTableView registerNib:[UINib nibWithNibName:characteristicEnumerationFieldCellClassString bundle:nil] forCellReuseIdentifier:characteristicEnumerationFieldCellClassString];
    self.sizingCharacteristicEnumerationCell = (SILDebugCharacteristicEnumerationFieldTableViewCell *)[self.view initWithNibNamed:characteristicEnumerationFieldCellClassString];
    
    NSString *characteristicEncodingFieldCellClassString = NSStringFromClass([SILDebugCharacteristicEncodingFieldTableViewCell class]);
    [self.servicesTableView registerNib:[UINib nibWithNibName:characteristicEncodingFieldCellClassString bundle:nil] forCellReuseIdentifier:characteristicEncodingFieldCellClassString];
    self.sizingCharacteristicEncodingCell = (SILDebugCharacteristicEncodingFieldTableViewCell *)[self.view initWithNibNamed:characteristicEncodingFieldCellClassString];
    
    NSString *spacerCellClassString = NSStringFromClass([SILDebugSpacerTableViewCell class]);
    [self.servicesTableView registerNib:[UINib nibWithNibName:spacerCellClassString bundle:nil] forCellReuseIdentifier:spacerCellClassString];
}

- (void)setUpServicesTableView {
    self.servicesTableView.rowHeight = UITableViewAutomaticDimension;
    self.servicesTableView.sectionHeaderHeight = 40;
    self.servicesTableView.hidden = YES;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.servicesTableViewLeadingConstraint.constant = kTableViewEdgePadding;
        self.servicesTableViewTrailingConstraint.constant = kTableViewEdgePadding;
        self.servicesTableView.estimatedRowHeight = 96;
        self.servicesTableViewTopConstraint.constant = kTableViewEdgePadding;
    } else {
        self.servicesTableViewLeadingConstraint.constant = 0;
        self.servicesTableViewTrailingConstraint.constant = 0;
        self.servicesTableViewTopConstraint.constant = 0;
        self.servicesTableView.estimatedRowHeight = 100;
    }
}

- (void)setUpSubviews {
    self.title = self.peripheral.name ?: kUnknownPeripheralName;
    self.activityBarViewControllerHideConstraint.priority = kOffPriority;
    [self.activityBarViewController scanningAnimationWithMessage:kScanningForPeripheralsMessage];
    [self.alertBarView configureLabel:self.disconnectedMessageLabel revealConstraint:self.disconnectedBarRevealConstraint hideConstraint:self.disconnectedBarHideConstraint];
}

- (void)startServiceSearch {
    self.peripheral.delegate = self;
    [self.peripheral discoverServices:nil];
}

- (void)setupActivityBarViewController {
    self.activityBarViewController = [[SILActivityBarViewController alloc] init];
    [self ip_addChildViewController:self.activityBarViewController toView:self.activityBarViewControllerContainer];
    [self.activityBarViewController.view autoPinEdgesToSuperviewEdges];
}

#pragma mark -Lazy Intanstiation

- (NSMutableArray *)allServiceModels {
    if (!_allServiceModels) {
        _allServiceModels = [[NSMutableArray alloc] init];
    }
    return _allServiceModels;
}

- (NSArray *)modelsToDisplay {
    if (!_modelsToDisplay) {
        _modelsToDisplay = [[NSArray alloc] init];
    }
    return _modelsToDisplay;
}

#pragma mark - Actions

- (void)didTapOTABarButtonItem {
    self.isUpdatingFirmware = YES;
    self.otaUICoordinator = [[SILOTAUICoordinator alloc] initWithPeripheral:self.peripheral
                                                             centralManager:self.centralManager
                                                   presentingViewController:self];
    self.otaUICoordinator.delegate = self;
    [self.otaUICoordinator initiateOTAFlow];
}

#pragma mark - SILOTAUICoordinatorDelegate

- (void)otaUICoordinatorDidFishishOTAFlow:(SILOTAUICoordinator *)coordinator {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Activity Bar

- (void)hideActivityBarViewController {
    __weak SILDebugServicesViewController *weakSelf = self;
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.5 animations:^{
        weakSelf.activityBarViewControllerHideConstraint.priority = kOnPriority;
        [weakSelf.view layoutIfNeeded];
        [weakSelf.view updateConstraints];
    }];
}

#pragma mark - Notifications

- (void)registerForNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didDisconnectPeripheralNotifcation:)
                                                 name:SILCentralManagerDidDisconnectPeripheralNotification
                                               object:self.centralManager];
}

#pragma mark - Notification Methods

- (void)didDisconnectPeripheralNotifcation:(NSNotification *)notification {
    if (!self.isUpdatingFirmware) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Table Timer

- (void)startRefreshTimer {
    self.tableRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:kTableRefreshInterval
                                                              target:self
                                                            selector:@selector(tableRefreshTimerFired)
                                                            userInfo:nil
                                                             repeats:YES];
}

- (void)tableRefreshTimerFired {
    if (self.tableNeedsRefresh) {
        [self refreshTable];
    }
    [self removeTimer];
}

- (void)removeTimer {
    if (self.tableRefreshTimer) {
        [self.tableRefreshTimer invalidate];
        self.tableRefreshTimer = nil;
    }
}

#pragma mark - UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.modelsToDisplay.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self configuredCellForIndexPath:indexPath tableView:tableView isSizing:NO];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([[tableView cellForRowAtIndexPath:indexPath] isKindOfClass:[SILDebugCharacteristicTableViewCell class]]) {
        SILCharacteristicTableModel *characteristicModel = self.modelsToDisplay[indexPath.row];
        if ([characteristicModel isUnknown]) {
            [characteristicModel toggleExpansionIfAllowed];
            id<SILGenericAttributeTableCell> cell = [tableView cellForRowAtIndexPath:indexPath];
            [cell expandIfAllowed:characteristicModel.isExpanded];
            [self refreshTable];
            return;
        }
    }
    
    if ([[tableView cellForRowAtIndexPath:indexPath] isKindOfClass:[SILDebugCharacteristicEncodingFieldTableViewCell class]]) {
        SILEncodingPseudoFieldRowModel *model = self.modelsToDisplay[indexPath.row];
        [self displayCharacteristicEncoding:model.parentCharacteristicModel canEdit:model.parentCharacteristicModel.canWrite];
    }
    
    if ([[tableView cellForRowAtIndexPath:indexPath] isKindOfClass:[SILDebugCharacteristicEnumerationFieldTableViewCell class]]) {
        SILEnumerationFieldRowModel *enumerationModel = self.modelsToDisplay[indexPath.row];
        if (enumerationModel.parentCharacteristicModel.canWrite) {
            [self displayEnumerationDetails:enumerationModel];
        }
    }
    
    if ([self.modelsToDisplay[indexPath.row] respondsToSelector:@selector(canExpand)]) {
        id<SILGenericAttributeTableModel> model = self.modelsToDisplay[indexPath.row];
        if ([model canExpand]) {
            [model toggleExpansionIfAllowed];
            id<SILGenericAttributeTableCell> cell = [tableView cellForRowAtIndexPath:indexPath];
            [cell expandIfAllowed:model.isExpanded];
        }
        [self refreshTable];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    SILDebugHeaderView *headerView = (SILDebugHeaderView *)[self.view initWithNibNamed:NSStringFromClass([SILDebugHeaderView class])];
    headerView.headerLabel.text = @"SERVICES";
    return headerView;
}

//Necessary for iOS7
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self configuredCellForIndexPath:indexPath tableView:tableView isSizing:YES];
    return [cell autoLayoutHeight];
}


#pragma mark - Configure Cells

- (SILDebugServiceTableViewCell *)serviceCellWithModel:(SILServiceTableModel *)serviceTableModel forTable:(UITableView *)tableView isSizing:(BOOL)isSizing {
    SILDebugServiceTableViewCell *serviceCell = isSizing ? self.sizingServiceCell : (SILDebugServiceTableViewCell *)[tableView dequeueReusableCellWithIdentifier:NSStringFromClass([SILDebugServiceTableViewCell class])];
    [serviceCell configureWithServiceModel:serviceTableModel];
    return serviceCell;
    
}

- (SILDebugCharacteristicTableViewCell *)characteristicCellWithModel:(SILCharacteristicTableModel *)characteristicTableModel forTable:(UITableView *)tableView isSizing:(BOOL)isSizing {
    SILDebugCharacteristicTableViewCell *characteristicCell = isSizing ? self.sizingCharacterisiticCell : (SILDebugCharacteristicTableViewCell *)[tableView dequeueReusableCellWithIdentifier:NSStringFromClass([SILDebugCharacteristicTableViewCell class])];
    [characteristicCell configureWithCharacteristicModel:characteristicTableModel];
    return characteristicCell;
}

- (SILDebugCharacteristicEnumerationFieldTableViewCell *)enumerationFieldCellWithModel:(SILEnumerationFieldRowModel *)enumerationFieldModel forTable:(UITableView *)tableView isSizing:(BOOL)isSizing {
    SILDebugCharacteristicEnumerationFieldTableViewCell *enumerationFieldCell = isSizing ? self.sizingCharacteristicEnumerationCell : (SILDebugCharacteristicEnumerationFieldTableViewCell *)[tableView dequeueReusableCellWithIdentifier:NSStringFromClass([SILDebugCharacteristicEnumerationFieldTableViewCell class])];
    [enumerationFieldCell configureWithEnumerationModel:enumerationFieldModel];
    return enumerationFieldCell;
}

- (SILDebugCharacteristicEncodingFieldTableViewCell *)encodingFieldCellWithModel:(SILEncodingPseudoFieldRowModel *)encodingFieldModel forTable:(UITableView *)tableView isSizing:(BOOL)isSizing {
    SILDebugCharacteristicEncodingFieldTableViewCell *cell = isSizing ? self.sizingCharacteristicEncodingCell : (SILDebugCharacteristicEncodingFieldTableViewCell *) [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([SILDebugCharacteristicEncodingFieldTableViewCell class])];
    NSData* subjectData = [encodingFieldModel dataForField];
    
    cell.editLabel.hidden = !encodingFieldModel.parentCharacteristicModel.canWrite;
    cell.hexValueLabel.text = [[SILCharacteristicFieldValueResolver sharedResolver] hexStringForData:subjectData];
    cell.asciiValueLabel.text = [[[SILCharacteristicFieldValueResolver sharedResolver] asciiStringForData:subjectData] stringByReplacingOccurrencesOfString:@"\0" withString:@""];
    cell.decimalValueLabel.text = [[SILCharacteristicFieldValueResolver sharedResolver] decimalStringForData:subjectData];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    [cell layoutIfNeeded];
    return cell;
}

- (SILDebugCharacteristicToggleFieldTableViewCell *)toggleFieldCellWithModel:(SILBitRowModel *)toggleFieldModel forTable:(UITableView *)tableView isSizing:(BOOL)isSizing {
    SILDebugCharacteristicToggleFieldTableViewCell *toggleFieldCell = isSizing ? self.sizingCharacteristicToggleCell : (SILDebugCharacteristicToggleFieldTableViewCell *)[tableView dequeueReusableCellWithIdentifier:NSStringFromClass([SILDebugCharacteristicToggleFieldTableViewCell class])];
    [toggleFieldCell configureWithBitRowModel:toggleFieldModel];
    toggleFieldCell.editDelegate = self;
    return toggleFieldCell;
}

- (SILDebugCharacteristicValueFieldTableViewCell *)valueFieldCellWithModel:(SILValueFieldRowModel *)valueFieldModel forTable:(UITableView *)tableView isSizing:(BOOL)isSizing {
    SILDebugCharacteristicValueFieldTableViewCell *valueFieldCell = isSizing ? self.sizingCharacterisitcValueFieldCell : (SILDebugCharacteristicValueFieldTableViewCell *)[tableView dequeueReusableCellWithIdentifier:NSStringFromClass([SILDebugCharacteristicValueFieldTableViewCell class])];
    [valueFieldCell configureWithValueModel:valueFieldModel];
    valueFieldCell.editDelegate = self;
    return valueFieldCell;
}

#pragma mark - SILCharacteristicEditEnablerDelegate

- (void)beginValueEditWithValue:(SILValueFieldRowModel *)valueModel {
    [self displayValueEditor:valueModel];
}

- (void)displayValueEditor:(SILValueFieldRowModel *)valueModel {
    SILValueFieldEditorViewController *valueEditViewController = [[SILValueFieldEditorViewController alloc] initWithValueFieldModel:valueModel];
    valueEditViewController.popoverDelegate = self;
    valueEditViewController.editDelegate = self;
    self.popoverController = [WYPopoverController sil_presentCenterPopoverWithContentViewController:valueEditViewController
                                                                             presentingViewController:self
                                                                                             delegate:self
                                                                                             animated:YES];
}

- (void)displayEnumerationDetails:(SILEnumerationFieldRowModel *)enumerationModel {
    SILDebugCharacteristicEnumerationListViewController *listViewController = [[SILDebugCharacteristicEnumerationListViewController alloc] initWithEnumeration:enumerationModel canEdit:YES];
    listViewController.popoverDelegate = self;
    listViewController.editDelegate = self;
    self.popoverController = [WYPopoverController sil_presentCenterPopoverWithContentViewController:listViewController
                                                                             presentingViewController:self
                                                                                             delegate:self
                                                                                             animated:YES];
}

- (void)displayCharacteristicEncoding:(SILCharacteristicTableModel *)characteristicModel canEdit:(BOOL)canEdit {
    SILDebugCharacteristicEncodingViewController *encodingViewController = [[SILDebugCharacteristicEncodingViewController alloc] initWithCharacteristicTableModel:characteristicModel canEdit:canEdit];
    encodingViewController.popoverDelegate = self;
    encodingViewController.editDelegate = self;
    self.popoverController = [WYPopoverController sil_presentCenterPopoverWithContentViewController:encodingViewController
                                                                             presentingViewController:self
                                                                                             delegate:self
                                                                                             animated:YES];
}

#pragma mark - SILPopoverViewControllerDelegate

- (void)didClosePopoverViewController:(SILDebugPopoverViewController *)popoverViewController {
    [self.popoverController dismissPopoverAnimated:YES completion:^{
        self.popoverController = nil;
    }];
}

- (void)didSaveCharacteristic:(SILCharacteristicTableModel *)characteristicModel withAction:(void (^)(void))saveActionBlock {
    SILCharacteristicTableModel *backupCharacteristic = characteristicModel;
    NSLog(@"Backup data: %@", [backupCharacteristic dataToWrite]);
    saveActionBlock();
    NSLog(@"Writin data: %@", [characteristicModel dataToWrite]);
    if ([characteristicModel dataToWrite]) {
        [characteristicModel writeIfAllowedToPeripheral:self.peripheral];
    }
    NSLog(@"Restoring as backup in case of write failure %@", [backupCharacteristic dataToWrite]);
    characteristicModel = backupCharacteristic;
}

#pragma mark - WYPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(WYPopoverController *)popoverController {
    [self.popoverController dismissPopoverAnimated:YES completion:nil];
    self.popoverController = nil;
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    [self hideActivityBarViewController];
    NSString* title;
    SILDiscoveredPeripheral* discoveredPeripheral = [self.centralManager discoveredPeripheralForPeripheral:self.peripheral];
    if (discoveredPeripheral) {
        title = discoveredPeripheral.advertisedLocalName;
    }
    if (!title) {
        title = self.peripheral.name ?: kUnknownPeripheralName;
    }
    self.title = title;

    self.servicesTableView.hidden = NO;
    for (CBService *service in peripheral.services) {
        [self addOrUpdateModelForService:service];
        [peripheral discoverCharacteristics:nil forService:service];
    }
    [self markTableForUpdate];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *characteristic in service.characteristics) {
        [self addOrUpdateModelForCharacteristic:characteristic forService:service];
        [peripheral readValueForCharacteristic:characteristic];
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        [peripheral discoverDescriptorsForCharacteristic:characteristic];
    }
    [self markTableForUpdate];
    [self configureNavigationItemWithPeripheral:peripheral];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    [CrashlyticsKit setObjectValue:peripheral.name forKey:@"peripheral"];
    [self addOrUpdateModelForCharacteristic:characteristic forService:characteristic.service];
    [self markTableForUpdate];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    for (CBDescriptor *descriptor in characteristic.descriptors) {
        [self addOrUpdateModelForDescriptor:descriptor forCharacteristic:characteristic];
        [peripheral readValueForDescriptor:descriptor];
    }
    [self markTableForUpdate];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error {
    [self addOrUpdateModelForDescriptor:descriptor forCharacteristic:descriptor.characteristic];
    [self markTableForUpdate];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSString *message;
    if (error) {
        NSLog(@"Write failed, restoring backup");
        message = @"Write failed.";
    } else {
        NSLog(@"Write successful, updating read value");
        message = @"Write successful!";
    }
    [peripheral readValueForCharacteristic:characteristic];
    [self.alertBarView revealAlertBarWithMessage:message revealTime:0.4 displayTime:3];
}

#pragma mark - Add or Update Attribute Models

- (BOOL)addOrUpdateModelForService:(CBService *)service {
    BOOL addedService = NO;
    SILServiceTableModel *serviceModel = [self findServiceModelForService:service];
    if (!serviceModel) {
        serviceModel = [[SILServiceTableModel alloc] initWithService:service];
        [self.allServiceModels addObject:serviceModel];
        addedService = YES;
    } else {
        serviceModel.service = service;
    }
    return addedService;
}

- (BOOL)addOrUpdateModelForCharacteristic:(CBCharacteristic *)characteristic forService:(CBService *)service {
    BOOL addedCharacteristic = NO;
    SILServiceTableModel *serviceModel = [self findServiceModelForService:service];
    SILCharacteristicTableModel *characteristicModel = [self findCharacteristicModelForCharacteristic:characteristic forServiceModel:serviceModel];
    
    if (serviceModel) {
        NSMutableArray *mutableCharacteristicModels = [serviceModel.characteristicModels mutableCopy] ?: [NSMutableArray new];
        if (!characteristicModel) {
            characteristicModel = [[SILCharacteristicTableModel alloc] initWithCharacteristic:characteristic];
            [characteristicModel updateRead:characteristic];
            [mutableCharacteristicModels addObject:characteristicModel];
            serviceModel.characteristicModels = [mutableCharacteristicModels copy];
            addedCharacteristic = YES;
        } else {
            characteristicModel.characteristic = characteristic;
            [characteristicModel updateRead:characteristic];
        }
    }
    return addedCharacteristic;
}

- (BOOL)addOrUpdateModelForDescriptor:(CBDescriptor *)descriptor forCharacteristic:(CBCharacteristic *)characteristic {
    BOOL addedDescriptor = NO;
    SILServiceTableModel *serviceModel = [self findServiceModelForService:characteristic.service];
    SILCharacteristicTableModel *characteristicModel = [self findCharacteristicModelForCharacteristic:characteristic forServiceModel:serviceModel];
    SILDescriptorTableModel *descriptorModel = [self findDescriptorModelForDescriptor:descriptor forCharacteristicModel:characteristicModel];
    
    if (characteristicModel) {
        NSMutableArray *mutableDescriptorModels = [characteristicModel.descriptorModels mutableCopy] ?: [NSMutableArray new];
        if (!descriptorModel) {
            descriptorModel = [[SILDescriptorTableModel alloc] initWithDescriptor:descriptor];
            [mutableDescriptorModels addObject:descriptorModel];
            characteristicModel.descriptorModels = [mutableDescriptorModels copy];
            addedDescriptor = YES;
        } else {
            descriptorModel.descriptor = descriptor;
        }
    }
    
    return addedDescriptor;
}

- (NSArray *)characteristicModelsForCharacteristics:(NSArray *)characteristics {
    NSMutableArray *characteristicModels = [[NSMutableArray alloc] init];
    for (CBCharacteristic *characteristic in characteristics) {
        SILCharacteristicTableModel *characteristicModel = [[SILCharacteristicTableModel alloc] initWithCharacteristic:characteristic];
        [characteristicModels addObject:characteristicModel];
    }
    return characteristicModels;
}

- (NSArray *)descriptorModelsForDescriptors:(NSArray *)descriptors {
    NSMutableArray *descriptorModels = [[NSMutableArray alloc] init];
    for (CBDescriptor *descriptor in descriptors) {
        SILDescriptorTableModel *attributeModel = [[SILDescriptorTableModel alloc] initWithDescriptor:descriptor];
        [descriptorModels addObject:attributeModel];
    }
    return descriptorModels;
}

#pragma mark - Find Attribute Models

- (SILServiceTableModel *)findServiceModelForService:(CBService *)service {
    for (SILServiceTableModel *serviceModel in self.allServiceModels) {
        if ([serviceModel.service.UUID isEqual:service.UUID]) {
            return serviceModel;
        }
    }
    return nil;
}

- (SILCharacteristicTableModel *)findCharacteristicModelForCharacteristic:(CBCharacteristic *)characteristic forServiceModel:(SILServiceTableModel *)serviceModel {
    if (serviceModel) {
        for (SILCharacteristicTableModel *characteristicModel in serviceModel.characteristicModels) {
            if ([characteristicModel.characteristic.UUID isEqual:characteristic.UUID]) {
                return characteristicModel;
            }
        }
    }
    return nil;
}

- (SILDescriptorTableModel *)findDescriptorModelForDescriptor:(CBDescriptor *)descriptor forCharacteristicModel:(SILCharacteristicTableModel *)characteristicModel {
    if (characteristicModel) {
        for (SILDescriptorTableModel *descriptorModel in characteristicModel.descriptorModels) {
            if ([descriptorModel.descriptor.UUID isEqual:descriptor.UUID]) {
                return descriptorModel;
            }
        }
    }
    return nil;
}

#pragma mark - Display Array

- (NSArray *)buildDisplayArray {
    NSMutableArray *displayArray = [[NSMutableArray alloc] init];
    
    bool firstService = YES;
    for (SILServiceTableModel *serviceModel in self.allServiceModels) {
        serviceModel.hideTopSeparator = firstService;
        [displayArray addObject:serviceModel];
        
        if (serviceModel.isExpanded) {
            [self buildDisplayCharacteristics:displayArray forServiceModel:serviceModel];
        }
        firstService = NO;
        [displayArray addObject:kSpacerCellIdentifieer];
    }
    
    return displayArray;
}

- (void)buildDisplayCharacteristics:(NSMutableArray *)displayArray forServiceModel:(SILServiceTableModel *)serviceModel {
    bool firstCharacteristic = YES;
    for (SILCharacteristicTableModel *characteristicModel in serviceModel.characteristicModels) {
        characteristicModel.hideTopSeparator = firstCharacteristic;
        [displayArray addObject:characteristicModel];
        
        if (characteristicModel.isExpanded) {
            [self buildDisplayCharacteristicFields:displayArray forCharacterisitcModel:characteristicModel];
        }
        
        firstCharacteristic = NO;
    }
}

- (void)buildDisplayCharacteristicFields:(NSMutableArray *)displayArray forCharacterisitcModel:(SILCharacteristicTableModel *)characteristicModel {
    bool firstField = YES;
    if ([characteristicModel isUnknown]) {
        // We are unknown. But lets display our encoding information as if we were a field.
        [displayArray addObject:[[SILEncodingPseudoFieldRowModel alloc] initForCharacteristicModel:characteristicModel]];
    } else {
        for (id<SILCharacteristicFieldRow> fieldModel in characteristicModel.fieldTableRowModels) {
            [fieldModel setParentCharacteristicModel:characteristicModel];
            if ([fieldModel requirementsSatisfied]) {
                fieldModel.hideTopSeparator = firstField;
                if ([fieldModel isKindOfClass:[SILBitFieldFieldModel class]]) {
                    SILBitFieldFieldModel *bitFieldModel = fieldModel;
                    [displayArray addObjectsFromArray:[bitFieldModel bitRowModels]];
                } else {
                    [displayArray addObject:fieldModel];
                }
                firstField = NO;
            } else {
                NSLog(@"Requirements not met for %@", characteristicModel.bluetoothModel.name);
            }
        }
    }
}

#pragma mark - Helpers

- (void)markTableForUpdate {
    self.tableNeedsRefresh = YES;
    if (!self.tableRefreshTimer) {
        [self refreshTable];
        [self startRefreshTimer];
    }
}

- (void)refreshTable {
    self.modelsToDisplay = [self buildDisplayArray];
    [self.servicesTableView reloadData];
    self.tableNeedsRefresh = NO;
}

- (UITableViewCell *)configuredCellForIndexPath:(NSIndexPath *)indexPath tableView:(UITableView *)tableView isSizing:(BOOL)isSizing {
    if ([self.modelsToDisplay[indexPath.row] isEqual:kSpacerCellIdentifieer]) {
        SILDebugSpacerTableViewCell *spacerCell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([SILDebugSpacerTableViewCell class])];
        return spacerCell;
    }
    
    id<SILGenericAttributeTableModel> model = self.modelsToDisplay[indexPath.row];
    if ([model isKindOfClass:[SILServiceTableModel class]]) {
        return [self serviceCellWithModel:model forTable:tableView isSizing:isSizing];
    } else if ([model isKindOfClass:[SILCharacteristicTableModel class]]) {
        SILCharacteristicTableModel *characteristicTableModel = (SILCharacteristicTableModel *)model;
        return [self characteristicCellWithModel:characteristicTableModel forTable:tableView isSizing:isSizing];
    } else {
        id<SILCharacteristicFieldRow> fieldModel = self.modelsToDisplay[indexPath.row];
        if ([model isKindOfClass:[SILEnumerationFieldRowModel class]]) {
            return [self enumerationFieldCellWithModel:fieldModel forTable:tableView isSizing:isSizing];
        } else if ([model isKindOfClass:[SILBitRowModel class]]) {
            return [self toggleFieldCellWithModel:fieldModel forTable:tableView isSizing:isSizing];
        } else if ([model isKindOfClass:[SILEncodingPseudoFieldRowModel class]]) {
            return [self encodingFieldCellWithModel:fieldModel forTable:tableView isSizing:isSizing];
        } else {
            return [self valueFieldCellWithModel:fieldModel forTable:tableView isSizing:isSizing];
        }
    }
}

- (void)configureNavigationItemWithPeripheral:(CBPeripheral *)peripheral {
    UIBarButtonItem *otaBarButtonItem;
    if ([peripheral hasOTAService]) {
        otaBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:kOTAButtonTitle
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:@selector(didTapOTABarButtonItem)];
    }
    [self.navigationItem setRightBarButtonItem:otaBarButtonItem];
}

#pragma mark - dealloc

- (void)dealloc {
    [self removeTimer];
}

@end
