//
//  CMBluetoothCentralDiscoveredPeripheral.h
//  NearPlayiOS
//
//  Created by Chris Miles on 8/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

@import Foundation;
@import CoreBluetooth;

extern NSString * const CMBluetoothCentralDiscoveredPeripheralErrorDomain;

typedef NS_ENUM(NSInteger, CMBluetoothCentralDiscoveredPeripheralError)
{
    CMBluetoothCentralDiscoveredPeripheralErrorNoServices = 1,
};


@interface CMBluetoothCentralDiscoveredPeripheral : NSObject

/* Unique identifier, assigned by the Bluetooth framework
 */
- (NSUUID *)identifier;

/* Advertised peripheral name
 */
- (NSString *)name;

- (NSDate *)lastSeenDate;

@property (assign, nonatomic, readonly, getter = isConnected) BOOL connected;

@property (copy, nonatomic) void (^characteristicValueUpdatedCallback)(NSString *serviceIdentifier, NSString *characteristicIdentifier, id value);

- (void)readValueForCharacteristicWithIdentifier:(NSString *)characteristicIdentifier serviceIdentifier:(NSString *)serviceIdentifier;
- (void)writeValue:(id)value toCharacteristicWithIdentifier:(NSString *)characteristicIdentifier serviceIdentifier:(NSString *)serviceIdentifier completion:(void (^)(NSError *error))completion;

@end
