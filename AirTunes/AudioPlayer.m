//
//  AudioPlayer.m
//  AirSpeaker
//
//  Created by Clément Vasseur on 2/10/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import "AudioPlayer.h"
#import "AirTunes.h"

#ifdef USE_ALAC_DECODER
# define kBufferByteSize 1408
#else
# define kBufferByteSize 2048
#endif

struct alac_cookie {
	uint32_t size_1;
	char frma[4];
	char alac_1[4];
	
	uint32_t size_2;
	char alac_2[4];
	uint32_t zero_1;
	uint32_t samples_per_frame;
	uint8_t fmtp_2;
	uint8_t sample_size;
	uint8_t rice_historymult;
	uint8_t rice_initialhistory;
	uint8_t rice_kmodifier;
	uint8_t channels;
	uint16_t fmtp_8;
	uint32_t fmtp_9;
	uint32_t fmtp_10;
	uint32_t sample_rate;
} __attribute__((packed));

@implementation AudioPlayer

static void logOSStatus(const char *func, OSStatus status)
{
	if (status != noErr)
		NSLog(@"Audio Queue Services: %s error %ld (0x%lx)", func, status, status);
}

static void audio_cb(void *userData,
					 AudioQueueRef audioQueue,
					 AudioQueueBufferRef audioBuffer)
{
	AudioPlayer *self = userData;
	NSData *audioPacket = [self dequeuePacket];
	AudioQueueBufferRef *bptr = audioBuffer->mUserData;

	*bptr = audioBuffer;
	
	if (audioPacket != nil)
		[self enqueuePacket:audioPacket];
}

- (void)beginInterruption
{
	NSLog(@"[AVAudioSession] audio interruption begin");

    if (playing) {
        playing = NO;
        interruptedWhilePlaying = YES;
    }
}

- (void)endInterruption
{
	NSError *error = nil;
	
    if (interruptedWhilePlaying) {
        if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
			NSLog(@"[AVAudioSession] setActive error %@", error);
			return;
		}
//        [player play];
        playing = YES;
        interruptedWhilePlaying = NO;
    }
}

- (void)setupAudioSession
{
	NSError *error = nil;

	// initialize audio session
	AVAudioSession *session = [AVAudioSession sharedInstance];
	
	// set playback category
	if (![session setCategory:AVAudioSessionCategoryPlayback error:&error]) {
		NSLog(@"[AVAudioSession] setCategory error: %@", error);
		return;
	}
	
	// set interruption delegate
	session.delegate = self;
	
	// activate audio session
	if (![session setActive:YES error:&error])
		NSLog(@"[AVAudioSession] setActive error: %@", error);
}

- (void)setFmt:(int[12])fmtp
{
#ifdef USE_ALAC_DECODER
	
    int sample_size = fmtp[3];
	
    alac = create_alac(sample_size, kAirTunesAudioChannelsPerFrame);
    if (alac == NULL)
        return;
	
    alac->setinfo_max_samples_per_frame = fmtp[1];
    alac->setinfo_7a = fmtp[2];
    alac->setinfo_sample_size = sample_size;
    alac->setinfo_rice_historymult = fmtp[4];
    alac->setinfo_rice_initialhistory = fmtp[5];
    alac->setinfo_rice_kmodifier = fmtp[6];
    alac->setinfo_7f = fmtp[7];
    alac->setinfo_80 = fmtp[8];
    alac->setinfo_82 = fmtp[9];
    alac->setinfo_86 = fmtp[10];
    alac->setinfo_8a_rate = fmtp[11];
	
    allocate_buffers(alac);
	
#else
	
	OSStatus status;
	
	struct alac_cookie cookie = {
		.size_1              = OSSwapHostToBigInt32(12),
		.frma                = "frma",
		.alac_1              = "alac",
		
		.size_2              = OSSwapHostToBigInt32(36),
		.alac_2              = "alac",
		.zero_1              = 0,
		.samples_per_frame   = OSSwapHostToBigInt32(fmtp[1]),
		.fmtp_2              = fmtp[2],
		.sample_size         = fmtp[3],
		.rice_historymult    = fmtp[4],
		.rice_initialhistory = fmtp[5],
		.rice_kmodifier      = fmtp[6],
		.channels            = fmtp[7],
		.fmtp_8              = OSSwapHostToBigInt16(fmtp[8]),
		.fmtp_9              = OSSwapHostToBigInt32(fmtp[9]),
		.fmtp_10             = OSSwapHostToBigInt32(fmtp[10]),
		.sample_rate         = OSSwapHostToBigInt32(fmtp[11]),
	};
	
	NSData *data = [NSData dataWithBytesNoCopy:&cookie length:sizeof(cookie) freeWhenDone:NO];
	NSLog(@"[AudioPlayer] cookie: %@", data);
	
	status = AudioQueueSetProperty(audioQueue, kAudioQueueProperty_MagicCookie, &cookie, sizeof(cookie));
	logOSStatus("AudioQueueSetProperty", status);
#endif
}

