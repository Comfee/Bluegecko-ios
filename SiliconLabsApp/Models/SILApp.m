//
//  SILApp.m
//  SiliconLabsApp
//
//  Created by Colden Prime on 1/13/15.
//  Copyright (c) 2015 SiliconLabs. All rights reserved.
//

#import "SILApp.h"
#import "UIImage+SILImages.h"

@implementation SILApp

+ (NSArray *)allApps {
    return @[
             [[SILApp alloc] initWithAppType:SILAppTypeHealthThermometer
                                       title:@"Health Thermometer"
                                 description:@"View current and saved thermometer readings."
                           showcasedProfiles:@{ @"HTP" : @"­Health Thermometer Profile" }
                                   imageName:SILImageNameHomeThermometer],
             [[SILApp alloc] initWithAppType:SILAppTypeRetailBeacon
                                       title:@"Bluetooth Beaconing"
                                 description:@"Identify and detect Apple iBeacons and Google EddyStone beacons."
                           showcasedProfiles:@{}
                                   imageName:SILImageNameHomeRetailBeacon],
             [[SILApp alloc] initWithAppType:SILAppTypeKeyFob
                                       title:@"Key Fobs"
                                 description:@"Detect and find Key Fobs via intelligent alerts."
                           showcasedProfiles:@{ @"FMP" : @"­Find Me"}
                                   imageName:SILImageNameHomeKeyFOB],
             [[SILApp alloc] initWithAppType:SILAppTypeDebug
                                       title:@"Bluetooth Browser"
                                 description:@"View info about nearby devices and their properties."
                           showcasedProfiles:@{}
                                   imageName:SILImageNameHomeDebug]
             ];
}

- (instancetype)initWithAppType:(SILAppType)appType
                           title:(NSString *)title
                     description:(NSString *)description
               showcasedProfiles:(NSDictionary *)showcasedProfiles
                       imageName:(NSString *)imageName {
    self = [super init];
    if (self) {
        self.appType = appType;
        self.title = title;
        self.appDescription = description;
        self.showcasedProfiles = showcasedProfiles;
        self.imageName = imageName;
    }
    return self;
}

@end
