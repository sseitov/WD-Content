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

@implementation AudioDecoder

- (BOOL)openWithContext:(AVCodecContext*)codecContext
{
	AVCodec* theCodec = avcodec_find_decoder(codecContext->codec_id);
	if (!theCodec) {
		NSLog(@"cannot find audio codec");
		return NO;
	}
	int err = avcodec_open2(codecContext, theCodec, NULL);
	if (err) {
		char buf[255];
		av_strerror(err, buf, 255);
		NSLog(@"error open codec: %s", buf);
		return NO;
	}
	self.context = codecContext;
	return YES;
}

- (void)close
{
	if (self.context) {
		avcodec_close(self.context);
	}
	self.context = NULL;
}

- (void)decodePacket:(AVPacket*)packet
{
	if (!self.context) {
		return;
	}
	int got_frame = 0;
	int len = -1;
	AVFrame *frame = av_frame_alloc();
	len = avcodec_decode_audio4(self.context, frame, &got_frame, packet);
	if (len > 0 && got_frame) {
		frame->pts = frame->pkt_dts;
		if (frame->pts == AV_NOPTS_VALUE) {
			frame->pts = frame->pkt_pts;
		}
		[self.delegate audioDecoder:self decodedFrame:frame];
	}
}

@end
