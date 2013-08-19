//
//  CMBluetoothPeripheralService.h
//  NearPlayiOS
//
//  Created by Chris Miles on 26/07/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

@import Foundation;
@import CoreBluetooth;

#import "CMBluetoothPeripheralCharacteristic.h"


@interface CMBluetoothPeripheralService : NSObject

- (id)initWithUUID:(NSString *)UUID primary:(BOOL)primary;

@property (copy, nonatomic, readonly) NSString *UUID;
@property (assign, nonatomic, readonly) BOOL isPrimary;

- (void)addCharacteristicWithUUID:(NSString *)characteristicUUID readRequest:(NSData *(^)(void))readRequestBlock writeRequest:(BOOL(^)(NSData *))writeRequestBlock allowNotify:(BOOL)allowNotify;

- (CBUUID *)CBUUID;
- (CBMutableService *)cbMutableService;

- (void)addToPeripheralManager:(CBPeripheralManager *)peripheralManager;
- (void)removeFromPeripheralManager:(CBPeripheralManager *)peripheralManager;

- (CMBluetoothPeripheralCharacteristic *)peripheralCharacteristicForCBCharacteristic:(CBCharacteristic *)cbCharacteristic;

- (CMBluetoothPeripheralCharacteristic *)characteristicWithUUID:(NSString *)characteristicUUID;

@end