- (id)initWithFmt:(int [12])fmtp
{
	if ((self = [super init])) {
		OSStatus status;
		
		const AudioStreamBasicDescription format = {
#ifdef USE_ALAC_DECODER
			.mSampleRate		= kAirTunesAudioSampleRate,
			.mFormatID			= kAudioFormatLinearPCM,
			.mFormatFlags		= kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
			.mBytesPerPacket	= (kAirTunesAudioBitsPerChannel / 8) * kAirTunesAudioChannelsPerFrame,
			.mFramesPerPacket	= 1,
			.mBytesPerFrame		= (kAirTunesAudioBitsPerChannel / 8) * kAirTunesAudioChannelsPerFrame,
			.mChannelsPerFrame	= kAirTunesAudioChannelsPerFrame,
			.mBitsPerChannel	= kAirTunesAudioBitsPerChannel,
#else
			.mSampleRate		= kAirTunesAudioSampleRate,
			.mFormatID			= kAudioFormatAppleLossless,
			.mFormatFlags		= kAppleLosslessFormatFlag_16BitSourceData,
			.mBytesPerPacket	= 0,
			.mFramesPerPacket	= kAirTunesAudioFramesPerPacket,
			.mBytesPerFrame		= 0,
			.mChannelsPerFrame	= kAirTunesAudioChannelsPerFrame,
			.mBitsPerChannel	= 0,
#endif
			.mReserved			= 0,
		};
		
		[self setupAudioSession];
		
		status = AudioQueueNewOutput(&format,
									 audio_cb,
									 self,
									 CFRunLoopGetCurrent(),
									 kCFRunLoopCommonModes,
									 0,
									 &audioQueue);
		
		logOSStatus("AudioQueueNewOutput", status);
		if (status != 0) {
			[self release];
			return nil;
		}
		
		// allocate audio buffers		
		for (int i = 0; i < kNumberBuffers; i++) {
			status = AudioQueueAllocateBufferWithPacketDescriptions(audioQueue, kBufferByteSize, 1, &buffers[i]);
			logOSStatus("AudioQueueAllocateBuffer", status);
			buffers[i]->mUserData = &buffers[i];
		}
		
		[self setGain:1.0];
		[self setFmt:fmtp];

		first_pkt = YES;
		
		audioPackets = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)setGain:(Float32)gain
{
	OSStatus status = AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, gain);
	logOSStatus("AudioQueueSetParameter", status);
}

- (void)start
{
//	NSLog(@"[AudioPlayer] start");
//	OSStatus status = AudioQueueStart(audioQueue, NULL);
//	logOSStatus("AudioQueueStart", status);
}

- (void)stop
{
	NSLog(@"[AudioPlayer] stop");
	
	[audioPackets removeAllObjects];

	OSStatus status = AudioQueueStop(audioQueue, true);
	logOSStatus("AudioQueueStop", status);
	
	first_pkt = YES;
}

- (void)pause
{
	OSStatus status = AudioQueuePause(audioQueue);
	logOSStatus("AudioQueuePause", status);
}

