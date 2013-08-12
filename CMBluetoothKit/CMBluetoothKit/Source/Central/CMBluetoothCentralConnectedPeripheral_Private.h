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

@property (copy, nonatomic) NSDictionary *requiredServiceUUIDsAndCharacteristicUUIDs;   // Service CBUUID -> Characteristic CBUUIDs
@property (copy, nonatomic) NSDictionary *serviceUUIDsAndCharacteristicUUIDsToDiscover;	// Service CBUUID -> Characteristic CBUUIDs (temporary - only used during discovery)
@property (strong, nonatomic) NSMutableSet *serviceCBUUIDSPendingFullDiscovery;		// Service CBUUIDs

@property (assign, nonatomic, getter = isConnected) BOOL connected;
@property (assign, nonatomic, getter = isFullyDiscovered) BOOL fullyDiscovered;

/* Callback blocks
 */
@property (copy, nonatomic) void (^discoverServicesCompletionCallback)(NSError *error);
@property (copy, nonatomic) void (^servicesInvalidatedCallback)(void);

- (void)discoverServices:(NSDictionary *)services withCompletion:(void (^)(NSError *error))completion;

@end
