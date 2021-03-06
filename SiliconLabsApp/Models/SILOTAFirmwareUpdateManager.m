//
//  SILOTAFirmwareUpdateManager.m
//  SiliconLabsApp
//
//  Created by Nicholas Servidio on 3/8/17.
//  Copyright © 2017 SiliconLabs. All rights reserved.
//

#import "SILOTAFirmwareUpdateManager.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "CBPeripheral+Services.h"
#import "CBService+Categories.h"
#import "SILDiscoveredPeripheral.h"
#import "SILUUIDProvider.h"
#import "SILCharacteristicTableModel.h"
#import "NSError+SILHelpers.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "SILOTAFirmwareFile.h"

static NSTimeInterval const kSILDurationBeforeUpdatingDFUStatusToWaiting = 2.0;
static NSTimeInterval const kSILDurationBeforeAttemptingToReconnect = 4.0;
static NSInteger const kSILOTAByteAlignment = 4;
static unsigned char kSILOTAByteAlignmentPadding[] = {0xFF, 0xFF, 0xFF, 0xFF};
static char const kSILInitiateDFUData = 0x00;
static char const kSILTerminateFimwareUpdateData = 0x03;

typedef NS_ENUM(NSInteger, SILFirmwareMode) {
    SILFirmwareModeUnknown,
    SILFirmwareModeDFU,
    SILFirmwareModeUpdateFile
};

@interface SILOTAFirmwareUpdateManager () <CBPeripheralDelegate>

@property (strong, nonatomic) CBPeripheral *peripheral;
@property (nonatomic) SILFirmwareMode firmwareUpdateMode;
@property (nonatomic) NSInteger location;
@property (nonatomic) NSInteger length;
@property (strong, nonatomic) NSData *fileData;
@property (nonatomic) BOOL expectingToDisconnectFromPeripheral;

@property (nonatomic, copy) void (^dfuCompletion)(CBPeripheral *, NSError *);
@property (nonatomic, copy) void (^fileCompletion)(CBPeripheral *, NSError *);
@property (nonatomic, copy) void (^fileProgress)(NSInteger, double);

@end

@implementation SILOTAFirmwareUpdateManager

#pragma mark - Initializers

- (instancetype)initWithPeriperal:(CBPeripheral *)peripheral centralManager:(SILCentralManager *)centralManager {
    self = [super init];
    if (self) {
        self.peripheral = peripheral;
        self.peripheral.delegate = self;
        self.centralManager = centralManager;
        [self registerForCentralManagerNotificaions];
    }
    return self;
}

#pragma mark - Setup

- (void)registerForCentralManagerNotificaions {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didConnectToPeripheral:)
                                                 name:SILCentralManagerDidConnectPeripheralNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didDisconnectFromPeripheral:)
                                                 name:SILCentralManagerDidDisconnectPeripheralNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didFailToConnectToPeripheral:)
                                                 name:SILCentralManagerDidFailToConnectPeripheralNotification object:nil];
}

#pragma mark - Notifications

- (void)didConnectToPeripheral:(NSNotification *)notification {
    self.peripheral = notification.userInfo[SILCentralManagerPeripheralKey];
    self.peripheral.delegate = self;
    [self.peripheral discoverServices:nil];
}

- (void)didDisconnectFromPeripheral:(NSNotification *)notification {
    if (self.expectingToDisconnectFromPeripheral) {
        self.expectingToDisconnectFromPeripheral = NO;
    } else {
        NSError *error = [NSError sil_errorWithCode:SILErrorCodeOTADisconnectedFromPeripheral underlyingError:nil];
        [self.delegate firmwareUpdateManagerDidUnexpectedlyDisconnectFromPeripheral:self withError:error];
    }
}

- (void)didFailToConnectToPeripheral:(NSNotification *)notification {
    NSError *error = [NSError sil_errorWithCode:SILErrorCodeOTAFailedToConnectToPeripheral underlyingError:nil];
    [self handleCompletionWithMode:self.firmwareUpdateMode peripheral:nil error:error];
}

