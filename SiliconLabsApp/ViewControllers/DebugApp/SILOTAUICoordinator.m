//
//  SILOTAUICoordinator.m
//  SiliconLabsApp
//
//  Created by Nicholas Servidio on 3/9/17.
//  Copyright © 2017 SiliconLabs. All rights reserved.
//

#import "SILOTAUICoordinator.h"
#import "SILOTAFirmwareUpdateManager.h"
#import "CBPeripheral+Services.h"
#import "WYPopoverController+SILHelpers.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "SILOTASetupViewController.h"
#import "NSError+SILHelpers.h"
#import "SILOTAFirmwareUpdate.h"
#import "SILOTAFirmwareFile.h"
#import "SILPopoverViewController.h"
#import "SILOTAProgressViewController.h"

static NSString * const kSILDFUStatusRebootingString = @"Rebooting...";
static NSString * const kSILDFUStatusWaitingString = @"Waiting...";
static NSString * const kSILDFUStatusConnectingString = @"Attempting Connection...";
static NSString * const kSILOKButtonTitle = @"OK";
static NSString * const kSILFirmwareUpdateUnknownErrorTitle = @"Error";
static NSString * const kSILFirmwareUpdateBGErrorMessageFormat = @"Code 0x%lx: %@";
static NSString * const kSILFirmwareUpdateBGErrSecurityImageChecksumError = @"Image checksum error";
static NSString * const kSILFirmwareUpdateBGErrWrongState = @"Wrong state";
static NSString * const kSILFirmwareUpdateBGErrBuffersFull = @"Buffers full";
static NSString * const kSILFirmwareUpdateBGErrCommandTooLong = @"Command too long";
static NSString * const kSILFirmwareUpdateBGErrInvalidFileFormat = @"Invalid file format";
static NSString * const kSILFirmwareUpdateBGErrUnspecified = @"Unspecified error";
static NSString * const kSILFirmwareUpdateBGErrUnknown = @"Unspecified error";

@interface SILOTAUICoordinator () <SILOTASetupViewControllerDelegate, SILOTAProgressViewControllerDelegate,
SILOTAFirmwareUpdateManagerDelegate>

@property (strong, nonatomic) CBPeripheral *peripheral;
@property (strong, nonatomic) SILOTAFirmwareUpdateManager *otaFirmwareUpdateManager;
@property (weak, nonatomic) UIViewController *presentingViewController;
@property (strong, nonatomic) SILOTASetupViewController *setupViewController;
@property (strong, nonatomic) SILOTAProgressViewController *progressViewController;
@property (strong, nonatomic) SILOTAProgressViewModel *progressViewModel;
@property (strong, nonatomic) SILPopoverViewController *popoverViewController;

@end

@implementation SILOTAUICoordinator

#pragma mark - Initializers

- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral
                    centralManager:(SILCentralManager *)centralManager
          presentingViewController:(UIViewController *)presentingViewController {
    self = [super init];
    if (self) {
        self.peripheral = peripheral;
        self.otaFirmwareUpdateManager = [[SILOTAFirmwareUpdateManager alloc] initWithPeriperal:self.peripheral
                                                                                centralManager:centralManager];
        self.otaFirmwareUpdateManager.delegate = self;
        self.presentingViewController = presentingViewController;
    }
    return self;
}

#pragma mark - Public

- (void)initiateOTAFlow {
    if ([self.peripheral hasOTAService]) {
        [self presentOTASetup];
    } else {
        [self.delegate otaUICoordinatorDidFishishOTAFlow:self];
    }
}

#pragma mark - Helpers

- (void)presentOTASetup {
    self.setupViewController = [[SILOTASetupViewController alloc] initWithPeripheral:_peripheral withCentralManager:_otaFirmwareUpdateManager.centralManager];
    self.setupViewController.delegate = self;
    self.popoverViewController = [[SILPopoverViewController alloc] initWithNibName:nil bundle:nil contentViewController:self.setupViewController];
    [self.presentingViewController presentViewController:self.popoverViewController animated:YES completion:nil];
}


- (void)showOTAProgressForFirmwareFile:(SILOTAFirmwareFile *)file ofType:(NSString *)type outOf:(NSInteger)totalNumber withCompletion:(void (^ __nullable)(void))completion {
    [self dismissPopoverWithCompletion:^{
        [self presentOTAProgressWithCompletion:^{
            self.progressViewModel.totalNumberOfFiles = totalNumber;
            self.progressViewModel.file = file;
            self.progressViewModel.uploadType = type;
            self.progressViewModel.uploadingFile = YES;
            if (completion) {
                completion();
            }
        }];
    }];
}

