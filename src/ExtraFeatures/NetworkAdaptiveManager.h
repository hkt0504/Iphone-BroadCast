
//
//  NetworkAdaptiveManager.h
//  iOSRTMP
//
//  Created by Mihai on 25/04/14.
//  Copyright (c) 2014 Agilio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Recorder.h"

@interface NetworkAdaptiveManager : NSObject

@property (nonatomic, retain) NSDate *lastFPSDecreaseTime;
@property (nonatomic, retain) NSDate *lastFPSIncreaseTime;
@property (nonatomic) CGFloat initialVideoRate;
@property (nonatomic) CGFloat minimumBitRate;
@property (nonatomic) VideoResolution initialVideoResolution;

@property (nonatomic, assign) Recorder *recorder;

- (void)initializeManager;
- (void)resetManager;

@end