//
//  CMBluetoothCentralConnectedPeripheral.h
//  NearPlayiOS
//
//  Created by Chris Miles on 8/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

@import Foundation;
@import CoreBluetooth;

extern NSString * const CMBluetoothCentralConnectedPeripheralErrorDomain;

typedef NS_ENUM(NSInteger, CMBluetoothCentralConnectedPeripheralError)
{
    CMBluetoothCentralConnectedPeripheralErrorNoServices = 1,
};


@interface CMBluetoothCentralConnectedPeripheral : NSObject

/* Unique identifier, assigned by the Bluetooth framework
 */
- (NSUUID *)identifier;

/* Advertised peripheral name
 */
- (NSString *)name;

@property (copy, nonatomic) void (^characteristicValueUpdatedCallback)(NSString *serviceIdentifier, NSString *characteristicIdentifier, NSData *value);

- (void)readValueForCharacteristicWithIdentifier:(NSString *)characteristicIdentifier serviceIdentifier:(NSString *)serviceIdentifier;

@end
