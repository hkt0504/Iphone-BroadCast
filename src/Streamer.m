//
//  Streamer.m
//  Streaming
//
//  Created by Radu Dan on 10/27/11.
//  Copyright (c) 2011 Medina Software. All rights reserved.
//

#import <stdlib.h>

#import "Streamer.h"
#import "RT_AVPachet.h"

int const NetworkStateIncrease = 1;
int const NetworkStateDecrease = 2;
int const NetworkStateReset = 3;

int const VIDEO_STREAM = 0;
int const AUDIO_STREAM = 1;
int const FLV_TAG_TYPE_AUDIO = 10;
int const FLV_TAG_TYPE_VIDEO = 7;
int const FLV_TIMEBASE = 1000;

NSString *NetworkStateChangedNotification = @"rtmp.networkStateChangedNotification";

@interface Streamer ()
{
    //NSMutableArray *audioQueue;
    
    //dispatch_queue_t sendPacketsQueue;
    
    int decreaseCount;
    int increaseCount;
    int frameDropFrequency;
    int frameCount;
    
    int64_t lastAudioPTS;
    int64_t lastVideoPTS;
    int64_t bandwidth;
    
    int videoFramesSent;
    
    double bufferLength;
    BOOL autoAdaptToNetwork;
    
    NSString *rtmpPath;
    
    //AVStream *video, *audio;
    
    BOOL noInternet;
    BOOL rewriteHeaders;
}

@property (nonatomic, assign) id<StreamingCallbackListener> delegate;

@end

@implementation Streamer

#pragma mark - public

/// Must be called once before trying to instantiate this class in order
/// to initialize some FFmpeg specific stuff.
+ (void)initialize {
    avformat_network_init();
}

/// Create a new Streamer.
/// @param URL The URL of the RTMP server, together with the application and stream name.
/// @param theAudioRate The audio bit rate.
- (id)initWithUrl: (NSString *)URL
     andAudioRate: (int)theAudioRate
     bufferLength: (double)theBufferLength
   adaptToNetwork: (BOOL)adaptToNetwork
 callbackListener: (id<StreamingCallbackListener>)listener
{

    nlog2(DBGLog, @"Streamer::Starting...");

    if (self = [super init]) {
        
        _delegate = listener;
        
        frameCount = 0;
        frameDropFrequency = 3;
        increaseCount = 0;
        decreaseCount = 0;
        bufferLength = theBufferLength;
        autoAdaptToNetwork = adaptToNetwork;
        rtmpPath = [URL retain];
        
        //sendPacketsQueue = dispatch_queue_create("com.sendPacketsQueue", DISPATCH_QUEUE_SERIAL);
        
        int retcode;
        
        [URL getCString:cname maxLength:1024 encoding:NSUTF8StringEncoding];

        if ((retcode = avformat_alloc_output_context2(&file, NULL, "flv", cname))) {
            @throw [NSException exceptionWithName: @"StreamingError"
                                           reason: [NSString stringWithFormat: @"Couldn't open URL at '%@'.", URL]
                                         userInfo: nil];
            if (_delegate) {
                [_delegate streamingStateChanged: StreamingState_Error withMessage: [NSString stringWithFormat: @"Couldn't open URL at '%@'.", URL]];
            }

        }

        if ((retcode = avio_open(&file->pb, cname, AVIO_FLAG_WRITE))) {
            @throw [NSException exceptionWithName: @"StreamingError"
                                           reason: [NSString stringWithFormat: @"Couldn't connect to stream at '%@'", URL]
                                         userInfo: nil];
            if (_delegate) {
                [_delegate streamingStateChanged: StreamingState_Error withMessage:  [NSString stringWithFormat: @"Couldn't connect to stream at '%@'", URL]];
            }
        }

        headers = YES;
        videoPosition = audioPosition = 0;
        lastAudioPTS = lastVideoPTS = -1;
        audioRate = theAudioRate;
        //audioQueue = [[NSMutableArray alloc] init];
        videoFramesSent = 0;
        
        //[self openStream: file2];

        nlog2(DBGLog, @"Streamer::Started.");
    }

    return self;
}

