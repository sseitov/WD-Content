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
#include <mutex>

@interface AudioDecoder () {
	AVCodecContext* _context;
	std::mutex		_mutex;
}


@end

@implementation AudioDecoder

- (BOOL)openWithContext:(AVCodecContext*)context
{
	std::unique_lock<std::mutex> lock(_mutex);
	AVCodec* theCodec = avcodec_find_decoder(context->codec_id);
	if (!theCodec || avcodec_open2(context, theCodec, NULL) < 0)
		return NO;
	_context = context;
	return YES;
}

- (void)close
{
	std::unique_lock<std::mutex> lock(_mutex);
	if (_context) {
		avcodec_close(_context);
	}
	_context = NULL;
}

- (BOOL)decodePacket:(AVPacket*)packet toFrame:(AVFrame*)frame
{
	std::unique_lock<std::mutex> lock(_mutex);
	int got_frame = 0;
	int len = -1;
	if (_context) {
		avcodec_get_frame_defaults(frame);
		len = avcodec_decode_audio4(_context, frame, &got_frame, packet);
		if (len > 0 && got_frame) {
			frame->pts = frame->pkt_dts;
			if (frame->pts == AV_NOPTS_VALUE) {
				frame->pts = frame->pkt_pts;
			}
			return YES;
		} else {
			return NO;
		}
	} else {
		return NO;
	}
}

@end
