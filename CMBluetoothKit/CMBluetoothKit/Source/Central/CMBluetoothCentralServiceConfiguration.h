//
//  CMBluetoothCentralServiceConfiguration.h
//  CMBluetoothKit
//
//  Created by Chris Miles on 13/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothTypes.h"
@import Foundation;
@class CBUUID;

@interface CMBluetoothCentralServiceConfiguration : NSObject

+ (instancetype)serviceConfigurationWithUUID:(NSString *)serviceUUID identifier:(NSString *)identifier;

- (void)addCharacteristicWithUUID:(NSString *)characteristicUUID identifier:(NSString *)identifier valueType:(CMBluetoothValueType)valueType;

- (NSString *)identifier;

- (id)unpackValueWithData:(NSData *)data forCharacteristicUUID:(CBUUID *)characteristicUUID;
- (NSData *)packDataWithValue:(id)value forCharacteristicUUID:(CBUUID *)characteristicUUID;

- (void)setNotify:(BOOL)notifyEnabled characteristicWithUUID:(NSString *)characteristicUUID;

@end
