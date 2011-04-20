//
//  AirSpeakerViewController.m
//  AirSpeaker
//
//  Created by Clément Vasseur on 1/24/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import "AirSpeakerViewController.h"

@implementation AirSpeakerViewController

@synthesize airtunes;

- (void)setAirtunes:(AirTunesController *)airtunesController
{
	airtunes = [airtunesController retain];
	airtunes.metadataDelegate = self;
	airtunes.coverDelegate = self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
	[airtunes release];
	[imageView dealloc];
	[artistLabel release];
	[songLabel release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
}
*/

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
}
*/

- (void)viewDidUnload
{
	[imageView release];
	imageView = nil;
	[artistLabel release];
	artistLabel = nil;
	[songLabel release];
	songLabel = nil;
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)setMetadata:(NSDictionary *)metadata
{
	NSString *artist = [metadata objectForKey:@"Artist"];
	NSString *song = [metadata objectForKey:@"Song"];
	
	NSLog(@"[Meta] song: %@", song);
	NSLog(@"[Meta] artist: %@", artist);
	NSLog(@"[Meta] album: %@", [metadata objectForKey:@"Album"]);

	imageView.image = nil;
	artistLabel.text = artist;
	songLabel.text = song;
}

- (void)setCoverData:(NSData *)cover
{
	imageView.image = [UIImage imageWithData:cover];
}

@end