- (void)dealloc
{
#ifdef USE_ALAC_DECODER
	free(alac->predicterror_buffer_a);
    free(alac->predicterror_buffer_b);	
    free(alac->outputsamples_buffer_a);
    free(alac->outputsamples_buffer_b);
	free(alac->uncompressed_bytes_buffer_a);
	free(alac->uncompressed_bytes_buffer_b);
	free(alac);
#endif
	
	OSStatus status = AudioQueueDispose(audioQueue, true);
	logOSStatus("AudioQueueDispose", status);
	[audioPackets release];

	[super dealloc];
}

static void enqueueBufferWithPacket(AudioQueueRef audioQueue,
									AudioQueueBufferRef audioBuffer,
									NSData *audioPacket,
									AudioPlayer *this)
{
#ifdef USE_ALAC_DECODER
	int outsize;
	
    decode_frame(this->alac, [audioPacket bytes], audioBuffer->mAudioData, &outsize);
	audioBuffer->mAudioDataByteSize = outsize;

#else
	if ([audioPacket length] > audioBuffer->mAudioDataBytesCapacity) {
		NSLog(@"Error: audio packet too big");
		return;
	}
	
	audioBuffer->mAudioDataByteSize = [audioPacket length];
	[audioPacket getBytes:audioBuffer->mAudioData length:audioBuffer->mAudioDataByteSize];
#endif

	audioBuffer->mPacketDescriptions[0].mStartOffset = 0;
	audioBuffer->mPacketDescriptions[0].mVariableFramesInPacket = kAirTunesAudioFramesPerPacket;
	audioBuffer->mPacketDescriptions[0].mDataByteSize = audioBuffer->mAudioDataByteSize;
	audioBuffer->mPacketDescriptionCount = 1;
	
//	NSLog(@"AudioPlayer: enqueue %lu bytes (%02x %02x %02x %02x)", audioBuffer->mAudioDataByteSize,
//		  ((uint8_t *) audioBuffer->mAudioData)[0],
//		  ((uint8_t *) audioBuffer->mAudioData)[1],
//		  ((uint8_t *) audioBuffer->mAudioData)[2],
//		  ((uint8_t *) audioBuffer->mAudioData)[3]);
	
#if 0		
	if (this->first_pkt) {
		AudioTimeStamp audioTimeStamp = {
			.mSampleTime = kAirTunesAudioSampleRate * 2, // 2 second buffer
			.mFlags = kAudioTimeStampSampleTimeValid,
		};
	
		NSLog(@"SET AUDIO TIME STAMP");
		OSStatus status = AudioQueueEnqueueBufferWithParameters(audioQueue,
																audioBuffer,
																0, NULL,
																0, 0,
																0, NULL,
																&audioTimeStamp, NULL);

		logOSStatus("AudioQueueEnqueueBufferWithParameters", status);
		this->first_pkt = NO;

		NSLog(@"[AudioPlayer] start");
		status = AudioQueueStart(audioQueue, NULL);
		logOSStatus("AudioQueueStart", status);

	} else {
#endif
		OSStatus status = AudioQueueEnqueueBuffer(audioQueue, audioBuffer, 0, NULL);
		logOSStatus("AudioQueueEnqueueBuffer", status);
//	}
}

- (void)enqueuePacket:(NSData *)audioPacket
{
	for (int i = 0; i < kNumberBuffers; i++)
		if (buffers[i] != NULL) {
			enqueueBufferWithPacket(audioQueue, buffers[i], audioPacket, self);
			buffers[i] = NULL;
			return;
		}

	[audioPackets addObject:audioPacket];
	
	if (first_pkt) {
		if ([audioPackets count] == 200) {
			NSLog(@"[AudioPlayer] start");
			OSStatus status = AudioQueueStart(audioQueue, NULL);
			logOSStatus("AudioQueueStart", status);
			first_pkt = NO;
		}
	}
}

- (NSData *)dequeuePacket
{
	if ([audioPackets count] == 0)
		return nil;

	NSData *audioPacket = [audioPackets objectAtIndex:0];
	[[audioPacket retain] autorelease]; // so it isn't dealloc'ed on remove
	[audioPackets removeObjectAtIndex:0];
    return audioPacket;
}

@end
