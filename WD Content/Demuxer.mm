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
#import "Decoder.h"

#include <queue>
#include <mutex>

@interface Demuxer () <VTDecoderDelegate, AudioDecoderDelegate, DecoderDelegate> {
	
	dispatch_queue_t	_networkQueue;
	
	std::queue<CMSampleBufferRef>	_videoQueue;
	AudioOutput*					_audioOutput;
	std::mutex						_audioMutex;
}

@property (strong, nonatomic) VTDecoder *videoDecoder;
@property (strong, nonatomic) AudioDecoder *audioDecoder;
@property (strong, nonatomic) Decoder *decoder;
@property (strong, nonatomic) NSCondition* decoderCondition;

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
		
		_decoder = [[Decoder alloc] init];
		_decoder.delegate = self;
		_decoderCondition = [[NSCondition alloc] init];
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
	NSString* sambaURL = @"http://panels.telemarker.cc/stream/tvc-tm.ts";
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
	[_audioOutput stop];
	AVCodecContext* enc = self.mediaContext->streams[audioCahnnel]->codec;
	[_audioDecoder close];
	if (![_audioDecoder openWithContext:enc]) {
		enc = self.mediaContext->streams[_audioIndex]->codec;
		[_audioDecoder openWithContext:enc];
		return NO;
	}
	_audioIndex = audioCahnnel;
	[_decoder changeAudio:_audioIndex];
	return YES;
}

- (BOOL)play:(int)audioCahnnel
{
	AVCodecContext* enc = self.mediaContext->streams[audioCahnnel]->codec;
	if (![_audioDecoder openWithContext:enc]) {
		return NO;
	}
	
	_audioIndex = audioCahnnel;
	[_decoder startWithAudio:_audioIndex];
 
	self.stopped = NO;

	_demuxerState = [[NSConditionLock alloc] initWithCondition:ThreadStillWorking];
	av_read_play(self.mediaContext);
	
	dispatch_async(_networkQueue, ^() {
		while (!self.stopped) {
			AVPacket nextPacket;
			if (av_read_frame(self.mediaContext, &nextPacket) < 0) { // eof
				[self.delegate demuxerDidStopped:self];
				break;
			}
			
			if (nextPacket.stream_index == _audioIndex || nextPacket.stream_index == _videoIndex) {
			
				switch ([_decoder pushPacket:&nextPacket]) {
					case StartBuffering:
						[self.delegate demuxer:self buffering:YES];
						break;
					case StopBuffering:
						[self.delegate demuxer:self buffering:NO];
						break;
					default:
						break;
				}
			} else {
				av_free_packet(&nextPacket);
			}
			
			[_decoderCondition lock];
			while (_decoder.size > 512) {
				[_decoderCondition wait];
			}
			[_decoderCondition unlock];
		}
		[_demuxerState lock];
		[_demuxerState unlockWithCondition:ThreadIsDone];
	});
	return YES;
}

- (void)close
{
	self.stopped = YES;

	[_decoder stop];
	
	[_demuxerState lockWhenCondition:ThreadIsDone];
	[_demuxerState unlock];
	
	[_audioDecoder close];
	[_audioOutput stop];
	
	while (!_videoQueue.empty()) {
		CMSampleBufferRef buffer = _videoQueue.front();
		CFRelease(buffer);
		_videoQueue.pop();
	}
	
	avformat_close_input(&_mediaContext);
}

#pragma mark - Decoder

- (void)decodePacket:(AVPacket*)packet
{
	std::unique_lock<std::mutex> lock(_audioMutex);
	if (packet->stream_index == _audioIndex) {
		[_audioDecoder decodePacket:packet];
	} else if (packet->stream_index == _videoIndex) {
		[_videoDecoder decodePacket:packet];
	}
	av_free_packet(packet);
	[_decoderCondition lock];
	[_decoderCondition signal];
	[_decoderCondition unlock];
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
