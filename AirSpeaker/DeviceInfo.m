//
//  DeviceInfo.m
//  AirSpeaker
//
//  Created by Clément Vasseur on 12/22/10.
//  Copyright 2010 Clément Vasseur. All rights reserved.
//

#import "DeviceInfo.h"

#include <sys/sysctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <ifaddrs.h>

#include <net/if.h>
#include <net/if_dl.h>

#if !defined(IFT_ETHER)
# define IFT_ETHER 0x6 /* Ethernet CSMACD */
#endif

@implementation DeviceInfo

+ (NSString *)getSysInfoByName:(char *)typeSpecifier
{
	size_t size;
	sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);
	char *answer = malloc(size);
	sysctlbyname(typeSpecifier, answer, &size, NULL, 0);
	NSString *results = [NSString stringWithCString:answer encoding:NSUTF8StringEncoding];
	free(answer);
	return results;
}

+ (NSString *)platform
{
	return [self getSysInfoByName:"hw.machine"];
}

+ (NSData *)deviceId
{
	NSData *res;
	struct ifaddrs *addrs;
	const struct ifaddrs *cursor;
	const struct sockaddr_dl *dlAddr;
	const uint8_t *base;
	
	if (getifaddrs(&addrs) != 0) {
		NSLog(@"[DeviceInfo] getifaddrs failed");
		return nil;
	}
	
	res = nil;
	
	for (cursor = addrs; cursor != NULL; cursor = cursor->ifa_next) {
		if ((cursor->ifa_addr->sa_family == AF_LINK) &&
			(((const struct sockaddr_dl *) cursor->ifa_addr)->sdl_type == IFT_ETHER)) {
			
			dlAddr = (const struct sockaddr_dl *) cursor->ifa_addr;
			base = (const uint8_t *) &dlAddr->sdl_data[dlAddr->sdl_nlen];
			res = [NSData dataWithBytes:base length:dlAddr->sdl_alen];
			break;
		}
	}
	
	freeifaddrs(addrs);
	return res;	
}

+ (NSString *)deviceIdWithSep:(NSString *)sep
{
	NSMutableString *res;
	NSData *data;
	const uint8_t *bytes;
	
	data = [self deviceId];
	if (data == nil)
		return nil;

	bytes = [data bytes];
	
	res = [NSMutableString stringWithCapacity:32];
	for (int i = 0; i < [data length]; i++) {
		if (sep != nil && i != 0)
			[res appendString:sep];
		[res appendFormat:@"%02X", bytes[i]];
	}

	return res;
}

+ (NSString *)deviceIdString
{
	return [self deviceIdWithSep:@":"];
}

@end
