//
//  CryptoController.m
//  AirSpeaker
//
//  Created by Clément Vasseur on 2/20/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import "CryptoController.h"
#import "DeviceInfo.h"
#import "Base64.h"

#define kAESKeyLength 16

@implementation CryptoController

- (SecKeyRef)getKeyRefWithPersistentKeyRef:(CFTypeRef)persistentRef
{
    OSStatus status = noErr;
    SecKeyRef keyRef = NULL;
    
	if (persistentRef == NULL)
		return NULL;

    NSMutableDictionary *queryKey = [[NSMutableDictionary alloc] init];
    
    // Set the SecKeyRef query dictionary.
    [queryKey setObject:(id)persistentRef forKey:(id)kSecValuePersistentRef];
    [queryKey setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnRef];
    
    // Get the persistent key reference.
    status = SecItemCopyMatching((CFDictionaryRef)queryKey, (CFTypeRef *)&keyRef);
    [queryKey release];
    
    return keyRef;
}

- (BOOL)setPrivateKey
{
	OSStatus status;
	
	NSString *keyName = @"AirSpeaker - AirTunes Private Key";

	NSData *key = base64_decode(@ // Thank you James Laird
		"MIIEpQIBAAKCAQEA59dE8qLieItsH1WgjrcFRKj6eUWqi+bGLOX1HL3U3GhC/j0Qg90u3sG/1CUt"
		"wC5vOYvfDmFI6oSFXi5ELabWJmT2dKHzBJKa3k9ok+8t9ucRqMd6DZHJ2YCCLlDRKSKv6kDqnw4U"
		"wPdpOMXziC/AMj3Z/lUVX1G7WSHCAWKf1zNS1eLvqr+boEjXuBOitnZ/bDzPHrTOZz0Dew0uowxf"
		"/+sG+NCK3eQJVxqcaJ/vEHKIVd2M+5qL71yJQ+87X6oV3eaYvt3zWZYD6z5vYTcrtij2VZ9Zmni/"
		"UAaHqn9JdsBWLUEpVviYnhimNVvYFZeCXg/IdTQ+x4IRdiXNv5hEewIDAQABAoIBAQDl8Axy9XfW"
		"BLmkzkEiqoSwF0PsmVrPzH9KsnwLGH+QZlvjWd8SWYGN7u1507HvhF5N3drJoVU3O14nDY4TFQAa"
		"LlJ9VM35AApXaLyY1ERrN7u9ALKd2LUwYhM7Km539O4yUFYikE2nIPscEsA5ltpxOgUGCY7b7ez5"
		"NtD6nL1ZKauw7aNXmVAvmJTcuPxWmoktF3gDJKK2wxZuNGcJE0uFQEG4Z3BrWP7yoNuSK3dii2jm"
		"lpPHr0O/KnPQtzI3eguhe0TwUem/eYSdyzMyVx/YpwkzwtYL3sR5k0o9rKQLtvLzfAqdBxBurciz"
		"aaA/L0HIgAmOit1GJA2saMxTVPNhAoGBAPfgv1oeZxgxmotiCcMXFEQEWflzhWYTsXrhUIuz5jFu"
		"a39GLS99ZEErhLdrwj8rDDViRVJ5skOp9zFvlYAHs0xh92ji1E7V/ysnKBfsMrPkk5KSKPrnjndM"
		"oPdevWnVkgJ5jxFuNgxkOLMuG9i53B4yMvDTCRiIPMQ++N2iLDaRAoGBAO9v//mU8eVkQaoANf0Z"
		"oMjW8CN4xwWA2cSEIHkd9AfFkftuv8oyLDCG3ZAf0vrhrrtkrfa7ef+AUb69DNggq4mHQAYBp7L+"
		"k5DKzJrKuO0r+R0YbY9pZD1+/g9dVt91d6LQNepUE/yY2PP5CNoFmjedpLHMOPFdVgqDzDFxU8hL"
		"AoGBANDrr7xAJbqBjHVwIzQ4To9pb4BNeqDndk5Qe7fT3+/H1njGaC0/rXE0Qb7q5ySgnsCb3DvA"
		"cJyRM9SJ7OKlGt0FMSdJD5KG0XPIpAVNwgpXXH5MDJg09KHeh0kXo+QA6viFBi21y340NonnEfdf"
		"54PX4ZGS/Xac1UK+pLkBB+zRAoGAf0AY3H3qKS2lMEI4bzEFoHeK3G895pDaK3TFBVmD7fV0Zhov"
		"17fegFPMwOII8MisYm9ZfT2Z0s5Ro3s5rkt+nvLAdfC/PYPKzTLalpGSwomSNYJcB9HNMlmhkGzc"
		"1JnLYT4iyUyx6pcZBmCd8bD0iwY/FzcgNDaUmbX9+XDvRA0CgYEAkE7pIPlE71qvfJQgoA9em0gI"
		"LAuE4Pu13aKiJnfft7hIjbK+5kyb3TysZvoyDnb3HOKvInK7vXbKuU4ISgxB2bB3HcYzQMGsz1qJ"
		"2gG0N5hvJpzwwhbhXqFKA4zaaSrw622wDniAK5MlIE0tIAKKP4yxNGjoD2QYjhBGuhvkWKaXTyY=");
	
	NSData *tag = [keyName dataUsingEncoding:NSUTF8StringEncoding];
	
	NSMutableDictionary *keyAttr = [[NSMutableDictionary alloc] init];
	
	[keyAttr setObject:(id)kSecClassKey forKey:(id)kSecClass];
	[keyAttr setObject:(id)kSecAttrKeyTypeRSA forKey:(id)kSecAttrKeyType];
	[keyAttr setObject:tag forKey:(id)kSecAttrApplicationTag];
	
	// delete any old key with the same tag
    SecItemDelete((CFDictionaryRef) keyAttr);
	
	[keyAttr setObject:(id)kSecAttrKeyClassPrivate forKey:(id)kSecAttrKeyClass];
	[keyAttr setObject:key forKey:(id)kSecValueData];
	[keyAttr setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnPersistentRef];

	SecKeyRef persistPrivateKey = NULL;
	
	status = SecItemAdd((CFDictionaryRef) keyAttr, (CFTypeRef *) &persistPrivateKey);
	if (status != noErr) {
		NSLog(@"[Crypto] SecItemAdd error %ld", status);
		return NO;
	}

	if (persistPrivateKey) {
        privateKey = [self getKeyRefWithPersistentKeyRef:persistPrivateKey];

    } else {
        [keyAttr removeObjectForKey:(id)kSecValueData];
        [keyAttr setObject:[NSNumber numberWithBool:YES] forKey:(id)kSecReturnRef];

        status = SecItemCopyMatching((CFDictionaryRef) keyAttr, (CFTypeRef *) &privateKey);
		if (status != noErr) {
			NSLog(@"[Crypto] SecItemCopyMatching error %ld", status);
			return NO;
		}
    }

	[keyAttr release];
	
	if (privateKey == NULL) {
		NSLog(@"[Crypto] unable to load private key");
		return NO;
	}

	return YES;
}

