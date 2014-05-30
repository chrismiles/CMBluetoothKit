//
//  CMBluetoothCentralController.m
//  NearPlayiOS
//
//  Created by Chris Miles on 6/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralController.h"
#import "CMBluetoothCentralDiscoveredPeripheral_Private.h"
#import "CMBluetoothCentralServiceConfiguration_Private.h"
@import CoreBluetooth;


NSString * const CMBluetoothCentralControllerErrorDomain = @"CMBluetoothCentralControllerErrorDomain";

static NSString *
NSStringFromCBCentralManagerState(CBCentralManagerState state);


@interface CMBluetoothCentralController () <CBCentralManagerDelegate>

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) dispatch_queue_t centralManagerQueue;

@property (strong, nonatomic) NSMapTable *discoveredPeripherals;  // (weak/weak) CBPeripheral -> CMBluetoothCentralDiscoveredPeripheral
@property (strong, nonatomic) NSMutableDictionary *fullyConnectedPeripherals; // CBPeripheral -> CMBluetoothCentralDiscoveredPeripheral

@property (strong, nonatomic) NSMutableDictionary *registeredServices;

/* Callback blocks
 */
@property (copy, nonatomic) void (^startScanningRequestCompletionBlock)(NSError *error);

@property (copy, nonatomic) CMBluetoothCentralControllerScanningStateChangeCallbackBlock scanningStateChangeCallback;
@property (copy, nonatomic) CMBluetoothCentralControllerPeripheralDiscoveredCallbackBlock peripheralDiscoveredCallback;
@property (copy, nonatomic) CMBluetoothCentralControllerPeripheralConnectionCallbackBlock peripheralConnectionCallback;

@end


@implementation CMBluetoothCentralController

- (id)init
{
    self = [super init];
    if (self) {
	_fullyConnectedPeripherals = [NSMutableDictionary dictionary];
	_registeredServices = [NSMutableDictionary dictionary];
        
        _discoveredPeripherals = [NSMapTable weakToWeakObjectsMapTable];
	
	_centralManagerQueue = dispatch_queue_create("info.chrismiles.NearPlay.CMBluetoothCentralController", DISPATCH_QUEUE_SERIAL);
	
	NSDictionary *options = nil; // TODO: support restoration
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:_centralManagerQueue options:options];
    }
    return self;
}


#pragma mark - Service Registration

- (void)registerServiceWithConfiguration:(CMBluetoothCentralServiceConfiguration *)serviceConfiguration
{
    [self.registeredServices setObject:serviceConfiguration forKey:serviceConfiguration.uuid];
}


#pragma mark - Scanning Control

- (void)setScanningEnabled:(BOOL)scanningEnabled
{
    if (scanningEnabled != _scanningEnabled) {
	_scanningEnabled = scanningEnabled;
        
	if (scanningEnabled) {
	    [self enableScanning];
	}
	else {
	    [self disableScanning];
	}
    }
}

- (void)enableScanning
{
    if ([self.registeredServices count] == 0) {
	NSException *exception = [NSException
				  exceptionWithName:@"NoServicesToScanForException"
				  reason:@"Scanning cannot start with no services registered"
				  userInfo:nil];
	@throw exception;
    }
    
    [self checkCentralManagerState];
}

- (void)disableScanning
{
    [self stopScanning];
}

- (BOOL)isScanning
{
    return (self.centralManager.state == CBCentralManagerStatePoweredOn && _scanningEnabled);
}

- (void)startScanningIfNeeded
{
    if (self.scanningEnabled) {
	__weak CMBluetoothCentralController *weakSelf = self;
	[self startScanningWithCompletion:^(NSError *error) {
	    __strong CMBluetoothCentralController *strongSelf = weakSelf;
	    [strongSelf performScanningStateChangeCallbackWithError:error];
	}];
    }
}

- (void)startScanningWithCompletion:(void (^)(NSError *error))completion
{
    self.startScanningRequestCompletionBlock = completion;

    NSArray *services = nil;

    if (self.discoverAllPeripheralsEnabled == NO)
    {
        services = [self CBUUIDsToScanFor];
    }
    NSDictionary *options = nil;
    [self.centralManager scanForPeripheralsWithServices:services options:options];
}

- (void)stopScanning
{
    DLog(@"Calling centralManager stopAdvertising");
    [self.centralManager stopScan];
    [self performScanningStateChangeCallbackWithError:nil];
}

- (void)performScanningStateChangeCallbackWithError:(NSError *)error
{
    void (^scanningStateChangeCallback)(BOOL isScanning, NSError *error) = [self.scanningStateChangeCallback copy];
    
    if (scanningStateChangeCallback) {
	dispatch_async(dispatch_get_main_queue(), ^{
	    scanningStateChangeCallback(self.isScanningEnabled, error);
	});
    }
}


#pragma mark - Central Manager State

