//
//  Decoder.m
//  WD Content
//
//  Created by Sergey Seitov on 13.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "Decoder.h"
#include "libavcodec/avcodec.h"

@implementation Decoder

- (BOOL)openWithContext:(struct AVCodecContext*)context
{
	AVCodec* theCodec = avcodec_find_decoder(context->codec_id);
	if (!theCodec || avcodec_open2(context, theCodec, NULL) < 0)
		return NO;
	_codec = context;
	return YES;
}

- (void)close
{
	if (_codec) {
		avcodec_close(self.codec);
	}
	_codec = NULL;
}

@end