- (void)presentOTAProgressWithCompletion:(void (^ __nullable)(void))completion {
    self.progressViewModel = [[SILOTAProgressViewModel alloc] initWithPeripheral:_peripheral withCentralManager:_otaFirmwareUpdateManager.centralManager];
    self.progressViewController = [[SILOTAProgressViewController alloc] initWithViewModel: self.progressViewModel];
    self.progressViewController.delegate = self;
    self.popoverViewController = [[SILPopoverViewController alloc] initWithNibName:nil bundle:nil contentViewController:self.progressViewController];
    [self.presentingViewController presentViewController:self.popoverViewController animated:YES completion:completion];
}

- (void)dismissPopoverWithCompletion:(void (^ __nullable)(void))completion {
    [self.popoverViewController dismissViewControllerAnimated:YES completion:completion];
}

- (NSString *)stringForDFUStatus:(SILDFUStatus)status {
    NSString *statusString;
    switch (status) {
        case SILDFUStatusRebooting:
            statusString = kSILDFUStatusRebootingString;
            break;
        case SILDFUStatusWaiting:
            statusString = kSILDFUStatusWaitingString;
            break;
        case SILDFUStatusConnecting:
            statusString = kSILDFUStatusConnectingString;
            break;
        default:
            break;
    }
    return statusString;
}

