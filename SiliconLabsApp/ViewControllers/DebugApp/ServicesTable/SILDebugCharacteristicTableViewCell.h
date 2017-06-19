//
//  SILDebugCharacteristicTableViewCell.h
//  SiliconLabsApp
//
//  Created by Eric Peterson on 10/7/15.
//  Copyright © 2015 SiliconLabs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SILGenericAttributeTableCell.h"
@class SILCharacteristicTableModel;

@interface SILDebugCharacteristicTableViewCell : UITableViewCell <SILGenericAttributeTableCell>
- (void)configureWithCharacteristicModel:(SILCharacteristicTableModel *)characteristicModel;
@end
