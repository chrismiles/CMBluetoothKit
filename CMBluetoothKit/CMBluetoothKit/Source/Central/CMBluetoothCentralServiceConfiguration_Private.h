//
//  CMBluetoothCentralServiceConfiguration_Private.h
//  CMBluetoothKit
//
//  Created by Chris Miles on 13/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralServiceConfiguration.h"
@class CBUUID;

@interface CMBluetoothCentralServiceConfiguration ()

@property (strong, nonatomic) NSMutableDictionary *characteristics;

@property (copy, nonatomic) NSString *identifier;
@property (strong, nonatomic) CBUUID *uuid;

- (NSArray *)characteristicCBUUIDs;

- (NSString *)characteristicIdentifierForUUID:(CBUUID *)characteristicUUID;
- (CBUUID *)characteristicUUIDForIdentifier:(NSString *)characteristicIdentifier;

- (NSSet *)characteristicUUIDsWithNotifyEnabled;

@end
