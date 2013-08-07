//
//  CMBluetoothPeripheralService.m
//  NearPlayiOS
//
//  Created by Chris Miles on 26/07/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothPeripheralService.h"
#import "CMBluetoothPeripheralCharacteristic.h"


@interface CMBluetoothPeripheralService ()
{
    CBMutableService *_cbMutableService;
}

@property (copy, nonatomic) NSString *UUID;
@property (assign, nonatomic) BOOL isPrimary;

@property (strong, nonatomic) NSMutableDictionary *characteristics;

@end


@implementation CMBluetoothPeripheralService

- (id)initWithUUID:(NSString *)UUID primary:(BOOL)primary
{
    self = [super init];
    if (self) {
        _UUID = UUID;
	_isPrimary = primary;
	_characteristics = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)addReadOnlyCharacteristicWithUUID:(NSString *)characteristicUUID request:(NSData *(^)(void))requestBlock
{
    if (_cbMutableService) {
	NSException *exception = [NSException
				  exceptionWithName:@"ServiceCannotBeModifiedException"
				  reason:@"Service cannot be modified after requesting cbMutableService"
				  userInfo:nil];
	@throw exception;
    }
    
    if (self.characteristics[characteristicUUID] != nil) {
	NSException *exception = [NSException
				  exceptionWithName:@"CharacteristicAlreadyAddedException"
				  reason:@"Cannot add characteristics with duplicate UUIDs"
				  userInfo:nil];
	@throw exception;
    }
    
    CMBluetoothPeripheralCharacteristic *characteristic = [[CMBluetoothPeripheralCharacteristic alloc] initWithCharacteristicUUID:characteristicUUID type:CMBluetoothPeripheralCharacteristicTypeReadonly permissions:CMBluetoothPeripheralCharacteristicPermissionsReadable];
    [characteristic setReadRequestBlock:requestBlock];
    
    self.characteristics[characteristicUUID] = characteristic;
}

- (void)addWriteOnlyCharacteristicWithUUID:(NSString *)characteristicUUID request:(BOOL(^)(NSData *))requestBlock
{
    if (_cbMutableService) {
	NSException *exception = [NSException
				  exceptionWithName:@"ServiceCannotBeModifiedException"
				  reason:@"Service cannot be modified after requesting cbMutableService"
				  userInfo:nil];
	@throw exception;
    }
    
    if (self.characteristics[characteristicUUID] != nil) {
	NSException *exception = [NSException
				  exceptionWithName:@"CharacteristicAlreadyAddedException"
				  reason:@"Cannot add characteristics with duplicate UUIDs"
				  userInfo:nil];
	@throw exception;
    }
    
    CMBluetoothPeripheralCharacteristic *characteristic = [[CMBluetoothPeripheralCharacteristic alloc] initWithCharacteristicUUID:characteristicUUID type:CMBluetoothPeripheralCharacteristicTypeWriteonly permissions:CMBluetoothPeripheralCharacteristicPermissionsWriteable];
    [characteristic setWriteRequestBlock:requestBlock];
    
    self.characteristics[characteristicUUID] = characteristic;
}

- (void)addNotifyOnlyCharacteristicWithUUID:(NSString *)characteristicUUID
{
    if (_cbMutableService) {
	NSException *exception = [NSException
				  exceptionWithName:@"ServiceCannotBeModifiedException"
				  reason:@"Service cannot be modified after requesting cbMutableService"
				  userInfo:nil];
	@throw exception;
    }
    
    if (self.characteristics[characteristicUUID] != nil) {
	NSException *exception = [NSException
				  exceptionWithName:@"CharacteristicAlreadyAddedException"
				  reason:@"Cannot add characteristics with duplicate UUIDs"
				  userInfo:nil];
	@throw exception;
    }
    
    CMBluetoothPeripheralCharacteristic *characteristic = [[CMBluetoothPeripheralCharacteristic alloc] initWithCharacteristicUUID:characteristicUUID type:CMBluetoothPeripheralCharacteristicTypeNotifyonly permissions:CMBluetoothPeripheralCharacteristicPermissionsReadable];
    
    self.characteristics[characteristicUUID] = characteristic;
}

- (CBUUID *)CBUUID
{
    return [CBUUID UUIDWithString:self.UUID];
}

- (CMBluetoothPeripheralCharacteristic *)characteristicWithUUID:(NSString *)characteristicUUID
{
    return self.characteristics[characteristicUUID];
}


#pragma mark - Peripheral Manager Add / Remove Service

- (void)addToPeripheralManager:(CBPeripheralManager *)peripheralManager
{
    CBMutableService *cbMutableService = [self cbMutableService];
    [peripheralManager addService:cbMutableService];
}

- (void)removeFromPeripheralManager:(CBPeripheralManager *)peripheralManager
{
    CBMutableService *cbMutableService = [self cbMutableService];
    [peripheralManager removeService:cbMutableService];
    
    [self clearFromCoreBluetooth];
}


#pragma mark - CBMutableService

- (CBMutableService *)cbMutableService
{
    if (_cbMutableService == nil) {
	_cbMutableService = [[CBMutableService alloc] initWithType:[self CBUUID] primary:self.isPrimary];
	
	NSMutableArray *cbMutableCharacteristics = [NSMutableArray array];
	[self.characteristics enumerateKeysAndObjectsUsingBlock:^(__unused id key, CMBluetoothPeripheralCharacteristic *characteristic, __unused BOOL *stop) {
	    CBMutableCharacteristic *cbMutableCharacteristic = [characteristic cbMutableCharacteristic];
	    [cbMutableCharacteristics addObject:cbMutableCharacteristic];
	}];
	
	_cbMutableService.characteristics = cbMutableCharacteristics;
    }
    
    return _cbMutableService;
}

- (void)clearFromCoreBluetooth
{
    [self.characteristics enumerateKeysAndObjectsUsingBlock:^(__unused id key, CMBluetoothPeripheralCharacteristic *characteristic, __unused BOOL *stop) {
	[characteristic clearFromCoreBluetooth];
    }];
    
    _cbMutableService = nil;
}


#pragma mark - Peripheral Characteristics

- (CMBluetoothPeripheralCharacteristic *)peripheralCharacteristicForCBCharacteristic:(CBCharacteristic *)cbCharacteristic
{
    __block CMBluetoothPeripheralCharacteristic *result = nil;
    
    [self.characteristics enumerateKeysAndObjectsUsingBlock:^(__unused id key, CMBluetoothPeripheralCharacteristic *peripheralCharacteristic, BOOL *stop) {
	if (peripheralCharacteristic.cbMutableCharacteristic == cbCharacteristic) {
	    result = peripheralCharacteristic;
	    *stop = YES;
	}
    }];
    
    return result;
}

@end
