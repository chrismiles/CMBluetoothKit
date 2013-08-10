//
//  CMBluetoothCentralController.h
//  NearPlayiOS
//
//  Created by Chris Miles on 6/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralConnectedPeripheral.h"
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

- (void)addServiceWithUUID:(NSString *)serviceUUID characteristicUUIDs:(NSArray *)characteristicUUIDs;
- (void)removeServiceWithUUID:(NSString *)serviceUUID;

@property (assign, nonatomic, getter = isScanningEnabled) BOOL scanningEnabled;

@property (copy, nonatomic) void ((^scanningStateChangeCallback)(CMBluetoothCentralControllerScanningState scanningState, NSError *error));
@property (copy, nonatomic) void ((^peripheralConnectionCallback)(CMBluetoothCentralConnectedPeripheral *peripheral, BOOL connected));

@end
