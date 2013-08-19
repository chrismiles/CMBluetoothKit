//
//  CMBluetoothCentralController.h
//  NearPlayiOS
//
//  Created by Chris Miles on 6/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralDiscoveredPeripheral.h"
#import "CMBluetoothCentralServiceConfiguration.h"
@import Foundation;


typedef NS_ENUM(NSInteger, CMBluetoothCentralControllerScanningState)
{
    CMBluetoothCentralControllerScanningStateNotScanning,
    CMBluetoothCentralControllerScanningStateTransitioning,
    CMBluetoothCentralControllerScanningStateIsScanning,
};

extern NSString * const CMBluetoothCentralControllerErrorDomain;

typedef NS_ENUM(NSInteger, CMBluetoothCentralControllerError)
{
    CMBluetoothCentralControllerErrorUnsupported = 1,
    CMBluetoothCentralControllerErrorPoweredOff,
};


@interface CMBluetoothCentralController : NSObject

- (void)registerServiceWithConfiguration:(CMBluetoothCentralServiceConfiguration *)serviceConfiguration;

- (void)connectPeripheral:(CMBluetoothCentralDiscoveredPeripheral *)discoveredPeripheral;

@property (assign, nonatomic, getter = isScanningEnabled) BOOL scanningEnabled;

@property (copy, nonatomic) void ((^scanningStateChangeCallback)(CMBluetoothCentralControllerScanningState scanningState, NSError *error));
@property (copy, nonatomic) void ((^peripheralDiscoveredCallback)(CMBluetoothCentralDiscoveredPeripheral *peripheral));
@property (copy, nonatomic) void ((^peripheralConnectionCallback)(CMBluetoothCentralDiscoveredPeripheral *peripheral, BOOL connected));

@end
