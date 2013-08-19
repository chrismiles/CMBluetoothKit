//
//  CMBluetoothPeripheralController.h
//  NearPlayiOS
//
//  Created by Chris Miles on 25/07/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

@import Foundation;

extern NSString * const CMBluetoothPeripheralControllerErrorDomain;

typedef NS_ENUM(NSInteger, CMBluetoothPeripheralControllerError)
{
    CMBluetoothPeripheralControllerErrorUnsupported = 1,
    CMBluetoothPeripheralControllerErrorAlreadyAdvertising,
    CMBluetoothPeripheralControllerErrorPoweredOff,
    CMBluetoothPeripheralControllerErrorTimeout,
};


@interface CMBluetoothPeripheralController : NSObject

/** Block that will be called when advertising starts or stops, or any errors
    occur which effect service advertising.
 
    The block will be called on the main thread.
 */
@property (copy, nonatomic) void (^advertisingStateChangeCallback)(BOOL isAdvertising, NSError *error);

/** The name to include in advertised packets.
 
    Defaults to the current device name.
 */
@property (copy, nonatomic) NSString *advertisedLocalName;

/** Service advertising is enabled (and active if possible) if set to YES.

    When set to YES, service advertising is enabled. Actual service advertising
    will start as soon as the Bluetooth hardware is powered on and ready.
 
    Advertising will only actually begin if/when the Bluetooth radio can
    be successfully powered on. This won't happen in some circumstances, for
    example, Airplane mode.
 
    Set to NO to signal the peripheral to stop advertising any services.
    There may be a delay before advertising actually stops.
 */
@property (assign, nonatomic, getter = isAdvertisingEnabled) BOOL advertisingEnabled;

/** Returns YES if the peripheral is powered on and advertising a service.
 
    Otherwise, returns no.
 */
- (BOOL)isAdvertising;

- (void)addServiceWithUUID:(NSString *)UUID;

- (void)addToServiceWithUUID:(NSString *)serviceUUID readOnlyCharacteristicWithUUID:(NSString *)characteristicUUID request:(NSData *(^)(void))requestBlock;
- (void)addToServiceWithUUID:(NSString *)serviceUUID readOnlyCharacteristicWithUUID:(NSString *)characteristicUUID request:(NSData *(^)(void))requestBlock  allowNotify:(BOOL)allowNotify;
- (void)addToServiceWithUUID:(NSString *)serviceUUID writeOnlyCharacteristicWithUUID:(NSString *)characteristicUUID request:(BOOL(^)(NSData *value))requestBlock;

- (BOOL)notifyUpdatedValueForServiceWithUUID:(NSString *)serviceUUID forCharacteristicWithUUID:(NSString *)characteristicUUID;

@end
