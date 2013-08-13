//
//  CMBluetoothCentralServiceConfiguration.h
//  CMBluetoothKit
//
//  Created by Chris Miles on 13/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothTypes.h"
@import Foundation;

@interface CMBluetoothCentralServiceConfiguration : NSObject

+ (instancetype)serviceConfigurationWithUUID:(NSString *)serviceUUID identifier:(NSString *)identifier;

- (void)addCharacteristicWithUUID:(NSString *)characteristicUUID identifier:(NSString *)identifier valueType:(CMBluetoothValueType)valueType;

- (NSString *)identifier;

@end
