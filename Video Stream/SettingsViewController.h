//
//  SettingsViewController.h
//  Video Stream
//
//  Created by Rus Flaviu on 12/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@protocol SettingsViewControllerDelegate <NSObject>

- (void)settingsDidSave;

@end

@interface SettingsViewController : UIViewController

@property (retain, nonatomic) IBOutlet UIScrollView *scrollView;

@property (retain, nonatomic) IBOutlet UITextField *textFieldForServer;
@property (retain, nonatomic) IBOutlet UITextField *testFieldForFPS;
@property (retain, nonatomic) IBOutlet UITextField *textFieldForApplication;
@property (retain, nonatomic) IBOutlet UITextField *textFieldForKeyFrameInterval;
@property (retain, nonatomic) IBOutlet UISegmentedControl *segmentForResolutions;
@property (retain, nonatomic) IBOutlet UISlider *sliderForkbps;
@property (retain, nonatomic) IBOutlet UILabel *labelForkbps;

@property (assign, nonatomic) id<SettingsViewControllerDelegate> delegate;

- (IBAction)sliderChangedValue:(id)sender;
- (IBAction)resolutionChangedValue:(id)sender;
- (IBAction)pushSaveSettings:(id)sender;
- (IBAction)pushCancel:(id)sender;
- (IBAction)backgroundTap:(id)sender;

@end
