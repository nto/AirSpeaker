//
//  DMAP.h
//  AirSpeaker
//
//  Created by Clément Vasseur on 4/19/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DMAP : NSObject {
	NSMutableDictionary *codes;
	NSMutableDictionary *types;
    NSData *data;
}

- (id)initWithData:(NSData *)data;
- (id)get:(NSString *)name;

@end
