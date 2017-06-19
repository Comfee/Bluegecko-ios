//
//  SILUUIDProvider.m
//  SiliconLabsApp
//
//  Created by Nicholas Servidio on 3/9/17.
//  Copyright © 2017 SiliconLabs. All rights reserved.
//

#import "SILUUIDProvider.h"

static NSString *kSILOtaServiceUUIDString = @"1d14d6ee-fd63-4fa1-bfa4-8f47b42119f0";
static NSString *kSILOtaCharacteristicDataUUIDString = @"984227f3-34fc-4045-a5d0-2c581f81a153";
static NSString *kSILOtaCharacteristicControlUUIDString = @"f7bf3564-fb6d-4e53-88a4-5e37e0326063";

@interface SILUUIDProvider ()

@property (strong, nonatomic, readwrite) CBUUID *otaServiceUUID;
@property (strong, nonatomic, readwrite) CBUUID *otaCharacteristicDataUUID;
@property (strong, nonatomic, readwrite) CBUUID *otaCharacteristicControlUUID;

@end

@implementation SILUUIDProvider

+ (instancetype)sharedProvider {
    static SILUUIDProvider *sharedProvider = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedProvider = [[SILUUIDProvider alloc] init];
    });
    return sharedProvider;
}

- (CBUUID *)otaServiceUUID {
    if (_otaServiceUUID == nil) {
        _otaServiceUUID = [CBUUID UUIDWithString:kSILOtaServiceUUIDString];
    }
    return _otaServiceUUID;
}

- (CBUUID *)otaCharacteristicDataUUID {
    if (_otaCharacteristicDataUUID == nil) {
        _otaCharacteristicDataUUID = [CBUUID UUIDWithString:kSILOtaCharacteristicDataUUIDString];
    }
    return _otaCharacteristicDataUUID;
}

- (CBUUID *)otaCharacteristicControlUUID {
    if (_otaCharacteristicControlUUID == nil) {
        _otaCharacteristicControlUUID = [CBUUID UUIDWithString:kSILOtaCharacteristicControlUUIDString];
    }
    return _otaCharacteristicControlUUID;
}

@end
