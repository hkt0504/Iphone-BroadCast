//
//  GoLiveViewController.m
//  Video Stream
//
//  Created by Rus Flaviu on 12/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "GoLiveViewController.h"
#import "SettingsViewController.h"
#import <SystemConfiguration/SCNetworkReachability.h>
#import "AppDelegate.h"

#include <netinet/in.h>

#import "Recorder.h"

#import "MotionProvider.h"

@interface GoLiveViewController ()<SettingsViewControllerDelegate, StreamingCallbackListener>
{
    int secondsPassed;
    Recorder *_stream;
}

@property (nonatomic, retain) NSTimer *timer;

@property (nonatomic, retain) NSTimer *previewHighlightTimer;

@end

@implementation GoLiveViewController


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
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupButtons];
    
    
    //NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithUser: @"streamingUser"];
    
    NSString *server = [defaults stringForKey: @"streaming.serverName"];
    
    [defaults release];
    
    self.buttonForSettings.enabled = NO;
    
    if ( ! server) {
        [self performSelector: @selector(pushSettings:) withObject:nil afterDelay:0.1];
    }
    else {
        [self initStreamer];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[MotionProvider sharedProvider] startMotionUpdate];
    [self startDrawPreviewHighlight];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self stopDrawPreviewHighlight];
    [[MotionProvider sharedProvider] stopMotionUpdate];
}

- (void)setupButtons
{
    [self.buttonForToggleStream setImage: [UIImage imageNamed: @"but_stop"] forState: UIControlStateSelected];
    [self.buttonForSound setImage: [UIImage imageNamed: @"but_mute"] forState: UIControlStateSelected];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	
	//return NO;
    if (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
		return YES ;
    }
    return NO ;
	
}

#pragma mark -
#pragma mark Actions

- (IBAction)pushSettings:(id)sender {
    
    NSLog(@"push settings");
    
    if (_stream) {
        [_stream endSession];
        _stream.delegate = nil;
        [_stream release];
    }
    
    NSString *nibName;
    nibName = @"SettingsViewController_iPhone";
        
    SettingsViewController *settingsViewController = [[SettingsViewController alloc] initWithNibName: nibName bundle: [NSBundle mainBundle]];
    settingsViewController.delegate = self;
    [self presentModalViewController: settingsViewController animated: YES];
    [settingsViewController release];
    
    self.buttonForSettings.enabled = NO;
}

- (IBAction)pushTorch:(id)sender {
    
    self.buttonForTorch.selected = !self.buttonForTorch.selected;
    
    [_stream useTorch: self.buttonForTorch.selected];
    
//    NSLog(@"BANDWIDTH = %llu", _stream.getUploadBandwidth);
}

- (IBAction)pushFlipCamera:(id)sender {
    
    [_stream useFrontCamera: !self.buttonForFlipCamera.selected completion:^(BOOL success) {
        
        NSLog(@"flipped camera: %d", success);
        
        if (success) {
            self.buttonForFlipCamera.selected = !self.buttonForFlipCamera.selected;
        }
    }];
}

- (IBAction)toggleStream:(id)sender {
    
    if (self.buttonForToggleStream.isSelected) {
        [_stream stop];
    }
    else {
        [_stream start];
    }
}

- (IBAction)toggleSound:(id)sender {
    
    if (self.buttonForSound.isSelected) {
        [self.buttonForSound setSelected: NO];
        [_stream  mute: NO];
    }
    else {
        [self.buttonForSound setSelected: YES];
        [_stream  mute: YES];
    }
}

#pragma mark -
#pragma mark Counter Setup

- (void)startCounter
{
    secondsPassed = 0;
    
    _timer = [NSTimer scheduledTimerWithTimeInterval: 1.0
                                              target: self
                                            selector: @selector(updateCounter)
                                            userInfo: nil
                                             repeats: YES];
}

- (void)updateCounter
{
    secondsPassed++;
    
    int minutes, seconds;
    
    minutes = (secondsPassed % 3600) / 60;
    seconds = (secondsPassed % 3600) % 60;
    self.labelForTime.text = [NSString stringWithFormat: @"%02d:%02d", minutes, seconds];
}

- (void)stopCounter
{
    if (self.timer) {
        [self.timer invalidate];
        _timer = nil;
    }
}

#pragma mark -
#pragma mark Settings Delegate

- (void)settingsDidSave
{
    [self performSelector: @selector(initStreamer)
               withObject: nil
               afterDelay: 0.1];
}

- (void)initStreamer
{
    //NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithUser: @"streamingUser"];
    
    CGFloat kbpsScalar = [defaults floatForKey: @"streaming.savedkbpsScalar"];
    
    NSString *server = [defaults stringForKey: @"streaming.serverName"];
    NSString *application = [defaults stringForKey: @"streaming.applicationName"];
    
    NSInteger fps = [defaults integerForKey: @"streaming.fps"];
    NSInteger keyFrInt = [defaults integerForKey: @"streaming.keyFrInt"];
    NSInteger resolution = [defaults integerForKey: @"streaming.savedResolution"];
    
    [defaults release];
    
    unsigned int bps;
    
    switch (resolution) {
        case VideoResolution_192x144:
            bps = kbpsScalar * MaximumBitrate_192x144;
            break;
        case VideoResolution_320x240:
            bps = kbpsScalar * MaximumBitrate_320x240;
            break;
        case VideoResolution_480x360:
            bps = kbpsScalar * MaximumBitrate_480x360;
            break;
        case VideoResolution_640x480:
            bps = kbpsScalar * MaximumBitrate_640x480;
            break;
        case VideoResolution_1280x720:
            bps = kbpsScalar * MaximumBitrate_1280x720;
            break;
        case VideoResolution_1920x1080:
            bps = kbpsScalar * MaximumBitrate_1920x1080;
            break;
        default:
            bps = 1000 * 1000;
            break;
    }
    
    NSLog(@"Server: %@", [NSString stringWithFormat: @"%@/%@", server, application]);

    _stream = [[Recorder alloc] initWithServer: [NSString stringWithFormat: @"%@/%@", server, application]
                                      username: nil
                                      password: nil
                                       preview: self.view
                                          mute: NO
                              callbackListener: self
                              usingFrontCamera: NO
                                    usingTorch: NO
                              videoWithQuality: resolution
                                     audioRate: 44100
                               andVideoBitRate: bps
                              keyFrameInterval: keyFrInt
                               framesPerSecond: fps
                                  andShowVideo: YES
                         saveVideoToCameraRoll: NO
                            autoAdaptToNetwork: YES
                   allowVideoResolutionChanges: YES
                                  bufferLength: kDefaultBufferLength
                             validOrientations: Orientation_LandscapeRight
                            previewOrientation: Orientation_LandscapeRight];
}

