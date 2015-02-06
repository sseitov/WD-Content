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

enum {
	ThreadStillWorking,
	ThreadIsDone
};

@interface Demuxer () <VTDecoderDelegate, AudioDecoderDelegate> {
	
	dispatch_queue_t	_networkQueue;

	std::queue<CMSampleBufferRef>	_videoQueue;
	AudioOutput*					_audioOutput;
	NSDate* startDate;
}

@property (strong, nonatomic) VTDecoder *videoDecoder;
@property (strong, nonatomic) AudioDecoder *audioDecoder;

@property (nonatomic) int audioIndex;
@property (nonatomic) int videoIndex;

@property (atomic) AVFormatContext*	mediaContext;
@property (strong, nonatomic) NSConditionLock *demuxerState;
@property (atomic) BOOL stopped;

@end

@implementation Demuxer

- (id)init
{
	self = [super init];
	if (self) {
		_audioDecoder = [[AudioDecoder alloc] init];
		_audioDecoder.delegate = self;
		_audioOutput = [[AudioOutput alloc] init];
		
		_networkQueue = dispatch_queue_create("com.vchannel.WD-Content.SMBNetwork", DISPATCH_QUEUE_SERIAL);
		
		_videoDecoder = [[VTDecoder alloc] init];
		_videoDecoder.delegate = self;
	}
	return self;
}

- (AVRational)timeBase
{
	return _audioDecoder.context->time_base;
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
/*
	NSString* sambaURL = @"http://panels.telemarker.cc/stream/ort-tm.ts";
*/
	int err = avformat_open_input(&_mediaContext, [sambaURL UTF8String], NULL, NULL);
	if ( err != 0) {
		return NULL;
	}
	
	// Retrieve stream information
	avformat_find_stream_info(self.mediaContext, NULL);
	
	_audioIndex = -1;
	_videoIndex = -1;
	AVCodecContext* enc;
	
	for (unsigned i=0; i<self.mediaContext->nb_streams; ++i) {
		enc = self.mediaContext->streams[i]->codec;
		if (enc->codec_type == AVMEDIA_TYPE_AUDIO) {
			if ([_audioDecoder openWithContext:enc]) {
				[audioChannels addObject:@{@"channel" : [NSNumber numberWithInt:i],
										   @"codec" : [NSString stringWithFormat:@"%s, %d channels", enc->codec->long_name, enc->channels]}];
			}
		} else if (enc->codec_type == AVMEDIA_TYPE_VIDEO) {
			if ([_videoDecoder openWithContext:enc]) {
				_videoIndex = i;
			}
		}
	}

	if (_audioIndex < 0 && _videoIndex < 0) {
		return NO;
	} else {
		return YES;
	}
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

- (void)play:(int)audioCahnnel
{
	_audioIndex = audioCahnnel;
	_demuxerState = [[NSConditionLock alloc] initWithCondition:ThreadStillWorking];
	_videoDecoder.timeBase = _audioDecoder.context->time_base;
	av_read_play(self.mediaContext);
	startDate = [NSDate date];
	self.stopped = NO;
	dispatch_async(_networkQueue, ^() {
		while (!self.stopped) {
			AVPacket nextPacket;
			if (av_read_frame(self.mediaContext, &nextPacket) < 0) { // eof
				[self.delegate demuxerDidStopped:self];
				break;
			}

			if (nextPacket.stream_index == _audioIndex) {
				[_audioDecoder decodePacket:&nextPacket];
			} else if (nextPacket.stream_index == _videoIndex) {
				[_videoDecoder decodePacket:&nextPacket];
			}
			av_free_packet(&nextPacket);
		}
		[_demuxerState lock];
		[_demuxerState unlockWithCondition:ThreadIsDone];
	});
}

- (void)close
{
	self.stopped = YES;
	[_demuxerState lockWhenCondition:ThreadIsDone];
	[_demuxerState unlock];
	
	[_audioOutput stop];
	[_audioDecoder close];
	avformat_close_input(&_mediaContext);
	
	while (!_videoQueue.empty()) {
		CMSampleBufferRef buffer = _videoQueue.front();
		CFRelease(buffer);
		_videoQueue.pop();
	}
}

#pragma mark - Audio

- (void)audioDecoder:(AudioDecoder*)decoder decodedFrame:(AVFrame*)frame
{
	if (!_audioOutput.started) {
		[_audioOutput startWithFrame:frame];
	}
	if (_audioOutput.started) {
		[_audioOutput enqueueFrame:frame];
	}
	av_frame_free(&frame);
}

#pragma mark - VTDecoder

- (CMSampleBufferRef)takeVideo
{
	if (!_videoQueue.empty()) {
		CMSampleBufferRef buffer = _videoQueue.front();
/*
		CMTime time = CMSampleBufferGetOutputDecodeTimeStamp(buffer);
		if (time.timescale) {
			double videoTime = (double)time.value / (double)time.timescale;
			NSLog(@"time %f, video %f", [[NSDate date] timeIntervalSinceDate:startDate], videoTime);
		}
*/
		_videoQueue.pop();
		return buffer;
	} else {
		return NULL;
	}
}

- (void)videoDecoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
	_videoQueue.push(buffer);
}

@end
