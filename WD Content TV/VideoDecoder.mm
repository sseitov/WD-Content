//
//  VideoDecoder.m
//  WD Content
//
//  Created by Сергей Сейтов on 19.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

#import "VideoDecoder.h"

#include "ConditionLock.h"
#include <queue>
#include <mutex>

@interface VideoDecoder () {
	std::queue<AVFrame*>	_queue;
	std::mutex				_mutex;
	dispatch_queue_t		_decoderQueue;
}

@property (atomic) AVCodecContext* codec;

@end

@implementation VideoDecoder

- (id)init
{
	self = [super init];
	if (self) {
		_decoderQueue = dispatch_queue_create("com.vchannel.WD-Content.Decoder", DISPATCH_QUEUE_SERIAL);
	}
	return self;
}

- (NSString*)name
{
	return @"VideoDecoder";
}

- (BOOL)openWithContext:(AVCodecContext*)context {
	AVCodec* theCodec = avcodec_find_decoder(context->codec_id);
	if (!theCodec || avcodec_open2(context, theCodec, NULL) < 0)
		return NO;
	
	_codec = context;
	return YES;
}

- (void)close
{
	if (_codec) {
		avcodec_close(_codec);
	}
	_codec = 0;
}

- (void)decodePacket:(AVPacket*)packet
{
	dispatch_async(_decoderQueue, ^{
		int got_frame = 0;
		int len = -1;
		AVFrame* frame = av_frame_alloc();
		if (self.codec) {
			len = avcodec_decode_video2(self.codec, frame, &got_frame, packet);
		}
		if (len > 0 && got_frame) {
			frame->pts = frame->pkt_dts;
			if (frame->pts == AV_NOPTS_VALUE) {
				frame->pts = frame->pkt_pts;
			}
			[self put:frame];
		} else {
			av_frame_free(&frame);
		}
	});
}

- (void)put:(AVFrame*)frame
{
	std::unique_lock<std::mutex> lock(_mutex);
	_queue.push(frame);
}

- (AVFrame*)take
{
	std::unique_lock<std::mutex> lock(_mutex);
	if (_queue.empty()) {
		return NULL;
	} else {
		AVFrame* buffer = _queue.front();
		_queue.pop();
		return buffer;
	}
}

@end
