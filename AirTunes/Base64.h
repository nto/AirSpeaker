//
//  Base64.h
//  AirSpeaker
//
//  Created by Clément Vasseur on 2/20/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString *base64_encode(NSData *data);
NSData *base64_decode(NSString *string);