- (id)init
{
	if ((self = [super init])) {
		if (![self setPrivateKey]) {
			[self release];
			return nil;
		}
	}
	
	return self;
}

- (NSData *)challengeResponse:(NSData *)challenge withAddr:(NSData *)addr
{
	OSStatus status;
	uint8_t data[38];
	size_t data_len;
	
	if (privateKey == NULL)
		return nil;
	
	// response begins with the challenge random data
	
	if ([challenge length] != 16)
		return nil;

	[challenge getBytes:data];
	data_len = [challenge length];
	
	// append ip address

	if ([addr length] > 16)
		return nil;

	[addr getBytes:data + data_len];
	data_len += [addr length];
		
	// append mac address
	
	NSData *deviceId = [DeviceInfo deviceId];
	if ([deviceId length] != 6)
		return nil;

	[deviceId getBytes:data + data_len];
	data_len += [deviceId length];
	
	// pad with 0 if necessary
	
	while (data_len < 32)
		data[data_len++] = 0;

	// sign response using the private key
	
	uint8_t buf[1024];
	size_t buf_len = sizeof(buf);
	
	status = SecKeyRawSign(privateKey,
						   kSecPaddingPKCS1,
						   data, data_len,
						   buf, &buf_len);

	if (status != noErr) {
		NSLog(@"[Crypto] SecKeyRawSign error %ld", status);
		return nil;
	}

	return [NSData dataWithBytes:buf length:buf_len];
}

