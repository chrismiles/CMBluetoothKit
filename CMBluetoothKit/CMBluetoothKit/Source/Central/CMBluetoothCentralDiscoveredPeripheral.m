//
//  CMBluetoothCentralDiscoveredPeripheral.m
//  NearPlayiOS
//
//  Created by Chris Miles on 8/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralDiscoveredPeripheral.h"
#import "CMBluetoothCentralDiscoveredPeripheral_Private.h"
#import "CMBluetoothCentralServiceConfiguration_Private.h"

NSString * const CMBluetoothCentralDiscoveredPeripheralErrorDomain = @"CMBluetoothCentralDiscoveredPeripheralErrorDomain";


@implementation CMBluetoothCentralDiscoveredPeripheral

- (id)initWithCBPeripheral:(CBPeripheral *)cbPeripheral advertisementData:(NSDictionary *)advertisementData
{
    self = [super init];
    if (self) {
	_advertisementData = advertisementData;
        _cbPeripheral = cbPeripheral;
        
        _peripheralWriteCompletionCallbacks = [NSMutableDictionary dictionary];
	
	cbPeripheral.delegate = self;
    }
    return self;
}

- (NSUUID *)identifier
{
    return self.cbPeripheral.identifier;
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

- (void)performCharacteristicUpdatedCallbackWithValue:(id)value characteristicIdentifier:(NSString *)characteristicIdentifier serviceIdentifier:(NSString *)serviceIdentifier
{
    void (^characteristicValueUpdatedCallback)(NSString *serviceIdentifier, NSString *characteristicIdentifier, id value) = [self.characteristicValueUpdatedCallback copy];
    
    if (characteristicValueUpdatedCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            characteristicValueUpdatedCallback(serviceIdentifier, characteristicIdentifier, value);
        });
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

- (void)readValueForCharacteristicWithIdentifier:(NSString *)characteristicIdentifier serviceIdentifier:(NSString *)serviceIdentifier
{
    CMBluetoothCentralServiceConfiguration *serviceConfiguration = [self serviceConfigurationForIdentifier:serviceIdentifier];
    CBUUID *serviceUUID = serviceConfiguration.uuid;
    CBUUID *characteristicUUID = [serviceConfiguration characteristicUUIDForIdentifier:characteristicIdentifier];
    [self readValueForCharacteristicUUID:characteristicUUID serviceUUID:serviceUUID];
}

- (void)readValueForCharacteristicUUID:(CBUUID *)characteristicUUID serviceUUID:(CBUUID *)serviceUUID
{
    CBService *cbService = [self cbServiceWithServiceUUID:serviceUUID];
    CBCharacteristic *cbCharacteristic = [self cbCharacteristicForCBService:cbService withCharacteristicUUID:characteristicUUID];
    [self.cbPeripheral readValueForCharacteristic:cbCharacteristic];
}

- (CMBluetoothCentralServiceConfiguration *)serviceConfigurationForIdentifier:(NSString *)identifier
{
    CMBluetoothCentralServiceConfiguration *result = nil;
    for (CMBluetoothCentralServiceConfiguration *serviceConfiguration in self.requiredServiceConfigurations) {
	if ([serviceConfiguration.identifier isEqualToString:identifier]) {
	    result = serviceConfiguration;
	    break;
	}
    }
    return result;
}

- (CBService *)cbServiceWithServiceUUID:(CBUUID *)serviceUUID
{
    CBService *result = nil;
    for (CBService *service in self.cbPeripheral.services) {
	if ([service.UUID isEqual:serviceUUID]) {
	    result = service;
	    break;
	}
    }
    return result;
}

- (CBCharacteristic *)cbCharacteristicForCBService:(CBService *)cbService withCharacteristicUUID:(CBUUID *)characteristicUUID
{
    CBCharacteristic *result = nil;
    for (CBCharacteristic *characteristic in cbService.characteristics) {
	if ([characteristic.UUID isEqual:characteristicUUID]) {
	    result = characteristic;
	    break;
	}
    }
    return result;
}

- (void)writeValue:(id)value toCharacteristicWithIdentifier:(NSString *)characteristicIdentifier serviceIdentifier:(NSString *)serviceIdentifier completion:(void (^)(NSError *error))completion
{
    CMBluetoothCentralServiceConfiguration *serviceConfiguration = [self serviceConfigurationForIdentifier:serviceIdentifier];
    CBUUID *serviceUUID = serviceConfiguration.uuid;
    CBUUID *characteristicUUID = [serviceConfiguration characteristicUUIDForIdentifier:characteristicIdentifier];
    
    NSData *data = [serviceConfiguration packDataWithValue:value forCharacteristicUUID:characteristicUUID];
    
    [self writeData:data toCharacteristicWithUUID:characteristicUUID serviceUUID:serviceUUID completion:completion];
}

- (void)writeData:(NSData *)data toCharacteristicWithUUID:(CBUUID *)characteristicUUID serviceUUID:(CBUUID *)serviceUUID completion:(void (^)(NSError *error))completion
{
    CBService *cbService = [self cbServiceWithServiceUUID:serviceUUID];
    CBCharacteristic *cbCharacteristic = [self cbCharacteristicForCBService:cbService withCharacteristicUUID:characteristicUUID];
    
    [self setPeripheralWriteCompletionCallback:completion forCBCharacteristic:cbCharacteristic];
    
    [self.cbPeripheral writeValue:data forCharacteristic:cbCharacteristic type:CBCharacteristicWriteWithResponse];
}

- (void)startCharacteristicNotifications
{
    for (CMBluetoothCentralServiceConfiguration *serviceConfiguration in self.requiredServiceConfigurations) {
        CBService *cbService = [self cbServiceWithServiceUUID:serviceConfiguration.uuid];
        
        NSSet *characteristicUUIDs = [serviceConfiguration characteristicUUIDsWithNotifyEnabled];
        
        for (CBUUID *characteristicUUID in characteristicUUIDs) {

            CBCharacteristic *cbCharacteristic = [self cbCharacteristicForCBService:cbService withCharacteristicUUID:characteristicUUID];
            
            DLog(@"Enabling notify for characteristic: %@", cbCharacteristic);
            [self.cbPeripheral setNotifyValue:YES forCharacteristic:cbCharacteristic];
        }
    }
}


#pragma mark - Peripheral Write Completion Callback Management

- (void)setPeripheralWriteCompletionCallback:(void (^)(NSError *error))completion forCBCharacteristic:(CBCharacteristic *)cbCharacteristic
{
    NSString *key = [self peripheralWriteCompletionCallbackKeyForCBCharacteristic:cbCharacteristic];
    if (completion == nil) {
        [self.peripheralWriteCompletionCallbacks removeObjectForKey:key];
    }
    else {
        self.peripheralWriteCompletionCallbacks[key] = [completion copy];
    }
}

- (void (^)(NSError *error))peripheralWriteCompletionCallbackForCBCharacteristic:(CBCharacteristic *)cbCharacteristic
{
    NSString *key = [self peripheralWriteCompletionCallbackKeyForCBCharacteristic:cbCharacteristic];
    return self.peripheralWriteCompletionCallbacks[key];
}

- (NSString *)peripheralWriteCompletionCallbackKeyForCBCharacteristic:(CBCharacteristic *)cbCharacteristic
{
    // Generate a key that uniquely identifies the specific characteristic in the specific service
    NSString *key = [NSString stringWithFormat:@"%p", cbCharacteristic];
    return key;
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
	NSError *zeroServicesError = [NSError errorWithDomain:CMBluetoothCentralDiscoveredPeripheralErrorDomain
							 code:CMBluetoothCentralDiscoveredPeripheralErrorNoServices
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
    
    ZAssert(peripheral == self.cbPeripheral, @"CBPeripheral mismatch");

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
        
        id value = [matchingServiceConfiguration unpackValueWithData:characteristic.value forCharacteristicUUID:characteristic.UUID];
	
	[self performCharacteristicUpdatedCallbackWithValue:value characteristicIdentifier:characteristicIdentifier serviceIdentifier:serviceIdentifier];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    DLog(@"peripheral: %@ characteristic: %@ error: %@", peripheral, characteristic, error);

    ZAssert(peripheral == self.cbPeripheral, @"CBPeripheral mismatch");
    
    void (^completion)(NSError *error) = [self peripheralWriteCompletionCallbackForCBCharacteristic:characteristic];
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
        
        [self setPeripheralWriteCompletionCallback:nil forCBCharacteristic:characteristic];
    }
}

//- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
//- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
//- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
//- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error

@end
