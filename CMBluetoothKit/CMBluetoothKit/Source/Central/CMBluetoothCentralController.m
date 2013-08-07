//
//  CMBluetoothCentralController.m
//  NearPlayiOS
//
//  Created by Chris Miles on 6/08/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//

#import "CMBluetoothCentralController.h"
@import CoreBluetooth;


@interface CMBluetoothCentralController () <CBCentralManagerDelegate>

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) dispatch_queue_t centralManagerQueue;

@property (strong, nonatomic) NSMutableDictionary *servicesToScanFor;

@end


@implementation CMBluetoothCentralController

- (id)init
{
    self = [super init];
    if (self) {
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
    [self.servicesToScanFor setValue:characteristicUUIDs forKey:serviceUUID];
}

- (void)removeServiceWithUUID:(NSString *)serviceUUID
{
    [self.servicesToScanFor removeObjectForKey:serviceUUID];
}


#pragma mark - Scanning Control

- (void)startScanning
{
    
}

- (void)stopScanning
{
    
}


#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    DLog(@"TODO central: %@", central);
    
}

//- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary *)dict;

//- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals;

//- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals;

//- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI;

//- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral;

//- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;

//- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;

@end
