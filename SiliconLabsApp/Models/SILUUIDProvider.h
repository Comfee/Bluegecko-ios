//
//  SILUUIDProvider.h
//  SiliconLabsApp
//
//  Created by Nicholas Servidio on 3/9/17.
//  Copyright © 2017 SiliconLabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface SILUUIDProvider : NSObject

+ (instancetype)sharedProvider;

@property (strong, nonatomic, readonly) CBUUID *otaServiceUUID;
@property (strong, nonatomic, readonly) CBUUID *otaCharacteristicDataUUID;
@property (strong, nonatomic, readonly) CBUUID *otaCharacteristicControlUUID;

@end
