//
//  CMBluetoothCentralConnectedPeripheral_Private.h
//  CMBluetoothKit
//
//  Created by Chris Miles on 10/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralConnectedPeripheral.h"

@interface CMBluetoothCentralConnectedPeripheral () <CBPeripheralDelegate>

@property (strong, nonatomic) NSDictionary *advertisementData;
@property (strong, nonatomic) CBPeripheral *cbPeripheral;

@property (copy, nonatomic) NSDictionary *serviceUUIDsAndCharacteristicUUIDsToDiscover;	// Service CBUUID -> Characteristic CBUUIDs
@property (strong, nonatomic) NSMutableSet *serviceCBUUIDSPendingFullDiscovery;		// Service CBUUIDs

@property (assign, nonatomic, getter = isConnected) BOOL connected;

/* Callback blocks
 */
@property (copy, nonatomic) void (^discoverServicesCompletionCallback)(NSError *error);

- (void)discoverServices:(NSDictionary *)services withCompletion:(void (^)(NSError *error))completion;

@end
