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

typedef void (^CMBluetoothCentralControllerPeripheralConnectionCallbackBlock)(CMBluetoothCentralDiscoveredPeripheral *peripheral, BOOL connected);
typedef void (^CMBluetoothCentralControllerPeripheralDiscoveredCallbackBlock)(CMBluetoothCentralDiscoveredPeripheral *peripheral);
typedef void (^CMBluetoothCentralControllerScanningStateChangeCallbackBlock)(CMBluetoothCentralControllerScanningState scanningState, NSError *error);


@interface CMBluetoothCentralController : NSObject

- (void)registerServiceWithConfiguration:(CMBluetoothCentralServiceConfiguration *)serviceConfiguration;

- (void)connectPeripheral:(CMBluetoothCentralDiscoveredPeripheral *)discoveredPeripheral;
- (void)disconnectPeripheral:(CMBluetoothCentralDiscoveredPeripheral *)discoveredPeripheral;

@property (assign, nonatomic, getter = isScanningEnabled) BOOL scanningEnabled;

- (void)setScanningStateChangeCallback:(CMBluetoothCentralControllerScanningStateChangeCallbackBlock)scanningStateChangeCallback;
- (void)setPeripheralDiscoveredCallback:(CMBluetoothCentralControllerPeripheralDiscoveredCallbackBlock)peripheralDiscoveredCallback;
- (void)setPeripheralConnectionCallback:(CMBluetoothCentralControllerPeripheralConnectionCallbackBlock)peripheralConnectionCallback;

@end
