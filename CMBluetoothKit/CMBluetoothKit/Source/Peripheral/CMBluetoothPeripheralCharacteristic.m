//
//  CMBluetoothPeripheralCharacteristic.m
//  NearPlayiOS
//
//  Created by Chris Miles on 26/07/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothPeripheralCharacteristic.h"

@interface CMBluetoothPeripheralCharacteristic ()
{
    CBMutableCharacteristic *_cbMutableCharacteristic;
}

@property (copy, nonatomic) NSString *UUID;
@property (assign, nonatomic) CMBluetoothPeripheralCharacteristicType type;
@property (assign, nonatomic) CMBluetoothPeripheralCharacteristicPermissions permissions;

@end


@implementation CMBluetoothPeripheralCharacteristic

- (id)initWithCharacteristicUUID:(NSString *)UUID type:(CMBluetoothPeripheralCharacteristicType)type permissions:(CMBluetoothPeripheralCharacteristicPermissions)permissions
{
    self = [super init];
    if (self) {
        _UUID = UUID;
	_type = type;
	_permissions = permissions;
    }
    return self;
}

- (CBUUID *)CBUUID
{
    return [CBUUID UUIDWithString:self.UUID];
}

- (CBMutableCharacteristic *)cbMutableCharacteristic
{
    if (_cbMutableCharacteristic == nil) {
	CBCharacteristicProperties characteristicProperties;
	if (self.type == CMBluetoothPeripheralCharacteristicTypeReadonly) {
	    characteristicProperties = CBCharacteristicPropertyRead;
	}
	else if (self.type == CMBluetoothPeripheralCharacteristicTypeWriteonly) {
	    characteristicProperties = CBCharacteristicPropertyWrite;
	}
	else if (self.type == CMBluetoothPeripheralCharacteristicTypeNotifyonly) {
	    characteristicProperties = CBCharacteristicPropertyNotify;
	}
	else {
	    NSException *exception = [NSException
				      exceptionWithName:@"InvalidCharacteristicTypeException"
				      reason:@"The characteristic type value is invalid"
				      userInfo:nil];
	    @throw exception;
	}

	CBAttributePermissions attributePermissions;
	if (self.permissions == CMBluetoothPeripheralCharacteristicPermissionsReadable) {
	    attributePermissions = CBAttributePermissionsReadable;
	}
	else if (self.permissions == CMBluetoothPeripheralCharacteristicPermissionsWriteable) {
	    attributePermissions = CBAttributePermissionsWriteable;
	}
	else {
	    NSException *exception = [NSException
				      exceptionWithName:@"InvalidCharacteristicPermissionsException"
				      reason:@"The characteristic permissions value is invalid"
				      userInfo:nil];
	    @throw exception;
	}
	
	_cbMutableCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[self CBUUID] properties:characteristicProperties value:nil permissions:attributePermissions];
    }
    
    return _cbMutableCharacteristic;
}

- (void)clearFromCoreBluetooth
{
    _cbMutableCharacteristic = nil;
}

- (NSData *)valueForReadRequest
{
    __block NSData *result = nil;
    
    if (self.readRequestBlock) {
	dispatch_sync(dispatch_get_main_queue(), ^{
	    result = self.readRequestBlock();
	});
    }
    
    return result;
}

- (BOOL)writeRequestWithValue:(NSData *)value
{
    __block BOOL result = NO;
    if (self.writeRequestBlock) {
	dispatch_sync(dispatch_get_main_queue(), ^{
	    result = self.writeRequestBlock(value);
	});
    }
    return result;
}

@end