- (void)reinitializeSession
{
    int retcode = 0;
    
    if (file) {
        
        if (!headers && (retcode = av_write_trailer(file)))
            @throw [NSException exceptionWithName: @"StreamingError"
                                           reason: @"Could not close connection."
                                         userInfo: nil];
        
        
        avio_close(file->pb);
        avformat_free_context(file);
    }
    
    if ((retcode = avformat_alloc_output_context2(&file, NULL, "flv", cname))) {
        @throw [NSException exceptionWithName: @"StreamingError"
                                       reason: [NSString stringWithFormat: @"Couldn't open URL at '%@'.",rtmpPath]
                                     userInfo: nil];
        if (_delegate) {
            [_delegate streamingStateChanged: StreamingState_Error withMessage: [NSString stringWithFormat: @"Couldn't open URL at '%@'.", rtmpPath]];
        }
    }
    
    NSLog(@"passed alloc output");
    
    if ((retcode = avio_open(&file->pb, cname, AVIO_FLAG_WRITE))) {
        @throw [NSException exceptionWithName: @"StreamingError"
                                       reason: [NSString stringWithFormat: @"Couldn't connect to stream at '%@'", rtmpPath]
                                     userInfo: nil];
        if (_delegate) {
            [_delegate streamingStateChanged: StreamingState_Error withMessage: [NSString stringWithFormat: @"Couldn't connect to stream at '%@'", rtmpPath]];
        }
    }
    
    videoPosition = audioPosition = 0;
}

- (void)dealloc {
    nlog2(DBGLog, @"Streamer::Stopping...");

    int retcode = 0;

    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
    //dispatch_release(sendPacketsQueue);
    
    //[audioQueue release];
    [rtmpPath release];
    
    if (file) {
        if (!headers && (retcode = av_write_trailer(file))) {
            /*
            @throw [NSException exceptionWithName: @"StreamingError"
                                           reason: @"Could not close connection."
                                         userInfo: nil];
             */
            if (_delegate) {
                [_delegate streamingStateChanged: StreamingState_Warning withMessage: [NSString stringWithFormat: @"Could not close connection '%@'", rtmpPath]];
            }
        }

        avio_close(file->pb);
        avformat_free_context(file);
    }

    [super dealloc];

    nlog2(DBGLog, @"Streamer::Stopped.");
}

