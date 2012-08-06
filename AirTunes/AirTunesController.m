//
//  AirTunesController.m
//  AirSpeaker
//
//  Created by Clément Vasseur on 1/24/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import "AirTunesController.h"
#import "AsyncUdpSocket.h"
#import "GCDAsyncSocket.h"
#import "DeviceInfo.h"
#import "TimeSync.h"
#import "AirTunes.h"
#import "AudioPlayer.h"
#import "Base64.h"
#import "CryptoController.h"
#import "DMAP.h"

#include <netinet/in.h>

#define TIMEOUT_NONE -1

enum tag_tcp {
	TAG_REQUEST,
	TAG_HEADER,
	TAG_CONTENT,
	TAG_REPLY,
};

enum tag_udp {
	TAG_SERVER,
	TAG_CONTROL,
};

@implementation AirTunesController

@synthesize metadataDelegate;
@synthesize coverDelegate;

- (void)publishNetService
{
	// create and publish the bonjour service

	UInt16 port = [asyncSocket localPort];
	
	NSString *name = [[DeviceInfo deviceIdWithSep:@""]
					  stringByAppendingFormat:@"@%@",
					  [[UIDevice currentDevice] name]];
	
	netService = [[NSNetService alloc] initWithDomain:@"local."
												 type:@"_raop._tcp."
												 name:name
												 port:port];
	[netService setDelegate:self];
	[netService publish];
	
	// add TXT record stuff
	
	NSDictionary *txtDict = [NSDictionary dictionaryWithObjectsAndKeys:
							 
							 // txt record version
							 @"1", @"txtvers",
							 
							 // airtunes server version
							 @"104.29", @"vs",
							 
							 // 2 channels, 44100 Hz, 16-bit audio
							 @"2", @"ch",
							 @"44100", @"sr",
							 @"16", @"ss",
							 
							 // no password
							 @"false", @"pw",
							 
							 // encryption types
							 //  0: no encryption
							 //  1: airport express (RSA+AES)
							 //  3: apple tv (FairPlay+AES)
							 @"0,1", @"et",
							 @"1", @"ek",
							 
							 // transport protocols
							 @"TCP,UDP", @"tp",
							 
							 @"0,1", @"cn",
							 @"false", @"sv",
							 @"true", @"da",
							 @"65537", @"vn",
							 @"0,1,2", @"md",							 
							 @"0x4", @"sf",
							 
							 // [DeviceInfo platform], @"am",
							 @"AppleTV2,1", @"am",
							 nil];
	
	NSData *txtData = [NSNetService dataFromTXTRecordDictionary:txtDict];
	[netService setTXTRecordData:txtData];
}

- (BOOL)start
{
    // Stop the device from sleeping whilst we're playing our tunes
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
	// Create our socket.
	// We tell it to invoke our delegate methods on the main thread.
	
	asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	// Now we tell the socket to accept incoming connections.
	// We don't care what port it listens on, so we pass zero for the port number.
	// This allows the operating system to automatically assign us an available port.
	
	NSError *err = nil;
	if (![asyncSocket acceptOnPort:0 error:&err])
	{
		NSLog(@"Error in acceptOnPort:error: -> %@", err);
		return NO;
	}
	
	[self publishNetService];

	cryptoController = [[CryptoController alloc] init];
	
	return YES;
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
	NSLog(@"[Net] accept connection from %@:%hu", [newSocket connectedHost], [newSocket connectedPort]);
	
	[newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:TIMEOUT_NONE tag:TAG_REQUEST];
}

- (void)replyOK:(GCDAsyncSocket *)sock
	withHeaders:(NSDictionary *)hDict
	   withData:(NSData *)data
{
	NSMutableData *rep = [[[NSMutableData alloc] init] autorelease];
	NSMutableString *str = [NSMutableString stringWithString:@"RTSP/1.0 200 OK\r\n"];
	
	if ([data length] > 0) {
		[str appendString:@"Content-Type: application/octet-stream\r\n"];
		[str appendFormat:@"Content-Length: %u\r\n", [data length]];
	}
	
	for (NSString *key in hDict)
		[str appendFormat:@"%@: %@\r\n", key, [hDict valueForKey:key]];
	
	[str appendString:@"Server: AirTunes/104.29\r\n"];
	[str appendFormat:@"CSeq: %@\r\n\r\n", [headers valueForKey:@"CSeq"]];

//	NSLog(@"SEND %@", str);
//	NSLog(@"SEND RTSP/1.0 200 OK");
	
	NSData *rep_data = [str dataUsingEncoding:NSASCIIStringEncoding];

	[rep appendData:rep_data];
	[rep appendData:data];

	[sock writeData:rep withTimeout:TIMEOUT_NONE tag:TAG_REPLY];
}

