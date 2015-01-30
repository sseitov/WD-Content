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

class PacketQueue : public SynchroQueue<AVPacket> {
public:
	virtual void free(AVPacket* packet)
	{
		av_free_packet(packet);
	}
};

@interface Demuxer () <VTDecoderDelegate> {
	
	dispatch_queue_t	_demuxerQueue;
	std::mutex			_videoMutex;
	
	dispatch_queue_t	_audioQueue;
	PacketQueue			_packetQueue;
	
	AVFormatContext*	_mediaContext;
	std::mutex			_mediaMutex;
	
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
		_audioOutput = [[AudioOutput alloc] init];
		
		_demuxerQueue = dispatch_queue_create("com.vchannel.WD-Content.Demuxer", DISPATCH_QUEUE_SERIAL);
		_audioQueue = dispatch_queue_create("com.vchannel.WD-Content.Audio", DISPATCH_QUEUE_SERIAL);
		
		_videoDecoder = [[VTDecoder alloc] init];
		_videoDecoder.delegate = self;
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
	dispatch_async(_audioQueue, ^() {
		AVPacket packet;
		static AVFrame frame;
		while (_packetQueue.pop(&packet)) {
			avcodec_get_frame_defaults(&frame);
			[_audioDecoder decodePacket:&packet toFrame:&frame];
			av_free_packet(&packet);
			if (!_audioOutput.started) {
				[_audioOutput startWithFrame:&frame];
			}
			if (_audioOutput.started) {
				[_audioOutput writeFrame:&frame];
			}
		}
	});
}

- (void)close
{
	_packetQueue.stop();
	std::unique_lock<std::mutex> lock(_mediaMutex);
	avformat_close_input(&_mediaContext);
	_mediaContext = NULL;
}

- (void)play
{
	av_read_play(_mediaContext);
}

- (void)stop
{
	av_read_pause(_mediaContext);
}

- (void)requestMoreMediaData
{
	static BOOL doRequest;
	if (doRequest) {
		return;
	}
	dispatch_async(_demuxerQueue, ^() {
		doRequest = YES;
		while (self.isReadyForMoreVideoData) {
			std::unique_lock<std::mutex> lock(_mediaMutex);
			if (!_mediaContext) {	// closed
				break;
			}
			
			AVPacket nextPacket;
			if (av_read_frame(_mediaContext, &nextPacket) < 0) { // eof
				[self.delegate didStopped:self];
				break;
			}
			
			if (nextPacket.stream_index == _audioIndex) {
				_packetQueue.push(&nextPacket);
			} else if (nextPacket.stream_index == _videoIndex) {
				[_videoDecoder decodePacket:&nextPacket];
				av_free_packet(&nextPacket);
			} else {
				av_free_packet(&nextPacket);
			}
		}
		doRequest = NO;
	});
}

#pragma mark - VTDecoder

- (CMSampleBufferRef)takeVideo
{
	std::unique_lock<std::mutex> lock(_videoMutex);
	if (!_videoQueue.empty()) {
		CMSampleBufferRef buffer = _videoQueue.front();
		_videoQueue.pop();
		return buffer;
	} else {
		[self requestMoreMediaData];
//		NSLog(@"requestMoreMediaData");
		return NULL;
	}
}

- (BOOL)isReadyForMoreVideoData
{
	std::unique_lock<std::mutex> lock(_videoMutex);
	return (_videoQueue.size() < 2);
}

- (void)videoDecoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
	std::unique_lock<std::mutex> lock(_videoMutex);
	_videoQueue.push(buffer);
}

@end
