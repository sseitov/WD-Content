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

class VideoQueue : public SynchroQueue<CMSampleBufferRef> {
public:
	VideoQueue() : SynchroQueue<CMSampleBufferRef>() {}
	virtual void free(CMSampleBufferRef* pBuffer)
	{
		CFRelease(*pBuffer);
	}
};

@interface Demuxer () <VTDecoderDelegate, AudioDecoderDelegate> {
	
	dispatch_queue_t	_demuxerQueue;
	
	VideoQueue			_videoQueue;
	AudioOutput*		_audioOutput;
}

@property (strong, nonatomic) VTDecoder *videoDecoder;
@property (strong, nonatomic) AudioDecoder *audioDecoder;

@property (nonatomic) int audioIndex;
@property (nonatomic) int videoIndex;

@property (atomic) AVFormatContext*	mediaContext;

@end

@implementation Demuxer

- (id)init
{
	self = [super init];
	if (self) {
		_audioDecoder = [[AudioDecoder alloc] init];
		_audioDecoder.delegate = self;
		_audioOutput = [[AudioOutput alloc] init];
		
		_demuxerQueue = dispatch_queue_create("com.vchannel.WD-Content.Demuxer", DISPATCH_QUEUE_SERIAL);
		
		_videoDecoder = [[VTDecoder alloc] init];
		_videoDecoder.delegate = self;
	}
	return self;
}

- (AVCodecContext*)videoContext
{
	return _videoDecoder.context;
}

- (AVCodecContext*)audioContext
{
	return _audioDecoder.context;
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
/*
	NSString* sambaURL = [self sambaURL:url];
	if (!sambaURL) {
		return NO;
	}
*/
	NSString* sambaURL = @"http://panels.telemarker.cc/stream/ort-tm.ts";

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
	dispatch_async(_demuxerQueue, ^() {
		NSMutableArray *audioChannels = [NSMutableArray new];
		if (![self loadMedia:path audioChannels:audioChannels]) {
			completion(nil);
		} else {
			completion(audioChannels);
		}
	});
}

- (BOOL)closed
{
	return (self.mediaContext == NULL);
}

- (void)close
{
	[_audioOutput stop];
	[_audioDecoder close];
	_videoQueue.stop();
	AVFormatContext *context = self.mediaContext;
	self.mediaContext = NULL;
	avformat_close_input(&context);
}

- (void)play:(int)audioCahnnel
{
	_audioIndex = audioCahnnel;
	av_read_play(self.mediaContext);
	dispatch_async(_demuxerQueue, ^() {
		while (!self.closed) {
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
	});
}

- (void)pause
{
	av_read_pause(self.mediaContext);
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
}

#pragma mark - VTDecoder

- (CMSampleBufferRef)takeVideo
{
	CMSampleBufferRef buffer = NULL;
	if (!_videoQueue.pop(&buffer)) {
		return NULL;
	} else {
		return buffer;
	}
/*
	if (!_videoQueue.front(&buffer)) {
		return NULL;
	}
	double audioTime = _audioOutput.getCurrentTime;
	CMTime time = CMSampleBufferGetOutputDecodeTimeStamp(buffer);
	double videoTime = (double)time.value / (double)time.timescale;
	if (videoTime < audioTime) {
		_videoQueue.pop(&buffer);
		NSLog(@"audio %f, video %f", audioTime, videoTime);
		return buffer;
	} else {
		return NULL;
	}*/
}

- (void)videoDecoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
//	NSLog(@"video queue size %d", _videoQueue.size());
	_videoQueue.push(&buffer);
}

@end
