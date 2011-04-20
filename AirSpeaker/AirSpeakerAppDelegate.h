//
//  AirSpeakerAppDelegate.h
//  AirSpeaker
//
//  Created by Clément Vasseur on 1/24/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AirSpeakerViewController;
@class AirTunesController;

@interface AirSpeakerAppDelegate : NSObject <UIApplicationDelegate> {
	AirTunesController *airtunes;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet AirSpeakerViewController *viewController;

@end
