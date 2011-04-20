//
//  AirSpeakerViewController.h
//  AirSpeaker
//
//  Created by Clément Vasseur on 1/24/11.
//  Copyright 2011 Clément Vasseur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AirTunesController.h"

@interface AirSpeakerViewController : UIViewController <AirTunesMetadataDelegate, AirTunesCoverDelegate> {
    AirTunesController *airtunes;
	IBOutlet UIImageView *imageView;
	IBOutlet UILabel *artistLabel;
	IBOutlet UILabel *songLabel;
}

@property (readwrite, retain, nonatomic) AirTunesController *airtunes;

- (void)setMetadata:(NSDictionary *)metadata;
- (void)setCoverData:(NSData *)cover;

@end
