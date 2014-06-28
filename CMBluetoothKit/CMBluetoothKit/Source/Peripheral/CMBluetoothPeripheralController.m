//
//  CMBluetoothPeripheralController.m
//  NearPlayiOS
//
//  Created by Chris Miles on 25/07/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothPeripheralController.h"
#import "CMBluetoothPeripheralService.h"

#if TARGET_OS_IPHONE
    @import CoreBluetooth;
    @import UIKit;
#else
    @import IOBluetooth;
#endif


NSString * const CMBluetoothPeripheralControllerErrorDomain = @"CMBluetoothPeripheralControllerErrorDomain";


static NSString *
NSStringFromCBPeripheralManagerState(CBPeripheralManagerState state);



@interface CMBluetoothPeripheralController () <CBPeripheralManagerDelegate>

@property (strong, nonatomic) NSMutableArray *pendingNotifyUpdates;
@property (strong, nonatomic) NSMutableDictionary *services;    // NSString -> CMBluetoothPeripheralService

@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) dispatch_queue_t peripheralManagerQueue;

/* State
 */
@property (assign, atomic) NSInteger countOfServicesToAdd;
@property (assign, atomic) BOOL isPreparingToStartAdvertising;

/* Callback blocks
 */
@property (copy, nonatomic) void (^allServicesAddedCompletionBlock)(NSError *error);
@property (copy, nonatomic) void (^startAdvertisingRequestCompletionBlock)(NSError *error);

@end


@implementation CMBluetoothPeripheralController

- (id)init
{
    self = [super init];
    if (self) {
	_pendingNotifyUpdates = [NSMutableArray array];
        _services = [NSMutableDictionary dictionary];
	_peripheralManagerQueue = dispatch_queue_create("info.chrismiles.NearPlay.CMBluetoothPeripheralController", DISPATCH_QUEUE_SERIAL);
	
	CBPeripheralManager *peripheralManager = [CBPeripheralManager alloc];
	if ([peripheralManager respondsToSelector:@selector(initWithDelegate:queue:options:)]) {
	    NSDictionary *options = NULL; // TODO: support restoration
	    _peripheralManager = [peripheralManager initWithDelegate:self queue:_peripheralManagerQueue options:options];
	}
	else {
	    _peripheralManager = [peripheralManager initWithDelegate:self queue:_peripheralManagerQueue];
	}
    }
    return self;
}


#pragma mark - Add Service

- (void)addServiceWithUUID:(NSString *)UUID
{
    CMBluetoothPeripheralService *service = [[CMBluetoothPeripheralService alloc] initWithUUID:UUID primary:YES];
    self.services[UUID] = service;
}


#pragma mark - Add Characteristics

- (void)addToServiceWithUUID:(NSString *)serviceUUID readOnlyCharacteristicWithUUID:(NSString *)characteristicUUID request:(NSData *(^)(void))requestBlock
{
    [self addToServiceWithUUID:serviceUUID readOnlyCharacteristicWithUUID:characteristicUUID request:requestBlock allowNotify:NO];
}

- (void)addToServiceWithUUID:(NSString *)serviceUUID readOnlyCharacteristicWithUUID:(NSString *)characteristicUUID request:(NSData *(^)(void))requestBlock  allowNotify:(BOOL)allowNotify
{
    CMBluetoothPeripheralService *service = self.services[serviceUUID];
    if (service == nil) {
	NSException *exception = [NSException
				  exceptionWithName:@"ServiceNotFoundException"
				  reason:@"No service exists with the specified UUID"
				  userInfo:nil];
	@throw exception;
    }
    
    [service addCharacteristicWithUUID:characteristicUUID readRequest:requestBlock writeRequest:nil allowNotify:allowNotify];
}

- (void)addToServiceWithUUID:(NSString *)serviceUUID writeOnlyCharacteristicWithUUID:(NSString *)characteristicUUID request:(BOOL(^)(NSData *value))requestBlock
{
    CMBluetoothPeripheralService *service = self.services[serviceUUID];
    if (service == nil) {
	NSException *exception = [NSException
				  exceptionWithName:@"ServiceNotFoundException"
				  reason:@"No service exists with the specified UUID"
				  userInfo:nil];
	@throw exception;
    }
    
    [service addCharacteristicWithUUID:characteristicUUID readRequest:nil writeRequest:requestBlock allowNotify:NO];
}


