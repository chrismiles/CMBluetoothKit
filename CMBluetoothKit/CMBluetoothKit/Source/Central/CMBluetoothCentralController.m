//
//  CMBluetoothCentralController.m
//  NearPlayiOS
//
//  Created by Chris Miles on 6/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralController.h"
#import "CMBluetoothCentralConnectedPeripheral_Private.h"
@import CoreBluetooth;


NSString * const CMBluetoothCentralControllerErrorDomain = @"CMBluetoothCentralControllerErrorDomain";

static NSString *
NSStringFromCBCentralManagerState(CBCentralManagerState state);


@interface CMBluetoothCentralController () <CBCentralManagerDelegate>

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) dispatch_queue_t centralManagerQueue;

@property (strong, nonatomic) NSMutableDictionary *discoveredPeripherals; // CBPeripheral -> CMBluetoothCentralConnectedPeripheral
@property (strong, nonatomic) NSMutableDictionary *servicesToScanFor;

/* Callback blocks
 */
@property (copy, nonatomic) void (^startScanningRequestCompletionBlock)(NSError *error);

@end


@implementation CMBluetoothCentralController

- (id)init
{
    self = [super init];
    if (self) {
	_discoveredPeripherals = [NSMutableDictionary dictionary];
	_servicesToScanFor = [NSMutableDictionary dictionary];
	
	_centralManagerQueue = dispatch_queue_create("info.chrismiles.NearPlay.CMBluetoothCentralController", DISPATCH_QUEUE_SERIAL);
	
	NSDictionary *options = nil; // TODO: support restoration
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:_centralManagerQueue options:options];
    }
    return self;
}


#pragma mark - Service Registration

- (void)addServiceWithUUID:(NSString *)serviceUUID characteristicUUIDs:(NSArray *)characteristicUUIDs
{
    CBUUID *serviceCBUUID = [CBUUID UUIDWithString:serviceUUID];
    ZAssert(serviceCBUUID != nil, @"service UUID could not be converted to CBUUID");
    
    NSMutableArray *characteristicCBUUIDs = [NSMutableArray array];
    for (NSString *uuidString in characteristicUUIDs) {
	CBUUID *characteristicCBUUID = [CBUUID UUIDWithString:uuidString];
	ZAssert(characteristicCBUUID != nil, @"characteristic UUID could not be converted to CBUUID");
	[characteristicCBUUIDs addObject:characteristicCBUUID];
    }
    
    [self.servicesToScanFor setObject:characteristicCBUUIDs forKey:serviceCBUUID];
}

- (void)removeServiceWithUUID:(NSString *)serviceUUID
{
    CBUUID *serviceCBUUID = [CBUUID UUIDWithString:serviceUUID];
    ZAssert(serviceCBUUID != nil, @"service UUID could not be converted to CBUUID");
    
    [self.servicesToScanFor removeObjectForKey:serviceCBUUID];
}


#pragma mark - Scanning Control

- (void)setScanningEnabled:(BOOL)scanningEnabled
{
    if (scanningEnabled != _scanningEnabled) {
	if (scanningEnabled) {
	    [self enableScanning];
	}
	else {
	    [self disableScanning];
	}
	
	_scanningEnabled = scanningEnabled;
    }
}

