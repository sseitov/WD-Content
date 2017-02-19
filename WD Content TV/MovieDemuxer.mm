//
//  MovieDemuxer.m
//  WD Content
//
//  Created by Сергей Сейтов on 18.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

#import "MovieDemuxer.h"
#import "SMBConnection.h"
#import "YUVTexture.h"

#import "AudioDecoder.h"
#import "VideoDecoder.h"
#include "ConditionLock.h"
#include <mutex>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavformat/avio.h>
};
#import <GLKit/GLKit.h>

static const int kBufferSize = 4 * 1024;

@interface MovieDemuxer () <DecoderDelegate> {
	dispatch_queue_t	_networkQueue;
	unsigned char*		_ioBuffer;
	AVIOContext*		_ioContext;
	AVFormatContext*	_mediaContext;
	std::mutex			_audioMutex;
}

@property (strong, nonatomic, readonly) SMBConnection* connection;
@property (nonatomic, readonly) smb_fd file;

@property (atomic) int audioIndex;
@property (nonatomic) int videoIndex;
@property (strong, nonatomic) VideoDecoder *videoDecoder;
@property (strong, nonatomic) AudioDecoder *audioDecoder;
@property (strong, nonatomic) NSCondition *demuxerState;
@property (strong, nonatomic) NSConditionLock *threadState;
@property (atomic) BOOL stopped;
@property (atomic) BOOL buffering;
@property (nonatomic) BOOL textureCreated;

@end

static int readContext(void *opaque, unsigned char *buf, int buf_size) {
	MovieDemuxer* demuxer = (__bridge MovieDemuxer *)(opaque);
	return [demuxer.connection readFile:demuxer.file buffer:buf size:buf_size];
}

static int64_t seekContext(void *opaque, int64_t offset, int whence) {
	MovieDemuxer* demuxer = (__bridge MovieDemuxer *)(opaque);
	return [demuxer.connection seekFile:demuxer.file offset:offset whence:whence];
}

@implementation MovieDemuxer

- (instancetype)init {

	self = [super init];
	if (self){
		av_register_all();
		avcodec_register_all();
		int ret = avformat_network_init();
		NSLog(@"avformat_network_init = %d", ret);
		
		_ioBuffer = new unsigned char[kBufferSize];
		_ioContext = avio_alloc_context((unsigned char*)_ioBuffer, kBufferSize, 0, (__bridge void*)self, readContext, NULL, seekContext);
		
		_audioDecoder = [[AudioDecoder alloc] init];
		_audioDecoder.delegate = self;
		_videoDecoder = [[VideoDecoder alloc] init];
		
		_connection = [[SMBConnection alloc] init];

		_networkQueue = dispatch_queue_create("com.vchannel.WD-Content.SMBNetwork", DISPATCH_QUEUE_SERIAL);
		_textureCreated = false;
	}
	return self;
}

- (void)dealloc {
	if (_file)
		[_connection closeFile:_file];
	[_connection disconnect];
	if (_mediaContext)
		avformat_close_input(&_mediaContext);	// AVFormatContext is released by avformat_close_input
	if (_ioContext)
		av_free(_ioContext);					// AVIOContext is released by av_free
}

- (bool)load:(NSString*)host port:(int)port user:(NSString*)user password:(NSString*)password file:(NSString*)filePath  audioChannels:(NSMutableArray*) audioChannels {

	if (![_connection connectTo:host port:port user:user password:password])
		return false;
	
	_file = [_connection openFile:filePath];
	if (!_file)
		return false;
	
	_mediaContext = avformat_alloc_context();
	_mediaContext->pb = _ioContext;
	_mediaContext->flags = AVFMT_FLAG_CUSTOM_IO;
	
	int err = avformat_open_input(&_mediaContext, "", NULL, NULL);
	if ( err < 0) {
		char errStr[256];
		av_strerror(err, errStr, sizeof(errStr));
		NSLog(@"open error: %s", errStr);
		return false;
	}
	
	// Retrieve stream information
	avformat_find_stream_info(_mediaContext, NULL);
	
	_audioIndex = -1;
	_videoIndex = -1;
	AVCodecContext* enc;
	
	for (unsigned i=0; i<_mediaContext->nb_streams; ++i) {
		enc = _mediaContext->streams[i]->codec;
		if (enc->codec_type == AVMEDIA_TYPE_AUDIO && enc->codec_descriptor) {
			[audioChannels addObject:@{@"channel" : [NSNumber numberWithInt:i],
									   @"codec" : [NSString stringWithFormat:@"%s, %d channels", enc->codec_descriptor->long_name, enc->channels]}];
		} else if (enc->codec_type == AVMEDIA_TYPE_VIDEO) {
			if (_videoIndex < 0 && [_videoDecoder openWithContext:enc]) {
				_videoIndex = i;
			}
		}
	}
	
	return (_videoIndex >= 0);
}

- (BOOL)play:(int)audioCahnnel
{
	AVCodecContext* enc = _mediaContext->streams[audioCahnnel]->codec;
	if (![_audioDecoder openWithContext:enc]) {
		return NO;
	}
	
	self.audioIndex = audioCahnnel;
 
	self.stopped = NO;
	
	[_audioDecoder start];
	
	_threadState = [[NSConditionLock alloc] initWithCondition:ThreadStillWorking];
	av_read_play(_mediaContext);
	
	dispatch_async(_networkQueue, ^() {
		while (!self.stopped) {
			AVPacket nextPacket;
			if (av_read_frame(_mediaContext, &nextPacket) < 0) { // eof
				break;
			}
			
			std::unique_lock<std::mutex> lock(_audioMutex);

			if (nextPacket.stream_index == _audioIndex) {
				[_audioDecoder push:&nextPacket];
			} else if (nextPacket.stream_index == _videoIndex) {
				[_videoDecoder decodePacket:&nextPacket];
			} else {
				av_packet_unref(&nextPacket);
			}
		}
		[_threadState lock];
		[_threadState unlockWithCondition:ThreadIsDone];
	});
	return YES;
}

- (void)close
{
	if (self.stopped)
		return;
	self.stopped = YES;
	
	[_audioDecoder stop];
	[_audioDecoder close];
	[_videoDecoder close];
	
	[_threadState lockWhenCondition:ThreadIsDone];
	[_threadState unlock];
	
	avformat_close_input(&_mediaContext);
}

- (void)takeVideo {
	
	if (self.buffering || _audioDecoder.currentTime < 0) {
		return;
	} else {
		AVFrame* frame = [_videoDecoder take];//[_videoDecoder takeWithTime:_audioDecoder.currentTime];
		if (frame != nil) {
			if (_textureCreated) {
				texture->update(frame);
			} else {
				_textureCreated = true;
				texture->create(frame);
			}
			av_frame_free(&frame);
		}
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
