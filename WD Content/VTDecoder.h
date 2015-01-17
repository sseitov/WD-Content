//
//  VTDecoder.h
//  DirectVideo
//
//  Created by Sergey Seitov on 03.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import "Decoder.h"

@class VTDecoder;

@protocol VTDecoderDelegate <NSObject>

- (void)decoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer;

@end

@interface VTDecoder : NSObject<Decoder>

@property (weak, nonatomic) id<VTDecoderDelegate> delegate;
/*
- (BOOL)openWithContext:(AVCodecContext*)codec;
- (void)close;
- (BOOL)decodePacket:(AVPacket*)packet toFrame:(AVFrame*)frame;
*/

@end
