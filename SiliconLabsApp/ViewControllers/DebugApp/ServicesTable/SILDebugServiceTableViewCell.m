//
//  SILServicesServiceTableViewCell.m
//  SiliconLabsApp
//
//  Created by Eric Peterson on 10/6/15.
//  Copyright © 2015 SiliconLabs. All rights reserved.
//

#import "SILDebugServiceTableViewCell.h"
#import "UIColor+SILColors.h"
#import "SILServiceTableModel.h"
#import "SILBluetoothServiceModel.h"

@interface SILDebugServiceTableViewCell()
@property (weak, nonatomic) IBOutlet UIView *topSeparatorView;
@property (weak, nonatomic) IBOutlet UIView *bottomSeparatorView;
@property (weak, nonatomic) IBOutlet UILabel *serviceNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *serviceUuidLabel;
@property (weak, nonatomic) IBOutlet UIImageView *viewMoreChevron;
@end

@implementation SILDebugServiceTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self configureIPadCell];
    }
}

- (void)configureWithServiceModel:(SILServiceTableModel *)serviceTableModel {
    self.serviceNameLabel.text = serviceTableModel.bluetoothModel.name ?: @"Unknown Service";
    self.serviceUuidLabel.text = [serviceTableModel uuidString] ?: @"";
    self.topSeparatorView.hidden = serviceTableModel.hideTopSeparator;
    [self configureAsExpandanble:[serviceTableModel canExpand]];
    [self layoutIfNeeded];
}

- (void)configureAsExpandanble:(BOOL)canExpand {
    self.viewMoreChevron.hidden = !canExpand;
}

-(void)configureIPadCell {
    self.contentView.layer.borderColor = [UIColor sil_lineGreyColor].CGColor;
    self.contentView.layer.borderWidth = 1.0f;
}

#pragma mark - SILGenericAttributeTableCell

- (void)expandIfAllowed:(BOOL)isExpanding {
    self.bottomSeparatorView.hidden = !isExpanding;
    [UIView animateWithDuration:0.3 animations:^{
        CGFloat angle = isExpanding ? M_PI : 0;
        self.viewMoreChevron.transform = CGAffineTransformMakeRotation(angle);
    }];
}

@end
