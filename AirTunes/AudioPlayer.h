//
//  AudioPlayer.h
//  AirSpeaker
//
//  Created by Clément Vasseur on 2/10/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioQueue.h>
#import <AVFoundation/AVAudioSession.h>

// I could not get the native AppleLossless codec to work on
// the iPhone, even though it works fine on the simulator,
// so we will use a software decoder instead.

#define USE_ALAC_DECODER

#ifdef USE_ALAC_DECODER
# import "alac.h"
#endif

#define kNumberBuffers 8

@interface AudioPlayer : NSObject <AVAudioSessionDelegate> {
	AudioQueueRef		audioQueue;
	NSMutableArray		*audioPackets;
	AudioQueueBufferRef	buffers[kNumberBuffers];
	BOOL				playing;
	BOOL				interruptedWhilePlaying;
	BOOL				first_pkt;
	
#ifdef USE_ALAC_DECODER
	alac_file			*alac;
#endif
}

- (id)initWithFmt:(int[12])fmtp;
- (void)setGain:(Float32)gain;
- (void)start;
- (void)enqueuePacket:(NSData *)audioPacket;
- (NSData *)dequeuePacket;
- (void)pause;
- (void)stop;
- (void)dealloc;

@end
