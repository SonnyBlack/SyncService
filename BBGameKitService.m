//
//  BBWiFiGameKitService.m
//  TestScanner
//
//  Created by Alexey Kolmyk on 28.12.13.
//  Copyright (c) 2013 SonnyBlack. All rights reserved.
//

#import "BBGameKitService.h"

#import <GameKit/GameKit.h>

#define dataChunksLength 1024 // chunk lenght (bytes)

@interface BBGameKitService () <GKSessionDelegate, GKPeerPickerControllerDelegate>

@property (nonatomic, strong) GKSession *clientSession;
@property (nonatomic, strong) GKSession *serverSession;

@property (nonatomic, strong) GKPeerPickerController *pickerController;

@property (nonatomic, assign) CommonServiseType	connectionType;

@end

@implementation BBGameKitService

-(id)init {
	if (self = [super init]) {
	
		self.pickerController = [[GKPeerPickerController alloc] init];
		self.pickerController.delegate = self;
		self.pickerController.connectionTypesMask = GKPeerPickerConnectionTypeOnline | GKPeerPickerConnectionTypeNearby;
//		[self.pickerController show];
	}
	return self;
}

-(void) setConnectionType:(CommonServiseType)type {
	_connectionType = type;
}

-(void) startServerSide {
	if (self.connectionType == CommonServiceTypeGameKitWiFi) {
		self.serverSession = [self peerPickerController:self.pickerController sessionForConnectionType:GKPeerPickerConnectionTypeNearby];
	}else{
		self.serverSession = [self peerPickerController:self.pickerController sessionForConnectionType:GKPeerPickerConnectionTypeOnline];
	}
}

-(void) startSearchDevices {
	if (self.connectionType == CommonServiceTypeGameKitBluetooth) {
		self.clientSession = [self peerPickerController:self.pickerController sessionForConnectionType:GKPeerPickerConnectionTypeNearby];
	}else{
		self.clientSession = [self peerPickerController:self.pickerController sessionForConnectionType:GKPeerPickerConnectionTypeOnline];
	}
}

-(void) selectDevice:(DeviceModel *)deviceModel {
	NSString *peerID = deviceModel.device;
	[self.clientSession connectToPeer:peerID withTimeout:10];
}

-(void) clean {
	[self.clientSession disconnectFromAllPeers];
	[self.clientSession setDataReceiveHandler:nil withContext:nil];
	self.clientSession.delegate = nil;
	self.clientSession.available = NO;
	self.clientSession = nil;
	
	[self.serverSession disconnectFromAllPeers];
	[self.serverSession setDataReceiveHandler:nil withContext:nil];
	self.serverSession.delegate = nil;
	self.serverSession.available = NO;
	self.serverSession = nil;
}

#pragma mark - GKSessionDelegate

- (void)session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID{
    // check for exist at least one user

	NSError *err;
	[session acceptConnectionFromPeer:peerID error:&err];
	
	NSLog(@"ERROR in accept: %@", err);
}


- (void)session:(GKSession *)session peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state{
    switch (state){
        case GKPeerStateConnected:
			NSLog(@"GKPeerStateConnected, peer=%@", [session displayNameForPeer:peerID]);

			if (session == self.clientSession) {
				[self sendOwnUserIDForSession:session];
			}

		break;
			
        case GKPeerStateDisconnected:
			NSLog(@"GKPeerStateDisconnected");
			[session setDataReceiveHandler:nil withContext:nil];
            break;
        case GKPeerStateAvailable:
			NSLog(@"GKPeerStateAvailable, peer=%@, peerID=%@",[session displayNameForPeer:peerID], peerID);
			
			if(![self.serverSession.peerID isEqualToString:peerID]){
				
				if (self.delegate && [self.delegate respondsToSelector:@selector(service:didFindDevice:)]) {
					DeviceModel *foundedDevice = [DeviceModel new];
					foundedDevice.device = peerID;
					[foundedDevice setDeviceName:[session displayNameForPeer:peerID]];
					
					[self.delegate service:self didFindDevice:foundedDevice];
				}
			}
            break;
        case GKPeerStateUnavailable:
			//            DLog(@"GKPeerStateUnavailable, peer=%@,  peerID=%@",[session displayNameForPeer:peerID], peerID);
			//
			//            [searchDevicesAlert removePeerName:[session displayNameForPeer:peerID] andPeerIdAndUpdateTabe:peerID];
            break;
        case GKPeerStateConnecting:
			NSLog(@"GKPeerStateConnecting");
            break;
    }
}

- (void)session:(GKSession *)session connectionWithPeerFailed:(NSString *)peerID withError:(NSError *)error{
    NSLog(@"connectionWithPeerFailed, peer=%@, error=%@", [session displayNameForPeer:peerID], error);
    
}

#pragma mark
#pragma mark Send/Recieve Data
#pragma mark

// Send data
- (void) sendOwnUserIDForSession:(GKSession *)session{
	QBUUser *currentUser = [[QBClient shared] getCurrentUser];
	NSString *userID = [NSString stringWithFormat:@"%d", currentUser.ID];
	NSData *myID = [userID dataUsingEncoding:NSUTF8StringEncoding];
	
	 NSLog(@"My ID is= %@", userID);
    NSLog(@"Send data, length=%d", [myID length]);
    BOOL isSend = [session sendDataToAllPeers:myID withDataMode:GKSendDataReliable error:nil];
	NSLog(@"IS SEND : %d", isSend);
}

// Receive data
- (void) receiveData:(NSData *)data fromPeer:(NSString *)peer inSession: (GKSession *)session context:(void *)context{
    // Read the bytes in data and perform an application-specific action.
    
	NSString *opponentData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	
	if (session == self.serverSession) {
		if (self.delegate && [self.delegate respondsToSelector:@selector(service:serverDidFinishedSync:)]) {
			
			[[QBClient shared] createPairWithUser:[opponentData integerValue] block:^(Pair *pair, NSError *anError) {
				if (pair) {
					[self sendOwnUserIDForSession:session];
					[self.delegate service:self serverDidFinishedSync:YES];
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
			
			[self.delegate service:self clientDidFinishedSync:YES];
		}
	}
}

#pragma mark - GKPeerPickerControllerDelegate methods

- (void)peerPickerController:(GKPeerPickerController *)picker
              didConnectPeer:(NSString *)peerID
                   toSession:(GKSession *)session
{
	
}

- (GKSession *)peerPickerController:(GKPeerPickerController *)picker
           sessionForConnectionType:(GKPeerPickerConnectionType)type
{
	NSString *sessionId = @"skyrim_ebana";
    NSString *name = [[UIDevice currentDevice] name];
    GKSession *session = [[GKSession alloc] initWithSessionID:sessionId
												  displayName:name
												  sessionMode:GKSessionModePeer];
	session.delegate = self;
	session.available = YES;
	[session setDataReceiveHandler:self withContext:nil];
	
	return session;
}

- (void)peerPickerControllerDidCancel:(GKPeerPickerController *)picker
{

}


@end
