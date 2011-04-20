//
//  TimeSync.h
//  AirSpeaker
//
//  Created by Clément Vasseur on 2/8/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AsyncUdpSocket;

@interface TimeSync : NSObject {
	AsyncUdpSocket	*socket;
	uint64_t		startTime;
	uint64_t		clockOffset;
	int				queryCount;
	uint32_t		latency;
	id				delegate;
	id				userData;
}

- (id)initWithServer:(NSData *)address;
- (void)startWithDelegate:(id)delegate userData:(id)data;
- (UInt16)localPort;
- (uint32_t)latency;

@end

#pragma mark -

@protocol TimeSyncDelegate
@optional

- (void)timeSyncWithLatency:(uint32_t)latency userData:(id)data;

@end
