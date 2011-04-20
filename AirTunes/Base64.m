//
//  Base64.m
//  AirSpeaker
//
//  Created by Clément Vasseur on 2/20/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import "Base64.h"

static const char encodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

NSString *base64_encode(NSData *data)
{
	size_t data_length = [data length];
	const uint8_t *data_bytes = [data bytes];
	
	if (data_length == 0)
		return @"";
	
    char *characters = malloc(((data_length + 2) / 3) * 4);
	if (characters == NULL)
		return nil;
	
	NSUInteger length = 0;
	NSUInteger i = 0;
	
	while (i < data_length) {
		char buffer[3] = {0, 0, 0};
		short bufferLength = 0;
		while (bufferLength < 3 && i < data_length)
			buffer[bufferLength++] = data_bytes[i++];
		
		//  Encode the bytes in the buffer to four characters, including padding "=" characters if necessary.
		characters[length++] = encodingTable[(buffer[0] & 0xFC) >> 2];
		characters[length++] = encodingTable[((buffer[0] & 0x03) << 4) | ((buffer[1] & 0xF0) >> 4)];

		if (bufferLength > 1)
			characters[length++] = encodingTable[((buffer[1] & 0x0F) << 2) | ((buffer[2] & 0xC0) >> 6)];
//		else
//			characters[length++] = '=';

		if (bufferLength > 2)
			characters[length++] = encodingTable[buffer[2] & 0x3F];
//		else
//			characters[length++] = '=';	
	}
	
	return [[[NSString alloc] initWithBytesNoCopy:characters
										   length:length
										 encoding:NSASCIIStringEncoding
									 freeWhenDone:YES] autorelease];
}

NSData *base64_decode(NSString *string)
{
	if ([string length] == 0)
		return [NSData data];
	
	char decodingTable[256];
	memset(decodingTable, CHAR_MAX, 256);

	for (int i = 0; i < 64; i++)
		decodingTable[(short)encodingTable[i]] = i;

	const char *characters = [string cStringUsingEncoding:NSASCIIStringEncoding];
	if (characters == NULL)     //  Not an ASCII string!
		return nil;
	char *bytes = malloc((([string length] + 3) / 4) * 3);
	if (bytes == NULL)
		return nil;

	NSUInteger length = 0;
	NSUInteger i = 0;
	
	while (YES) {
		char buffer[4];
		short bufferLength;

		for (bufferLength = 0; bufferLength < 4; i++) {
			if (characters[i] == '\0')
				break;
			if (isspace(characters[i]) || characters[i] == '=')
				continue;
			buffer[bufferLength] = decodingTable[(short)characters[i]];
			if (buffer[bufferLength++] == CHAR_MAX) {      //  Illegal character!
				free(bytes);
				return nil;
			}
		}
		
		if (bufferLength == 0)
			break;

		if (bufferLength == 1) {     //  At least two characters are needed to produce one byte!
			free(bytes);
			return nil;
		}
		
		//  Decode the characters in the buffer to bytes.
		bytes[length++] = (buffer[0] << 2) | (buffer[1] >> 4);
		if (bufferLength > 2)
			bytes[length++] = (buffer[1] << 4) | (buffer[2] >> 2);
		if (bufferLength > 3)
			bytes[length++] = (buffer[2] << 6) | buffer[3];
	}
	
	realloc(bytes, length);
	
	return [NSData dataWithBytesNoCopy:bytes length:length];
}