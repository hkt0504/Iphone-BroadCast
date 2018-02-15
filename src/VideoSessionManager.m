//
//  VideoSessionManager.m
//  Video Stream
//
//  Created by Mihai on 08/04/14.
//
//

#import "VideoSessionManager.h"

@implementation VideoSessionManager

+ (BOOL)setPreset:(VideoResolution)resolution forSession:(AVCaptureSession *)session
{
    BOOL success = YES;
    
    switch (resolution) {
        case VideoResolution_192x144:
            [session setSessionPreset: AVCaptureSessionPresetLow];
            break;
        case VideoResolution_320x240:
            [session setSessionPreset: AVCaptureSessionPreset352x288];
            break;
        case VideoResolution_480x360:
            [session setSessionPreset: AVCaptureSessionPresetMedium];
            break;
        case VideoResolution_640x480:
            [session setSessionPreset: AVCaptureSessionPreset640x480];
            break;
        case VideoResolution_1280x720:
            [session setSessionPreset: AVCaptureSessionPreset1280x720];
            //saveVideoToCameraRoll = NO;
            break;
        case VideoResolution_1920x1080:
            [session setSessionPreset: AVCaptureSessionPreset1920x1080];
            //saveVideoToCameraRoll = NO;
            break;
        default:
            [session setSessionPreset: AVCaptureSessionPresetLow];
            success = NO;
            break;
    }
    
    return success;
}

+ (NSString*)videoProfileForWidth:(NSInteger *)width height:(NSInteger *)height forResolution:(VideoResolution *)resolution
{
    BOOL success = YES;
    
    NSString *profile = AVVideoProfileLevelH264Baseline30;
    
    switch (*resolution) {
        case VideoResolution_192x144:
        {
            CGSize highlightSize = [self getHighlightVideoSize:CGSizeMake(192, 144)];
            *width = highlightSize.width;
            *height = highlightSize.height;
            break;
        }
        case VideoResolution_320x240:
        {
            CGSize highlightSize = [self getHighlightVideoSize:CGSizeMake(320, 240)];
            *width = highlightSize.width;
            *height = highlightSize.height;
            break;
        }
        case VideoResolution_480x360:
        {
            CGSize highlightSize = [self getHighlightVideoSize:CGSizeMake(480, 360)];
            *width = highlightSize.width;
            *height = highlightSize.height;
            break;
        }
        case VideoResolution_640x480:
        {
            CGSize highlightSize = [self getHighlightVideoSize:CGSizeMake(640, 480)];
            *width = highlightSize.width;
            *height = highlightSize.height;
            break;
        }
        case VideoResolution_1280x720:
        {
            CGSize highlightSize = [self getHighlightVideoSize:CGSizeMake(1280, 720)];
            *width = highlightSize.width;
            *height = highlightSize.height;
            //*width = 1280;
            //*height = 720;
            profile = AVVideoProfileLevelH264Baseline31;
            break;
        }
        case VideoResolution_1920x1080:
        {
            CGSize highlightSize = [self getHighlightVideoSize:CGSizeMake(1920, 1080)];
            *width = highlightSize.width;
            *height = highlightSize.height;
            profile = AVVideoProfileLevelH264Baseline41;
            break;
        }
            
        default:
            success = NO;
            profile = nil;
            break;
    }
    
    return profile;
}

+ (CGSize)getHighlightVideoSize:(CGSize)screenSize
{
    CGSize highlightSize;
    
    CGFloat screenWidth = screenSize.width;
    CGFloat screenHeight = screenSize.height;
    
    CGFloat diagonal = (screenWidth > screenHeight) ? screenHeight : screenWidth;
    
    CGFloat previewWidth = diagonal / sqrt(16 * 16 + 9 * 9) * 16;
    CGFloat previewHeight = diagonal / sqrt(16 * 16 + 9 * 9) * 9;
    
    highlightSize.width = (int)(previewWidth / 16) * 16;
    highlightSize.height = (int)(previewHeight / 16) * 16;
    
    return highlightSize;
}

@end
