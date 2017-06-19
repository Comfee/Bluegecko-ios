//
//  SILAppSelectionHelpViewController.m
//  SiliconLabsApp
//
//  Created by Colden Prime on 1/26/15.
//  Copyright (c) 2015 SiliconLabs. All rights reserved.
//

#import "SILAppSelectionHelpViewController.h"

@interface SILAppSelectionHelpViewController ()

- (IBAction)didTapOKButton:(id)sender;

@end

@implementation SILAppSelectionHelpViewController

- (IBAction)didTapOKButton:(id)sender {
    [self.delegate didFinishHelpWithAppSelectionHelpViewController:self];
}

#pragma mark - UIViewController Methods

- (CGSize)preferredContentSize {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return CGSizeMake(540, 350);
    } else {
        return CGSizeMake(296, 330);
    }
}

@end
