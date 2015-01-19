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

#include <queue>
#include <mutex>

extern "C" {
#	include "libavcodec/avcodec.h"
#	include "libavformat/avformat.h"
#	include "libavformat/avio.h"
#	include "libavfilter/avfilter.h"
};

@interface Demuxer () <VTDecoderDelegate, AudioDecoderDelegate> {
	
	dispatch_queue_t	_demuxerQueue;
	std::mutex			_videoMutex;

	AVFormatContext*	_mediaContext;
	std::mutex			_mediaMutex;
	
	std::queue<CMSampleBufferRef> _videoQueue;
}

@property (strong, nonatomic) VTDecoder *videoDecoder;
@property (strong, nonatomic) AudioDecoder *audioDecoder;

@property (nonatomic) int audioIndex;
@property (nonatomic) int videoIndex;

@end

@implementation Demuxer

- (id)init
{
	self = [super init];
	if (self) {
		_demuxerQueue = dispatch_queue_create("com.vchannel.WD-Content.Demuxer", DISPATCH_QUEUE_SERIAL);
		
		_videoDecoder = [[VTDecoder alloc] init];
		_videoDecoder.delegate = self;
		
		_audioDecoder = [[AudioDecoder alloc] init];
		_audioDecoder.delegate = self;
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
	
	AVCodecContext* enc;
	for (unsigned i=0; i<mediaContext->nb_streams; ++i) {
		enc = mediaContext->streams[i]->codec;
		if (enc->codec_type == AVMEDIA_TYPE_AUDIO) {
			if ([_audioDecoder openWithContext:enc]) {
				_audioIndex = i;
			} else {
				NSLog(@"error open audio");
				return NULL;
			}
		} else if (enc->codec_type == AVMEDIA_TYPE_VIDEO) {
			if ([_videoDecoder openWithContext:enc]) {
				_videoIndex = i;
			} else {
				NSLog(@"error open video");
				return NULL;
			}
		}
	}
	
	return mediaContext;
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

- (void)close
{
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
				[_audioDecoder decodePacket:&nextPacket];
			} else if (nextPacket.stream_index == _videoIndex) {
				[_videoDecoder decodePacket:&nextPacket];
			}
			av_free_packet(&nextPacket);
		}
		doRequest = NO;
	});
}

#pragma mark - AudioDecoder

- (void)audioDecoder:(AudioDecoder*)decoder decodedBuffer:(AVFrame*)frame
{
	
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
		NSLog(@"requestMoreMediaData");
		return NULL;
	}
}

- (BOOL)isReadyForMoreVideoData
{
	std::unique_lock<std::mutex> lock(_videoMutex);
	return _videoQueue.empty();
}

- (void)videoDecoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
	std::unique_lock<std::mutex> lock(_videoMutex);
	_videoQueue.push(buffer);
}

@end