#pragma mark - Advertise

- (void)setAdvertisingEnabled:(BOOL)advertisingEnabled
{
    if (advertisingEnabled != _advertisingEnabled) {
	_advertisingEnabled = advertisingEnabled;

	if (advertisingEnabled) {
	    if ([self enableAdvertising] == NO) return;
	}
	else {
	    [self disableAdvertising];
	}
    }
}

// TODO: probably doesn't need to return BOOL anymore
- (BOOL)enableAdvertising
{
    if ([self.services count] == 0) {
	NSException *exception = [NSException
				  exceptionWithName:@"NoServicesToAdvertiseException"
				  reason:@"Advertising cannot start with no services configured"
				  userInfo:nil];
	@throw exception;
	return NO; // redundant I know
    }

    [self checkPeripheralManagerState];
    
    return YES;
}

- (void)disableAdvertising
{
    [self stopAdvertisingAndClearServices];
    
    [self waitForAdvertisingStoppedWithTimeout:60.0 completion:^(NSError *error){
	[self performAdvertisingStateChangeCallbackWithError:error];
    }];
}

- (BOOL)isAdvertising
{
    return (self.peripheralManager.state == CBPeripheralManagerStatePoweredOn && self.peripheralManager.isAdvertising);
}


#pragma mark - Notify

// TODO: return BOOL useful??
- (BOOL)notifyUpdatedValueForServiceWithUUID:(NSString *)serviceUUID forCharacteristicWithUUID:(NSString *)characteristicUUID
{
    if (self.peripheralManager.isAdvertising == NO) {
        DLog(@"Cannot notify, peripheral is not advertising");
        return NO;
    }

    CMBluetoothPeripheralService *service = self.services[serviceUUID];
    if (service == nil) {
	NSException *exception = [NSException
				  exceptionWithName:@"ServiceNotFoundException"
				  reason:@"No service found with specified UUID"
				  userInfo:nil];
	@throw exception;
    }

    CMBluetoothPeripheralCharacteristic *characteristic = [service characteristicWithUUID:characteristicUUID];
    if (characteristicUUID == nil) {
	NSException *exception = [NSException
				  exceptionWithName:@"CharacteristicNotFoundException"
				  reason:@"No characteristic found with specified UUID in service"
				  userInfo:nil];
	@throw exception;
    }
    
    NSData *value = [characteristic valueForReadRequest];
    
    [self notifyUpdatedValue:value forCharacteristic:characteristic.cbMutableCharacteristic];
    return YES;
}

- (void)notifyUpdatedValue:(NSData *)value forServiceWithUUID:(NSString *)serviceUUID forCharacteristicWithUUID:(NSString *)characteristicUUID
{
    CMBluetoothPeripheralService *service = self.services[serviceUUID];
    if (service == nil) {
	NSException *exception = [NSException
				  exceptionWithName:@"ServiceNotFoundException"
				  reason:@"No service found with specified UUID"
				  userInfo:nil];
	@throw exception;
    }
    
    CMBluetoothPeripheralCharacteristic *characteristic = [service characteristicWithUUID:characteristicUUID];
    if (characteristicUUID == nil) {
	NSException *exception = [NSException
				  exceptionWithName:@"CharacteristicNotFoundException"
				  reason:@"No characteristic found with specified UUID in service"
				  userInfo:nil];
	@throw exception;
    }
    
    CBMutableCharacteristic *cbMutableCharacteristic = characteristic.cbMutableCharacteristic;
    [self notifyUpdatedValue:value forCharacteristic:cbMutableCharacteristic];
}

- (void)notifyUpdatedValue:(NSData *)value forCharacteristic:(CBMutableCharacteristic *)cbMutableCharacteristic
{
    DLog(@"Update value %@ for characteristic: %@", value, cbMutableCharacteristic);
    BOOL result = [self.peripheralManager updateValue:value forCharacteristic:cbMutableCharacteristic onSubscribedCentrals:nil];
    
    if (result == NO)
    {
	// If the method returns NO because the underlying transmit queue is full, the peripheral manager calls the peripheralManagerIsReadyToUpdateSubscribers: method of its delegate object when more space in the transmit queue becomes available. After this delegate method is called, you may resend the update.
	
	ZAssert(self.pendingNotifyUpdates != nil, @"self.pendingNotifyUpdates is nil");
	
	dispatch_async(self.peripheralManagerQueue, ^{
	    //NSDictionary *queuedNotify = @{@"value": value, @"serviceUUID": serviceUUID, @"characteristicUUID": characteristicUUID};
	    NSDictionary *queuedNotify = @{@"value": value, @"cbMutableCharacteristic": cbMutableCharacteristic};
	    DLog(@"Queueing for retransmit after notify queue frees up: %@", queuedNotify);
	    [self.pendingNotifyUpdates addObject:queuedNotify];
	});
    }
}


