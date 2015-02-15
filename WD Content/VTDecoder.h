//
//  VTDecoder.h
//  DirectVideo
//
//  Created by Sergey Seitov on 03.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

extern "C" {
#	include "libavcodec/avcodec.h"
#	include "libavformat/avio.h"
}

@class VTDecoder;

@protocol VTDecoderDelegate <NSObject>

- (void)videoDecoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer;

@end

@interface VTDecoder : NSObject

@property (weak, nonatomic) id<VTDecoderDelegate> delegate;
@property (readwrite, nonatomic) AVCodecContext* context;

- (BOOL)openWithContext:(AVCodecContext*)context;
- (void)close;
- (void)decodePacket:(AVPacket*)packet;

@end
