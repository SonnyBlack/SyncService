//
//  CommonServise.h
//  TestScanner
//
//  Created by Alexey Kolmyk on 27.12.13.
//  Copyright (c) 2013 SonnyBlack. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#import "QBClient.h"
#import "DeviceModel.h"


@protocol CommonServiseDelegate;


@interface CommonServise : NSObject

@property (nonatomic, weak) id<CommonServiseDelegate> delegate;

-(void) setConnectionType:(CommonServiseType)type;

-(void) startServerSide;

-(void) startSearchDevices;
-(void) selectDevice:(DeviceModel *)deviceModel;

-(void) clean;

@end

@protocol CommonServiseDelegate <NSObject>

@optional

-(void) service:(CommonServise *)servise didFindDevice:(DeviceModel *)device;
-(void) service:(CommonServise *)servise didRemoveDevice:(DeviceModel *)device;

-(void) service:(CommonServise *)servise serverDidFinishedSync:(BOOL)isFinished;
-(void) service:(CommonServise *)servise clientDidFinishedSync:(BOOL)isFinished;

@end


