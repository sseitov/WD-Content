//
//  VideoDecoder.h
//  WD Content
//
//  Created by Сергей Сейтов on 19.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
extern "C" {
#	include "libavcodec/avcodec.h"
}

@interface VideoDecoder : NSObject

- (BOOL)openWithContext:(AVCodecContext*)context;
- (void)close;
- (void)decodePacket:(AVPacket*)packet;
- (AVFrame*)take;

@end
