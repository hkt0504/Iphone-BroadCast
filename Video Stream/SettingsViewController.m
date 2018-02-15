//
//  SettingsViewController.m
//  Video Stream
//
//  Created by Rus Flaviu on 12/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "SettingsViewController.h"
#import "Util.h"

#define kDefaultServer @"rtmp://192.168.1.109:1935/live"
#define kDefaultApplication @"testRtmp"

@interface SettingsViewController ()

@end

@implementation SettingsViewController

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	
	//return NO;
    if (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		return YES ;
    }
    return NO ;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [_textFieldForServer release];
    [_testFieldForFPS release];
    [_textFieldForApplication release];
    [_textFieldForKeyFrameInterval release];
    [_segmentForResolutions release];
    [_sliderForkbps release];
    [_labelForkbps release];
    [_scrollView release];
    [super dealloc];
}
- (void)viewDidUnload {
    
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
    [self setTextFieldForServer:nil];
    [self setTestFieldForFPS:nil];
    [self setTextFieldForApplication:nil];
    [self setTextFieldForKeyFrameInterval:nil];
    [self setSegmentForResolutions:nil];
    [self setSliderForkbps:nil];
    [self setLabelForkbps:nil];
    [self setScrollView:nil];
    [super viewDidUnload];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(keyboardDidShow)
                                                 name: UIKeyboardDidShowNotification
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(keyboardDidHide)
                                                 name: UIKeyboardDidHideNotification
                                               object: nil];
    
    self.sliderForkbps.maximumValue = 1.0;
    self.sliderForkbps.minimumValue = 0.1;
    
    [self loadSavedValues];
    [self sliderChangedValue: nil];
}

#pragma mark -
#pragma mark UIKeyboard Notifications

- (void)keyboardDidShow
{
    self.scrollView.contentSize = CGSizeMake(480, self.scrollView.frame.size.height + 162);
}

- (void)keyboardDidHide
{
    self.scrollView.contentSize = CGSizeMake(480, self.scrollView.frame.size.height);
}

#pragma mark -
#pragma mark Settings Values

- (void)loadSavedValues
{
    //NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithUser: @"streamingUser"];
    
    self.segmentForResolutions.selectedSegmentIndex = [defaults integerForKey: @"streaming.savedResolution"];
    
    CGFloat kbpsScalar = [defaults floatForKey: @"streaming.savedkbpsScalar"];
    
    if (kbpsScalar < 0.1) {
        kbpsScalar = 0.4;
    }
    
    self.sliderForkbps.value = kbpsScalar;
    
    NSString *server = [defaults stringForKey: @"streaming.serverName"];
    NSString *application = [defaults stringForKey: @"streaming.applicationName"];
    
    NSInteger fps = [defaults integerForKey: @"streaming.fps"];
    NSInteger keyFrInt = [defaults integerForKey: @"streaming.keyFrInt"];
    
    [defaults release];
    
    self.textFieldForServer.text = server ? server : kDefaultServer;
    self.textFieldForApplication.text = application ? application : kDefaultApplication;
    self.testFieldForFPS.text = fps != 0 ? [NSString stringWithFormat: @"%ld", (long)fps] : [NSString stringWithFormat: @"%d", kDefaultFramesPerSecond];
    self.textFieldForKeyFrameInterval.text = keyFrInt != 0 ? [NSString stringWithFormat: @"%ld", (long)keyFrInt] : [NSString stringWithFormat: @"%d", kDefaultKeyFrameInterval];
}

- (BOOL)saveValues
{
    if (self.textFieldForApplication.text.length == 0 ||
        self.testFieldForFPS.text.length == 0 ||
        self.textFieldForKeyFrameInterval.text.length == 0 ||
        self.textFieldForServer.text.length == 0) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @""
                                                        message: @"Please complete all fields."
                                                       delegate: nil
                                              cancelButtonTitle: @"Ok"
                                              otherButtonTitles: nil];
        [alert show];
        [alert release];
        
        return NO;
    }
    else {
        //NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithUser: @"streamingUser"];
        
        [defaults setInteger: self.segmentForResolutions.selectedSegmentIndex forKey: @"streaming.savedResolution"];
        [defaults setFloat: self.sliderForkbps.value forKey: @"streaming.savedkbpsScalar"];
        [defaults setInteger: self.textFieldForKeyFrameInterval.text.integerValue forKey: @"streaming.keyFrInt"];
        [defaults setInteger: self.testFieldForFPS.text.integerValue forKey: @"streaming.fps"];
        [defaults setObject: self.textFieldForApplication.text forKey: @"streaming.applicationName"];
        [defaults setObject: self.textFieldForServer.text forKey: @"streaming.serverName"];
        [defaults synchronize];
        
        [defaults release];
        
        return YES;
    }
}

#pragma mark -
#pragma mark Actions

- (IBAction)sliderChangedValue:(id)sender {
    
    CGFloat sliderValue;
    
    switch (self.segmentForResolutions.selectedSegmentIndex) {
        case 0:
            sliderValue = self.sliderForkbps.value * MaximumBitrate_192x144 / 1000;
            break;
        case 1:
            sliderValue = self.sliderForkbps.value * MaximumBitrate_320x240 / 1000;
            break;
        case 2:
            sliderValue = self.sliderForkbps.value * MaximumBitrate_480x360 / 1000;
            break;
        case 3:
            sliderValue = self.sliderForkbps.value * MaximumBitrate_640x480 / 1000;
            break;
        case 4:
            sliderValue = self.sliderForkbps.value * MaximumBitrate_1280x720 / 1000;
            break;
        case 5:
            sliderValue = self.sliderForkbps.value * MaximumBitrate_1920x1080 / 1000;
            break;
        default:
            sliderValue = 1000;
            break;
    }
    
    self.labelForkbps.text = [NSString stringWithFormat: @"%d kbps", (int)sliderValue];
}

- (IBAction)resolutionChangedValue:(id)sender {
    [self sliderChangedValue: nil];
}

- (IBAction)pushSaveSettings:(id)sender {
    
    if ([self saveValues]) {
        [self dismissModalViewControllerAnimated: YES];
        [self.delegate settingsDidSave];
    }
    
}

- (IBAction)pushCancel:(id)sender
{
    [self dismissModalViewControllerAnimated: YES];
    [self.delegate settingsDidSave];
}

- (IBAction)backgroundTap:(id)sender {
    [self.testFieldForFPS resignFirstResponder];
    [self.textFieldForApplication resignFirstResponder];
    [self.textFieldForKeyFrameInterval resignFirstResponder];
    [self.textFieldForServer resignFirstResponder];
}
@end
