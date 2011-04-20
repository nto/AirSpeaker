//
//  CryptoController.h
//  AirSpeaker
//
//  Created by Clément Vasseur on 2/20/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCryptor.h>
#import <Security/Security.h>

@interface CryptoController : NSObject {
	SecKeyRef privateKey;
	CCCryptorRef cryptor;
	NSData *iv;
}

- (id)init;
- (NSData *)challengeResponse:(NSData *)challenge withAddr:(NSData *)addr;
- (BOOL)setRsaAesKey:(NSData *)key;
- (BOOL)setAesIv:(NSData *)iv;
- (NSData *)decryptData:(NSData *)data;
- (void)reset;
- (void)dealloc;

@end
