//
//  AirTunes.h
//  AirSpeaker
//
//  Created by Clément Vasseur on 2/10/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#include <stdint.h>

#define AIRTUNES_PACKET						0x80
#define AIRTUNES_FIRST_PACKET				0x90
#define AIRTUNES_AUDIO_PACKET				0x60
#define AIRTUNES_AUDIO_FIRST				0xe0
#define AIRTUNES_TIMING_QUERY				0xd2
#define AIRTUNES_TIMING_REPLY				0xd3
#define AIRTUNES_CONTROL_SYNC				0xd4

#define kAirTunesAudioSampleRate			44100
#define kAirTunesAudioFramesPerPacket		352
#define kAirTunesAudioChannelsPerFrame		2
#define kAirTunesAudioBitsPerChannel		16

struct airtunes_control_packet {
	uint8_t airtunes_packet;
	uint8_t airtunes_command;
	uint16_t fixed;
	uint32_t current_rtp_time;
	uint64_t current_ntp_timestamp;
	uint32_t next_rtp_time;
} __attribute__((packed));

struct airtunes_timing_packet {
	uint8_t airtunes_packet;
	uint8_t airtunes_command;
	uint16_t fixed;
	uint32_t zero;
	uint64_t timestamp_1;
	uint64_t timestamp_2;
	uint64_t timestamp_3;
} __attribute__((packed));

struct airtunes_audio_packet {
	uint8_t airtunes_packet;
	uint8_t airtunes_command;
	uint16_t rtp_sequence;
	uint32_t rtp_time;
	uint32_t session_id;
	uint8_t audio_data[];
} __attribute__((packed));