#pragma mark - Public

- (void)cycleDeviceWithInitiationByteSequence:(BOOL)initiatingByteSequence
                                     progress:(void(^)(SILDFUStatus status))progress
                                   completion:(void(^)(CBPeripheral *peripheral, NSError *error))completion {
    self.firmwareUpdateMode = SILFirmwareModeDFU;
    self.dfuCompletion = completion;
    self.expectingToDisconnectFromPeripheral = YES;
    if (initiatingByteSequence) {
        [self writeSingleByteValue:kSILInitiateDFUData toCharacteristic:[self.peripheral otaControlCharacteristic]];
    } else {
        [self disconnectConnectedPeripheral];
    }

    progress(SILDFUStatusRebooting);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSILDurationBeforeUpdatingDFUStatusToWaiting * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        progress(SILDFUStatusWaiting);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSILDurationBeforeAttemptingToReconnect * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        progress(SILDFUStatusConnecting);
        SILDiscoveredPeripheral *discoveredPeripheral = [[SILDiscoveredPeripheral alloc] initWithPeripheral:self.peripheral advertisementData:nil RSSI:nil];
        [self.centralManager connectToDiscoveredPeripheral:discoveredPeripheral];
    });
}

- (void)uploadFile:(SILOTAFirmwareFile *)file
          progress:(void(^)(NSInteger bytes, double fraction))progress
        completion:(void(^)(CBPeripheral *peripheral, NSError *error))completion {
    self.fileCompletion = completion;
    self.fileProgress = progress;
    self.firmwareUpdateMode = SILFirmwareModeUpdateFile;
    [self uploadFile:file];
}

- (void)disconnectConnectedPeripheral {
    [self.centralManager disconnectConnectedPeripheral];
}

#pragma mark - CBPeriphralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
    if (error == nil) {
        if ([self.peripheral hasOTAService]) {
            [self.peripheral discoverCharacteristics:nil forService:[self.peripheral otaService]];
        } else {
            NSError *theError = [NSError sil_errorWithCode:SILErrorCodeOTAFailedToFindOTAService underlyingError:error];
            [self handleCompletionWithMode:self.firmwareUpdateMode peripheral:peripheral error:theError];
        }
    } else {
        NSError *theError = [NSError sil_errorWithCode:SILErrorCodeOTADiscoveredServicesError underlyingError:error];
        [self handleCompletionWithMode:self.firmwareUpdateMode peripheral:peripheral error:theError];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error == nil) {
        if ([peripheral hasOTADataCharacteristic]) {
            switch (self.firmwareUpdateMode) {
                case SILFirmwareModeDFU:
                    [self handleCompletionWithMode:self.firmwareUpdateMode peripheral:peripheral error:nil];
                    break;
                default:
                    break;
            }
        } else {
            NSError *theError = [NSError sil_errorWithCode:SILErrorCodeOTAFailedToFindOTADataCharacteristic underlyingError:error];
            [self handleCompletionWithMode:self.firmwareUpdateMode peripheral:peripheral error:theError];
        }
    } else {
        NSError *theError = [NSError sil_errorWithCode:SILErrorCodeOTADiscoveredCharacteristicsError underlyingError:error];
        [self handleCompletionWithMode:self.firmwareUpdateMode peripheral:peripheral error:theError];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error == nil) {
        if ([characteristic isEqual:[self.peripheral otaDataCharacteristic]]) {
            if (_location < _fileData.length) {
                [self writeFileDataToCharacteristic:characteristic];
                if (self.fileProgress) {
                    double fraction = (double)_location / (double)_fileData.length;
                    self.fileProgress(_location, fraction);
                }
            } else {
                self.expectingToDisconnectFromPeripheral = YES;
                [self writeSingleByteValue:kSILTerminateFimwareUpdateData toCharacteristic:[self.peripheral otaControlCharacteristic]];
                self.fileProgress = nil;
                if (self.fileCompletion) {
                    self.fileCompletion(peripheral, nil);
                    self.fileCompletion = nil;
                }
            }
        }
    } else {
        NSError *theError = [NSError sil_errorWithCode:SILErrorCodeOTAFailedToWriteToCharacteristicError underlyingError:error];
        [self handleCompletionWithMode:self.firmwareUpdateMode peripheral:peripheral error:theError];
    }
}

