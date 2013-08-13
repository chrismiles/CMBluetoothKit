//
//  CMBluetoothCentralCharacteristicConfiguration.h
//  CMBluetoothKit
//
//  Created by Chris Miles on 13/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothTypes.h"
@import Foundation;
@class CBUUID;

@interface CMBluetoothCentralCharacteristicConfiguration : NSObject

+ (instancetype)characteristicConfigurationWithUUID:(NSString *)characteristicUUID identifier:(NSString *)identifier valueType:(CMBluetoothValueType)valueType;

@property (strong, nonatomic, readonly) CBUUID *uuid;

- (NSString *)identifier;

- (id)unpackValueWithData:(NSData *)data;

@end
