//
//  SILCentralManager.h
//  SiliconLabsApp
//
//  Created by Colden Prime on 2/4/15.
//  Copyright (c) 2015 SiliconLabs. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SILDiscoveredPeripheral;
@class CBPeripheral;
@class CBUUID;

extern NSString * const SILCentralManagerDidConnectPeripheralNotification;
extern NSString * const SILCentralManagerDidDisconnectPeripheralNotification;
extern NSString * const SILCentralManagerDidFailToConnectPeripheralNotification;

extern NSString * const SILCentralManagerDiscoveredPeripheralsKey;
extern NSString * const SILCentralManagerPeripheralKey;
extern NSString * const SILCentralManagerErrorKey;

@interface SILCentralManager : NSObject

@property (strong, nonatomic, readonly) NSArray *serviceUUIDs;
@property (strong, nonatomic, readonly) CBPeripheral *connectedPeripheral;

- (instancetype)initWithServiceUUID:(CBUUID *)serviceUUID;
- (instancetype)initWithServiceUUIDs:(NSArray *)serviceUUIDs;

- (NSArray *)discoveredPeripherals;
- (SILDiscoveredPeripheral *)discoveredPeripheralForPeripheral:(CBPeripheral *)peripheral;

- (BOOL)canConnectToDiscoveredPeripheral:(SILDiscoveredPeripheral *)discoveredPeripheral;
- (void)connectToDiscoveredPeripheral:(SILDiscoveredPeripheral *)discoveredPeripheral;
- (void)disconnectConnectedPeripheral;
- (void)removeAllDiscoveredPeripherals;

- (void)addScanForPeripheralsObserver:(id)observer selector:(SEL)aSelector;
- (void)removeScanForPeripheralsObserver:(id)observer;

@end
