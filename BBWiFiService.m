//
//  BBWiFiService.m
//  TestScanner
//
//  Created by Alexey Kolmyk on 27.12.13.
//  Copyright (c) 2013 SonnyBlack. All rights reserved.
//

#import "BBWiFiService.h"
#import <DTBonjourServer.h>
#import <DTBonjourDataConnection.h>


@interface BBWiFiService () <DTBonjourDataConnectionDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate, DTBonjourServerDelegate>

@property (nonatomic, strong)	DTBonjourServer			*server;
@property (nonatomic, strong)	DTBonjourDataConnection	*client;
@property (nonatomic, strong)	NSNetServiceBrowser		*serviceBrowser;

@end

@implementation BBWiFiService 

-(void) startServerSide {
	self.server = [[DTBonjourServer alloc] initWithBonjourType:@"_TestScanner_SKYRIM._tcp."];
	self.server.delegate = self;
	[self.server start];
}

-(void) startSearchDevices {
	_serviceBrowser = [[NSNetServiceBrowser alloc] init];
	_serviceBrowser.delegate = self;
	[_serviceBrowser searchForServicesOfType:@"_TestScanner_SKYRIM._tcp." inDomain:@""];
}

-(void) selectDevice:(DeviceModel *)deviceModel {
	if ([deviceModel.device isKindOfClass:[NSNetService class]]) {
		_client = [[DTBonjourDataConnection alloc] initWithService:deviceModel.device];
		_client.delegate = self;
		[_client open];
	}
}

-(void) clean {
	[_serviceBrowser stop];
	_serviceBrowser = nil;
	
	[_client close];
	_client = nil;
	
	[_server stop];
	_server = nil;
}

#pragma mark - NetServiceBrowser Delegate

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
		   didFindService:(NSNetService *)aNetService
			   moreComing:(BOOL)moreComing {
	
	aNetService.delegate = self;
	[aNetService startMonitoring];
	
	if (self.delegate && [self.delegate respondsToSelector:@selector(service:didFindDevice:)]) {
		DeviceModel *foundedDevice = [DeviceModel new];
		foundedDevice.device = aNetService;
		[self.delegate service:self didFindDevice:foundedDevice];
	}
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
		 didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
	
	if (self.delegate && [self.delegate respondsToSelector:@selector(service:didRemoveDevice:)]) {
		DeviceModel *foundedDevice = [DeviceModel new];
		foundedDevice.device = aNetService;
		[self.delegate service:self didRemoveDevice:foundedDevice];
	}
}


#pragma mark - NSNetService Delegate

- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data
{
	[sender stopMonitoring];
}

-(void)netService:(NSNetService *)sender didAcceptConnectionWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream {
	
}

#pragma mark - DTBonjourConnection Delegate (Client)

- (void)connectionDidOpen:(DTBonjourDataConnection *)connection {
	NSError *error;
	QBUUser *currentUser = [[QBClient shared] getCurrentUser];
	
	if (![_client sendObject:@(currentUser.ID) error:&error]) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[alert show];
		
	}
}

- (void)connection:(DTBonjourDataConnection *)connection didReceiveObject:(id)object
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(service:clientDidFinishedSync:)]) {
		
		if ([object isKindOfClass:[NSNumber class]]) {
			Pair *myPair = [Pair new];
			QBUUser  *currentUser = [[QBClient shared] getCurrentUser];
			myPair.myID = currentUser.ID;
			myPair.opponentID = [object integerValue];
			[QBClient shared].currentPair = myPair;
			
			[self.delegate service:self clientDidFinishedSync:YES];

		}else{
			[self.delegate service:self clientDidFinishedSync:NO];
		}
		
	}
}

#pragma mark - DTBonjourServer Delegate (Server)

- (void)bonjourServer:(DTBonjourServer *)server didReceiveObject:(id)object onConnection:(DTBonjourDataConnection *)connection
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(service:serverDidFinishedSync:)]) {
		
		if ([object isKindOfClass:[NSNumber class]]) {
			[[QBClient shared] createPairWithUser:[object integerValue] block:^(Pair *pair, NSError *anError) {
				if (pair) {
					[self.server broadcastObject:@(pair.myID)];
					[self.delegate service:self serverDidFinishedSync:YES];
				}
			}];
		}else{
			[self.delegate service:self serverDidFinishedSync:NO];
		}
	}
}


@end
