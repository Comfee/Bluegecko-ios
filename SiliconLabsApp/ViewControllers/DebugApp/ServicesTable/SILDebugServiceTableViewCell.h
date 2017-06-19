//
//  SILServicesServiceTableViewCell.h
//  SiliconLabsApp
//
//  Created by Eric Peterson on 10/6/15.
//  Copyright © 2015 SiliconLabs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SILGenericAttributeTableCell.h"
@class SILServiceTableModel;

@interface SILDebugServiceTableViewCell : UITableViewCell <SILGenericAttributeTableCell>
- (void)configureWithServiceModel:(SILServiceTableModel *)serviceTableModel;
@end
