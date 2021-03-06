//
//  CMBluetoothCentralServiceConfiguration.m
//  CMBluetoothKit
//
//  Created by Chris Miles on 13/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralServiceConfiguration.h"
#import "CMBluetoothCentralServiceConfiguration_Private.h"

#import "CMBluetoothCentralDiscoveredPeripheral_Private.h"
#import "CMBluetoothCentralCharacteristicConfiguration.h"
@import CoreBluetooth;


@implementation CMBluetoothCentralServiceConfiguration

+ (instancetype)serviceConfigurationWithUUID:(NSString *)serviceUUID identifier:(NSString *)identifier
{
    CMBluetoothCentralServiceConfiguration *serviceConfiguration = [[CMBluetoothCentralServiceConfiguration alloc] initWithServiceUUID:serviceUUID identifier:identifier];
    return serviceConfiguration;
}

- (id)initWithServiceUUID:(NSString *)serviceUUID identifier:(NSString *)identifier
{
    self = [super init];
    if (self) {
        _uuid = [CBUUID UUIDWithString:serviceUUID];
	_identifier = [identifier copy];
	
	_characteristics = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)addCharacteristicWithUUID:(NSString *)characteristicUUID identifier:(NSString *)identifier valueType:(CMBluetoothValueType)valueType
{
    CMBluetoothCentralCharacteristicConfiguration *characteristicConfiguration = [CMBluetoothCentralCharacteristicConfiguration characteristicConfigurationWithUUID:characteristicUUID identifier:identifier valueType:valueType];
    
    [self.characteristics setObject:characteristicConfiguration forKey:characteristicConfiguration.uuid];
}


#pragma mark - Notify

- (void)setNotify:(BOOL)notifyEnabled characteristicWithUUID:(NSString *)characteristicUUID
{
    CBUUID *cbuuid = [CBUUID UUIDWithString:characteristicUUID];
    CMBluetoothCentralCharacteristicConfiguration *characteristicConfiguration = self.characteristics[cbuuid];
    if (characteristicConfiguration == nil) {
        NSException *exception = [NSException
				  exceptionWithName:@"CharacteristicNotFoundException"
				  reason:@"No characteristic exists with the specified UUID"
				  userInfo:nil];
	@throw exception;
    }
    
    characteristicConfiguration.notifyEnabled = notifyEnabled;
}

- (NSSet *)characteristicUUIDsWithNotifyEnabled
{
    NSMutableSet *result = [NSMutableSet set];
    
    [self.characteristics enumerateKeysAndObjectsUsingBlock:^(CBUUID *uuid, CMBluetoothCentralCharacteristicConfiguration *characteristicConfiguration, __unused BOOL *stop) {
        if (characteristicConfiguration.notifyEnabled) {
            [result addObject:uuid];
        }
    }];
    
    return result;
}


#pragma mark - Util

- (NSArray *)characteristicCBUUIDs
{
    return [self.characteristics allKeys];
}

- (NSString *)characteristicIdentifierForUUID:(CBUUID *)characteristicUUID
{
    NSString *result = nil;
    
    for (CMBluetoothCentralCharacteristicConfiguration *characteristicConfiguration in [self.characteristics allValues]) {
	if ([characteristicConfiguration.uuid isEqual:characteristicUUID]) {
	    result = characteristicConfiguration.identifier;
	    break;
	}
    }
    return result;
}

- (CBUUID *)characteristicUUIDForIdentifier:(NSString *)characteristicIdentifier
{
    CBUUID *result = nil;
    
    for (CMBluetoothCentralCharacteristicConfiguration *characteristicConfiguration in [self.characteristics allValues]) {
	if ([characteristicConfiguration.identifier isEqual:characteristicIdentifier]) {
	    result = characteristicConfiguration.uuid;
	    break;
	}
    }
    return result;
}

- (id)unpackValueWithData:(NSData *)data forCharacteristicUUID:(CBUUID *)characteristicUUID
{
    CMBluetoothCentralCharacteristicConfiguration *characteristicConfiguration = self.characteristics[characteristicUUID];
    return [characteristicConfiguration unpackValueWithData:data];
}

- (NSData *)packDataWithValue:(id)value forCharacteristicUUID:(CBUUID *)characteristicUUID
{
    CMBluetoothCentralCharacteristicConfiguration *characteristicConfiguration = self.characteristics[characteristicUUID];
    return [characteristicConfiguration packDataWithValue:value];
}

@end
