//
//  BBBluetoothServise.m
//  TestScanner
//
//  Created by Alexey Kolmyk on 27.12.13.
//  Copyright (c) 2013 SonnyBlack. All rights reserved.
//

#import "BBBluetoothServise.h"

#define SERVICE_UUID					@"E20A39F4-73F5-4BC4-A12F-17D1AD07A961"
#define WRITE_CHARACTERISTIC_UUID		@"08590F7E-DB05-467E-8757-72F6FAEB13D4"
#define READ_CHARACTERISTIC_UUID		@"30AF2355-F365-4D79-9138-E1D679D441D1"

#import "BluetoothServise.h"

@interface BBBluetoothServise () <CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate>

@property (strong, nonatomic) CBPeripheralManager		*peripheralManager;
@property (strong, nonatomic) CBPeripheral				*discoveredPeripheral;
@property (strong, nonatomic) CBCentralManager			*centralManager;

@end

@implementation BBBluetoothServise

-(void) startServerSide {
	self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

-(void) startSearchDevices {
	self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

-(void) selectDevice:(DeviceModel *)deviceModel {
	if ([deviceModel.device isKindOfClass:[CBPeripheral class]]) {
		[self.centralManager connectPeripheral:deviceModel.device options:nil];
	}
}

-(void) clean {
	[self cleanup];
	
	[self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
	self.centralManager = nil;
	
	[self.peripheralManager stopAdvertising];
	[self.peripheralManager removeAllServices];
	self.peripheralManager = nil;
	
	self.discoveredPeripheral = nil;
}


#pragma mark - Central Methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
	if (![self isCentralManagerSupportLE])
    {
		[self showNotSupportingAlert];
		return;
    }
	
    if (central.state != CBCentralManagerStatePoweredOn) {
        // In a real app, you'd deal with all the states correctly
        return;
    }
	
    [self scan];
}

- (BOOL)isCentralManagerSupportLE {
	return [self checkManager:YES];
}

- (BOOL)isPeripheralManagerSupportLE {
	return [self checkManager:NO];
}

- (BOOL)checkManager:(BOOL)managerType
{
    NSString *state = nil;
    
	
    switch ( (managerType ? [self.centralManager state] : [self.peripheralManager state]) )
    {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            return TRUE;
        case CBCentralManagerStateUnknown:
        default:
            return false;
    }
	
    
    NSLog(@"Central manager state: %@", state);
	
    return false;
}

-(void) showNotSupportingAlert {
	UIAlertView *error = [[UIAlertView alloc] initWithTitle:@"Error"
													message:@"Your device doesn't support Bluetooth LE. FOOooooooo"
												   delegate:nil
										  cancelButtonTitle:@"Ok"
										  otherButtonTitles:nil];
	[error show];
}

- (void)scan
{
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SERVICE_UUID]]
                                                options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    
    NSLog(@"Scanning started");
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    
    if (self.discoveredPeripheral != peripheral) {
        
        self.discoveredPeripheral = peripheral;
		
        NSLog(@"Connecting to peripheral %@", peripheral);
//        [self.centralManager connectPeripheral:peripheral options:nil];
		
		if (self.delegate && [self.delegate respondsToSelector:@selector(service:didFindDevice:)]) {
			DeviceModel *foundedDevice = [DeviceModel new];
			foundedDevice.device = peripheral;
			if (peripheral.name == nil) {
				[foundedDevice setDeviceName:advertisementData[CBAdvertisementDataLocalNameKey]];
			}
			if (peripheral.name == nil) {
				[foundedDevice setDeviceName:@"Unknown device"];
			}
			
			
			[self.delegate service:self didFindDevice:foundedDevice];
			[self.centralManager stopScan];
		}

    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
    [self cleanup];
}


- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral Connected");
    
    // Stop scanning
    [self.centralManager stopScan];
    NSLog(@"Scanning stopped");
	
    peripheral.delegate = self;
    
    [peripheral discoverServices:@[[CBUUID UUIDWithString:SERVICE_UUID]]];
	
}


