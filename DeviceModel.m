//
//  DeviceModel.m
//  TestScanner
//
//  Created by Alexey Kolmyk on 27.12.13.
//  Copyright (c) 2013 SonnyBlack. All rights reserved.
//

#import "DeviceModel.h"
#import <CoreBluetooth/CBPeripheral.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface DeviceModel ()
{
	NSString *_name;
}

@end

@implementation DeviceModel


-(void)setDevice:(id)device {
	if ([device isKindOfClass:[NSNetService class]]) {
		NSNetService *netServise = (NSNetService *)device;
		_device = nil;
		_device = netServise;
		_name = netServise.name;
		
	}else if ([device isKindOfClass:[CBPeripheral class]]) {
		CBPeripheral *peripheral = (CBPeripheral *)device;
		_device = nil;
		_name = peripheral.name;
		_device = peripheral;
	}else if ([device isKindOfClass:[MCPeerID class]]) {
		MCPeerID *peerID = (MCPeerID *)device;
		_device = nil;
		_name = peerID.displayName;
		_device = peerID;
	}else {
		_device = nil;
		_device = device;
	}
}



-(NSString *)deviceName {
	return _name;
}

-(void)setDeviceName:(NSString *)name {
	_name = nil;
	_name = name;
}

-(BOOL) isDeviceEqualTo:(id)otherDevice {
	if ([_name isEqualToString:[otherDevice deviceName]])
		return YES;
	else
		return NO;
}

@end
