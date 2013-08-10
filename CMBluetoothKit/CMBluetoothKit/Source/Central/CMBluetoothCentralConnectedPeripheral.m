//
//  CMBluetoothCentralConnectedPeripheral.m
//  NearPlayiOS
//
//  Created by Chris Miles on 8/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralConnectedPeripheral.h"
#import "CMBluetoothCentralConnectedPeripheral_Private.h"

NSString * const CMBluetoothCentralConnectedPeripheralErrorDomain = @"CMBluetoothCentralConnectedPeripheralErrorDomain";


@implementation CMBluetoothCentralConnectedPeripheral

- (id)initWithCBPeripheral:(CBPeripheral *)cbPeripheral advertisementData:(NSDictionary *)advertisementData
{
    self = [super init];
    if (self) {
	_advertisementData = advertisementData;
        _cbPeripheral = cbPeripheral;
	
	cbPeripheral.delegate = self;
    }
    return self;
}

- (void)discoverServices:(NSDictionary *)services withCompletion:(void (^)(NSError *error))completion
{
    self.serviceUUIDsAndCharacteristicUUIDsToDiscover = services;
    self.serviceCBUUIDSPendingFullDiscovery = [[services allKeys] mutableCopy];
    self.discoverServicesCompletionCallback = completion;
    
    // Expect an array of CBUUID objects
    NSArray *serviceCBUUIDs = [services allKeys];
    
    DLog(@"Peripheral %@ discoverServices:%@", self, serviceCBUUIDs);
    [self.cbPeripheral discoverServices:serviceCBUUIDs];
}

- (void)discoveredAllCharacteristicsForService:(CBService *)service
{
    ZAssert([self.serviceCBUUIDSPendingFullDiscovery containsObject:service.UUID], @"Discovered all characteristics for unexpected service: %@", service);
    [self.serviceCBUUIDSPendingFullDiscovery removeObject:service.UUID];
    
    if ([self.serviceCBUUIDSPendingFullDiscovery count] == 0) {
	DLog(@"All services found for peripheral: %@", self.cbPeripheral);
	[self performDiscoverServicesCompletionCallbackWithError:nil];
    }
}

- (void)performDiscoverServicesCompletionCallbackWithError:(NSError *)error
{
    if (self.discoverServicesCompletionCallback) {
	self.discoverServicesCompletionCallback(error);
	self.discoverServicesCompletionCallback = nil;
    }
#ifdef DEBUG
    else {
	ALog(@"Attempt to call nil discoverServicesCompletionCallback()");
    }
#endif
}


#pragma mark - CBPeripheralDelegate

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral
{
    DLog(@"TODO peripheral: %@", peripheral);
    
}

//- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray *)invalidatedServices
//- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    DLog(@"peripheral: %@ didDiscoverServices: %@", self, peripheral.services);
    ZAssert(peripheral == self.cbPeripheral, @"CBPeripheral mismatch");

    if ([peripheral.services count] == 0) {
	DLog(@"peripheral.services count = 0 for %@", peripheral);
	
    }

    if (error) {
	[self performDiscoverServicesCompletionCallbackWithError:error];
    }
    else if ([peripheral.services count] == 0) {
	DLog(@"peripheral.services count = 0 for %@", peripheral);
	NSError *zeroServicesError = [NSError errorWithDomain:CMBluetoothCentralConnectedPeripheralErrorDomain
							 code:CMBluetoothCentralConnectedPeripheralErrorNoServices
						     userInfo:nil];
	[self performDiscoverServicesCompletionCallbackWithError:zeroServicesError];
    }
    else {
	for (CBService *service in peripheral.services) {
	    DLog(@"Discovered service: %@", service);
	    
	    NSArray *characteristicCBUUIDs = self.serviceUUIDsAndCharacteristicUUIDsToDiscover[service.UUID];
	    if (characteristicCBUUIDs && [characteristicCBUUIDs count] > 0) {
		DLog(@"Peripheral %@ service: %@ discoverCharacteristics:%@", self, service, characteristicCBUUIDs);
		[peripheral discoverCharacteristics:characteristicCBUUIDs forService:service];
	    }
	}
    }
}

//- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(NSError *)error

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error) {
	[self performDiscoverServicesCompletionCallbackWithError:error];
    }
    
    ZAssert(peripheral == self.cbPeripheral, @"CBPeripheral mismatch");
    
    NSMutableArray *characteristicsToDiscover = self.serviceUUIDsAndCharacteristicUUIDsToDiscover[service.UUID];
    ZAssert(characteristicsToDiscover != nil, @"Discovered characteristics for unexpected service: %@", service);
    
    if (characteristicsToDiscover) {
	for (CBCharacteristic *characteristic in service.characteristics) {
	    DLog(@"discovered characteristic: %@", characteristic);
	    if ([characteristicsToDiscover containsObject:characteristic.UUID]) {
		[characteristicsToDiscover removeObject:characteristic.UUID];
	    }
	    else {
		ALog(@"Discovered characteristic we weren't waiting for: %@ (service: %@)", characteristic, service);
	    }
	}
	
	if ([characteristicsToDiscover count] == 0) {
	    DLog(@"Found all characteristics for service: %@", service);
	    [self discoveredAllCharacteristicsForService:service];
	}
    }
}

//- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
//- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
//- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
//- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
//- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
//- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error

@end