/** The Transfer Service was discovered
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }
	
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:READ_CHARACTERISTIC_UUID]] forService:service];
    }
}


/** The Transfer characteristic was discovered.
 *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    // Deal with errors (if any)
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }
	
    for (CBCharacteristic *characteristic in service.characteristics) {
        
		if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:READ_CHARACTERISTIC_UUID]]) {
			
            // If it is, subscribe to it
			[peripheral setNotifyValue:YES forCharacteristic:characteristic];
			
        }
		
    }
	
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
		[self.delegate service:self clientDidFinishedSync:NO];
        return;
    }
    
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    
	// Log it
    NSLog(@"Received ON CENTER: %@", stringFromData);
	
	if (self.delegate && [self.delegate respondsToSelector:@selector(service:clientDidFinishedSync:)]) {
		
			[[QBClient shared] createPairWithUser:[stringFromData integerValue] block:^(Pair *pair, NSError *anError) {
				if (pair) {
					CBService *service = [peripheral.services objectAtIndex:0];
					
					for (CBCharacteristic *characteristic in service.characteristics) {
						
						if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:WRITE_CHARACTERISTIC_UUID]]) {
							
							QBUUser *currentUser = [[QBClient shared] getCurrentUser];
							
							NSString *userID = [NSString stringWithFormat:@"%d", currentUser.ID];
							
							NSData *myID = [userID dataUsingEncoding:NSUTF8StringEncoding];
							
							[peripheral writeValue:myID forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
							[self.delegate service:self clientDidFinishedSync:YES];
						}
					}
				}
			}];
	}
}


/** The peripheral letting us know whether our subscribe/unsubscribe happened or not
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
		return;
    }
    
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:READ_CHARACTERISTIC_UUID]]) {
        return;
    }
	
    if (!characteristic.isNotifying) {
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

/** Once the disconnection happens, we need to clean up our local copy of the peripheral
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Peripheral Disconnected");
    self.discoveredPeripheral = nil;
	
    [self scan];
}

- (void)cleanup
{
    // Don't do anything if we're not connected
    if (!self.discoveredPeripheral.isConnected) {
        return;
    }
    
    // See if we are subscribed to a characteristic on the peripheral
    if (self.discoveredPeripheral.services != nil) {
        for (CBService *service in self.discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:WRITE_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
							
                            [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
							
                            return;
                        }
                    }
					
					else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:READ_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
							
                            [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
							
                            return;
                        }
                    }
					
                }
            }
        }
    }
	
    [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}

#pragma mark - Peripheral Methods

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
	if (![self isPeripheralManagerSupportLE])
    {
		[self showNotSupportingAlert];
		return;
    }
	
    // Opt out from any other state
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        return;
    }
	
    NSLog(@"self.peripheralManager powered on.");
    
	
	CBMutableCharacteristic *writeCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:WRITE_CHARACTERISTIC_UUID]
																					  properties:CBCharacteristicPropertyWrite
																						   value:nil
																					 permissions:CBAttributePermissionsWriteable];
	
	
	CBMutableCharacteristic *readCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:READ_CHARACTERISTIC_UUID]
																					 properties:CBCharacteristicPropertyNotify
																						  value:nil
																					permissions:CBAttributePermissionsReadable];
	
    // Then the service
    CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:SERVICE_UUID]
																	   primary:YES];
    
    // Add the characteristic to the service
    transferService.characteristics = @[writeCharacteristic, readCharacteristic];
    
    // And add it to the peripheral manager
//	NSString *deviceName = [[UIDevice currentDevice].name substringWithRange:NSMakeRange(0, 8)];
	NSDictionary *advertismentData = @{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:SERVICE_UUID]] };
	
//	NSMutableDictionary *advertismentData = [NSMutableDictionary new];
//	[advertismentData setValue:[UIDevice currentDevice].name forKey:CBAdvertisementDataLocalNameKey];
//	[advertismentData setValue:[NSArray arrayWithObject:[CBUUID UUIDWithString:SERVICE_UUID]] forKey:CBAdvertisementDataServiceUUIDsKey];
	
    [self.peripheralManager addService:transferService];
	[self.peripheralManager startAdvertising:advertismentData];
	
}


- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central subscribed to characteristic");
	
	[self sendDataForCharacteristic:(CBMutableCharacteristic *)characteristic];
}


- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central unsubscribed from characteristic");
}

- (void)sendDataForCharacteristic:(CBMutableCharacteristic *)characteristic
{
	QBUUser *currentUser = [[QBClient shared] getCurrentUser];
	
	NSString *userID = [NSString stringWithFormat:@"%d", currentUser.ID];
	
	NSData *myID = [userID dataUsingEncoding:NSUTF8StringEncoding];
	
	BOOL didSend = [self.peripheralManager updateValue:myID
									 forCharacteristic:characteristic
								  onSubscribedCentrals:nil];
	NSLog(@"DID SEND : %D", didSend);
}


- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    // Start sending again
}

- (void)peripheral:(CBPeripheral *)peripheral
didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
	
    if (error) {
        NSLog(@"Error writing characteristic value: %@",
			  [error localizedDescription]);
    }
	
	
	NSLog(@"COMPLETION");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests {
	
	
	if ([requests count] == 0) {
		[self.delegate service:self serverDidFinishedSync:NO];
		return;
	}
	
	CBATTRequest *req = [requests objectAtIndex:0];
	NSLog(@"RECIEVED ON PER : %@", req.value);
	
	NSString *opponentData = [[NSString alloc] initWithData:req.value encoding:NSUTF8StringEncoding];
	
	if (self.delegate && [self.delegate respondsToSelector:@selector(service:serverDidFinishedSync:)]) {
		Pair *myPair = [Pair new];
		QBUUser  *currentUser = [[QBClient shared] getCurrentUser];
		myPair.myID = currentUser.ID;
		myPair.opponentID = [opponentData integerValue];
		[QBClient shared].currentPair = myPair;
		
		[self.delegate service:self serverDidFinishedSync:YES];

	}
	[peripheral respondToRequest:[requests objectAtIndex:0]
					  withResult:CBATTErrorSuccess];
	
}


@end
