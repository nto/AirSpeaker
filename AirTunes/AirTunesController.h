//
//  AirTunesController.h
//  AirSpeaker
//
//  Created by Clément Vasseur on 1/24/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GCDAsyncSocket;
@class AsyncUdpSocket;
@class TimeSync;
@class AudioPlayer;
@class CryptoController;

@protocol AirTunesMetadataDelegate

- (void)setMetadata:(NSDictionary *)metadata;

@end

@protocol AirTunesCoverDelegate

- (void)setCoverData:(NSData *)cover;

@end

@interface AirTunesController : NSObject <NSNetServiceDelegate> {
	NSNetService		*netService;
	GCDAsyncSocket		*asyncSocket;
	AudioPlayer			*audioPlayer;
	CryptoController	*cryptoController;
	
	NSString			*method;
	NSString			*location;
	NSMutableDictionary	*headers;
	NSData				*content;
	NSUInteger			contentLength;
	
	UInt16				controlPort;
	UInt16				timingPort;
	int					fmtp[12];
	
	AsyncUdpSocket		*serverSocket;
	AsyncUdpSocket		*controlSocket;

	TimeSync			*timeSync;
	
	id<AirTunesMetadataDelegate> metadataDelegate;
	id<AirTunesCoverDelegate> coverDelegate;
}

@property (nonatomic, retain) id<AirTunesMetadataDelegate> metadataDelegate;
@property (nonatomic, retain) id<AirTunesCoverDelegate> coverDelegate;

- (BOOL)start;

@end
