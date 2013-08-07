//
//  CMBluetoothPeripheralCharacteristic.h
//  NearPlayiOS
//
//  Created by Chris Miles on 26/07/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

@import Foundation;
@import CoreBluetooth;

typedef NS_ENUM(NSInteger, CMBluetoothPeripheralCharacteristicType)
{
    CMBluetoothPeripheralCharacteristicTypeReadonly = 0,
    CMBluetoothPeripheralCharacteristicTypeWriteonly,
    CMBluetoothPeripheralCharacteristicTypeNotifyonly,
};

typedef NS_ENUM(NSInteger, CMBluetoothPeripheralCharacteristicPermissions)
{
    CMBluetoothPeripheralCharacteristicPermissionsReadable = 0,
    CMBluetoothPeripheralCharacteristicPermissionsWriteable,
};


@interface CMBluetoothPeripheralCharacteristic : NSObject

- (id)initWithCharacteristicUUID:(NSString *)UUID type:(CMBluetoothPeripheralCharacteristicType)type permissions:(CMBluetoothPeripheralCharacteristicPermissions)permissions;

@property (copy, nonatomic, readonly) NSString *UUID;
@property (assign, nonatomic, readonly) CMBluetoothPeripheralCharacteristicType type;
@property (assign, nonatomic, readonly) CMBluetoothPeripheralCharacteristicPermissions permissions;

@property (copy, nonatomic) NSData *(^readRequestBlock)(void);
@property (copy, nonatomic) BOOL(^writeRequestBlock)(NSData *);

- (CBMutableCharacteristic *)cbMutableCharacteristic;
- (void)clearFromCoreBluetooth;

- (NSData *)valueForReadRequest;
- (BOOL)writeRequestWithValue:(NSData *)value;

@end
