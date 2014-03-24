//
//  DeviceModel.h
//  TestScanner
//
//  Created by Alexey Kolmyk on 27.12.13.
//  Copyright (c) 2013 SonnyBlack. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DeviceModel : NSObject

@property (nonatomic, strong)	id		device;

-(NSString *)deviceName;
-(void)setDeviceName:(NSString *)name;

-(BOOL) isDeviceEqualTo:(id)otherDevice;

@end
