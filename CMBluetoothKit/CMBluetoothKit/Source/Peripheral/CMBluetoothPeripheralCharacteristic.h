//
//  CMBluetoothPeripheralCharacteristic.h
//  NearPlayiOS
//
//  Created by Chris Miles on 26/07/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

@import Foundation;
@import CoreBluetooth;

typedef NS_OPTIONS(NSInteger, CMBluetoothPeripheralCharacteristicType)
{
    CMBluetoothPeripheralCharacteristicTypeRead     = 0x01,
    CMBluetoothPeripheralCharacteristicTypeWrite    = 0x02,
    CMBluetoothPeripheralCharacteristicTypeNotify   = 0x04
};

typedef NS_OPTIONS(NSInteger, CMBluetoothPeripheralCharacteristicPermissions)
{
    CMBluetoothPeripheralCharacteristicPermissionsReadable  = 0x01,
    CMBluetoothPeripheralCharacteristicPermissionsWriteable = 0x02,
};


@interface CMBluetoothPeripheralCharacteristic : NSObject

- (id)initWithCharacteristicUUID:(NSString *)UUID types:(CMBluetoothPeripheralCharacteristicType)types permissions:(CMBluetoothPeripheralCharacteristicPermissions)permissions;

@property (copy, nonatomic, readonly) NSString *UUID;
@property (assign, nonatomic, readonly) CMBluetoothPeripheralCharacteristicType types;
@property (assign, nonatomic, readonly) CMBluetoothPeripheralCharacteristicPermissions permissions;

@property (copy, nonatomic) NSData *(^readRequestBlock)(void);
@property (copy, nonatomic) BOOL(^writeRequestBlock)(NSData *);

@property (assign, nonatomic) BOOL allowNotify;

- (CBMutableCharacteristic *)cbMutableCharacteristic;
- (void)clearFromCoreBluetooth;

- (NSData *)valueForReadRequest;
- (BOOL)writeRequestWithValue:(NSData *)value;

@end