- (void)enableScanning
{
    if ([self.servicesToScanFor count] == 0) {
	NSException *exception = [NSException
				  exceptionWithName:@"NoServicesToScanForException"
				  reason:@"Scanning cannot start with no services configured"
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
    
    NSArray *services = [self CBUUIDsToScanFor];
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
    DLog(@"Central manager state: %@", NSStringFromCBCentralManagerState(self.centralManager.state));
    
    if (self.centralManager.state == CBPeripheralManagerStatePoweredOn) {
	[self startScanningIfNeeded];
    }
    else {
	[self stopScanning];
	
	if (self.centralManager.state == CBCentralManagerStateUnsupported) {
	    NSError *error = [NSError errorWithDomain:CMBluetoothCentralControllerErrorDomain
						 code:CMBluetoothCentralControllerErrorUnsupported
					     userInfo:@{NSLocalizedDescriptionKey: @"Bluetooth LE is not supported by this device"}];
	    [self performScanningStateChangeCallbackWithError:error]; //TODO: necessary??
	}
	else if (self.centralManager.state == CBCentralManagerStatePoweredOff) {
	    // Handle powered off state, for example if Bluetooth off or Airplane mode...
	    DLog(@"CBCentralManagerStatePoweredOff");
	    NSError *error = [NSError errorWithDomain:CMBluetoothCentralControllerErrorDomain
						 code:CMBluetoothCentralControllerErrorPoweredOff
					     userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Bluetooth is powered off or Airplane mode is enabled", @"Bluetooth is powered off or Airplane mode is enabled")}];
	    [self performScanningStateChangeCallbackWithError:error]; //TODO: necessary??
	}
	else {
	    DLog(@"Unhandled central state: %@", NSStringFromCBCentralManagerState(self.centralManager.state));
	}
    }
}


- (NSArray *)CBUUIDsToScanFor
{
    return [self.servicesToScanFor allKeys];
}


#pragma mark - Connected Peripherals

- (void)connectedPeripheralWasFullyDiscovered:(CMBluetoothCentralConnectedPeripheral *)connectedPeripheral
{
    DLog(@"connectedPeripheral: %@", connectedPeripheral);
    connectedPeripheral.fullyDiscovered = YES;
    [self performPeripheralConnectionCallbackWithConnectedPeripheral:connectedPeripheral];
}

- (void)connectedPeripheralFailedServiceDiscovery:(CMBluetoothCentralConnectedPeripheral *)connectedPeripheral withError:(NSError *)error
{
    DLog(@"connectedPeripheral: %@ error: %@", connectedPeripheral, error);
    [self.centralManager cancelPeripheralConnection:connectedPeripheral.cbPeripheral];
}

- (void)performPeripheralConnectionCallbackWithConnectedPeripheral:(CMBluetoothCentralConnectedPeripheral *)connectedPeripheral
{
    void (^peripheralConnectionCallback)(CMBluetoothCentralConnectedPeripheral *peripheral, BOOL connected) = [self.peripheralConnectionCallback copy];
    
    if (peripheralConnectionCallback) {
	dispatch_async(dispatch_get_main_queue(), ^{
	    peripheralConnectionCallback(connectedPeripheral, connectedPeripheral.isConnected);
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

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)cbPeripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    DLog(@"cbPeripheral: %@ advertisementData: %@ RSSI:%@", cbPeripheral, advertisementData, RSSI);
    DLog(@"self.discoveredPeripherals: %@", self.discoveredPeripherals);
    
    CMBluetoothCentralConnectedPeripheral *connectedPeripheral = self.discoveredPeripherals[cbPeripheral];
    if (connectedPeripheral == nil) {
	connectedPeripheral = [[CMBluetoothCentralConnectedPeripheral alloc] initWithCBPeripheral:cbPeripheral advertisementData:advertisementData];
	self.discoveredPeripherals[cbPeripheral] = connectedPeripheral;
	
	[central connectPeripheral:cbPeripheral options:nil];
    }
    else {
	// This can be called multiple times as new advertisementData is received
	DLog(@"Updating advertisementData for peripheral: %@", cbPeripheral);
	[connectedPeripheral updateAdvertisementData:advertisementData];
    }
}

- (void)centralManager:(__unused CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)cbPeripheral
{
    DLog(@"cbPeripheral: %@", cbPeripheral);
    
    CMBluetoothCentralConnectedPeripheral *connectedPeripheral = self.discoveredPeripherals[cbPeripheral];
    if (connectedPeripheral) {
	connectedPeripheral.connected = YES;

	__weak CMBluetoothCentralController *weakSelf = self;
	
	[connectedPeripheral discoverServices:self.servicesToScanFor withCompletion:^(NSError *error){
	    __strong CMBluetoothCentralController *strongSelf = weakSelf;
	    
	    if (error) {
		[strongSelf connectedPeripheralFailedServiceDiscovery:connectedPeripheral withError:error];
	    }
	    else {
		[strongSelf connectedPeripheralWasFullyDiscovered:connectedPeripheral];
	    }
	}];

//	__weak CMBluetoothCentralController *weakSelf = self;
//	[connectedPeripheral discoverServices:^(NSString *serviceUUID){
//	    __strong CMBluetoothCentralController *strongSelf = weakSelf;
//	    return self.servicesToScanFor[serviceUUID];
//	}];
    }
    else {
	ALog(@"Connected peripheral that is not in discoveredPeripherals: %@", cbPeripheral);
    }
}

- (void)centralManager:(__unused CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)cbPeripheral error:(NSError *)error
{
    DLog(@"cbPeripheral: %@ error: %@", cbPeripheral, error);
    [self.discoveredPeripherals removeObjectForKey:cbPeripheral];
}

- (void)centralManager:(__unused CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)cbPeripheral error:(NSError *)error
{
    DLog(@"cbPeripheral: %@ error: %@", cbPeripheral, error);

    CMBluetoothCentralConnectedPeripheral *connectedPeripheral = self.discoveredPeripherals[cbPeripheral];
    if (connectedPeripheral) {
	connectedPeripheral.connected = NO;
	
	if (connectedPeripheral.isFullyDiscovered) {
	    [self performPeripheralConnectionCallbackWithConnectedPeripheral:connectedPeripheral];
	}
	
	[self.discoveredPeripherals removeObjectForKey:connectedPeripheral.cbPeripheral];
    }
    else {
	ALog(@"Connected peripheral that is not in discoveredPeripherals: %@", cbPeripheral);
    }
    
    DLog(@"self.discoveredPeripherals: %@", self.discoveredPeripherals);
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