- (AsyncUdpSocket *)udpSocketWithTag:(long)tag
{
	NSError *error;
	static int p = 4243;

	AsyncUdpSocket *socket = [[AsyncUdpSocket alloc] initWithDelegate:self];

	if (![socket bindToPort:p++ error:&error]) {
		NSLog(@"Error: unable to bind UDP socket: %@", error);
		[socket release];
		return nil;
	}

	[socket receiveWithTimeout:TIMEOUT_NONE tag:tag];
	return socket;
}

- (void)setVolume:(float)volume
{
	Float32 gain;
	
	// input       : output
	// -144.0      : silence
	// -30.0 - 0.0 : 0.0 - 1.0
	
	if (volume == -144.0)
		gain = 0.0;
	else
		gain = 1.0 + volume / 30.0;
	
	[audioPlayer setGain:gain];
}

- (NSData *)modifyAddress:(NSData *)address withPort:(UInt16)port
{
	struct sockaddr_in addr4;
	struct sockaddr_in6 addr6;
	
	if ([address length] == sizeof(addr4)) {
		[address getBytes:&addr4 length:sizeof(addr4)];
		addr4.sin_port = htons(port);
		return [NSData dataWithBytes:&addr4 length:sizeof(addr4)];

	} else if ([address length] == sizeof(addr6)) {
		[address getBytes:&addr6 length:sizeof(addr6)];
		addr6.sin6_port = htons(port);
		return [NSData dataWithBytes:&addr6 length:sizeof(addr6)];
	}
	
	return nil;
}

static NSData *getLocalAddress(NSData *addr)
{
	const struct sockaddr_in *addr_in;
	const struct sockaddr_in6 *addr_in6;
	
	addr_in = [addr bytes];

	if (addr_in->sin_family == AF_INET6) {
		addr_in6 = [addr bytes];
		return [NSData dataWithBytes:addr_in6->sin6_addr.__u6_addr.__u6_addr8 length:16];
	}
	
	return [NSData dataWithBytes:&addr_in->sin_addr.s_addr length:4];
}

