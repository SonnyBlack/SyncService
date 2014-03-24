//
//  BBMultiPeerService.m
//  TestScanner
//
//  Created by Alexey Kolmyk on 28.12.13.
//  Copyright (c) 2013 SonnyBlack. All rights reserved.
//

#import "BBMultiPeerService.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface BBMultiPeerService () <MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate>

@property (nonatomic, strong) MCAdvertiserAssistant *assistant;
@property (nonatomic, strong) MCSession				*serverSession;
@property (nonatomic, strong) MCSession				*clientSession;

@property (nonatomic, strong) MCNearbyServiceBrowser	*browser;
@property (nonatomic, strong) MCNearbyServiceAdvertiser	*advertiser;

@end

@implementation BBMultiPeerService


-(void) setConnectionType:(CommonServiseType)type {
	
//	MCPeerID *myPeerId = [[MCPeerID alloc] initWithDisplayName:[UIDevice currentDevice].name];

//	self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:myPeerId serviceType:kServiceType];
//	self.browser.delegate=self;
	
//	self.serverSession = [[MCSession alloc] initWithPeer:myPeerId securityIdentity:nil encryptionPreference:MCEncryptionNone];
//	
//	self.browser = [[MCBrowserViewController alloc] initWithServiceType:@"fus-ro-dah" session:self.serverSession];
//	[self.browser.browser startBrowsingForPeers];
//	self.browser.delegate = self;
//	self.browser.browser.delegate = self;
}

-(void) startServerSide {
	MCPeerID *myPeerId = [[MCPeerID alloc] initWithDisplayName:[UIDevice currentDevice].name];
	self.serverSession = [[MCSession alloc] initWithPeer:myPeerId securityIdentity:nil encryptionPreference:MCEncryptionNone];
	self.serverSession.delegate = self;
	
	self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:myPeerId discoveryInfo:nil serviceType:@"fus-ro-dah"];
	self.advertiser.delegate = self;
	[self.advertiser startAdvertisingPeer];
}

-(void) startSearchDevices {
	MCPeerID *myPeerId = [[MCPeerID alloc] initWithDisplayName:[UIDevice currentDevice].name];
	self.clientSession = [[MCSession alloc] initWithPeer:myPeerId securityIdentity:nil encryptionPreference:MCEncryptionNone];
	self.clientSession.delegate = self;
	
	self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:myPeerId  serviceType:@"fus-ro-dah"];
	self.browser.delegate = self;
	[self.browser startBrowsingForPeers];
	
}

-(void) selectDevice:(DeviceModel *)deviceModel {
	[self.browser invitePeer:deviceModel.device toSession:self.clientSession withContext:nil timeout:10];
	[self.browser stopBrowsingForPeers];
}

-(void) clean {
	[self.browser stopBrowsingForPeers];
	self.browser = nil;
	
	[self.advertiser stopAdvertisingPeer];
	self.advertiser = nil;
	
	[self.serverSession disconnect];
	self.serverSession = nil;
	
	[self.clientSession disconnect];
	self.clientSession = nil;
	
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID
	   withContext:(NSData *)context
 invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler {
	
	[advertiser stopAdvertisingPeer];
	invitationHandler(YES, self.serverSession);
	
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error {
	
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info {
	if(![peerID.displayName isEqualToString:self.clientSession.myPeerID.displayName]){
		
		if (self.delegate && [self.delegate respondsToSelector:@selector(service:didFindDevice:)]) {
			DeviceModel *foundedDevice = [DeviceModel new];
			foundedDevice.device = peerID;
			[self.delegate service:self didFindDevice:foundedDevice];
		}
	}
}

// A nearby peer has stopped advertising
- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
	if(![peerID.displayName isEqualToString:self.clientSession.myPeerID.displayName]){
		
		if (self.delegate && [self.delegate respondsToSelector:@selector(service:didRemoveDevice:)]) {
			DeviceModel *foundedDevice = [DeviceModel new];
			foundedDevice.device = peerID;
			[self.delegate service:self didRemoveDevice:foundedDevice];
		}
	}
}


// Browsing did not start due to an error
- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error {
	
}

#pragma mark - MCSessionDelegate

// Remote peer changed state
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
	
	switch (state) {
		case MCSessionStateNotConnected:

			
			break;
			
		case MCSessionStateConnecting:
			
			break;
			
		case MCSessionStateConnected:
			if (session == self.clientSession) {
				[self sendOwnUserIDForSession:session ];
				
			}
			
			
			break;
			
		default:
			break;
	}
	
}

// Received data from remote peer
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
	NSString *opponentData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
	if (session == self.serverSession) {
		
		if (self.delegate && [self.delegate respondsToSelector:@selector(service:serverDidFinishedSync:)]) {
			
			[[QBClient shared] createPairWithUser:[opponentData integerValue] block:^(Pair *pair, NSError *anError) {
				if (pair) {
					[self sendOwnUserIDForSession:session];
					dispatch_async(dispatch_get_main_queue(), ^{
						[self.delegate service:self serverDidFinishedSync:YES];
						
					});
				}
				
			}];
		}
		
	}else if (session == self.clientSession) {
		
		if (self.delegate && [self.delegate respondsToSelector:@selector(service:clientDidFinishedSync:)]) {
			Pair *myPair = [Pair new];
			QBUUser  *currentUser = [[QBClient shared] getCurrentUser];
			myPair.myID = currentUser.ID;
			myPair.opponentID = [opponentData integerValue];
			[QBClient shared].currentPair = myPair;
			dispatch_async(dispatch_get_main_queue(), ^{
				[self.delegate service:self clientDidFinishedSync:YES];
				
			});
		}
	}
}

// Received a byte stream from remote peer
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
	
}

// Start receiving a resource from remote peer
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
	
}

// Finished receiving a resource from remote peer and saved the content in a temporary location - the app is responsible for moving the file to a permanent location within its sandbox
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)erro {
	
}

- (void) sendOwnUserIDForSession:(MCSession *)session{
	QBUUser *currentUser = [[QBClient shared] getCurrentUser];
	NSString *userID = [NSString stringWithFormat:@"%d", currentUser.ID];
	NSData *myID = [userID dataUsingEncoding:NSUTF8StringEncoding];
	
	NSLog(@"My ID is= %@", userID);
    NSLog(@"Send data, length=%d", [myID length]);
	NSError *err;
    BOOL isSend = [session sendData:myID toPeers:session.connectedPeers withMode:MCSessionSendDataReliable error:&err];
	NSLog(@"IS SEND  err: %d: %@", isSend, err);
}

@end
