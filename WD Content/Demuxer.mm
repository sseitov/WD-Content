//
//  Demuxer.m
//  WD Content
//
//  Created by Sergey Seitov on 19.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "Demuxer.h"
#import "DataModel.h"
#import "AudioDecoder.h"
#import "VTDecoder.h"
#include "ConditionLock.h"
#include <mutex>

extern "C" {
#	include "libavformat/avformat.h"
};

@interface Demuxer () <DecoderDelegate> {
	
	dispatch_queue_t	_networkQueue;
	std::mutex			_audioMutex;
}

@property (strong, nonatomic) VTDecoder *videoDecoder;
@property (strong, nonatomic) AudioDecoder *audioDecoder;

@property (atomic) int audioIndex;
@property (nonatomic) int videoIndex;

@property (atomic) AVFormatContext*	mediaContext;

@property (strong, nonatomic) NSCondition *demuxerState;
@property (strong, nonatomic) NSConditionLock *threadState;
@property (atomic) BOOL stopped;
@property (atomic) BOOL buffering;

@end

@implementation Demuxer

- (id)init
{
	self = [super init];
	if (self) {
		_audioDecoder = [[AudioDecoder alloc] init];
		_audioDecoder.delegate = self;
		_videoDecoder = [[VTDecoder alloc] init];
		_videoDecoder.delegate = self;
		
		_networkQueue = dispatch_queue_create("com.vchannel.WD-Content.SMBNetwork", DISPATCH_QUEUE_SERIAL);
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

- (BOOL)loadMedia:(NSString*)url audioChannels:(NSMutableArray*)audioChannels
{
	NSString* sambaURL = [self sambaURL:url];
	if (!sambaURL) {
		return NO;
	}
	
	int err = avformat_open_input(&_mediaContext, [sambaURL UTF8String], NULL, NULL);
	if ( err < 0) {
		return NULL;
	}
	
	// Retrieve stream information
	avformat_find_stream_info(self.mediaContext, NULL);
	
	_audioIndex = -1;
	_videoIndex = -1;
	AVCodecContext* enc;
	
	for (unsigned i=0; i<self.mediaContext->nb_streams; ++i) {
		enc = self.mediaContext->streams[i]->codec;
		if (enc->codec_type == AVMEDIA_TYPE_AUDIO && enc->codec_descriptor) {
			[audioChannels addObject:@{@"channel" : [NSNumber numberWithInt:i],
									   @"codec" : [NSString stringWithFormat:@"%s, %d channels", enc->codec_descriptor->long_name, enc->channels]}];
		} else if (enc->codec_type == AVMEDIA_TYPE_VIDEO) {
			if ([_videoDecoder openWithContext:enc]) {
				_videoIndex = i;
			}
		}
	}

	return (_videoIndex >= 0);
}

- (void)openWithPath:(NSString*)path completion:(void (^)(NSArray*))completion
{
	dispatch_async(_networkQueue, ^() {
		NSMutableArray *audioChannels = [NSMutableArray new];
		if (![self loadMedia:path audioChannels:audioChannels]) {
			completion(nil);
		} else {
			completion(audioChannels);
		}
	});
}

- (BOOL)changeAudio:(int)audioCahnnel
{
	std::unique_lock<std::mutex> lock(_audioMutex);
	
	[_audioDecoder stop];
	[_audioDecoder close];
	AVCodecContext* enc = self.mediaContext->streams[audioCahnnel]->codec;
	if (![self.audioDecoder openWithContext:enc]) {
		enc = self.mediaContext->streams[_audioIndex]->codec;
		[_audioDecoder openWithContext:enc];
		[_audioDecoder start];
		return NO;
	}
	self.audioIndex = audioCahnnel;
	[_audioDecoder start];
	return YES;
}

- (BOOL)play:(int)audioCahnnel
{
	AVCodecContext* enc = self.mediaContext->streams[audioCahnnel]->codec;
	if (![_audioDecoder openWithContext:enc]) {
		return NO;
	}
	
	self.audioIndex = audioCahnnel;
 
	self.stopped = NO;

	[_audioDecoder start];
	[_videoDecoder start];
	
	_threadState = [[NSConditionLock alloc] initWithCondition:ThreadStillWorking];
	av_read_play(self.mediaContext);
	
	dispatch_async(_networkQueue, ^() {
		while (!self.stopped) {
			AVPacket nextPacket;
			if (av_read_frame(self.mediaContext, &nextPacket) < 0) { // eof
				break;
			}
			
			std::unique_lock<std::mutex> lock(_audioMutex);
			
			if (nextPacket.stream_index == self.audioIndex) {
				[_audioDecoder push:&nextPacket];
			} else if (nextPacket.stream_index == self.videoIndex) {
				[_videoDecoder push:&nextPacket];
			} else {
				av_packet_unref(&nextPacket);
			}
			
			ConditionLock locker(_demuxerState);
			while (_audioDecoder.isFull && _videoDecoder.isFull) {
				[_demuxerState wait];
			}
		}
		[_threadState lock];
		[_threadState unlockWithCondition:ThreadIsDone];
	});
	return YES;
}

- (void)close
{
	self.stopped = YES;
	
	[_audioDecoder stop];
	[_audioDecoder close];
	[_videoDecoder stop];
	[_videoDecoder close];
	
	[_threadState lockWhenCondition:ThreadIsDone];
	[_threadState unlock];
	
	avformat_close_input(&_mediaContext);
}

- (CMSampleBufferRef)takeVideo
{
	if (self.buffering || _audioDecoder.currentTime < 0) {
		return NULL;
	} else {
		return [_videoDecoder takeWithTime:_audioDecoder.currentTime];
	}
}

- (void)decoder:(Decoder*)decoder changeState:(enum DecoderState)state
{
	switch (state) {
		case Continue:
		{
			ConditionLock locker(_demuxerState);
			[_demuxerState signal];
		}
			break;
		case StartBuffering:
			[self.delegate demuxer:self buffering:YES];
			self.buffering = YES;
			break;
		case StopBuffering:
			[self.delegate demuxer:self buffering:NO];
			self.buffering = NO;
			break;
		default:
			break;
	}
}

@end
