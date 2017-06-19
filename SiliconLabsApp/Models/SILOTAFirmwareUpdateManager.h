//
//  SILOTAFirmwareUpdateManager.h
//  SiliconLabsApp
//
//  Created by Nicholas Servidio on 3/8/17.
//  Copyright © 2017 SiliconLabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SILCentralManager.h"
#import <CoreBluetooth/CoreBluetooth.h>
@class SILOTAFirmwareFile;

typedef NS_ENUM(NSInteger, SILDFUStatus) {
    SILDFUStatusRebooting,
    SILDFUStatusWaiting,
    SILDFUStatusConnecting
};

@protocol SILOTAFirmwareUpdateManagerDelegate;

@interface SILOTAFirmwareUpdateManager : NSObject

@property (strong, nonatomic) SILCentralManager *centralManager;
@property (weak, nonatomic) id<SILOTAFirmwareUpdateManagerDelegate> delegate;

- (instancetype)initWithPeriperal:(CBPeripheral *)peripheral centralManager:(SILCentralManager *)centralManager;
- (void)cycleDeviceWithInitiationByteSequence:(BOOL)initiatingByteSequence
                                     progress:(void(^)(SILDFUStatus status))progress
                                   completion:(void(^)(CBPeripheral *peripheral, NSError *error))completion;
- (void)uploadFile:(SILOTAFirmwareFile *)file
          progress:(void(^)(NSInteger bytes, double fraction))progress
        completion:(void(^)(CBPeripheral *peripheral, NSError *error))completion;
- (void)disconnectConnectedPeripheral;
+ (NSUInteger)maximumByteAlignedWriteValueLengthForPeripheral:(CBPeripheral *)peripheral forType:(CBCharacteristicWriteType)type;

@end

@protocol SILOTAFirmwareUpdateManagerDelegate <NSObject>

- (void)firmwareUpdateManagerDidUnexpectedlyDisconnectFromPeripheral:(SILOTAFirmwareUpdateManager *)firmwareUpdateManager
                                                           withError:(NSError *)error;

@end
