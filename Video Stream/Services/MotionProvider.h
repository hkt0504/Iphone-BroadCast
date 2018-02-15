//
//  MotionProvider.h
//  Video Stream
//
//  Created by Hai Li on 2/23/16.
//
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>

@interface MotionProvider : NSObject

@property (assign, atomic) CGFloat tiltAngle;

+ (instancetype)sharedProvider;

- (void)startMotionUpdate;
- (void)stopMotionUpdate;

- (void)setOrientation:(UIInterfaceOrientation)interfaceOrientation;

@end

