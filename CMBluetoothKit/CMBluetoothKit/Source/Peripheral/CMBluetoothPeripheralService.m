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

- (void)addCharacteristicWithUUID:(NSString *)characteristicUUID readRequest:(NSData *(^)(void))readRequestBlock writeRequest:(BOOL(^)(NSData *))writeRequestBlock allowNotify:(BOOL)allowNotify
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
    
    CMBluetoothPeripheralCharacteristicType characteristicTypes = (CMBluetoothPeripheralCharacteristicType)0;
    CMBluetoothPeripheralCharacteristicPermissions characteristicPermissions = (CMBluetoothPeripheralCharacteristicPermissions)0;
    
    if (readRequestBlock) {
        characteristicTypes |= CMBluetoothPeripheralCharacteristicTypeRead;
        characteristicPermissions |= CMBluetoothPeripheralCharacteristicPermissionsReadable;
    }
    if (writeRequestBlock ) {
        characteristicTypes |= CMBluetoothPeripheralCharacteristicTypeWrite;
        characteristicPermissions |= CMBluetoothPeripheralCharacteristicPermissionsWriteable;
    }
    if (allowNotify) {
        if (readRequestBlock == nil) {
            @throw [NSException
                    exceptionWithName:@"AllowNotifyWithoutReadRequestBlockException"
                    reason:@"Cannot allow characteristic notify without also setting a read request callback block"
                    userInfo:nil];
        }
        
        characteristicTypes |= CMBluetoothPeripheralCharacteristicTypeNotify;
        characteristicPermissions |= CMBluetoothPeripheralCharacteristicPermissionsReadable;
    }
    
    ZAssert(characteristicTypes != 0, @"characteristicTypes cannot be 0");
    ZAssert(characteristicPermissions != 0, @"characteristicPermissions cannot be 0");
    
    CMBluetoothPeripheralCharacteristic *characteristic = [[CMBluetoothPeripheralCharacteristic alloc] initWithCharacteristicUUID:characteristicUUID types:characteristicTypes permissions:characteristicPermissions];
    
    if (readRequestBlock) [characteristic setReadRequestBlock:readRequestBlock];
    if (writeRequestBlock) [characteristic setWriteRequestBlock:writeRequestBlock];
    characteristic.allowNotify = allowNotify;
    
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
