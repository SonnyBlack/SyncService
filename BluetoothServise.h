//
//  BluetoothServise.h
//  TestScanner
//
//  Created by Alexey Kolmyk on 26.12.13.
//  Copyright (c) 2013 SonnyBlack. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface BluetoothServise : NSObject

+(instancetype)shared;

-(void) startCentralManager;
-(void) stopCentralManager;

-(void) startPeripheralManager;
-(void) stopPeripheralManager;

@end
