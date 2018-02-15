//
//  NetworkAdaptiveManager.m
//  Video Stream
//
//  Created by Mihai on 07/04/14.
//
//

#import "NetworkAdaptiveManager.h"

#import "Util.h"
#import "StreamingCallbackListener.h"
#import <AVFoundation/AVFoundation.h>

static int videoResolutions[6] = {
    VideoResolution_192x144,
    VideoResolution_320x240,
    VideoResolution_480x360,
    VideoResolution_640x480,
    VideoResolution_1280x720,
    VideoResolution_1920x1080
};

static int minimumBitRates[6] = {
    MinimumBitrate_192x144,
    MinimumBitrate_320x240,
    MinimumBitrate_480x360,
    MinimumBitrate_640x480,
    MinimumBitrate_1280x720,
    MinimumBitrate_1920x1080
};

@implementation NetworkAdaptiveManager

- (void)dealloc
{
    NSLog(@"dealloc adaptive manager");
    
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
    if (_lastFPSDecreaseTime) {
        [_lastFPSDecreaseTime release];
    }
    
    if (_lastFPSIncreaseTime) {
        [_lastFPSIncreaseTime release];
    }
    
    [super dealloc];
}

- (void)initializeManager
{
    self.lastFPSDecreaseTime = [NSDate date];
    self.lastFPSIncreaseTime = [NSDate date];
    self.initialVideoRate = self.recorder.theVideoRate;
    self.minimumBitRate = minimumBitRates[self.recorder.theVideoResolution];
    self.initialVideoResolution = self.recorder.theVideoResolution;
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(decreaseFPS:)
                                                 name: @"com.decreaseFPSNotification"
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(increaseFPS:)
                                                 name: @"com.increaseFPSNotification"
                                               object: nil];
}

- (void)resetManager
{
    self.recorder.theVideoRate = _initialVideoRate;
    self.recorder.theVideoResolution = _initialVideoResolution;
    self.recorder.changePreset = NO;
    _minimumBitRate = minimumBitRates[self.recorder.theVideoResolution];
}

- (void)decreaseFPS:(NSNotification*)notification
{
    if (1 || ([[NSDate date] timeIntervalSince1970] - [self.lastFPSDecreaseTime timeIntervalSince1970] > 4.5)) {
        
        if (self.recorder.theVideoRate > _minimumBitRate) {
            
            CGFloat bitrateThreshold = 25.0/100.0 * self.recorder.theVideoRate;
            
            self.recorder.theVideoRate = self.recorder.theVideoRate - bitrateThreshold;
            
            if (self.recorder.theVideoRate < _minimumBitRate) {
                self.recorder.theVideoRate = _minimumBitRate;
            }
            
            NSLog(@"---------------------------------------------------------------------------------------decrease bitrate to : %f", self.recorder.theVideoRate);
            
            self.lastFPSDecreaseTime = [NSDate date];
            
            [NSThread detachNewThreadSelector: @selector(callbackAdaptiveWithState:)
                                     toTarget: self
                                   withObject: [NSNumber numberWithInt: AutoAdaptState_DecreasingBitrate]];
        }
        else if ( ! self.recorder.dropFrames) {
            self.recorder.dropFrames = YES;
            self.recorder.frameDroppingFrequency = 3;
            self.lastFPSDecreaseTime = [NSDate date];
            [NSThread detachNewThreadSelector: @selector(callbackAdaptiveWithState:)
                                     toTarget: self
                                   withObject: [NSNumber numberWithInt: AutoAdaptState_DroppingVideoFrames]];
            
            NSLog(@"---------------------------------------------------------------------------------------decrease | FD frequency : %d", self.recorder.frameDroppingFrequency);
        }
        else if (self.recorder.frameDroppingFrequency > 2) {
            self.recorder.frameDroppingFrequency = 2;
            self.lastFPSDecreaseTime = [NSDate date];
            [NSThread detachNewThreadSelector: @selector(callbackAdaptiveWithState:)
                                     toTarget: self
                                   withObject: [NSNumber numberWithInt: AutoAdaptState_DroppingVideoFrames]];
            NSLog(@"---------------------------------------------------------------------------------------decrease | FD frequency : %d", self.recorder.frameDroppingFrequency);
        }
        else if (self.recorder.allowsVideoResolutionChanges && self.recorder.theVideoResolution > VideoResolution_192x144){
            
            self.recorder.changePreset = YES;
            
            self.recorder.theVideoResolution = videoResolutions[self.recorder.theVideoResolution - 1];
            _minimumBitRate = minimumBitRates[self.recorder.theVideoResolution];
            
            CGFloat bitrateThreshold = 25.0/100.0 * self.recorder.theVideoRate;
            
            self.recorder.theVideoRate = self.recorder.theVideoRate - bitrateThreshold;
            
            if (self.recorder.theVideoRate < _minimumBitRate) {
                self.recorder.theVideoRate = _minimumBitRate;
            }
            
            self.lastFPSDecreaseTime = [NSDate date];
            
            [NSThread detachNewThreadSelector: @selector(callbackAdaptiveWithState:)
                                     toTarget: self
                                   withObject: [NSNumber numberWithInt: AutoAdaptState_DecreasingResolution]];
            
            NSLog(@"---------------------------------------------------------------------------------------decrease bitrate to : %f and resolution: %@", self.recorder.theVideoRate, [self sessionPresetForResolution: self.recorder.theVideoResolution]);
        }
        else {
            NSLog(@"---------------------------------------------------------------------------------------reached minimum");
        }
    }
    else {
        NSLog(@"---------------------------------------------------------------------------------------to soon to drecrease FPS or Bitrate");
    }
}

