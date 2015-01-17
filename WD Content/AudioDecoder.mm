//
//  AudioDecoder.m
//  WD Content
//
//  Created by Sergey Seitov on 17.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "AudioDecoder.h"
extern "C" {
#	include "libavcodec/avcodec.h"
};

@interface AudioDecoder ()

@property (readwrite, atomic) AVCodecContext* codec;

@end

@implementation AudioDecoder

- (BOOL)openWithContext:(AVCodecContext*)context
{
	AVCodec* theCodec = avcodec_find_decoder(context->codec_id);
	if (!theCodec || avcodec_open2(context, theCodec, NULL) < 0)
		return NO;
	self.codec = context;
	return YES;
}

- (void)close
{
	if (self.codec) {
		avcodec_close(self.codec);
	}
	self.codec = 0;
}

- (BOOL)decodePacket:(AVPacket*)packet toFrame:(AVFrame*)frame
{
	int got_frame = 0;
	int len = -1;
	if (self.codec) {
		len = avcodec_decode_audio4(self.codec, frame, &got_frame, packet);
	}
	if (len > 0 && got_frame) {
		frame->pts = frame->pkt_dts;
		if (frame->pts == AV_NOPTS_VALUE) {
			frame->pts = frame->pkt_pts;
		}
		return true;
	} else {
		return false;
	}
}

@end
