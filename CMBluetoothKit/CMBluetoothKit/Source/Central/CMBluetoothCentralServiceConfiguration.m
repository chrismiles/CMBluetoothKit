//
//  CMBluetoothCentralServiceConfiguration.m
//  CMBluetoothKit
//
//  Created by Chris Miles on 13/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralServiceConfiguration.h"
#import "CMBluetoothCentralServiceConfiguration_Private.h"

#import "CMBluetoothCentralConnectedPeripheral_Private.h"
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

- (NSArray *)characteristicCBUUIDs
{
    return [self.characteristics allKeys];
}

- (NSString *)characteristicIdentifierForUUID:(CBUUID *)characteristicUUID
{
    NSString *result = nil;
    
    for (CMBluetoothCentralCharacteristicConfiguration *characteristicConfiguration in self.characteristics) {
	if ([characteristicConfiguration.uuid isEqual:characteristicUUID]) {
	    result = characteristicConfiguration.identifier;
	    break;
	}
    }
    return result;
}

@end