- (bool)writePacket: (Demuxer *)source
       andSendVideo: (bool)sendVideo
               date: (NSDate *)date
            newSize: (BOOL)newSize
  audioCodecContext: (AVCodecContext *)audioCodec
{
    if (newSize) {
        rewriteHeaders = YES;
    }
    
    if (sendVideo && -[date timeIntervalSinceNow] >= bufferLength) {
        
        //NSLog(@"Video frames sent: %d", videoFramesSent);
        //NSLog(@"Get rid of = %lu audio packets!!!!!!!!!", (unsigned long)self.audioQueue.count);
        
        videoFramesSent = 0;

        @synchronized(self.audioQueue) {
            
            for (RT_AVPachet *audioPacket in self.audioQueue) {
                av_free_packet(audioPacket->packet);
            }
            
            [self.audioQueue removeAllObjects];
        }
        
        if (autoAdaptToNetwork){
            //NSLog(@"detach new thread for network verification");
            [NSThread detachNewThreadSelector: @selector(adaptToNetwork:)
                                     toTarget: self
                                   withObject: [NSNumber numberWithInt: NetworkStateDecrease]];
            //NSLog(@"come back from that");
             
        }
        
        return NO;
    }
    
    int code = 0;
    
    AVCodecContext
    *videoCodec = [source videoCodec];
    
    if (audioCodec == NULL) {
        audioCodec = [source audioCodec];
    }
    
    if (headers) {
        
        AVStream
        *video = avformat_new_stream(file, videoCodec->codec),
        *audio = avformat_new_stream(file, audioCodec->codec);
        
        if (!video || !audio)
            @throw [NSException exceptionWithName: @"StreamingError"
                                           reason: @"Could not allocate audio and video streams."
                                         userInfo: nil];
        
        memcpy(video->codec, videoCodec, sizeof(AVCodecContext));
        memcpy(audio->codec, audioCodec, sizeof(AVCodecContext));
        
        video->codec->extradata = av_malloc(video->codec->extradata_size);
        audio->codec->extradata = av_malloc(audio->codec->extradata_size);
        
        memcpy(video->codec->extradata, videoCodec->extradata, video->codec->extradata_size);
        memcpy(audio->codec->extradata, audioCodec->extradata, audio->codec->extradata_size);
        
        video->codec->codec_tag = FLV_TAG_TYPE_VIDEO;
        audio->codec->codec_tag = FLV_TAG_TYPE_AUDIO;
        video->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
        audio->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
        audio->codec->sample_rate = audioRate;
        
        video->codec->time_base.num = 1;
        audio->codec->time_base.den = video->codec->time_base.den = FLV_TIMEBASE;
        
        if ((code = avformat_write_header(file, NULL))) {
            elog2(@"Could not write stream headers: %s.", code);
            @throw [NSException exceptionWithName: @"StreamingError" reason: @"Could not write stream headers" userInfo: nil];
        }
        
        headers = NO;
    }
    else if (rewriteHeaders) {
        
        //memcpy(video->codec, videoCodec, sizeof(AVCodecContext));
        //memcpy(audio->codec, audioCodec, sizeof(AVCodecContext));
        
        NSLog(@"new size<<<<<<<<<<<<<<");
        
        [self reinitializeSession];
        
        AVStream
        *video = avformat_new_stream(file, videoCodec->codec),
        *audio = avformat_new_stream(file, audioCodec->codec);
        
        if (!video || !audio)
            @throw [NSException exceptionWithName: @"StreamingError"
                                           reason: @"Could not allocate audio and video streams."
                                         userInfo: nil];
        
        memcpy(video->codec, videoCodec, sizeof(AVCodecContext));
        memcpy(audio->codec, audioCodec, sizeof(AVCodecContext));
        
        video->codec->extradata = av_malloc(video->codec->extradata_size);
        audio->codec->extradata = av_malloc(audio->codec->extradata_size);
        
        memcpy(video->codec->extradata, videoCodec->extradata, video->codec->extradata_size);
        memcpy(audio->codec->extradata, audioCodec->extradata, audio->codec->extradata_size);
        
        video->codec->codec_tag = FLV_TAG_TYPE_VIDEO;
        audio->codec->codec_tag = FLV_TAG_TYPE_AUDIO;
        video->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
        audio->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
        audio->codec->sample_rate = audioRate;
        
        video->codec->time_base.num = 1;
        audio->codec->time_base.den = video->codec->time_base.den = FLV_TIMEBASE;
        
        if ((code = avformat_write_header(file, NULL))) {
            elog2(@"Could not write stream headers: %s.", code);
            @throw [NSException exceptionWithName: @"StreamingError" reason: @"Could not write stream headers" userInfo: nil];
        }
        
        rewriteHeaders = NO;
    }
    
    bool isVideo;
    
    AVPacket *packet = [source readPacket:&isVideo];
    
    if (!packet) {
        
        //NSLog(@"No more Packtes. Dropping audio packets: %lu", (unsigned long)self.audioQueue.count);
        //NSLog(@"Video frames sent: %d", videoFramesSent);
        
//        if (videoFramesSent < 20) {
//            videoPosition = audioPosition;
//        }
        
        videoFramesSent = 0;
        
        //NSLog(@"audio presentation timestamp %lld", audioPosition);
        //NSLog(@"video presentation timestamp %lld", videoPosition);
        
        //audioPosition-=23*audioQueue.count;
        
        
//        for (RT_AVPachet *myPacket in self.audioQueue) {
//            audioPosition -= myPacket->packet->duration;
//            av_free_packet(myPacket->packet);
//        }
//        
//        @synchronized(self.audioQueue) {
//            [self.audioQueue removeAllObjects];
//        }
        
//        int audioQueueMax = 43 * bufferLength;
//        int audioQueueCount = (int)self.audioQueue.count;
//        
//        if (audioQueueCount > audioQueueMax) {
//            @synchronized(self.audioQueue) {
//                RT_AVPachet *lastAudioPacket = [self.audioQueue objectAtIndex: audioQueueCount - audioQueueMax];
//                
//                videoPosition = lastAudioPacket->packet->pts;
//            }
//        }
        
        if (autoAdaptToNetwork) {
            
            if ((-[date timeIntervalSinceNow]) <= 0.7 * bufferLength) {
                [NSThread detachNewThreadSelector: @selector(adaptToNetwork:)
                                         toTarget: self
                                       withObject: [NSNumber numberWithInt: NetworkStateIncrease]];
            }
            else {
                [NSThread detachNewThreadSelector: @selector(adaptToNetwork:)
                                         toTarget: self
                                       withObject: [NSNumber numberWithInt: NetworkStateReset]];
            }
        }
        
        return NO;
    }
    
    if (isVideo) {
        
        packet->stream_index = VIDEO_STREAM;
        packet->duration = FLV_TIMEBASE * packet->duration * videoCodec->ticks_per_frame * videoCodec->time_base.num / videoCodec->time_base.den;
        
        if (packet->duration < 0) {
            //NSLog(@">>>>>>>>>>>packet duration: %d", packet->duration);
            //packet->duration = abs(packet->duration);
            //NSLog(@"NEW packet duration = %d", packet->duration);
        }
        else {
            videoPosition +=packet->duration;
        }
        
        RT_AVPachet *my_packet;
        
        while (self.audioQueue.count) {
            
            @synchronized(self.audioQueue){
                my_packet = [self.audioQueue objectAtIndex: 0];
            }
            
            if (my_packet->packet->pts <= packet->pts) {
                
                if ( ! noInternet) {
                    [self streamPacket: [my_packet retain] sendVideo: sendVideo];
                }
                else {
                    return NO;
                }
            }
            else {
                break;
            }
            
            @synchronized(self.audioQueue) {
                [self.audioQueue removeObjectAtIndex: 0];
            }
        }
        
        videoFramesSent++;
        frameCount++;
        
        if (lastVideoPTS < packet->pts) {
            
            if (! noInternet) {
                
                //frameCount++;
                
                //if (frameCount < frameDropFrequency) {
                    [self streamPacket: [[RT_AVPachet alloc] initWithPacket: packet isVideo: YES] sendVideo: sendVideo];
                    lastVideoPTS = packet->pts;
                //}
                //else {
                    //NSLog(@"drop frame------------------");
                //    frameCount = 0;
                //}
            }
            else {
                return NO;
            }
            
        }
        else {
            NSLog(@"---------------------------------------------------- non monotonically increasing dts to muxer in video stream");
            av_free_packet(packet);
        }
        
    } else {
        
//        packet->stream_index = AUDIO_STREAM;
//        packet->dts = audioPosition;
//        packet->pts = audioPosition;
//        packet->duration = FLV_TIMEBASE * packet->duration / audioRate;
//
//        audioPosition += packet->duration;
//        
//        if (lastAudioPTS < packet->pts) {
//            RT_AVPachet *my_packet = [[RT_AVPachet alloc] initWithPacket: packet isVideo: NO];
//            
//            @synchronized(audioQueue) {
//                [audioQueue addObject: my_packet];
//            }
//            
//            [my_packet release];
//            
//            lastAudioPTS = packet->pts;
//        }
//        else {
//            //NSLog(@"---------------------------------------------------- non monotonically increasing dts to muxer in audio stream");
//            av_free_packet(packet);
//        }
        
        av_free_packet(packet);
    }
    
    return YES;
}

