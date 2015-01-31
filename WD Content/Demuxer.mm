//
//  Demuxer.m
//  WD Content
//
//  Created by Sergey Seitov on 19.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "Demuxer.h"
#import "DataModel.h"
#import "VTDecoder.h"
#import "AudioDecoder.h"
#import "AudioOutput.h"

#include <queue>
#include "SynchroQueue.h"

extern "C" {
#	include "libavcodec/avcodec.h"
#	include "libavformat/avformat.h"
#	include "libavformat/avio.h"
#	include "libavfilter/avfilter.h"
};

#define QUEUE_SIZE	31

class PacketQueue : public BlockedQueue<AVPacket> {
public:
	PacketQueue() : BlockedQueue<AVPacket>(QUEUE_SIZE) {}
	virtual void free(AVPacket* packet)
	{
		av_free_packet(packet);
	}
};

@interface Demuxer () <VTDecoderDelegate> {
	
	dispatch_queue_t	_demuxerQueue;
	dispatch_queue_t	_decoderQueue;
	
	AVFormatContext*	_mediaContext;
	std::mutex			_mediaMutex;
	
	PacketQueue			_packetQueue;
	
	std::queue<CMSampleBufferRef>	_videoQueue;
}

@property (strong, nonatomic) VTDecoder *videoDecoder;
@property (strong, nonatomic) AudioDecoder *audioDecoder;

@property (nonatomic) int audioIndex;
@property (nonatomic) int videoIndex;

@property (strong, nonatomic) AudioOutput *audioOutput;

@end

@implementation Demuxer

- (id)init
{
	self = [super init];
	if (self) {
		_audioDecoder = [[AudioDecoder alloc] init];
		
		_demuxerQueue = dispatch_queue_create("com.vchannel.WD-Content.Demuxer", DISPATCH_QUEUE_SERIAL);
		_decoderQueue = dispatch_queue_create("com.vchannel.WD-Content.Decoder", DISPATCH_QUEUE_SERIAL);
		
		_videoDecoder = [[VTDecoder alloc] init];
		_videoDecoder.delegate = self;
		
		_audioOutput = [[AudioOutput alloc] init];
	}
	return self;
}

- (NSString*)sambaURL:(NSString*)path
{
	NSRange p = [path rangeOfString:@"smb://"];
	NSRange r = {p.length, path.length - p.length};
	NSRange s = [path rangeOfString:@"/" options:NSCaseInsensitiveSearch range:r];
	NSRange ss = {p.length, s.location - p.length};
	NSString* server = [path substringWithRange:ss];
	NSRange pp = {s.location, path.length - s.location};
	NSString *smbPath = [path substringWithRange:pp];
	
	NSDictionary* auth = [DataModel authForHost:server];
	if (auth) {
		return [NSString stringWithFormat:@"smb://%@:%@@%@%@",
				[auth objectForKey:@"user"],
				[auth objectForKey:@"password"],
				server, smbPath];
	} else {
		return nil;
	}
}

- (AVFormatContext*)loadMedia:(NSString*)url
{
	NSString* sambaURL = [self sambaURL:url];
	NSLog(@"open %@", sambaURL);
	AVFormatContext* mediaContext = 0;
	
	int err = avformat_open_input(&mediaContext, [sambaURL UTF8String], NULL, NULL);
	if ( err != 0) {
		return NULL;
	}
	
	// Retrieve stream information
	avformat_find_stream_info(mediaContext, NULL);
	
	_audioIndex = -1;
	_videoIndex = -1;
	AVCodecContext* enc;
	for (unsigned i=0; i<mediaContext->nb_streams; ++i) {
		enc = mediaContext->streams[i]->codec;
		if (enc->codec_type == AVMEDIA_TYPE_AUDIO) {
			if ([_audioDecoder openWithContext:enc]) {
				_audioIndex = i;
			}
		} else if (enc->codec_type == AVMEDIA_TYPE_VIDEO) {
			if ([_videoDecoder openWithContext:enc]) {
				_videoIndex = i;
			}
		}
	}

	if (_audioIndex < 0 && _videoIndex < 0) {
		return NULL;
	} else {
		return mediaContext;
	}
}

- (void)openWithPath:(NSString*)path completion:(void (^)(BOOL))completion
{
	dispatch_async(_demuxerQueue, ^() {
		_mediaContext = [self loadMedia:path];
		if (!_mediaContext) {
			completion(NO);
		} else {
			completion(YES);
		}
	});
}

- (BOOL)closed
{
	std::unique_lock<std::mutex> lock(_mediaMutex);
	return (_mediaContext == NULL);
}

- (void)close
{
	_packetQueue.stop();
	std::unique_lock<std::mutex> lock(_mediaMutex);
	avformat_close_input(&_mediaContext);
	_mediaContext = NULL;
}

- (AVPacket)createAudioPacket:(AVPacket*)src
{
	AVPacket packet;
	av_new_packet(&packet, src->size);
	packet.pts = src->pts;
	packet.dts = src->dts;
	memcpy(packet.data, src->data, src->size);
	packet.size = src->size;
	packet.stream_index = _audioIndex;
	packet.duration = src->duration;
	return packet;
}

- (void)play
{
	__block NSCondition *started = [NSCondition new];
	
	// decoder thread
	dispatch_async(_decoderQueue, ^() {
		[started lock];
		[started signal];
		[started unlock];
		AVPacket packet;
		while (_packetQueue.pop(&packet)) {
//			NSLog(@"queue size after pop %d", _packetQueue.size());
			if (packet.stream_index == _audioIndex) {
				AVFrame *frame = av_frame_alloc();
				if ([_audioDecoder decodePacket:&packet toFrame:frame]) {
					if (!_audioOutput.started) {
						[_audioOutput startWithFrame:frame];
					}
					if (_audioOutput.started) {
						[_audioOutput writeFrame:frame];
					}
				}
				av_frame_free(&frame);
			} else {
				[_videoDecoder decodePacket:&packet];
			}
//			NSLog(@"packet sent into decoder");
			av_free_packet(&packet);
		}
	});
	[started lock];
	[started wait];
	[started unlock];
	
	av_read_play(_mediaContext);
	dispatch_async(_demuxerQueue, ^() {
		while (!self.closed) {
			AVPacket nextPacket;
			if (av_read_frame(_mediaContext, &nextPacket) < 0) { // eof
				[self.delegate didStopped:self];
				break;
			}
			if (nextPacket.stream_index == _videoIndex) {
//			if ((nextPacket.stream_index == _audioIndex) || (nextPacket.stream_index == _videoIndex)) {
				_packetQueue.push(&nextPacket);
			} else {
				av_free_packet(&nextPacket);
			}
		}
	});
}

- (void)pause
{
	av_read_pause(_mediaContext);
}

#pragma mark - VTDecoder

- (CMSampleBufferRef)takeVideo
{
	if (_videoQueue.empty()) {
		return NULL;
	} else {
		CMSampleBufferRef buffer = _videoQueue.front();
		_videoQueue.pop();
		return buffer;
	}
}

- (void)videoDecoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
	_videoQueue.push(buffer);
}

@end
