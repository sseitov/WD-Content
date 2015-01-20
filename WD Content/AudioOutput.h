//
//  AudioOutput.h
//  vTV
//
//  Created by Sergey Seitov on 13.08.13.
//  Copyright (c) 2013 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>

extern "C" {
#	include "libavcodec/avcodec.h"
#	include "libavformat/avformat.h"
};

#define AUDIO_POOL_SIZE 16

@class AudioOutput;

@protocol AudioOutputDelegate <NSObject>

- (void)requestMoreAudioData:(AudioOutput*)output;

@end

@interface AudioOutput : NSObject

@property (weak, nonatomic) id<AudioOutputDelegate> delegate;

@property (readonly, nonatomic) int64_t currentPTS;
@property (readwrite, nonatomic) BOOL started;

- (BOOL)startWithFrame:(AVFrame*)frame;
- (void)stop;
- (void)reset;
- (void)flush:(int64_t)pts;
- (void)writeData:(uint8_t**)data numSamples:(int)numSamples withPts:(int64_t)pts;

- (BOOL)isReadyForMoreAudioData;

- (void)currentPTS:(int64_t*)ppts withTime:(int64_t*)ptime;
- (double)getCurrentTime;

- (int)decodedPacketCount;

@end