#pragma mark - Multitasking Notifications

- (void) willEnterBackground
{
    /*
    UIApplication *app = [UIApplication sharedApplication];
 
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        [app endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    // Do the work associated with the task, preferably in chunks.
    if (self.streaming) {
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            // The device is an iPad running iPhone 3.2 or later.
            [self.playStopButton setImage: [UIImage imageNamed: @"but_golive1.png"] forState: UIControlStateNormal];
        }
        else {
            // The device is an iPhone or iPod touch.
            [self.playStopButton setImage: [UIImage imageNamed: @"but_golive.png"] forState: UIControlStateNormal];
        }
        
        [self stopStreaming];
    }
     */
    
}

- (void) willEnterForeground
{
    /*
    if (( ! self.streaming) && ( ! [self.stream active])) {
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            // The device is an iPad running iPhone 3.2 or later.
            [self.playStopButton setImage: [UIImage imageNamed: @"but_golive1.png"] forState: UIControlStateNormal];
        }
        else {
            // The device is an iPhone or iPod touch.
            [self.playStopButton setImage: [UIImage imageNamed: @"but_golive.png"] forState: UIControlStateNormal];
        }
        
        [self.cameraSelectionButton setAlpha: 1.0];
    }
    else {
        
        [self stopStreaming];
    }
    
    UIApplication *app = [UIApplication sharedApplication];
    
    if (bgTask != UIBackgroundTaskInvalid) {
        [app endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }
     */
}

//- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
//{
//    switch (toInterfaceOrientation) {
//        case UIInterfaceOrientationLandscapeRight:
//            [_stream setPreviewOrientation: Orientation_LandscapeRight];
//            [_stream changePreviewFrame: CGRectMake(0, 0, 568, 320)];
//            break;
//        case UIInterfaceOrientationLandscapeLeft:
//            [_stream setPreviewOrientation: Orientation_LandscapeLeft];
//            [_stream changePreviewFrame: CGRectMake(0, 0, 568, 320)];
//            break;
//        case UIInterfaceOrientationPortrait:
//            [_stream setPreviewOrientation: Orientation_Portrait];
//            [_stream changePreviewFrame: CGRectMake(0, 0, 320, 568)];
//            break;
//        default:
//            break;
//    }
//}

#pragma mark -
#pragma mark Recorder Delegate

- (void)streamingStateChanged:(StreamingState)streamingState withMessage:(NSString *)message
{
    NSLog(@"state changed: %@", message);
    
    switch (streamingState) {
        case StreamingState_Started:
            self.buttonForToggleStream.selected = YES;
            self.buttonForSettings.enabled = NO;
            [self startCounter];
        break;
        case StreamingState_NoInternet:
            break;
        case StreamingState_Error:
            
            if (self.buttonForToggleStream.selected) {
                self.buttonForToggleStream.selected = NO;
                self.buttonForSettings.enabled = YES;
                [self stopCounter];
            }
            break;
            
        case StreamingState_Stopped:
            self.buttonForToggleStream.selected = NO;
            self.buttonForSettings.enabled = YES;
            //[self pushSettings: nil];
            [self stopCounter];
            break;
        case StreamingState_Ready:
            self.buttonForSettings.enabled = YES;
            break;
        default:
            break;
    }
}

- (void)adaptedToNetworkWithState:(AutoAdaptState)adaptState fps:(int)fps bitrate:(int)bitrate resolution:(VideoResolution)resolution
{
    NSLog(@"*********************************************************");
    NSLog(@"new adapt state: %d", adaptState);
    NSLog(@"fps = %d", fps);
    NSLog(@"bitrate = %d", bitrate);
    NSLog(@"*********************************************************");
}

- (BOOL) connectedToNetwork
{
    // Create zero addy
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    // Recover reachability flags
    SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
    SCNetworkReachabilityFlags flags;
    
    BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
    CFRelease(defaultRouteReachability);
    
    if (!didRetrieveFlags) {
        printf("Error. Could not recover network reachability flags\n");
        return 0;
    }
    
    BOOL isReachable = flags & kSCNetworkFlagsReachable;
    BOOL needsConnection = flags & kSCNetworkFlagsConnectionRequired;
    return (isReachable && !needsConnection) ? YES : NO;
}

#pragma mark - Preview Highlight Rectangle

- (void)startDrawPreviewHighlight
{
    self.previewHighlightTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f / 25
                                                                  target:self
                                                                selector:@selector(drawPreviewHighlight)
                                                                userInfo:nil
                                                                 repeats:YES];
}

- (void)drawPreviewHighlight
{
    [self.highlightView setNeedsLayout];
}

- (void)stopDrawPreviewHighlight
{
    [self.previewHighlightTimer invalidate];
    self.previewHighlightTimer = nil;
}

@end
