//
//  AudioOutput.h
//  vTV
//
//  Created by Sergey Seitov on 13.08.13.
//  Copyright (c) 2013 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Decoder.h"

extern "C" {
#	include "libavcodec/avcodec.h"
#	include "libavformat/avformat.h"
};

#define AUDIO_POOL_SIZE 4

@protocol AudioOutputDelegate;

@interface AudioOutput : NSObject

@property (readwrite, atomic) int64_t lastFlushPTS;
@property (readonly, nonatomic) int64_t currentPTS;
@property (strong, nonatomic) id<Decoder> decoder;

@property (weak, nonatomic) id<AudioOutputDelegate> delegate;

- (void)currentPTS:(int64_t*)ppts withTime:(int64_t*)ptime;
- (void)stop;
- (void)reset;
- (void)flush:(int64_t)pts;
- (void)pushPacket:(AVPacket*)packet;
- (double)getCurrentTime;

- (int64_t)lock;
- (void)unlock;
- (int64_t)shiftTo:(int64_t)pts;
- (void)shiftNolock:(int64_t)shift;

- (int)decodedPacketCount;

@end

@protocol AudioOutputDelegate <NSObject>

//Может вызваться на background thread
- (void)audioOutput:(AudioOutput *)audioOutput encounteredError:(NSError *)error;

@end