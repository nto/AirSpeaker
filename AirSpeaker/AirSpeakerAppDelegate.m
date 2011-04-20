//
//  AirSpeakerAppDelegate.m
//  AirSpeaker
//
//  Created by Clément Vasseur on 1/24/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import "AirSpeakerAppDelegate.h"
#import "AirSpeakerViewController.h"
#import "AirTunesController.h"

@implementation AirSpeakerAppDelegate

@synthesize window;
@synthesize viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// Override point for customization after application launch.
	 
	self.window.rootViewController = self.viewController;
	[self.window makeKeyAndVisible];

	airtunes = [[AirTunesController alloc] init];
	[airtunes start];
	
	viewController.airtunes = airtunes;

	return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	/*
	 Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	 Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	 */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	// Save data if appropriate.
}

- (void)dealloc
{
	[airtunes release];
	[window release];
	[viewController release];
    [super dealloc];
}

@end
