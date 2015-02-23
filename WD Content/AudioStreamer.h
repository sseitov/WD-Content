//
//  AudioStreamer.h
//  WD Content
//
//  Created by Sergey Seitov on 23.02.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>

extern "C" {
#	include "libavcodec/avcodec.h"
}

@interface AudioStreamer : NSObject

- (BOOL)openWithContext:(AVCodecContext*)context;
- (void)close;

- (void)start;
- (void)stop;

- (void)push:(AVPacket*)packet;
- (double)getCurrentTime;

@property (atomic) AVCodecContext* context;
@property (atomic) BOOL stopped;

@end