- (NSData *)decryptRsa:(NSData *)data
{
	OSStatus status;
	uint8_t *plainText;
	size_t plainTextLen;
	
	if (privateKey == NULL)
		return nil;
	
	// check input data size
	plainTextLen = [data length];
	if (plainTextLen != SecKeyGetBlockSize(privateKey)) {
		NSLog(@"[Crypto] encrypted nonce is too large and falls outside multiplicative group");
		return nil;
	}
    
    // allocate some buffer space
    plainText = calloc(1, plainTextLen);
	if (plainText == NULL)
		return nil;
	
	// decrypt using the private key
    status = SecKeyDecrypt(privateKey,
						   kSecPaddingOAEP,
						   [data bytes],
						   [data length],
						   plainText,
						   &plainTextLen);
	
	if (status != noErr) {
		NSLog(@"[Crypto] SecKeyDecrypt error %ld", status);
		free(plainText);
		return nil;
	}

	return [NSData dataWithBytesNoCopy:plainText length:plainTextLen];
}

- (BOOL)setRsaAesKey:(NSData *)key
{
	CCCryptorStatus status;
	
	key = [self decryptRsa:key];
	
	if ([key length] != kAESKeyLength) {
		NSLog(@"[Crypto] invalid AES key length");
		return NO;
	}
	
	status = CCCryptorCreate(kCCDecrypt, kCCAlgorithmAES128, 0,
							 [key bytes], [key length], NULL,
							 &cryptor);

	if (status != kCCSuccess) {
		NSLog(@"[Crypto] CCCryptorCreate error %u", status);
		return FALSE;
	}

	return YES;
}

- (BOOL)setAesIv:(NSData *)aesIv
{
	if ([aesIv length] != kAESKeyLength)
		return NO;
	
	[iv release];
	iv = [aesIv retain];
	
	return YES;
}

- (NSData *)decryptData:(NSData *)data
{
	NSMutableData *outData;
	CCCryptorStatus status;
	size_t dataOutMoved;
	size_t clear_len;
	size_t crypt_len;
	
	if (cryptor == NULL)
		return [NSData dataWithData:data];

	clear_len = [data length] % kAESKeyLength;
	crypt_len = [data length] - clear_len;
	
	outData = [NSMutableData dataWithData:data];
	if (outData == nil)
		return nil;
	
	if (crypt_len == 0)
		return outData;
	
	status = CCCryptorReset(cryptor, [iv bytes]);
	if (status != kCCSuccess) {
		NSLog(@"[Crypto] CCCryptorReset error %u", status);
		[outData release];
		return nil;
	}
	
	uint8_t dataOut[crypt_len];
	
	status = CCCryptorUpdate(cryptor,
							 [data bytes], crypt_len,
							 dataOut, crypt_len,
							 &dataOutMoved);
	
	[outData replaceBytesInRange:(NSRange){0, crypt_len} withBytes:dataOut];
	
	if (status != kCCSuccess) {
		NSLog(@"[Crypto] CCCryptorUpdate error %u", status);
		[outData release];
		return nil;
	}
	
	return outData;
}

- (void)reset
{
	CCCryptorStatus status;
	
	if (cryptor != NULL) {
		status = CCCryptorRelease(cryptor);
		if (status != kCCSuccess)
			NSLog(@"[Crypto] CCCryptorRelease error %u", status);
		cryptor = NULL;
	}
	
	[iv release];
	iv = nil;
}

- (void)dealloc
{
	[self reset];
	[super dealloc];
}

@end