#pragma mark - Helpers

- (void)uploadFile:(SILOTAFirmwareFile *)file {
    self.expectingToDisconnectFromPeripheral = NO;
    [self writeSingleByteValue:kSILInitiateDFUData toCharacteristic:[self.peripheral otaControlCharacteristic]];

    // TODO: Move something executing here to a background queue. There is too much happening on the main queue at this
    // moment. We have to dispatch openWithCompletionHandler: on the main queue in order to not have an exception thrown.
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([file.fileData length] > 0) {
            _fileData = file.fileData;
            _location = 0;
            // Even though the data characteristic is advertised as WriteWithResponse and WriteWithoutResponse, choose
            // WriteWithoutResponse.
            _length = [SILOTAFirmwareUpdateManager maximumByteAlignedWriteValueLengthForPeripheral:self.peripheral forType:CBCharacteristicWriteWithoutResponse];
            if (_location < _fileData.length) {
                [self writeFileDataToCharacteristic:[self.peripheral otaDataCharacteristic]];
            }
        } else {
            NSError *error = [NSError sil_errorWithCode:SILErrorCodeOTAFailedToReadFile underlyingError:nil];
            [self handleCompletionWithMode:self.firmwareUpdateMode peripheral:nil error:error];
        }
    });
}

- (void)writeFileDataToCharacteristic:(CBCharacteristic *)characteristic {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSData *data;
        if (_location + _length > _fileData.length) {
            NSInteger currentLength = _fileData.length - _location;
            NSMutableData *mutableData = [[NSMutableData alloc] initWithData:[_fileData subdataWithRange:NSMakeRange(_location, currentLength)]];
            NSInteger lengthPastByteAlignmentBoundary = currentLength % kSILOTAByteAlignment;
            if (lengthPastByteAlignmentBoundary > 0) {
                NSInteger requiredAdditionalLength = kSILOTAByteAlignment - lengthPastByteAlignmentBoundary;
                [mutableData appendBytes:kSILOTAByteAlignmentPadding length:requiredAdditionalLength];
            }
            data = [[NSData alloc] initWithData:mutableData];
            _location = _location + currentLength;
        } else {
            data = [_fileData subdataWithRange:NSMakeRange(_location, _length)];
            _location = _location + _length;
        }
        [_peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    });
}

- (void)handleCompletionWithMode:(SILFirmwareMode)firmwareMode peripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (firmwareMode == SILFirmwareModeDFU) {
        if (self.dfuCompletion) {
            self.dfuCompletion(peripheral, error);
            self.dfuCompletion = nil;
        }
    } else if (firmwareMode == SILFirmwareModeUpdateFile) {
        if (self.fileCompletion) {
            self.fileCompletion(peripheral, error);
            self.fileCompletion = nil;
        }
    }
}

- (void)writeSingleByteValue:(char)value toCharacteristic:(CBCharacteristic *)characteristic {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        SILCharacteristicTableModel *characteristicTableModel = [[SILCharacteristicTableModel alloc] initWithCharacteristic:characteristic];
        NSData *data = [NSData dataWithBytes:&value length:1];
        [characteristicTableModel setIfAllowedFullWriteValue:data];
        [characteristicTableModel writeIfAllowedToPeripheral:self.peripheral];
    });
}

+ (NSUInteger)maximumByteAlignedWriteValueLengthForPeripheral:(CBPeripheral *)peripheral forType:(CBCharacteristicWriteType)type {
    NSUInteger rawLength = [peripheral maximumWriteValueLengthForType:type];
    return kSILOTAByteAlignment * (rawLength/kSILOTAByteAlignment);
}

@end
