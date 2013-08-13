//
//  CMBluetoothCentralConnectedPeripheral.m
//  NearPlayiOS
//
//  Created by Chris Miles on 8/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralConnectedPeripheral.h"
#import "CMBluetoothCentralConnectedPeripheral_Private.h"
#import "CMBluetoothCentralServiceConfiguration_Private.h"

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


- (NSString *)name
{
    NSString *name = self.advertisementData[@"kCBAdvDataLocalName"];
    if (name == nil) name = self.cbPeripheral.name;
    return name;
}


#pragma mark - Private

- (void)updateAdvertisementData:(NSDictionary *)advertisementData
{
    self.advertisementData = advertisementData;
}

- (void)discoverServices:(NSArray *)services withCompletion:(void (^)(NSError *))completion
{
    self.requiredServiceConfigurations = services;
    
    // Mutable copy services values
    NSMutableDictionary *serviceUUIDsAndCharacteristicUUIDsToDiscover = [NSMutableDictionary dictionary];
    for (CMBluetoothCentralServiceConfiguration *serviceConfiguration in services) {
	BOOL correctKindOfClass = [serviceConfiguration isKindOfClass:[CMBluetoothCentralServiceConfiguration class]];
	ZAssert(correctKindOfClass, @"Expecting service of type CMBluetoothCentralServiceConfiguration - got %@", [serviceConfiguration class]);
	
	if (correctKindOfClass) {
	    serviceUUIDsAndCharacteristicUUIDsToDiscover[serviceConfiguration.uuid] = [serviceConfiguration.characteristicCBUUIDs mutableCopy];
	}
    }
    
    self.serviceUUIDsAndCharacteristicUUIDsToDiscover = serviceUUIDsAndCharacteristicUUIDsToDiscover;
    
    self.serviceCBUUIDSPendingFullDiscovery = [[serviceUUIDsAndCharacteristicUUIDsToDiscover allKeys] mutableCopy];
    self.discoverServicesCompletionCallback = completion;
    
    // Expect an array of CBUUID objects
    NSArray *serviceCBUUIDs = [serviceUUIDsAndCharacteristicUUIDsToDiscover allKeys];
    
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

- (void)performServicesInvalidatedCallback
{
    if (self.servicesInvalidatedCallback) {
	DLog(@"Calling servicesInvalidatedCallback()");
	self.servicesInvalidatedCallback();
    }
}

- (void)performCharacteristicUpdatedCallbackWithValue:(NSData *)value characteristicIdentifier:(NSString *)characteristicIdentifier serviceIdentifier:(NSString *)serviceIdentifier
{
    if (self.characteristicValueUpdatedCallback) {
	self.characteristicValueUpdatedCallback(serviceIdentifier, characteristicIdentifier, value);
    }
}

- (NSSet *)requiredServiceCBUUIDs
{
    NSMutableSet *result = [NSMutableSet set];
    for (CMBluetoothCentralServiceConfiguration *serviceConfiguration in self.requiredServiceConfigurations) {
	[result addObject:serviceConfiguration.uuid];
    }
    return result;
}


#pragma mark - CBPeripheralDelegate

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral
{
    DLog(@"TODO peripheral: %@", peripheral);
    
}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray *)invalidatedServices
{
    DLog(@"peripheral: %@ invalidatedServices: %@", peripheral, invalidatedServices);
    ZAssert(peripheral == self.cbPeripheral, @"CBPeripheral mismatch");
    
    BOOL requiredServiceModified = NO;
    NSSet *requiredServiceCBUUIDs = [self requiredServiceCBUUIDs];
    
    for (CBService *service in invalidatedServices) {
	if ([requiredServiceCBUUIDs containsObject:service.UUID]) {
	    requiredServiceModified = YES;
	    break;
	}
    }
    
    if (requiredServiceModified) {
	[self performServicesInvalidatedCallback];
    }
}

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
	    else {
		ALog(@"Zero characteristics to discover for service: %@ self.serviceUUIDsAndCharacteristicUUIDsToDiscover=%@", service, self.serviceUUIDsAndCharacteristicUUIDsToDiscover);
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

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    DLog(@"peripheral: %@ characteristic: %@ error: %@", peripheral, characteristic, error);
    
    if (error) {
	DLog(@"Characteristic update returned error: %@", error);
	return;
    }
    
    //DLog(@"characteristic.value: %@", characteristic.value);
    
    if (characteristic.value == nil) {
	ALog(@"Characteristic update with nil value (and no error)");
	return;
    }

    __block CMBluetoothCentralServiceConfiguration *matchingServiceConfiguration = nil;
    __strong CBService *cbService = characteristic.service;
    
    [self.requiredServiceConfigurations enumerateObjectsUsingBlock:^(CMBluetoothCentralServiceConfiguration *serviceConfiguration, __unused NSUInteger idx, BOOL *stop) {
	
	if ([cbService.UUID isEqual:serviceConfiguration.uuid]) {
	    for (CBUUID *characteristicUUID in [serviceConfiguration characteristicCBUUIDs]) {
		if ([characteristic.UUID isEqual:characteristicUUID]) {
		    matchingServiceConfiguration = serviceConfiguration;
		    *stop = YES;
		    break;
		}
	    }
	}
	
    }];

    if (matchingServiceConfiguration) {
	NSString *serviceIdentifier = matchingServiceConfiguration.identifier;
	NSString *characteristicIdentifier = [matchingServiceConfiguration characteristicIdentifierForUUID:characteristic.UUID];
	
	[self performCharacteristicUpdatedCallbackWithValue:characteristic.value characteristicIdentifier:characteristicIdentifier serviceIdentifier:serviceIdentifier];
    }
}

//- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
//- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
//- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
//- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
//- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error

@end