- (void)streamPacket:(RT_AVPachet*)my_packet sendVideo:(BOOL)sendVideo
{
    //int code = 0;
    
    NSDate *date = [NSDate date];
    
    my_packet->packet->pos = -1;
    my_packet->packet->convergence_duration = AV_NOPTS_VALUE;
    
    //nlog(DBGDebug, @"Streamer::Writing frame w/ stream idx: %d dts: %lld pts: %lld.", my_packet->packet->stream_index, my_packet->packet->dts, my_packet->packet->pts);
    
    //NSLog(@"before send VIDEO");
    if (sendVideo || ! my_packet->isVideo) {
        av_write_frame(file, my_packet->packet);
    }
    //NSLog(@"after send VIDEO");
    
    /*
     elog(@"Streamer::Couldn't write frame w/ stream idx: %d dts: %lld pts: %lld. Error: '%s'."
     , code
     , my_packet->packet->stream_index
     , my_packet->packet->dts
     , my_packet->packet->pts);
     */
    
//    AVPacket myPacket;
//    
//    av_new_packet(&myPacket, 7);
//    memcpy(myPacket.data, , <#size_t#>)
    
    //bandwidth = bw * kBWLowPasFilterScalar + bandwidth * (1.0 - kBWLowPasFilterScalar);
    
    int64_t bw = my_packet->packet->size/8 / -[date timeIntervalSinceNow];
    
    bandwidth = bw * 0.08 + bandwidth * (1.0 - 0.08);
    
    av_write_frame(file, NULL);
    av_free_packet(my_packet->packet);
    
    [my_packet release];
}

- (int64_t)getUploadBandwidth
{
    return bandwidth;
}

- (void)adaptToNetwork:(NSNumber *)stateNumber
{
    @autoreleasepool {
        
        int state = stateNumber.intValue;
        
        if (state == NetworkStateIncrease) {
            decreaseCount = 0;
            increaseCount++;
            
            if (increaseCount >= 50) {
                increaseCount = 0;
                [[NSNotificationCenter defaultCenter] postNotificationName: @"com.increaseFPSNotification" object: nil];
            }
            else {
                NSLog(@"increase count is only %d", increaseCount);
            }
        }
        else if (state == NetworkStateDecrease){
            increaseCount = 0;
            decreaseCount++;
            
            if (decreaseCount >= 3) {
                decreaseCount = 0;
                [[NSNotificationCenter defaultCenter] postNotificationName: @"com.decreaseFPSNotification" object: nil];
            }
            else {
                NSLog(@"decrease count is only %d", decreaseCount);
            }
        }
        else {
            increaseCount = 0;
            decreaseCount = 0;
        }
    }
}

@end
