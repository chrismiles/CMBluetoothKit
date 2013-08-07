//
//  CMBluetoothCentralController.h
//  NearPlayiOS
//
//  Created by Chris Miles on 6/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralConnectedPeripheral.h"
@import Foundation;


@interface CMBluetoothCentralController : NSObject

- (void)addServiceWithUUID:(NSString *)serviceUUID characteristicUUIDs:(NSArray *)characteristicUUIDs;
- (void)removeServiceWithUUID:(NSString *)serviceUUID;

@property (copy, nonatomic) void ((^peripheralConnectionCallback)(CMBluetoothCentralConnectedPeripheral *peripheral, BOOL connected));

@end
