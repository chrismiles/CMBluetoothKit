//
//  CMBluetoothCentralConnectedPeripheral_Private.h
//  CMBluetoothKit
//
//  Created by Chris Miles on 10/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralConnectedPeripheral.h"

@interface CMBluetoothCentralConnectedPeripheral () <CBPeripheralDelegate>

- (id)initWithCBPeripheral:(CBPeripheral *)cbPeripheral advertisementData:(NSDictionary *)advertisementData;

- (void)updateAdvertisementData:(NSDictionary *)advertisementData;

@property (strong, nonatomic) NSDictionary *advertisementData;
@property (strong, nonatomic) CBPeripheral *cbPeripheral;

@property (copy, nonatomic) NSArray *requiredServiceConfigurations; // Array of CMBluetoothCentralServiceConfiguration objects
@property (copy, nonatomic) NSDictionary *serviceUUIDsAndCharacteristicUUIDsToDiscover;	// Service CBUUID -> Characteristic CBUUIDs (temporary - only used during discovery)
@property (strong, nonatomic) NSMutableSet *serviceCBUUIDSPendingFullDiscovery;		// Service CBUUIDs

@property (strong, nonatomic) NSMutableDictionary *peripheralWriteCompletionCallbacks;

@property (assign, nonatomic, getter = isConnected) BOOL connected;
@property (assign, nonatomic, getter = isFullyDiscovered) BOOL fullyDiscovered;

- (void)discoverServices:(NSArray *)services withCompletion:(void (^)(NSError *error))completion;

- (void)startCharacteristicNotifications;

/* Callback blocks
 */
@property (copy, nonatomic) void (^discoverServicesCompletionCallback)(NSError *error);
@property (copy, nonatomic) void (^servicesInvalidatedCallback)(void);

@end