- (void)checkCentralManagerState
{
    CBCentralManagerState state = self.centralManager.state;
    DLog(@"Central manager state: %@", NSStringFromCBCentralManagerState(state));

    if (state == CBCentralManagerStatePoweredOn) {
	[self startScanningIfNeeded];
    }
    else {
	[self stopScanning];
	
	if (state == CBCentralManagerStateUnsupported) {
	    NSError *error = [NSError errorWithDomain:CMBluetoothCentralControllerErrorDomain
						 code:CMBluetoothCentralControllerErrorUnsupported
					     userInfo:@{NSLocalizedDescriptionKey: @"Bluetooth LE is not supported by this device"}];
	    [self performScanningStateChangeCallbackWithError:error]; //TODO: necessary??
	}
	else if (state == CBCentralManagerStatePoweredOff) {
	    // Handle powered off state, for example if Bluetooth off or Airplane mode...
	    DLog(@"CBCentralManagerStatePoweredOff");
	    NSError *error = [NSError errorWithDomain:CMBluetoothCentralControllerErrorDomain
						 code:CMBluetoothCentralControllerErrorPoweredOff
					     userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Bluetooth is powered off or Airplane mode is enabled", @"Bluetooth is powered off or Airplane mode is enabled")}];
	    [self performScanningStateChangeCallbackWithError:error]; //TODO: necessary??
	}
	else {
	    DLog(@"Unhandled central state: %@", NSStringFromCBCentralManagerState(state));
	}
    }
}


- (NSArray *)CBUUIDsToScanFor
{
    return [self.registeredServices allKeys];
}


#pragma mark - Connected Peripherals

- (void)connectedPeripheralWasFullyDiscovered:(CMBluetoothCentralDiscoveredPeripheral *)discoveredPeripheral
{
    DLog(@"discoveredPeripheral: %@", discoveredPeripheral);
    discoveredPeripheral.fullyDiscovered = YES;
    
    self.fullyConnectedPeripherals[discoveredPeripheral.cbPeripheral] = discoveredPeripheral;
    
    __weak CMBluetoothCentralController *weakSelf = self;
    __weak CMBluetoothCentralDiscoveredPeripheral *weakDiscoveredPeripheral = discoveredPeripheral;
    discoveredPeripheral.servicesInvalidatedCallback = ^{
	__strong CMBluetoothCentralController *strongSelf = weakSelf;
	__strong CMBluetoothCentralDiscoveredPeripheral *strongDiscoveredPeripheral = weakDiscoveredPeripheral;
	DLog(@"Cancelling peripheral connection due to invalidated services: %@", strongDiscoveredPeripheral.cbPeripheral);
	[strongSelf.centralManager cancelPeripheralConnection:strongDiscoveredPeripheral.cbPeripheral];
    };
    
    [discoveredPeripheral startCharacteristicNotifications];
    
    [self performPeripheralConnectionCallbackWithDiscoveredPeripheral:discoveredPeripheral];
}

- (void)connectedPeripheralFailedServiceDiscovery:(CMBluetoothCentralDiscoveredPeripheral *)discoveredPeripheral withError:(NSError *)error
{
    DLog(@"discoveredPeripheral: %@ error: %@", discoveredPeripheral, error);
    [self.centralManager cancelPeripheralConnection:discoveredPeripheral.cbPeripheral];
}

- (void)connectPeripheral:(CMBluetoothCentralDiscoveredPeripheral *)discoveredPeripheral
{
    CBPeripheral *cbPeripheral = discoveredPeripheral.cbPeripheral;
    ZAssert(cbPeripheral != nil, @"discoveredPeripheral.cbPeripheral is nil");
    
    [self.centralManager connectPeripheral:cbPeripheral options:nil];
}

- (void)disconnectPeripheral:(CMBluetoothCentralDiscoveredPeripheral *)discoveredPeripheral
{
    CBPeripheral *cbPeripheral = discoveredPeripheral.cbPeripheral;
    ZAssert(cbPeripheral != nil, @"discoveredPeripheral.cbPeripheral is nil");
    
    [self.centralManager cancelPeripheralConnection:cbPeripheral];
}

- (void)performPeripheralDiscoveredCallbackWithDiscoveredPeripheral:(CMBluetoothCentralDiscoveredPeripheral *)discoveredPeripheral
{
    CMBluetoothCentralControllerPeripheralDiscoveredCallbackBlock peripheralDiscoveredCallback = [self.peripheralDiscoveredCallback copy];

    if (peripheralDiscoveredCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            peripheralDiscoveredCallback(discoveredPeripheral);
        });
    }
}

- (void)performPeripheralConnectionCallbackWithDiscoveredPeripheral:(CMBluetoothCentralDiscoveredPeripheral *)discoveredPeripheral
{
    CMBluetoothCentralControllerPeripheralConnectionCallbackBlock peripheralConnectionCallback = [self.peripheralConnectionCallback copy];
    
    if (peripheralConnectionCallback) {
	dispatch_async(dispatch_get_main_queue(), ^{
	    peripheralConnectionCallback(discoveredPeripheral, discoveredPeripheral.isConnected);
	});
    }
}


#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    DLog(@"central: %@", central);
    [self checkCentralManagerState];
}

//- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary *)dict;

//- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals;

//- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals;

