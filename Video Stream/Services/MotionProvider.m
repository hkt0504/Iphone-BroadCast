//
//  MotionProvider.m
//  Video Stream
//
//  Created by Hai Li on 2/23/16.
//
//

#import "MotionProvider.h"

#define RADIAN_TO_DEGREES(radian) ((radian) * (180.0 / M_PI))
#define DEGREES_TO_RADIAN(angle) ((angle) / 180.0 * M_PI)

@interface MotionProvider () {
    UIInterfaceOrientation orientation;
    double deltaAngle;
}

@property (strong, nonatomic) CMMotionManager *motionManager;

@end

@implementation MotionProvider

@synthesize tiltAngle;

+ (instancetype)sharedProvider
{
    static id sharedProvider = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedProvider = [[self alloc] init];
    });
    
    return sharedProvider;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.motionManager = [[CMMotionManager alloc] init];
        self.motionManager.deviceMotionUpdateInterval = 0.01f;
    }
    
    return self;
}

- (void)setOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    orientation = interfaceOrientation;
    [self deltaAngleFromOrientation];
}

- (void)deltaAngleFromOrientation
{
    switch (orientation) {
        case UIInterfaceOrientationPortrait:
            deltaAngle = M_PI_2;
            break;
        case UIInterfaceOrientationLandscapeRight:
            deltaAngle = M_PI;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            deltaAngle = M_PI_2;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            deltaAngle = M_PI + M_PI;
            break;
        default:
            deltaAngle = M_PI_2;
            break;
    }
}

#pragma mark - Start Updating

- (void)startMotionUpdate
{
    [self deltaAngleFromOrientation];
    self.tiltAngle = 0.0f;
    
    if ([self.motionManager isDeviceMotionAvailable]) {
        NSOperationQueue *deviceMotionQueue = [[NSOperationQueue alloc] init];
        
        [self.motionManager startDeviceMotionUpdatesToQueue:deviceMotionQueue withHandler:^(CMDeviceMotion *motion, NSError *error) {
            double rotationRateZ = fabs(motion.rotationRate.z);
            double rotationLimitRateZ = DEGREES_TO_RADIAN(1.0f);
            
            double angle = atan2(motion.gravity.x, motion.gravity. y);
            angle += deltaAngle;
            
            double zAngle = acos(fabs(motion.gravity.z));
            double zLimitAngle = DEGREES_TO_RADIAN(20.0f);
            
            if (zAngle > zLimitAngle && rotationRateZ > rotationLimitRateZ) {
                self.tiltAngle = angle;
            }
        }];
    }
}

- (void)stopMotionUpdate
{
    [self.motionManager stopDeviceMotionUpdates];
}

@end