#pragma mark - CoreBluetooth Integration

/*
    Internal CoreBluetooth Integration
 */

- (void)stopAdvertisingAndClearServices
{
    if (self.peripheralManager.isAdvertising) {
	DLog(@"Calling peripheralManager stopAdvertising");
	[self.peripheralManager stopAdvertising];
    }
    
    [self removeServicesFromPeripheralManager];
}

- (void)waitForAdvertisingStoppedWithTimeout:(NSTimeInterval)timeout completion:(void (^)(NSError *error))completion
{
    if (self.isAdvertising == NO) {
	if (completion) completion(nil);
    }
    else if (timeout <= 0.0) {
	if (completion) {
	    NSError *error = [NSError errorWithDomain:CMBluetoothPeripheralControllerErrorDomain
						 code:CMBluetoothPeripheralControllerErrorTimeout
					     userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Timed out waiting for advertising to stop", @"Timed out waiting for advertising to stop")}];
	    completion(error);
	}
    }
    else {
	double delayInSeconds = 0.2;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
	    [self waitForAdvertisingStoppedWithTimeout:(timeout - delayInSeconds) completion:completion];
	});
    }
}

- (void)checkPeripheralManagerState
{
    DLog(@"Peripheral manager state: %@", NSStringFromCBPeripheralManagerState(self.peripheralManager.state));
    
    if (self.peripheralManager.state == CBPeripheralManagerStatePoweredOn) {
	[self startAdvertisingIfNeeded];
    }
    else {
	[self stopAdvertisingAndClearServices];

	if (self.peripheralManager.state == CBPeripheralManagerStateUnsupported) {
	    NSError *error = [NSError errorWithDomain:CMBluetoothPeripheralControllerErrorDomain
						 code:CMBluetoothPeripheralControllerErrorUnsupported
					     userInfo:@{NSLocalizedDescriptionKey: @"Bluetooth LE is not supported by this device"}];
	    [self performAdvertisingStateChangeCallbackWithError:error]; //TODO: necessary??
	}
	else if (self.peripheralManager.state == CBPeripheralManagerStatePoweredOff) {
	    // Handle powered off state, for example if Bluetooth off or Airplane mode...
	    DLog(@"CBPeripheralManagerStatePoweredOff");
	    NSError *error = [NSError errorWithDomain:CMBluetoothPeripheralControllerErrorDomain
						 code:CMBluetoothPeripheralControllerErrorPoweredOff
					     userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Bluetooth is powered off or Airplane mode is enabled", @"Bluetooth is powered off or Airplane mode is enabled")}];
	    [self performAdvertisingStateChangeCallbackWithError:error]; //TODO: necessary??
	}
	else {
	    DLog(@"Unhandled peripheral state: %@", NSStringFromCBPeripheralManagerState(self.peripheralManager.state));
	}
    }
}

- (void)startAdvertisingIfNeeded
{
    if (self.advertisingEnabled) {
	if (self.peripheralManager.isAdvertising == NO) {
	    __weak CMBluetoothPeripheralController *weakSelf = self;
	    [self startAdvertisingWithCompletion:^(NSError *error) {
		__strong CMBluetoothPeripheralController *strongSelf = weakSelf;
		[strongSelf performAdvertisingStateChangeCallbackWithError:error];
	    }];
	}
    }
}

- (void)startAdvertisingWithCompletion:(void (^)(NSError *error))completion
{
    if (self.peripheralManager.isAdvertising) {
	if (completion) {
	    NSDictionary *userInfo = @{@"reason": @"Bluetooth peripheral is already advertising"};
	    NSError *error = [NSError errorWithDomain:CMBluetoothPeripheralControllerErrorDomain code:CMBluetoothPeripheralControllerErrorAlreadyAdvertising userInfo:userInfo];
	    completion(error);
	}
	return;
    }

    __weak CMBluetoothPeripheralController *weakSelf = self;
    
    self.allServicesAddedCompletionBlock = ^(NSError *error){
	if (error) {
	    if (completion) completion(error);
	}
	else {
	    __strong CMBluetoothPeripheralController *strongSelf = weakSelf;
	    
	    strongSelf.startAdvertisingRequestCompletionBlock = completion;
	    
	    NSMutableArray *serviceUUIDObjects = [NSMutableArray array];
	    [strongSelf.services enumerateKeysAndObjectsUsingBlock:^(__unused NSString *key, CMBluetoothPeripheralService *service, __unused BOOL *stop) {
		[serviceUUIDObjects addObject:service.CBUUID];
	    }];
	    
	    NSString *advertisedLocalName = strongSelf.advertisedLocalName;
	    if (advertisedLocalName == nil) advertisedLocalName = [[UIDevice currentDevice] name];
	    NSDictionary *advertisementData = @{
						CBAdvertisementDataLocalNameKey: advertisedLocalName,
						CBAdvertisementDataServiceUUIDsKey: serviceUUIDObjects,
						};
	    DLog(@"Start advertising with data: %@", advertisementData);
	    [strongSelf.peripheralManager startAdvertising:advertisementData];
	}
    };
    
    [self addServicesToPeripheralManager];
}

- (void)performAdvertisingStateChangeCallbackWithError:(NSError *)error
{
    void (^advertisingStateChangeCallback)(BOOL isAdvertising, NSError *error) = [self.advertisingStateChangeCallback copy];
    
    if (advertisingStateChangeCallback) {
	dispatch_async(dispatch_get_main_queue(), ^{
	    advertisingStateChangeCallback(self.isAdvertising, error);
	});
    }
}

- (void)addServicesToPeripheralManager
{
    DLog(@"Adding %lu services to peripheral manager", (unsigned long)[self.services count]);
    
    self.countOfServicesToAdd = 0;
    
    [self.services enumerateKeysAndObjectsUsingBlock:^(__unused NSString *key, CMBluetoothPeripheralService *service, __unused BOOL *stop) {
	self.countOfServicesToAdd += 1;
	[service addToPeripheralManager:self.peripheralManager];
    }];
}

- (void)removeServicesFromPeripheralManager
{
    DLog(@"Remove services from peripheral manager");
    [self.services enumerateKeysAndObjectsUsingBlock:^(__unused NSString *key, CMBluetoothPeripheralService *service, __unused BOOL *stop) {
	[service removeFromPeripheralManager:self.peripheralManager];
    }];
}

- (CMBluetoothPeripheralService *)peripheralServiceForCBService:(CBService *)cbService
{
    __block CMBluetoothPeripheralService *result = nil;
    
    [self.services enumerateKeysAndObjectsUsingBlock:^(__unused id key, CMBluetoothPeripheralService *peripheralService, BOOL *stop) {
	if (peripheralService.cbMutableService == cbService) {
	    result = peripheralService;
	    *stop = YES;
	}
    }];
    
    return result;
}


#pragma mark - CBPeripheralManagerDelegate

/* NOTE: All these callbacks are on our custom dispatch queue
 */

- (void)peripheralManagerDidUpdateState:(__unused CBPeripheralManager *)peripheral
{
    [self checkPeripheralManagerState];
}

//TODO: - (void)peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary *)dict;

- (void)peripheralManager:(__unused CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    DLog(@"service: %@ error: %@", service, error);
    
    if (error == nil) {
	self.countOfServicesToAdd -= 1;
	DLog(@"countOfServicesToAdd: %ld", (long)self.countOfServicesToAdd);
	if (self.countOfServicesToAdd > 0) {
	    return;
	}
    }
    
    if (self.allServicesAddedCompletionBlock) {
	self.allServicesAddedCompletionBlock(error);
	self.allServicesAddedCompletionBlock = nil;
    }
}

- (void)peripheralManagerDidStartAdvertising:(__unused CBPeripheralManager *)peripheral error:(NSError *)error
{
    if (self.startAdvertisingRequestCompletionBlock) {
	dispatch_async(dispatch_get_main_queue(), ^{
	    self.startAdvertisingRequestCompletionBlock(error);
	    self.startAdvertisingRequestCompletionBlock = nil;
	});
    }
}

//TODO: - (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic;

//TODO: - (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic;

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    CBCharacteristic *cbCharacteristic = request.characteristic;
    CBService *cbService = cbCharacteristic.service;
    CMBluetoothPeripheralService *service = [self peripheralServiceForCBService:cbService];

    CMBluetoothPeripheralCharacteristic *characteristic = [service peripheralCharacteristicForCBCharacteristic:cbCharacteristic];
    if (service == nil) {
	DLog(@"Unsupported read request (no characteristic found): %@ -- responding with: CBATTErrorRequestNotSupported", request);
	[peripheral respondToRequest:request withResult:CBATTErrorRequestNotSupported];
	return;
    }

    NSData *value = [characteristic valueForReadRequest];
    
    CBATTError responseResult = CBATTErrorSuccess;
    
    if (value) {
	if (request.offset > 0) {
	    if (request.offset < [value length]) {
		NSRange range = NSMakeRange(request.offset, [value length] - request.offset);
		value = [value subdataWithRange:range];
	    }
	    else {
		value = nil;
		responseResult = CBATTErrorInvalidOffset;
	    }
	}
    }
    else {
	responseResult = CBATTErrorRequestNotSupported;
    }

    request.value = value;
    
#ifdef DEBUG
    if (responseResult != CBATTErrorSuccess) DLog(@"** Error response ** respondToRequest: %@ withResult: %ld", request, (long)responseResult);
#endif

    [peripheral respondToRequest:request withResult:responseResult];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    for (CBATTRequest *request in requests) {
	CBCharacteristic *cbCharacteristic = request.characteristic;
	CBService *cbService = cbCharacteristic.service;
	
	CMBluetoothPeripheralService *service = [self peripheralServiceForCBService:cbService];
	if (service == nil) {
	    DLog(@"Unsupported write request: %@", request);
	    [peripheral respondToRequest:request withResult:CBATTErrorRequestNotSupported];
	}

	CMBluetoothPeripheralCharacteristic *characteristic = [service peripheralCharacteristicForCBCharacteristic:cbCharacteristic];
	if (service == nil) {
	    DLog(@"Unsupported write request: %@", request);
	    [peripheral respondToRequest:request withResult:CBATTErrorRequestNotSupported];
	}
	
	BOOL success = [characteristic writeRequestWithValue:request.value];
	
	if (success) {
	    [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
	}
	else {
	    [peripheral respondToRequest:request withResult:CBATTErrorUnlikelyError];
	}
    }
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(__unused CBPeripheralManager *)peripheral
{
    NSArray *notifyUpdates = [self.pendingNotifyUpdates copy];
    [self.pendingNotifyUpdates removeAllObjects];
    
    for (NSDictionary *queuedNotify in notifyUpdates) {
	
	DLog(@"Re-trying notifyUpdateValue: %@", queuedNotify);
	
	NSData *value = queuedNotify[@"value"];
        CBMutableCharacteristic *cbMutableCharacteristic = queuedNotify[@"cbMutableCharacteristic"];
        /*
	NSString *serviceUUID = queuedNotify[@"serviceUUID"];
	NSString *characteristicUUID = queuedNotify[@"characteristicUUID"];
	[self notifyUpdatedValue:value forServiceWithUUID:serviceUUID forCharacteristicWithUUID:characteristicUUID];
         */
        
        [self notifyUpdatedValue:value forCharacteristic:cbMutableCharacteristic];
    }
}

@end


static NSString *
NSStringFromCBPeripheralManagerState(CBPeripheralManagerState state)
{
    NSString *result = nil;
    
    if (state == CBPeripheralManagerStatePoweredOn) result = @"CBPeripheralManagerStatePoweredOn";
    else if (state == CBPeripheralManagerStatePoweredOff) result = @"CBPeripheralManagerStatePoweredOff";
    else if (state == CBPeripheralManagerStateResetting) result = @"CBPeripheralManagerStateResetting";
    else if (state == CBPeripheralManagerStateUnauthorized) result = @"CBPeripheralManagerStateUnauthorized";
    else if (state == CBPeripheralManagerStateUnknown) result = @"CBPeripheralManagerStateUnknown";
    else if (state == CBPeripheralManagerStateUnsupported) result = @"CBPeripheralManagerStateUnsupported";
    else result = @"(Unknown Value)";
    return result;
}
