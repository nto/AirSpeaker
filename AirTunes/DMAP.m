//
//  DMAP.m
//  AirSpeaker
//
//  Created by Clément Vasseur on 4/19/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import "DMAP.h"

#define ARRAY_SIZE(A) (sizeof(A) / sizeof((A)[0]))

@implementation DMAP

enum dmap_type {
	DMAP_TYPE_BYTE,
	DMAP_TYPE_SHORT,
	DMAP_TYPE_INT,
	DMAP_TYPE_LONG,
	DMAP_TYPE_STRING,
	DMAP_TYPE_LIST,
	DMAP_TYPE_VERSION,
	DMAP_TYPE_DATE,
};

static const struct {
	const char code[4];
	enum dmap_type type;
	const char *name;

} dmapDefs[] = {
	
	// Code		Type				Name							Description
	{ "mdcl",	DMAP_TYPE_LIST,		"dmap.dictionary" },			// a dictionary entry
	{ "mstt",	DMAP_TYPE_INT,		"dmap.status" },				// the response status code, these appear to be http status codes, e.g. 200
	{ "miid",	DMAP_TYPE_INT,		"dmap.itemid" },				// an item's id
	{ "minm",	DMAP_TYPE_STRING,	"dmap.itemname" },				// an items name
	{ "mikd",	DMAP_TYPE_BYTE,		"dmap.itemkind" },				// the kind of item.  So far, only '2' has been seen, an audio file?
	{ "mper",	DMAP_TYPE_LONG,		"dmap.persistentid" },			// a persistend id
	{ "mcon",	DMAP_TYPE_LIST,		"dmap.container" },				// an arbitrary container
	{ "mcti",	DMAP_TYPE_INT,		"dmap.containeritemid" },		// the id of an item in its container
	{ "mpco",	DMAP_TYPE_INT,		"dmap.parentcontainerid" },
	{ "msts",	DMAP_TYPE_STRING,	"dmap.statusstring" },
	{ "mimc",	DMAP_TYPE_INT,		"dmap.itemcount" },				// number of items in a container
	{ "mrco",	DMAP_TYPE_INT,		"dmap.returnedcount" },			// number of items returned in a request
	{ "mtco",	DMAP_TYPE_INT,		"dmap.specifiedtotalcount" },	// number of items in response to a request
	{ "mlcl",	DMAP_TYPE_LIST,		"dmap.listing" },				// a list
	{ "mlit",	DMAP_TYPE_LIST,		"dmap.listingitem" },			// a single item in said list
	{ "mbcl",	DMAP_TYPE_LIST,		"dmap.bag" },
	{ "mdcl",	DMAP_TYPE_LIST,		"dmap.dictionary" },
	
	{ "msrv",	DMAP_TYPE_LIST,		"dmap.serverinforesponse" },	// response to a /server-info
	{ "msau",	DMAP_TYPE_BYTE,		"dmap.authenticationmethod" },	// (should be self explanitory)
	{ "mslr",	DMAP_TYPE_BYTE,		"dmap.loginrequired" },
	{ "mpro",	DMAP_TYPE_VERSION,	"dmap.protocolversion" },
	{ "apro",	DMAP_TYPE_VERSION,	"daap.protocolversion" },
	{ "msal",	DMAP_TYPE_BYTE,		"dmap.supportsuatologout" },
	{ "msup",	DMAP_TYPE_BYTE,		"dmap.supportsupdate" },
	{ "mspi",	DMAP_TYPE_BYTE,		"dmap.supportspersistentids" },
	{ "msex",	DMAP_TYPE_BYTE,		"dmap.supportsextensions" },
	{ "msbr",	DMAP_TYPE_BYTE,		"dmap.supportsbrowse" },
	{ "msqy",	DMAP_TYPE_BYTE,		"dmap.supportsquery" },
	{ "msix",	DMAP_TYPE_BYTE,		"dmap.supportsindex" },
	{ "msrs",	DMAP_TYPE_BYTE,		"dmap.supportsresolve" },
	{ "mstm",	DMAP_TYPE_INT,		"dmap.timeoutinterval" },
	{ "msdc",	DMAP_TYPE_INT,		"dmap.databasescount" },
	
	{ "mccr",	DMAP_TYPE_LIST,		"dmap.contentcodesresponse" },	// the response to the content-codes request
	{ "mcnm",	DMAP_TYPE_INT,		"dmap.contentcodesnumber" },	// the four letter code
	{ "mcna",	DMAP_TYPE_STRING,	"dmap.contentcodesname" },		// the full name of the code
	{ "mcty",	DMAP_TYPE_SHORT,	"dmap.contentcodestype" },		// the type of the code (see appendix b for type values)
	
	{ "mlog",	DMAP_TYPE_LIST,		"dmap.loginresponse" },			// response to a /login
	{ "mlid",	DMAP_TYPE_INT,		"dmap.sessionid" },				// the session id for the login session
	
	{ "mupd",	DMAP_TYPE_LIST,		"dmap.updateresponse" },		// response to a /update
	{ "msur",	DMAP_TYPE_INT,		"dmap.serverrevision" },		// revision to use for requests
	{ "muty",	DMAP_TYPE_BYTE,		"dmap.updatetype" },
	{ "mudl",	DMAP_TYPE_LIST,		"dmap.deletedidlisting" },		// used in updates?  (document soon)
	
	{ "avdb",	DMAP_TYPE_LIST,		"daap.serverdatabases" },		// response to a /databases
	{ "abro",	DMAP_TYPE_LIST,		"daap.databasebrowse" },
	{ "abal",	DMAP_TYPE_LIST,		"daap.browsealbumlistung" },	  
	{ "abar",	DMAP_TYPE_LIST,		"daap.browseartistlisting" },
	{ "abcp",	DMAP_TYPE_LIST,		"daap.browsecomposerlisting" },
	{ "abgn",	DMAP_TYPE_LIST,		"daap.browsegenrelisting" },
	
	{ "adbs",	DMAP_TYPE_LIST,		"daap.databasesongs" },			// response to a /databases/id/items
	{ "asal",	DMAP_TYPE_STRING,	"daap.songalbum" },				// the song ones should be self exp.
	{ "asar",	DMAP_TYPE_STRING,	"daap.songartist" },
	{ "asbt",	DMAP_TYPE_SHORT,	"daap.songsbeatsperminute" },
	{ "asbr",	DMAP_TYPE_SHORT,	"daap.songbitrate" },
	{ "ascm",	DMAP_TYPE_STRING,	"daap.songcomment" },
	{ "asco",	DMAP_TYPE_BYTE,		"daap.songcompilation" },
	{ "asda",	DMAP_TYPE_DATE,		"daap.songdateadded" },
	{ "asdm",	DMAP_TYPE_DATE,		"daap.songdatemodified" },
	{ "asdc",	DMAP_TYPE_SHORT,	"daap.songdisccount" },
	{ "asdn",	DMAP_TYPE_SHORT,	"daap.songdiscnumber" },
	{ "asdb",	DMAP_TYPE_BYTE,		"daap.songdisabled" },
	{ "aseq",	DMAP_TYPE_STRING,	"daap.songeqpreset" },
	{ "asfm",	DMAP_TYPE_STRING,	"daap.songformat" },
	{ "asgn",	DMAP_TYPE_STRING,	"daap.songgenre" },
	{ "asdt",	DMAP_TYPE_STRING,	"daap.songdescription" },
	{ "asrv",	DMAP_TYPE_BYTE,		"daap.songrelativevolume" },
	{ "assr",	DMAP_TYPE_INT,		"daap.songsamplerate" },
	{ "assz",	DMAP_TYPE_INT,		"daap.songsize" },
	{ "asst",	DMAP_TYPE_INT,		"daap.songstarttime" },			// (in milliseconds)	
	{ "assp",	DMAP_TYPE_INT,		"daap.songstoptime" },			// (in milliseconds)
	{ "astm",	DMAP_TYPE_INT,		"daap.songtime" },				// (in milliseconds)
	{ "astc",	DMAP_TYPE_SHORT,	"daap.songtrackcount" },
	{ "astn",	DMAP_TYPE_SHORT,	"daap.songtracknumber" },
	{ "asur",	DMAP_TYPE_BYTE,		"daap.songuserrating" },
	{ "asyr",	DMAP_TYPE_SHORT,	"daap.songyear" },
	{ "asdk",	DMAP_TYPE_BYTE,		"daap.songdatakind" },
	{ "asul",	DMAP_TYPE_STRING,	"daap.songdataurl" },
	
	{ "aply",	DMAP_TYPE_LIST,		"daap.databaseplaylists" },		// response to /databases/id/containers
	{ "abpl",	DMAP_TYPE_BYTE,		"daap.baseplaylist" },
	
	{ "apso",	DMAP_TYPE_LIST,		"daap.playlistsongs" },			// response to /databases/id/containers/id/items
	{ "prsv",	DMAP_TYPE_LIST,		"daap.resolve" },
	{ "arif",	DMAP_TYPE_LIST,		"daap.resolveinfo" },
	
	{ "aeNV",	DMAP_TYPE_INT,		"com.apple.itunes.norm-volume" },
	{ "aeSP",	DMAP_TYPE_BYTE,		"com.apple.itunes.smart-playlist" },
};