- (void)presentAlertControllerWithError:(NSError *)error animated:(BOOL)animated {
    NSString *title;
    NSString *message;

    NSError *underlyingError = error.userInfo[NSUnderlyingErrorKey];
    NSString *underlyingSILErrorMessage = [self underlyingSILErrorMessageForError:error withUnderlyingError:underlyingError];

    if (underlyingSILErrorMessage) {
        title = kSILFirmwareUpdateUnknownErrorTitle;
        message = underlyingSILErrorMessage;

    } else {
        title = (underlyingError == nil) ? error.localizedDescription : underlyingError.localizedDescription;
        message = (underlyingError == nil) ? error.localizedRecoverySuggestion : underlyingError.localizedRecoverySuggestion;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *action = [self alertActionForError:error];
    [alert addAction:action];
    [self.presentingViewController presentViewController:alert animated:animated completion:nil];
}

- (NSString *)underlyingSILErrorMessageForError:(NSError *)error withUnderlyingError:(NSError *)underlyingError {
    NSString *message;
    if (error && underlyingError && error.code == 9) {
        switch (underlyingError.code) {
            case 0x80:
                message = kSILFirmwareUpdateBGErrSecurityImageChecksumError;
                break;
            case 0x81:
                message = kSILFirmwareUpdateBGErrWrongState;
                break;
            case 0x82:
                message = kSILFirmwareUpdateBGErrBuffersFull;
                break;
            case 0x83:
                message = kSILFirmwareUpdateBGErrCommandTooLong;
                break;
            case 0x84:
                message = kSILFirmwareUpdateBGErrInvalidFileFormat;
                break;
            case 0x85:
                message = kSILFirmwareUpdateBGErrUnspecified;
                break;
            default:
                message = kSILFirmwareUpdateBGErrUnknown;
                break;
        }
        return [NSString stringWithFormat:kSILFirmwareUpdateBGErrorMessageFormat, (long)underlyingError.code, message];
    }
    return NULL;
}

- (UIAlertAction *)alertActionForError:(NSError *)error {
    void (^ __nullable handler)(UIAlertAction *);
    if (error.code == SILErrorCodeOTAFailedToConnectToPeripheral || error.code == SILErrorCodeOTADisconnectedFromPeripheral) {
        handler = ^void(UIAlertAction * handler) {
            [self.delegate otaUICoordinatorDidFishishOTAFlow:self];
        };
    }
    return [UIAlertAction actionWithTitle:kSILOKButtonTitle
                                    style:UIAlertActionStyleDefault
                                  handler:handler];
}

#pragma mark - SILOTASetupViewControllerDelegate

- (void)otaSetupViewControllerEnterDFUModeForFirmwareUpdate:(SILOTAFirmwareUpdate *)firmwareUpdate {
    [SVProgressHUD show];
    __weak SILOTAUICoordinator *weakSelf = self;
    [self.otaFirmwareUpdateManager cycleDeviceWithInitiationByteSequence:YES
                                                                progress:^(SILDFUStatus status) {
                                                                    [SVProgressHUD setStatus:[weakSelf stringForDFUStatus:status]];
                                                                } completion:^(CBPeripheral *peripheral, NSError *error) {
                                                                    [SVProgressHUD dismiss];
                                                                    if (error == nil) {
                                                                        weakSelf.peripheral = peripheral;
                                                                        [weakSelf otaSetupViewControllerDidInitiateFirmwareUpdate:firmwareUpdate];
                                                                    } else {
                                                                        [weakSelf dismissPopoverWithCompletion:^{
                                                                            [weakSelf presentAlertControllerWithError:error animated:YES];
                                                                        }];
                                                                    }
                                                                }];
}

- (void)otaSetupViewControllerDidCancel:(SILOTASetupViewController *)controller {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)otaSetupViewControllerDidInitiateFirmwareUpdate:(SILOTAFirmwareUpdate *)firmwareUpdate {

    __weak SILOTAUICoordinator *weakSelf = self;

    void (^appFileUploadCompletion)(CBPeripheral *, NSError *) = ^void(CBPeripheral *peripheral, NSError *error) {
        weakSelf.progressViewModel.uploadingFile = NO;
        if (error == nil) {
            weakSelf.progressViewModel.finished = YES;
        } else {
            [weakSelf dismissPopoverWithCompletion:^{
                [weakSelf presentAlertControllerWithError:error animated:YES];
            }];
        }
    };

    if (firmwareUpdate.updateMode == SILOTAModeFull) {
        [self showOTAProgressForFirmwareFile:firmwareUpdate.stackFile ofType:@"STACK" outOf:2 withCompletion:^ {
            [self.otaFirmwareUpdateManager uploadFile:firmwareUpdate.stackFile progress:^(NSInteger bytes, double fraction) {
                weakSelf.progressViewModel.progressFraction = (CGFloat)fraction;
                weakSelf.progressViewModel.progressBytes = bytes;
            } completion:^(CBPeripheral *peripheral, NSError *error) {
                if (error != nil) {
                    [weakSelf dismissPopoverWithCompletion:^{
                        [weakSelf presentAlertControllerWithError:error animated:YES];
                    }];
                    return;
                }
                [weakSelf.otaFirmwareUpdateManager cycleDeviceWithInitiationByteSequence:NO
                                                                                progress:^(SILDFUStatus status) {
                                                                                    weakSelf.progressViewModel.uploadingFile = NO;
                                                                                    weakSelf.progressViewModel.statusString = [self stringForDFUStatus:status];
                                                                                } completion:^(CBPeripheral *peripheral, NSError *error) {
                                                                                    weakSelf.progressViewModel.file = firmwareUpdate.appFile;
                                                                                    weakSelf.progressViewModel.uploadType = @"APP";
                                                                                    weakSelf.progressViewModel.uploadingFile = YES;
                                                                                    [weakSelf.otaFirmwareUpdateManager uploadFile:firmwareUpdate.appFile progress:^(NSInteger bytes, double progress) {
                                                                                        weakSelf.progressViewModel.progressFraction = (CGFloat)progress;
                                                                                        weakSelf.progressViewModel.progressBytes = bytes;
                                                                                    } completion:appFileUploadCompletion];
                                                                                }];
            }];
        }];
    } else if (firmwareUpdate.updateMode == SILOTAModePartial) {
        [self showOTAProgressForFirmwareFile:firmwareUpdate.appFile ofType:@"APP" outOf:1 withCompletion:^ {
            [self.otaFirmwareUpdateManager uploadFile:firmwareUpdate.appFile progress:^(NSInteger bytes, double progress) {
                weakSelf.progressViewModel.progressFraction = (CGFloat)progress;
                weakSelf.progressViewModel.progressBytes = bytes;
            } completion:appFileUploadCompletion];
        }];
    }
}

#pragma mark - SILOTAProgressViewControllerDelegate

- (void)progressViewControllerDidPressDoneButton:(SILOTAProgressViewController *)controller {
    [self dismissPopoverWithCompletion:^{
        [self.otaFirmwareUpdateManager disconnectConnectedPeripheral];
        [self.delegate otaUICoordinatorDidFishishOTAFlow:self];
    }];
}

#pragma mark - SILOTAFirmwareUpdateManagerDelegate 


- (void)firmwareUpdateManagerDidUnexpectedlyDisconnectFromPeripheral:(SILOTAFirmwareUpdateManager *)firmwareUpdateManager
                                                           withError:(NSError *)error {
    [self dismissPopoverWithCompletion:^{
        [self presentAlertControllerWithError:error animated:YES];
    }];
}

@end
