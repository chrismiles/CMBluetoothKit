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

- (id)unpackValueWithData:(NSData *)data
{
    id value = nil;
    
    if (self.valueType == CMBluetoothValueTypeData) {
        value = data;
    }
    else if (self.valueType == CMBluetoothValueTypeInteger) {
        if ([data length] == 0) {
            ALog(@"0 bytes received for PlaybackState");
            return nil;
        }
        
        NSInteger *integerPtr = (NSInteger *)[data bytes];
        value = [NSNumber numberWithInteger:*integerPtr];
    }
    else if (self.valueType == CMBluetoothValueTypeString) {
        if ([data length] > 0) {
            const char *valueStr = (const char *)[data bytes];
            value = [NSString stringWithCString:valueStr encoding:NSUTF8StringEncoding];
        }
    }
    
    return value;
}

@end
