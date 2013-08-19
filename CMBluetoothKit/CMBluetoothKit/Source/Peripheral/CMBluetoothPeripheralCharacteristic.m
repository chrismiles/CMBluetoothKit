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
@property (assign, nonatomic) CMBluetoothPeripheralCharacteristicType types;
@property (assign, nonatomic) CMBluetoothPeripheralCharacteristicPermissions permissions;

@end


@implementation CMBluetoothPeripheralCharacteristic

- (id)initWithCharacteristicUUID:(NSString *)UUID types:(CMBluetoothPeripheralCharacteristicType)types permissions:(CMBluetoothPeripheralCharacteristicPermissions)permissions
{
    self = [super init];
    if (self) {
        _UUID = UUID;
	_types = types;
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
	CBCharacteristicProperties characteristicProperties = (CBCharacteristicProperties)0;
	if ((self.types & CMBluetoothPeripheralCharacteristicTypeRead) != 0) {
	    characteristicProperties ^= CBCharacteristicPropertyRead;
	}
	if ((self.types & CMBluetoothPeripheralCharacteristicTypeWrite) != 0) {
	    characteristicProperties ^= CBCharacteristicPropertyWrite;
	}
	if ((self.types & CMBluetoothPeripheralCharacteristicTypeNotify) != 0) {
	    characteristicProperties ^= CBCharacteristicPropertyNotify;
	}
	if (characteristicProperties == 0) {
	    NSException *exception = [NSException
				      exceptionWithName:@"InvalidCharacteristicTypeException"
				      reason:@"The characteristic type value is invalid"
				      userInfo:nil];
	    @throw exception;
	}

	CBAttributePermissions attributePermissions = (CBAttributePermissions)0;
	if ((self.permissions & CMBluetoothPeripheralCharacteristicPermissionsReadable) != 0) {
	    attributePermissions ^= CBAttributePermissionsReadable;
	}
	if ((self.permissions & CMBluetoothPeripheralCharacteristicPermissionsWriteable) != 0) {
	    attributePermissions ^= CBAttributePermissionsWriteable;
	}
	if (attributePermissions == 0) {
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
        void ((^readResult)(void)) = ^{
	    result = self.readRequestBlock();
	};
        
        if ([NSThread isMainThread]) {
            readResult();
        }
        else {
            dispatch_sync(dispatch_get_main_queue(), readResult);
        }
    }
#ifdef DEBUG
    else {
        DLog(@"Called valueForReadRequest when self.readRequestBlock is nil");
    }
#endif
    
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