- (void)increaseFPS:(NSNotification*)notification
{
    if (1 || ([[NSDate date] timeIntervalSince1970] - [self.lastFPSIncreaseTime timeIntervalSince1970] > 4.5)) {
        
        if (self.recorder.allowsVideoResolutionChanges) {
            
            if (self.recorder.theVideoResolution < _initialVideoResolution) {
                
                CGFloat newVideoBitRate = self.recorder.theVideoRate * 100.0/75.0; //(25/100 * theVideoRate);
                VideoResolution newVideoResolution = videoResolutions[self.recorder.theVideoResolution+1];
                CGFloat newMinimumBitRate = minimumBitRates[newVideoResolution];
                
                if (newVideoBitRate >= newMinimumBitRate) {
                    
                    self.recorder.changePreset = YES;
                    
                    self.recorder.theVideoResolution = newVideoResolution;
                    _minimumBitRate = newMinimumBitRate;
                    self.recorder.theVideoRate = newVideoBitRate;
                    
                    [NSThread detachNewThreadSelector: @selector(callbackAdaptiveWithState:)
                                             toTarget: self
                                           withObject: [NSNumber numberWithInt: AutoAdaptState_IncreasingResolution]];
                    
                    NSLog(@"---------------------------------------------------------------------------------------increase bitrate to : %f and resolution: %@", self.recorder.theVideoRate, [self sessionPresetForResolution: self.recorder.theVideoResolution]);
                    
                    return;
                }
                else {
                    self.recorder.theVideoRate = newVideoBitRate;
                    
                    [NSThread detachNewThreadSelector: @selector(callbackAdaptiveWithState:)
                                             toTarget: self
                                           withObject: [NSNumber numberWithInt: AutoAdaptState_IncreasingBitrate]];
                    
                    NSLog(@"---------------------------------------------------------------------------------------increase bitrate : %f", self.recorder.theVideoRate);
                    
                    return;
                }
                
                self.lastFPSDecreaseTime = [NSDate date];
            }
        }
        
        if (self.recorder.dropFrames) {
            
            if (self.recorder.frameDroppingFrequency == 3) {
                self.recorder.dropFrames = NO;
                self.recorder.frameDroppingFrequency = 0;
                [NSThread detachNewThreadSelector: @selector(callbackAdaptiveWithState:)
                                         toTarget: self
                                       withObject: [NSNumber numberWithInt: AutoAdaptState_IncreasingVideoFrames]];
                NSLog(@"---------------------------------------------------------------------------------------increase | FD frequency : 0");
            }
            else {
                self.recorder.frameDroppingFrequency = 3;
                [NSThread detachNewThreadSelector: @selector(callbackAdaptiveWithState:)
                                         toTarget: self
                                       withObject: [NSNumber numberWithInt: AutoAdaptState_IncreasingVideoFrames]];
                NSLog(@"---------------------------------------------------------------------------------------increase | FD frequency : %d", self.recorder.frameDroppingFrequency);
            }
            
            self.lastFPSDecreaseTime = [NSDate date];
        }
        else if (self.recorder.theVideoRate < _initialVideoRate) {
            
            //CGFloat bitrateThreshold = 25.0/100.0 * theVideoRate;
            
            self.recorder.theVideoRate = self.recorder.theVideoRate * 100.0/75.0;
            
            if (self.recorder.theVideoRate > _initialVideoRate) {
                self.recorder.theVideoRate = _initialVideoRate;
            }
            
            NSLog(@"---------------------------------------------------------------------------------------increase bitrate to : %f", self.recorder.theVideoRate);
            
            self.lastFPSDecreaseTime = [NSDate date];
            
            [NSThread detachNewThreadSelector: @selector(callbackAdaptiveWithState:)
                                     toTarget: self
                                   withObject: [NSNumber numberWithInt: AutoAdaptState_IncreasingBitrate]];
        }
        else {
            NSLog(@"---------------------------------------------------------------------------------------reached maximum");
        }
    }
    else {
        
        NSLog(@"---------------------------------------------------------------------------------------to soon to increase FPS or Bitrate");
    }
}

- (void)callbackAdaptiveWithState: (NSNumber *)stateNumber
{
    AutoAdaptState adaptState = [stateNumber intValue];
    
    NSInteger fps = self.recorder.framesPerSecond;
    
    if (self.recorder.dropFrames) {
        fps = self.recorder.framesPerSecond * (self.recorder.frameDroppingFrequency - 1) / self.recorder.frameDroppingFrequency;
    }
    
    if ([self.recorder.delegate respondsToSelector:@selector(adaptedToNetworkWithState:fps:bitrate:resolution:)]) {
        [self.recorder.delegate adaptedToNetworkWithState: adaptState
                                                      fps: fps
                                                  bitrate: self.recorder.theVideoRate
                                               resolution: self.recorder.theVideoResolution];
    }
}

- (NSString *)sessionPresetForResolution:(VideoResolution)resolution
{
    NSString *returnResolution;
    
    switch (resolution) {
        case VideoResolution_192x144:
            returnResolution = AVCaptureSessionPresetLow;
            break;
        case VideoResolution_320x240:
            returnResolution = AVCaptureSessionPreset352x288;
            break;
        case VideoResolution_480x360:
            returnResolution = AVCaptureSessionPresetMedium;
            break;
        case VideoResolution_640x480:
            returnResolution = AVCaptureSessionPreset640x480;
            break;
        case VideoResolution_1280x720:
            returnResolution = AVCaptureSessionPreset1280x720;
            break;
        case VideoResolution_1920x1080:
            returnResolution = AVCaptureSessionPreset1920x1080;
            break;
        default:
            break;
    }
    
    return returnResolution;
}

@end
