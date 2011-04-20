//
//  TimeSync.m
//  AirSpeaker
//
//  Created by Clément Vasseur on 2/8/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import "AirTunes.h"
#import "TimeSync.h"
#import "AsyncUdpSocket.h"

#include <mach/mach_time.h>
#include <libkern/OSByteOrder.h>

#define TIMEOUT_NONE				-1
#define TIMESTAMP_EPOCH				(0x83aa7e80LL << 32)


@implementation TimeSync

- (id)initWithServer:(NSData *)address
{
	NSError *error;
	
	if ((self = [super init])) {
		socket = [[AsyncUdpSocket alloc] initWithDelegate:self];
		
		if (![socket connectToAddress:address error:&error]) {
			NSLog(@"Error: unable to connect UDP socket: %@", error);
			[socket release];
			[self release];
			return nil;
		}
	}
	
	return self;
}

- (uint64_t)getTimestamp
{
	static mach_timebase_info_data_t s_timebase_info;
	
	uint64_t t = mach_absolute_time() - startTime;

    if (s_timebase_info.denom == 0)
		(void) mach_timebase_info(&s_timebase_info);
	
	// convert absolute time difference to 32.32 fixed point timestamp
	return (t * s_timebase_info.numer * (1LL << 32)) / (s_timebase_info.denom * 1000000000LL);
}

- (BOOL)sendQuery
{
	struct airtunes_timing_packet pkt = {
		.airtunes_packet = AIRTUNES_PACKET,
		.airtunes_command = AIRTUNES_TIMING_QUERY,
		.fixed = htons(0x0007),
		.zero = 0,
		.timestamp_1 = 0,
		.timestamp_2 = 0,
		.timestamp_3 = OSSwapHostToBigInt64([self getTimestamp] + clockOffset),
	};
	
	NSLog(@"[Time] sync query: %f",
		  (double) (OSSwapBigToHostInt64(pkt.timestamp_3) - TIMESTAMP_EPOCH) / (1LL << 32));
	NSData *data = [NSData dataWithBytes:&pkt length:sizeof(pkt)];
	return [socket sendData:data withTimeout:TIMEOUT_NONE tag:0];
}

- (void)onUdpSocket:(AsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
	[sock receiveWithTimeout:TIMEOUT_NONE tag:0];
}

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock
	 didReceiveData:(NSData *)data
			withTag:(long)tag
		   fromHost:(NSString *)host
			   port:(UInt16)port
{
	struct airtunes_timing_packet pkt;
	
	if ([data length] != sizeof(pkt))
		return NO;
	
	[data getBytes:&pkt length:sizeof(pkt)];
	
	if (pkt.airtunes_packet != AIRTUNES_PACKET ||
		pkt.airtunes_command != AIRTUNES_TIMING_REPLY)
		return NO;

	// sntp time sync
	// http://www.faqs.org/rfcs/rfc1769.html

	int64_t timestamp_originate = OSSwapBigToHostInt64(pkt.timestamp_1) - TIMESTAMP_EPOCH;
	int64_t timestamp_receive = OSSwapBigToHostInt64(pkt.timestamp_2) - TIMESTAMP_EPOCH;
	int64_t timestamp_transmit = OSSwapBigToHostInt64(pkt.timestamp_3) - TIMESTAMP_EPOCH;
	int64_t timestamp_destination = [self getTimestamp] + clockOffset - TIMESTAMP_EPOCH;

//	NSLog(@"time sync reply: originate %f", (double) timestamp_originate / (1LL << 32));
//	NSLog(@"time sync reply: receive %f", (double) timestamp_receive / (1LL << 32));
//	NSLog(@"time sync reply: transmit %f", (double) timestamp_transmit / (1LL << 32));
//	NSLog(@"time sync reply: destination %f", (double) timestamp_destination / (1LL << 32));

	// compute the local clock offset
	
	int64_t local_clock_offset = ((timestamp_receive - timestamp_originate) +
								  (timestamp_transmit - timestamp_destination)) / 2;

	NSLog(@"[Time] local clock offset: %f", (double) local_clock_offset / (1LL << 32));
	clockOffset += local_clock_offset;
	
	if (timestamp_transmit > timestamp_destination)
		latency = 0;
	else
		latency = (1000 * (timestamp_destination - timestamp_transmit)) / (1LL << 32);
	
	NSLog(@"[Time] latency %u ms", latency);

	if (queryCount > 0) {
		[self sendQuery];
		queryCount--;
	} else if (delegate != nil) {
		[delegate timeSyncWithLatency:latency userData:userData];
		[delegate release];
		delegate = nil;
	}
	
	return YES;
}

- (void)startWithDelegate:(id)syncDelegate userData:(id)data
{
	delegate = [syncDelegate retain];
	userData = [data retain];

	startTime = mach_absolute_time();
	clockOffset = TIMESTAMP_EPOCH;
	queryCount = 2;

	[self sendQuery];
}

- (UInt16)localPort
{
	return [socket localPort];
}

- (uint32_t)latency
{
	return latency;
}

- (void)dealloc
{
	[socket release];
	[delegate release];
	[userData release];
	[super dealloc];
}

@end
