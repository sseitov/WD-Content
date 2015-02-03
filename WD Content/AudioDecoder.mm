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
	std::mutex			_mutex;
	NSOperationQueue	*_decoderQueue;
}

@end

@implementation AudioDecoder

- (id)init
{
	self = [super init];
	if (self) {
		_decoderQueue = [[NSOperationQueue alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[self close];
}

- (BOOL)openWithContext:(AVCodecContext*)context
{
	std::unique_lock<std::mutex> lock(_mutex);
	AVCodec* theCodec = avcodec_find_decoder(context->codec_id);
	if (!theCodec) {
		NSLog(@"cannot find audio codec");
		return NO;
	}
	int err = avcodec_open2(context, theCodec, NULL);
	if (err) {
		char buf[255];
		av_strerror(err, buf, 255);
		NSLog(@"error open codec: %s", buf);
		return NO;
	}
	_context = context;
	return YES;
}

- (void)close
{
	[_decoderQueue cancelAllOperations];
	std::unique_lock<std::mutex> lock(_mutex);
	if (_context) {
		avcodec_close(_context);
	}
	_context = NULL;
}

- (void)decodePacket:(AVPacket*)packet
{
	int got_frame = 0;
	int len = -1;
	static AVFrame frame;
	avcodec_get_frame_defaults(&frame);
	len = avcodec_decode_audio4(_context, &frame, &got_frame, packet);
	if (len > 0 && got_frame) {
		frame.pts = frame.pkt_dts;
		if (frame.pts == AV_NOPTS_VALUE) {
			frame.pts = frame.pkt_pts;
		}
		[self.delegate audioDecoder:self decodedFrame:&frame];
	}
}

@end
