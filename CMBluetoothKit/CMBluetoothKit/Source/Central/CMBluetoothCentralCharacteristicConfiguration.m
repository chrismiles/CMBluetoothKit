//
//  CMBluetoothCentralCharacteristicConfiguration.m
//  CMBluetoothKit
//
//  Created by Chris Miles on 13/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralCharacteristicConfiguration.h"
@import CoreBluetooth;


@interface CMBluetoothCentralCharacteristicConfiguration ()

@property (strong, nonatomic) CBUUID *uuid;
@property (copy, nonatomic) NSString *identifier;
@property (assign, nonatomic) CMBluetoothValueType valueType;

@end


@implementation CMBluetoothCentralCharacteristicConfiguration

+ (instancetype)characteristicConfigurationWithUUID:(NSString *)characteristicUUID identifier:(NSString *)identifier valueType:(CMBluetoothValueType)valueType
{
    CMBluetoothCentralCharacteristicConfiguration *characteristicConfiguration = [[CMBluetoothCentralCharacteristicConfiguration alloc] initWithCharacteristicUUID:characteristicUUID identifier:identifier valueType:valueType];
    return characteristicConfiguration;
}

- (id)initWithCharacteristicUUID:(NSString *)characteristicUUID identifier:(NSString *)identifier valueType:(CMBluetoothValueType)valueType
{
    self = [super init];
    if (self) {
        _uuid = [CBUUID UUIDWithString:characteristicUUID];
	_identifier = [identifier copy];
	_valueType = valueType;
    }
    return self;
}

@end
