//
//  Decoder.h
//  WD Content
//
//  Created by Sergey Seitov on 21.02.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>

extern "C" {
#	include "libavcodec/avcodec.h"
}

enum {
	ThreadStillWorking,
	ThreadIsDone
};

enum DecoderState {
	Terminate,
	Continue,
	StartBuffering,
	StopBuffering
};

#define MAX_BUFFER_SIZE	256
#define MIN_BUFFER_SIZE	16

@class Decoder;

@protocol DecoderDelegate <NSObject>

- (void)decoder:(Decoder*)decoder changeState:(enum DecoderState)state;

@end

@interface Decoder : NSObject

- (BOOL)openWithContext:(AVCodecContext*)context;
- (void)close;

- (void)start;
- (void)stop;
- (BOOL)threadStep;

- (void)push:(AVPacket*)packet;
- (BOOL)pop:(AVPacket*)packet;

- (size_t)size;
- (BOOL)isFull;
- (BOOL)isEmpty;

- (NSString*)name;
- (BOOL)running;
- (void)pause:(BOOL)pause;

@property (weak, nonatomic) id<DecoderDelegate> delegate;
@property (atomic) AVCodecContext* context;
@property (atomic) BOOL stopped;
@property (nonatomic) dispatch_queue_t	decoderThread;

@end