- (id)initWithData:(NSData *)dmapData
{
	if ((self = [super init])) {
		self->codes = [[NSMutableDictionary alloc] init];
		self->types = [[NSMutableDictionary alloc] init];
		
		for (unsigned i = 0; i < ARRAY_SIZE(dmapDefs); i++) {
			NSString *name = [NSString stringWithCString:dmapDefs[i].name
												encoding:NSASCIIStringEncoding];
			
			NSString *code = [[[NSString alloc] initWithBytes:dmapDefs[i].code
													   length:4
													 encoding:NSASCIIStringEncoding] autorelease];
			
			NSNumber *type = [NSNumber numberWithInt:dmapDefs[i].type];
			
			[codes setObject:code forKey:name];
			[types setObject:type forKey:name];
		}

		self->data = [dmapData retain];
	}
	
	return self;
}

static const uint8_t *getItem(const uint8_t *data,
							  size_t len,
							  const char code[4],
							  uint32_t *size)
{
	if (len < 8)
		return NULL;

	memcpy(size, data + 4, sizeof(*size));
	*size = OSSwapBigToHostInt32(*size);

	if (memcmp(data, code, 4) == 0)
		return data + 8;
	
	return getItem(data + 8 + *size, len - (8 + *size), code, size);
}

- (id)getRec:(NSString *)name data:(NSData *)dat
{
	uint32_t size;

	NSRange range = [name rangeOfString:@"/"];

	if (range.location == NSNotFound) {
		NSString *code = [codes objectForKey:name];
		NSNumber *type = [types objectForKey:name];

		const uint8_t *p = getItem([dat bytes], [dat length],
								   [code cStringUsingEncoding:NSASCIIStringEncoding],
								   &size);
		if (p == NULL)
			return nil;

		if ([type intValue] == DMAP_TYPE_STRING)
			return [[[NSString alloc] initWithBytes:p
											 length:size
										   encoding:NSUTF8StringEncoding] autorelease];

		// TODO: implement the other types
		
	} else {

		NSString *name0 = [name substringWithRange:(NSRange){0, range.location}];
		NSString *code = [codes objectForKey:name0];
		NSNumber *type = [types objectForKey:name0];

		if ([type intValue] != DMAP_TYPE_LIST)
			return nil;
		
		const uint8_t *p0 = [dat bytes];
		const uint8_t *p = getItem(p0, [dat length],
								   [code cStringUsingEncoding:NSASCIIStringEncoding],
								   &size);
		if (p == NULL)
			return nil;

		return [self getRec:[name substringFromIndex:range.location + 1]
					   data:[dat subdataWithRange:(NSRange){p - p0, size}]];
	}

	return nil;
}

- (id)get:(NSString *)name
{
	return [self getRec:name data:data];
}

- (void)dealloc
{
	[codes release];
	[types release];
	[data release];
	[super dealloc];
}

@end
