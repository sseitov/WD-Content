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
#include <list>
#include <mutex>

enum {
	ThreadStillWorking,
	ThreadIsDone
};

class PacketBuffer
{
protected:
	std::list<AVPacket>	_queue;
	std::mutex				_mutex;
	std::condition_variable _empty;
	int						_timeIndex;
	int						_bufferTime;
	
public:
	bool					running;
	
	PacketBuffer(int audioIndex) : running(false), _timeIndex(audioIndex), _bufferTime(0)
	{
	}
	
	~PacketBuffer()
	{
		_empty.notify_one();
		while (!_queue.empty()) {
			AVPacket packet = _queue.front();
			av_free_packet(&packet);
			_queue.pop_front();
		}
	}
	
	void push(AVPacket &packet)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		_queue.push_back(packet);
		if (packet.stream_index == _timeIndex) {
			_bufferTime++;
		}
		_empty.notify_one();
	}
	
	void pop(AVPacket &packet)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		_empty.wait(lock, [this]() { return (!_queue.empty() && running);});
		packet = _queue.front();
		_queue.pop_front();
		if (packet.stream_index == _timeIndex) {
			_bufferTime--;
		}
	}
	
	int time()
	{
		std::unique_lock<std::mutex> lock(_mutex);
		return _bufferTime;
	}
};

@interface Demuxer () <VTDecoderDelegate, AudioDecoderDelegate> {
	
	dispatch_queue_t	_networkQueue;
	dispatch_queue_t	_decoderQueue;

	PacketBuffer		*_packetBuffer;
	
	std::queue<CMSampleBufferRef>	_videoQueue;
	AudioOutput*					_audioOutput;
}

@property (strong, nonatomic) VTDecoder *videoDecoder;
@property (strong, nonatomic) AudioDecoder *audioDecoder;

@property (nonatomic) int audioIndex;
@property (nonatomic) int videoIndex;

@property (atomic) AVFormatContext*	mediaContext;
@property (strong, nonatomic) NSConditionLock *demuxerState;
@property (strong, nonatomic) NSConditionLock *decoderState;
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
		_decoderQueue = dispatch_queue_create("com.vchannel.WD-Content.Decodfer", DISPATCH_QUEUE_SERIAL);
		
		_videoDecoder = [[VTDecoder alloc] init];
		_videoDecoder.delegate = self;
	}
	return self;
}

- (AVRational)timeBase
{
	return _videoDecoder.context->time_base;
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

- (BOOL)play:(int)audioCahnnel
{
	_audioIndex = audioCahnnel;
	_packetBuffer = new PacketBuffer(_audioIndex);
	
	AVCodecContext* enc = self.mediaContext->streams[audioCahnnel]->codec;
	if (![_audioDecoder openWithContext:enc]) {
		return NO;
	}

	self.stopped = NO;
	
	_decoderState = [[NSConditionLock alloc] initWithCondition:ThreadStillWorking];
	
	dispatch_async(_decoderQueue, ^() {
		while (!self.stopped) {
			AVPacket nextPacket;
			_packetBuffer->pop(nextPacket);
			if (nextPacket.stream_index == _audioIndex) {
				[_audioDecoder decodePacket:&nextPacket];
				av_free_packet(&nextPacket);
			} else if (nextPacket.stream_index == _videoIndex) {
				[_videoDecoder decodePacket:&nextPacket];
				av_free_packet(&nextPacket);
			}
			av_free_packet(&nextPacket);
		}
		[_decoderState lock];
		[_decoderState unlockWithCondition:ThreadIsDone];
	});
	
	_demuxerState = [[NSConditionLock alloc] initWithCondition:ThreadStillWorking];
	av_read_play(self.mediaContext);
	
	dispatch_async(_networkQueue, ^() {
		[self.delegate demuxer:self buffering:YES];
		while (!self.stopped) {
			AVPacket nextPacket;
			if (av_read_frame(self.mediaContext, &nextPacket) < 0) { // eof
				[self.delegate demuxerDidStopped:self];
				break;
			}
			if (nextPacket.stream_index == _audioIndex || nextPacket.stream_index == _videoIndex) {
				_packetBuffer->push(nextPacket);
				if (_packetBuffer->time() > 256 && !_packetBuffer->running) {
					_packetBuffer->running = true;
					[self.delegate demuxer:self buffering:NO];
				} else if (_packetBuffer->time() < 16 && _packetBuffer->running) {
					_packetBuffer->running = false;
					[self.delegate demuxer:self buffering:YES];
				}
			} else {;
				av_free_packet(&nextPacket);
			}
		}
		[_demuxerState lock];
		[_demuxerState unlockWithCondition:ThreadIsDone];
	});
	return YES;
}

- (void)stop
{
	if (self.stopped) {
		return;
	}
	
	self.stopped = YES;
	
	[_decoderState lockWhenCondition:ThreadIsDone];
	[_decoderState unlock];
	
	[_demuxerState lockWhenCondition:ThreadIsDone];
	[_demuxerState unlock];
	
	[_audioDecoder close];
	[_audioOutput stop];
	
	delete _packetBuffer;
}

- (void)close
{
	[self stop];
	
	while (!_videoQueue.empty()) {
		CMSampleBufferRef buffer = _videoQueue.front();
		CFRelease(buffer);
		_videoQueue.pop();
	}
	
	avformat_close_input(&_mediaContext);
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
