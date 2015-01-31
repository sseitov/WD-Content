//
//  AudioDecoder.h
//  WD Content
//
//  Created by Sergey Seitov on 17.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>

extern "C" {
#	include "libavcodec/avcodec.h"
}

@class AudioDecoder;

@protocol AudioDecoderDelegate <NSObject>

- (void)audioDecoder:(AudioDecoder*)decoder decodedFrame:(AVFrame*)frame;

@end

@interface AudioDecoder : NSObject

@property (weak, nonatomic) id<AudioDecoderDelegate> delegate;

- (BOOL)openWithContext:(AVCodecContext*)context;
- (void)close;
- (void)decodePacket:(AVPacket)packet;

@end