- (void)socketReceivedRequest:(GCDAsyncSocket *)sock
{
	NSLog(@"[RAOP] %@ %@", method, location);
	
	if ([method isEqualToString:@"POST"] &&
		[location isEqualToString:@"/fp-setup"])
	{
		// 2 1 1 -> 4 : 02 00 02 bb
		uint8_t fply_1[] __attribute__((unused)) = {
			0x46, 0x50, 0x4c, 0x59, 0x02, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x04, 0x02, 0x00, 0x02, 0xbb
		};
		
		// 2 1 2 -> 130 : 02 02 xxx
		uint8_t fply_2[] = {
			                        0x46, 0x50, 0x4c, 0x59, 0x02, 0x01, 0x02, 0x00, 0x00, 0x00, 0x00, 0x82,
			0x02, 0x02, 0x2f, 0x7b, 0x69, 0xe6, 0xb2, 0x7e, 0xbb, 0xf0, 0x68, 0x5f, 0x98, 0x54, 0x7f, 0x37,
			0xce, 0xcf, 0x87, 0x06, 0x99, 0x6e, 0x7e, 0x6b, 0x0f, 0xb2, 0xfa, 0x71, 0x20, 0x53, 0xe3, 0x94,
			0x83, 0xda, 0x22, 0xc7, 0x83, 0xa0, 0x72, 0x40, 0x4d, 0xdd, 0x41, 0xaa, 0x3d, 0x4c, 0x6e, 0x30,
			0x22, 0x55, 0xaa, 0xa2, 0xda, 0x1e, 0xb4, 0x77, 0x83, 0x8c, 0x79, 0xd5, 0x65, 0x17, 0xc3, 0xfa,
			0x01, 0x54, 0x33, 0x9e, 0xe3, 0x82, 0x9f, 0x30, 0xf0, 0xa4, 0x8f, 0x76, 0xdf, 0x77, 0x11, 0x7e,
			0x56, 0x9e, 0xf3, 0x95, 0xe8, 0xe2, 0x13, 0xb3, 0x1e, 0xb6, 0x70, 0xec, 0x5a, 0x8a, 0xf2, 0x6a,
			0xfc, 0xbc, 0x89, 0x31, 0xe6, 0x7e, 0xe8, 0xb9, 0xc5, 0xf2, 0xc7, 0x1d, 0x78, 0xf3, 0xef, 0x8d,
			0x61, 0xf7, 0x3b, 0xcc, 0x17, 0xc3, 0x40, 0x23, 0x52, 0x4a, 0x8b, 0x9c, 0xb1, 0x75, 0x05, 0x66,
			0xe6, 0xb3
		};
		
		// 2 1 3 -> 152
		// 4 : 02 8f 1a 9c
		// 128 : xxx
		// 20 : 5b ed 04 ed c3 cd 5f e6 a8 28 90 3b 42 58 15 cb 74 7d ee 85

		uint8_t fply_3[] __attribute__((unused)) = {
			            0x46, 0x50, 0x4c, 0x59, 0x02, 0x01, 0x03, 0x00, 0x00, 0x00, 0x00, 0x98, 0x02, 0x8f,
			0x1a, 0x9c, 0x6e, 0x73, 0xd2, 0xfa, 0x62, 0xb2, 0xb2, 0x07, 0x6f, 0x52, 0x5f, 0xe5, 0x72, 0xa5,
			0xac, 0x4d, 0x19, 0xb4, 0x7c, 0xd8, 0x07, 0x1e, 0xdb, 0xbc, 0x98, 0xae, 0x7e, 0x4b, 0xb4, 0xb7,
			0x2a, 0x7b, 0x5e, 0x2b, 0x8a, 0xde, 0x94, 0x4b, 0x1d, 0x59, 0xdf, 0x46, 0x45, 0xa3, 0xeb, 0xe2,
			0x6d, 0xa2, 0x83, 0xf5, 0x06, 0x53, 0x8f, 0x76, 0xe7, 0xd3, 0x68, 0x3c, 0xeb, 0x1f, 0x80, 0x0e,
			0x68, 0x9e, 0x27, 0xfc, 0x47, 0xbe, 0x3d, 0x8f, 0x73, 0xaf, 0xa1, 0x64, 0x39, 0xf7, 0xa8, 0xf7,
			0xc2, 0xc8, 0xb0, 0x20, 0x0c, 0x85, 0xd6, 0xae, 0xb7, 0xb2, 0xd4, 0x25, 0x96, 0x77, 0x91, 0xf8,
			0x83, 0x68, 0x10, 0xa1, 0xa9, 0x15, 0x4a, 0xa3, 0x37, 0x8c, 0xb7, 0xb9, 0x89, 0xbf, 0x86, 0x6e,
			0xfb, 0x95, 0x41, 0xff, 0x03, 0x57, 0x61, 0x05, 0x00, 0x73, 0xcc, 0x06, 0x7e, 0x4f, 0xc7, 0x96,
			0xae, 0xba, 0x5b, 0xed, 0x04, 0xed, 0xc3, 0xcd, 0x5f, 0xe6, 0xa8, 0x28, 0x90, 0x3b, 0x42, 0x58,
			0x15, 0xcb, 0x74, 0x7d, 0xee, 0x85
		};
		
		// 2 1 4 -> 20 : 5b ed 04 ed c3 cd 5f e6 a8 28 90 3b 42 58 15 cb 74 7d ee 85
		uint8_t fply_4[] = {
			                  0x46, 0x50, 0x4c, 0x59, 0x02, 0x01, 0x04, 0x00, 0x00, 0x00, 0x00, 0x14, 0x5b,
			0xed, 0x04, 0xed, 0xc3, 0xcd, 0x5f, 0xe6, 0xa8, 0x28, 0x90, 0x3b, 0x42, 0x58, 0x15, 0xcb, 0x74,
			0x7d, 0xee, 0x85
		};
		
//		NSLog(@" content:%@", content);
		
		uint8_t fply_header[12];
		[content getBytes:fply_header length:sizeof(fply_header)];
		NSRange payload_range = {
			.location = sizeof(fply_header),
			.length = [content length] - sizeof(fply_header),
		};
		NSData *payload = [content subdataWithRange:payload_range];
//		NSLog(@" fply seq:%u len:%u %@", fply_header[6], fply_header[11], payload);
		
		NSMutableData *data;
		if (fply_header[6] == 1) {
			NSRange fply_id_range = {
				.location = 12 + 2,
				.length = 1,
			};
			[content getBytes:fply_2 + 13 range:fply_id_range];
			data = [NSData dataWithBytesNoCopy:fply_2 length:sizeof(fply_2) freeWhenDone:NO];
			[self replyOK:sock withHeaders:nil withData:data];

		} else if (fply_header[6] == 3) {
			NSRange fply_4_range = {
				.location = [payload length] - 20,
				.length = 20,
			};
			data = [NSMutableData dataWithBytes:fply_4 length:12];
			[data appendData:[payload subdataWithRange:fply_4_range]];
			[self replyOK:sock withHeaders:nil withData:data];
		}

		return;

	} else if ([method isEqualToString:@"POST"] &&
			   [location isEqualToString:@"/auth-setup"]) {

		[self replyOK:sock withHeaders:nil withData:content];

	} else if ([method isEqualToString:@"OPTIONS"]) {
		NSData *addr = getLocalAddress([sock localAddress]);
		
		NSMutableDictionary *hDict = [[NSMutableDictionary alloc] init];

		NSString *apple_challenge = [headers valueForKey:@"Apple-Challenge"];
		if (apple_challenge != nil) {
			NSData *challenge = base64_decode(apple_challenge);
			NSData *response = [cryptoController challengeResponse:challenge withAddr:addr];
//			NSLog(@"Apple-Challenge: %@", challenge);
//			NSLog(@"Apple-Response: %@", response);
			[hDict setObject:base64_encode(response) forKey:@"Apple-Response"];
		}
		
		[hDict setObject:@
		 "ANNOUNCE, "
		 "SETUP, "
		 "RECORD, "
		 "PAUSE, "
		 "FLUSH, "
		 "TEARDOWN, "
		 "OPTIONS, "
		 "GET_PARAMETER, "
		 "SET_PARAMETER, "
		 "POST, "
		 "GET" forKey:@"Public"];

		[self replyOK:sock withHeaders:hDict withData:nil];
		[hDict release];
		return;

	} else if ([method isEqualToString:@"ANNOUNCE"]) {
		NSData *rsa_aes_key = nil;
		NSData *aes_iv = nil;
		
		NSString *sdp = [[NSString alloc] initWithData:content encoding:NSASCIIStringEncoding];
		NSArray *a = [sdp componentsSeparatedByString:@"\r\n"];
		for (NSString *str in a) {
//			NSLog(@" %@", str);
			
			if ([str hasPrefix:@"a=fmtp:"]) {
				sscanf([[str substringFromIndex:7] UTF8String],
					   "%u %u %u %u %u %u %u %u %u %u %u %u",
					   &fmtp[0], &fmtp[1], &fmtp[2], &fmtp[3], &fmtp[4],
					   &fmtp[5], &fmtp[6], &fmtp[7], &fmtp[8], &fmtp[9],
					   &fmtp[10], &fmtp[11]);
				
			} else if ([str hasPrefix:@"a=rsaaeskey:"]) {
				rsa_aes_key = base64_decode([str substringFromIndex:12]);
				[cryptoController setRsaAesKey:rsa_aes_key];
			
			} else if ([str hasPrefix:@"a=aesiv:"]) {
				aes_iv = base64_decode([str substringFromIndex:8]);
				[cryptoController setAesIv:aes_iv];
			}
		}
		
		[sdp release];

		[self replyOK:sock withHeaders:nil withData:nil];
		return;

	} else if ([method isEqualToString:@"SETUP"]) {
		
		// retrieve control_port and timing_port from the Transport header
		controlPort = 0;
		timingPort = 0;
		
		NSString *transport = [headers valueForKey:@"Transport"];
		if (transport == nil) {
			// TODO: reply error
			return;
		}
		
		NSArray *settings = [transport componentsSeparatedByString:@";"];
		for (NSString *setting in settings) {
			NSArray *a = [setting componentsSeparatedByString:@"="];
			NSString *k = [a objectAtIndex:0];
			if ([k isEqualToString:@"control_port"])
				controlPort = [[a objectAtIndex:1] integerValue];
			else if ([k isEqualToString:@"timing_port"])
				timingPort = [[a objectAtIndex:1] integerValue];
		}

		if (controlPort == 0 || timingPort == 0) {
			// TODO: reply error
			return;
		}
		
		NSLog(@" control_port: %u", controlPort);
		NSLog(@" timing_port: %u", timingPort);

		// create server, control and timing udp sockets
		
		if ((serverSocket = [self udpSocketWithTag:TAG_SERVER]) == nil ||
			(controlSocket = [self udpSocketWithTag:TAG_CONTROL]) == nil)
			return;

		NSData *address = [self modifyAddress:[sock connectedAddress] withPort:timingPort];
		timeSync = [[TimeSync alloc] initWithServer:address];
		if (timeSync == nil) {
			// TODO: reply error
			return;
		}
		
		// reply with port information
		
		NSString *transport_reply = [NSString stringWithFormat:@"RTP/AVP/UDP;"
									 "unicast;"
									 "mode=record;"
									 "server_port=%u;"
									 "control_port=%u;"
									 "timing_port=%u",
									 [serverSocket localPort],
									 [controlSocket localPort],
									 [timeSync localPort]];
		
		NSDictionary *hDict = [NSDictionary dictionaryWithObjectsAndKeys:
							   transport_reply, @"Transport",
							   @"1", @"Session",
							   @"connected", @"Audio-Jack-Status",
							   nil];

		[self replyOK:sock withHeaders:hDict withData:nil];
		return;

	} else if ([method isEqualToString:@"RECORD"]) {
		[timeSync startWithDelegate:self userData:sock];
		return;

	} else if ([method isEqualToString:@"SET_PARAMETER"]) {
		NSString *content_type = [headers valueForKey:@"Content-Type"];
		NSLog(@" %@", content_type);

		if ([content_type isEqualToString:@"text/parameters"]) {
			NSString *parameters = [[[NSString alloc] initWithData:content
														  encoding:NSASCIIStringEncoding] autorelease];
			for (NSString *param in [parameters componentsSeparatedByString:@"\r\n"]) {
				if ([param length] == 0)
					continue;
				NSLog(@" %@", param);
				NSArray *a = [param componentsSeparatedByString:@":"];
				NSString *key = [a objectAtIndex:0];
				if ([key isEqualToString:@"volume"] && [a count] == 2)
					[self setVolume:[[a objectAtIndex:1] floatValue]];
			}

		} else if ([content_type hasPrefix:@"application/x-dmap-tagged"]) {
			DMAP *dmap = [[DMAP alloc] initWithData:content];
			NSDictionary *metadata = [NSDictionary dictionaryWithObjectsAndKeys:
									  [dmap get:@"dmap.listingitem/dmap.itemname"], @"Song",
									  [dmap get:@"dmap.listingitem/daap.songartist"], @"Artist",
									  [dmap get:@"dmap.listingitem/daap.songalbum"], @"Album",
									  nil];
			[metadataDelegate setMetadata:metadata];
			[dmap release];
			
		} else if ([content_type hasPrefix:@"image/"]) {
			[coverDelegate setCoverData:content];
		}
		
		[self replyOK:sock withHeaders:nil withData:nil];
		return;

	} else if ([method isEqualToString:@"FLUSH"]) {
		[audioPlayer stop];
		[self replyOK:sock withHeaders:nil withData:nil];

	} else if ([method isEqualToString:@"TEARDOWN"]) {
		[timeSync release];
		timeSync = nil;
		
		[serverSocket release];
		serverSocket = nil;
		[controlSocket release];
		controlSocket = nil;
		
		[cryptoController reset];
		
		[self replyOK:sock withHeaders:nil withData:nil];
	}
}

