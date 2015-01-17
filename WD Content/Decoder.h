//
//  Decoder.h
//  WD Content
//
//  Created by Sergey Seitov on 17.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>

extern "C" {
#	include "libavcodec/avcodec.h"
}

@protocol Decoder <NSObject>

- (BOOL)openWithContext:(AVCodecContext*)context;
- (void)close;
- (BOOL)decodePacket:(AVPacket*)packet toFrame:(AVFrame*)frame;

@end
