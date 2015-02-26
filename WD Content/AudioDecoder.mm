//
//  AudioDecoder.m
//  WD Content
//
//  Created by Sergey Seitov on 17.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "AudioDecoder.h"
#import "AudioOutput.h"

extern "C" {
#	include "libavcodec/avcodec.h"
};

@interface AudioDecoder ()

@property (strong, nonatomic) AudioOutput *audioOutput;
@property (atomic) double previouseTime;

@end

@implementation AudioDecoder

- (id)init
{
	self = [super init];
	if (self) {
		self.decoderThread = dispatch_queue_create("com.vchannel.WD-Content.AudioDecoder", DISPATCH_QUEUE_SERIAL);
		_audioOutput = [[AudioOutput alloc] init];
		self.previouseTime = 0;
	}
	return self;
}

- (NSString*)name
{
	return @"AudioDecoder";
}

- (double)currentTime
{
	if (_audioOutput.started) {
		return (self.previouseTime + _audioOutput.getCurrentTime);
	} else {
		return -1;
	}
}

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

- (void)push:(AVPacket*)packet
{
	[super push:packet];
	size_t size = [self size];
	if (size > 256 && !self.running) {
		[self pause:NO];
		[self.delegate decoder:self changeState:StopBuffering];
	}
	if (size < 16 && self.running) {
		[self pause:YES];
		[self.delegate decoder:self changeState:StartBuffering];
	}
}

- (BOOL)threadStep
{
	AVPacket packet;
	if ([self pop:&packet] && !self.stopped) {
		AVFrame* frame = [self decodePacket:&packet];
		av_free_packet(&packet);
		if (frame) {
			if (!_audioOutput.started) {
				[_audioOutput startWithFrame:frame];
			}
			if (_audioOutput.started) {
				[_audioOutput enqueueFrame:frame];
			}
			av_frame_free(&frame);
		}
		return YES;
	} else {
		return NO;
	}
}

- (void)stop
{
	[super stop];
	self.previouseTime += _audioOutput.getCurrentTime;
	[_audioOutput stop];
}

- (AVFrame*)decodePacket:(AVPacket*)packet
{
	if (!self.context) {
		return NULL;
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
		return frame;
	} else {
		return NULL;
	}
}

@end