- (void)timeSyncWithLatency:(uint32_t)latency userData:(id)data
{
	GCDAsyncSocket *sock = data;
	
	audioPlayer = [[AudioPlayer alloc] initWithFmt:fmtp];
	if (audioPlayer == nil) {
		NSLog(@"Error: unable to init audio player");
		// TODO: reply error
		return;
	}
	
	[audioPlayer start];

	NSDictionary *hDict = [NSDictionary dictionaryWithObjectsAndKeys:
						   [NSString stringWithFormat:@"%u", latency + 2000], @"Audio-Latency",
						   nil];
	
	[self replyOK:sock withHeaders:hDict withData:nil];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	switch (tag)
	{
		case TAG_REQUEST:
		{
			NSString *request = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
			NSArray *a = [request componentsSeparatedByString:@" "];
			method = [[a objectAtIndex:0] retain];
			location = [[a objectAtIndex:1] retain];
			[request release];
			headers = [[NSMutableDictionary alloc] init];
			[sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:TIMEOUT_NONE tag:TAG_HEADER];
			return;
		}
			
		case TAG_HEADER:
		{
			NSString *header = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
			if ([header isEqualToString:@"\r\n"]) {
				[header release];
				if (contentLength > 0)
					[sock readDataToLength:contentLength withTimeout:TIMEOUT_NONE tag:TAG_CONTENT];
				else
					[self socketReceivedRequest:sock];
				return;
			}
			
			NSRange range = [header rangeOfString:@":"];
			NSString *key = [header substringToIndex:range.location];
			range.location += 1;
			range.length = [header length] - range.location - 2;
			NSString *value = [[header substringWithRange:range]
							   stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];

			[headers setObject:value forKey:key];
			if ([key compare:@"Content-Length" options:NSCaseInsensitiveSearch] == NSOrderedSame)
				contentLength = [value integerValue];
			[header release];

//			NSLog(@" header %@ %@", key, value);
			[sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:TIMEOUT_NONE tag:TAG_HEADER];
			return;
		}
			
		case TAG_CONTENT:
		{
			content = [data retain];
//			NSLog(@" content: %@", content);
			[self socketReceivedRequest:sock];
			return;
		}
	}

	NSLog(@"Error: invalid read tag %lu", tag);
}

