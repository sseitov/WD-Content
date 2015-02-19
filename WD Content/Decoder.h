//
//  Decoder.h
//  WD Content
//
//  Created by Sergey Seitov on 19.02.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>

extern "C" {
#	include "libavcodec/avcodec.h"
#	include "libavformat/avformat.h"
#	include "libavformat/avio.h"
#	include "libavfilter/avfilter.h"
};

@protocol DecoderDelegate <NSObject>

- (void)decodePacket:(AVPacket*)packet;

@end

enum {
	ThreadStillWorking,
	ThreadIsDone
};

enum DecoderState {
	Continue,
	StartBuffering,
	StopBuffering
};

@interface Decoder : NSObject

@property (weak, nonatomic) id<DecoderDelegate> delegate;

- (void)startWithAudio:(int)audio;
- (void)changeAudio:(int)audio;
- (void)stop;

- (enum DecoderState)pushPacket:(AVPacket*)packet;
- (int)size;

@end