- (void)centralManager:(__unused CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)cbPeripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    DLog(@"cbPeripheral: %@ advertisementData: %@ RSSI:%@", cbPeripheral, advertisementData, RSSI);
    DLog(@"self.discoveredPeripherals (before): %@", self.discoveredPeripherals);
    
    CMBluetoothCentralDiscoveredPeripheral *discoveredPeripheral = [self.discoveredPeripherals objectForKey:cbPeripheral];
    if (discoveredPeripheral == nil) {
	discoveredPeripheral = [[CMBluetoothCentralDiscoveredPeripheral alloc] initWithCBPeripheral:cbPeripheral advertisementData:advertisementData];
	[self.discoveredPeripherals setObject:discoveredPeripheral forKey:cbPeripheral];
    }
    else {
	// This can be called multiple times as new advertisementData is received
	DLog(@"Updating advertisementData for peripheral: %@", cbPeripheral);
	[discoveredPeripheral updateAdvertisementData:advertisementData];
        [discoveredPeripheral setLastSeenDate:[NSDate date]];
    }
    
    [self performPeripheralDiscoveredCallbackWithDiscoveredPeripheral:discoveredPeripheral];
    
    DLog(@"self.discoveredPeripherals (after): %@", self.discoveredPeripherals);
    DLog(@"self.fullyConnectedPeripherals: %@", self.fullyConnectedPeripherals);
}

- (void)centralManager:(__unused CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)cbPeripheral
{
    DLog(@"cbPeripheral: %@", cbPeripheral);
    
    CMBluetoothCentralDiscoveredPeripheral *discoveredPeripheral = [self.discoveredPeripherals objectForKey:cbPeripheral];
    if (discoveredPeripheral) {
	discoveredPeripheral.connected = YES;

	__weak CMBluetoothCentralController *weakSelf = self;
	
	[discoveredPeripheral discoverServices:[self.registeredServices allValues] withCompletion:^(NSError *error){
	    __strong CMBluetoothCentralController *strongSelf = weakSelf;
	    
	    if (error) {
		[strongSelf connectedPeripheralFailedServiceDiscovery:discoveredPeripheral withError:error];
	    }
	    else {
		[strongSelf connectedPeripheralWasFullyDiscovered:discoveredPeripheral];
	    }
	}];
    }
    else {
	ALog(@"Connected peripheral that is not in discoveredPeripherals: %@", cbPeripheral);
    }
    
    DLog(@"self.discoveredPeripherals: %@", self.discoveredPeripherals);
    DLog(@"self.fullyConnectedPeripherals: %@", self.fullyConnectedPeripherals);
}

- (void)centralManager:(__unused CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)cbPeripheral error:(NSError *)error
{
    DLog(@"cbPeripheral: %@ error: %@", cbPeripheral, error);
    
    CMBluetoothCentralDiscoveredPeripheral *discoveredPeripheral = [self.discoveredPeripherals objectForKey:cbPeripheral];
    if (discoveredPeripheral) {
        // Notify client
        [self performPeripheralConnectionCallbackWithDiscoveredPeripheral:discoveredPeripheral];
    }
    else {
	ALog(@"Connected peripheral that is not in discoveredPeripherals: %@", cbPeripheral);
    }
}

- (void)centralManager:(__unused CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)cbPeripheral error:(NSError *)error
{
    DLog(@"cbPeripheral: %@ error: %@", cbPeripheral, error);

    CMBluetoothCentralDiscoveredPeripheral *discoveredPeripheral = [self.discoveredPeripherals objectForKey:cbPeripheral];
    if (discoveredPeripheral) {
	discoveredPeripheral.connected = NO;
	
	if (discoveredPeripheral.isFullyDiscovered) {
	    [self performPeripheralConnectionCallbackWithDiscoveredPeripheral:discoveredPeripheral];
	}
	
        [self.fullyConnectedPeripherals removeObjectForKey:discoveredPeripheral.cbPeripheral];
	//[self.discoveredPeripherals removeObjectForKey:discoveredPeripheral.cbPeripheral];
    }
    else {
	ALog(@"Connected peripheral that is not in discoveredPeripherals: %@", cbPeripheral);
    }
    
    DLog(@"self.discoveredPeripherals: %@", self.discoveredPeripherals);
    DLog(@"self.fullyConnectedPeripherals: %@", self.fullyConnectedPeripherals);
}

@end



static NSString *
NSStringFromCBCentralManagerState(CBCentralManagerState state)
{
    NSString *result = nil;
    
    if (state == CBCentralManagerStatePoweredOn) result = @"CBCentralManagerStatePoweredOn";
    else if (state == CBCentralManagerStatePoweredOff) result = @"CBCentralManagerStatePoweredOff";
    else if (state == CBCentralManagerStateResetting) result = @"CBCentralManagerStateResetting";
    else if (state == CBCentralManagerStateUnauthorized) result = @"CBCentralManagerStateUnauthorized";
    else if (state == CBCentralManagerStateUnknown) result = @"CBCentralManagerStateUnknown";
    else if (state == CBCentralManagerStateUnsupported) result = @"CBCentralManagerStateUnsupported";
    else result = @"(Unknown Value)";
    return result;
}