- (void)handleControlPacket:(NSData *)data
{
	struct airtunes_control_packet pkt;
	
	if ([data length] != sizeof(pkt))
		return;
	
	[data getBytes:&pkt length:sizeof(pkt)];
	
	if (pkt.airtunes_packet != AIRTUNES_PACKET &&
		pkt.airtunes_packet != AIRTUNES_FIRST_PACKET)
		return;
	
	pkt.current_rtp_time = OSSwapBigToHostInt32(pkt.current_rtp_time);
	pkt.current_ntp_timestamp = OSSwapBigToHostInt64(pkt.current_ntp_timestamp);
	pkt.next_rtp_time = OSSwapBigToHostInt32(pkt.next_rtp_time);
	
//	NSLog(@"Control: rtp=0x%x ntp=0x%llx next_rtp=0x%x",
//		  pkt.current_rtp_time, pkt.current_ntp_timestamp, pkt.next_rtp_time);
}

- (void)handleAudioPacket:(NSData *)data
{
	struct airtunes_audio_packet pkt;

//	NSLog(@"Audio pkt: %u", [data length]);
//	NSLog(@"Audio pkt: %u %@", [data length], data);
	
	if ([data length] < sizeof(pkt))
		return;
	
	[data getBytes:&pkt length:sizeof(pkt)];
	
	NSRange range = {
		.location = 12,
		.length = [data length] - 12,
	};

	[audioPlayer enqueuePacket:[cryptoController decryptData:[data subdataWithRange:range]]];
}

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock
	 didReceiveData:(NSData *)data
			withTag:(long)tag
		   fromHost:(NSString *)host
			   port:(UInt16)port
{
	switch (tag)
	{
		case TAG_SERVER:
			[self handleAudioPacket:data];
			[sock receiveWithTimeout:TIMEOUT_NONE tag:tag];
			return YES;
			
		case TAG_CONTROL:
			[self handleControlPacket:data];
			[sock receiveWithTimeout:TIMEOUT_NONE tag:tag];
			return YES;
	}
	
	NSLog(@"Error: invalid udp read tag %lu", tag);
	return NO;
}

- (void)cleanup
{
	[method release];
	method = nil;
	[location release];
	location = nil;
	[headers release];
	headers = nil;
	contentLength = 0;
	[content release];
	content = nil;
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	switch (tag)
	{
		case TAG_REPLY:
			// cleanup the current request
			[self cleanup];

			// read the next request
			[sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:TIMEOUT_NONE tag:TAG_REQUEST];
			return;
	}

	NSLog(@"Error: invalid write tag %lu", tag);
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	NSLog(@"[Net] disconnected");
	[self cleanup];
}


#pragma mark NSNetServiceDelegate


- (void)netServiceDidPublish:(NSNetService *)ns
{
	NSLog(@"[Bonjour] service published: domain(%@) type(%@) name(%@) port(%i)",
		  [ns domain], [ns type], [ns name], [ns port]);
}

- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict
{
	NSLog(@"[Bonjour] failed to publish service: domain(%@) type(%@) name(%@) - %@",
		  [ns domain], [ns type], [ns name], errorDict);
}

@end
