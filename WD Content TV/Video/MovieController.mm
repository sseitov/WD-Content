//
//  MovieController.m
//  WD Content
//
//  Created by Сергей Сейтов on 21.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

#import "MovieController.h"
#import "AudioOutput.h"
#import "VideoOutput.h"
#include "SynchroQueue.h"
#import "Util.h"
#import "SMBConnection.h"
#include <SVProgressHUD.h>

enum {
	DecoderStillWorking,
	DecoderIsFlashed
};

#define VIDEO_QUEUE_SIZE	SCREEN_POOL_SIZE*4
#define AUDIO_QUEUE_SIZE	AUDIO_POOL_SIZE*4
#define AUDIO_TRICKS		1

enum {
	ThreadStillWorking,
	ThreadIsDone
};

class PacketQueue : public SynchroQueue<AVPacket> {
private:
	int _maxSize;
	
public:
	PacketQueue(int maxSize) : _maxSize(maxSize) {}
	
	virtual void free(AVPacket* packet)
	{
		av_packet_unref(packet);
	}
	
	virtual bool push(AVPacket* packet)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		if (_stopped) {
			return false;
		} else {
			_queue.push(*packet);
			_empty.notify_one();
			return true;
		}
	}
	
	virtual void flush(int64_t pts = AV_NOPTS_VALUE)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		while (!_queue.empty()) {
			AVPacket pkt = _queue.front();
			if (pts == AV_NOPTS_VALUE || pkt.pts < pts) {
				free(&pkt);
				_queue.pop();
			} else
				break;
		}
		_empty.notify_one();
	}
};

@interface MovieController () <AudioOutputDelegate> {
	PacketQueue*		_videoQueue;
	PacketQueue*		_audioQueue;
	
	dispatch_queue_t	_networkQueue;
	unsigned char*		_ioBuffer;
	AVIOContext*		_ioContext;
	AVFormatContext*	_mediaContext;
}

@property (strong, nonatomic, readonly) SMBConnection* connection;
@property (nonatomic, readonly) smb_fd file;

@property (nonatomic) int		videoIndex;
@property (atomic) VideoOutput*	screen;

@property (nonatomic) int		audioIndex;
@property (atomic) AudioOutput*	audio;

@property (strong, nonatomic)	NSConditionLock *audioDecoderState;
@property (strong, nonatomic)	NSConditionLock *videoDecoderState;

@property (readwrite, atomic)	int64_t latestVideoPTS;

@property (strong, nonatomic) NSConditionLock *threadState;
@property (atomic) BOOL stopped;
@property (strong, nonatomic) NSCondition *pause;
@property (atomic) BOOL paused;

@end

static const int kMaxQueuesSize = 256;
static const int kBufferSize = 4 * 1024;

extern "C" {
	
	static int readContext(void *opaque, unsigned char *buf, int buf_size) {
		MovieController* demuxer = (__bridge MovieController *)(opaque);
		return [demuxer.connection readFile:demuxer.file buffer:buf size:buf_size];
	}
	
	static int64_t seekContext(void *opaque, int64_t offset, int whence) {
		MovieController* demuxer = (__bridge MovieController *)(opaque);
		return [demuxer.connection seekFile:demuxer.file offset:offset whence:whence];
	}
}

@implementation MovieController

- (void)viewDidLoad {
    [super viewDidLoad];
	
	av_register_all();
	avcodec_register_all();
	int ret = avformat_network_init();
	NSLog(@"avformat_network_init = %d", ret);
	
	_audio = [[AudioOutput alloc] init];
	_audio.delegate = self;
	
	_screen = [[VideoOutput alloc] initWithDelegate:self];
	[self addChildViewController: _screen];
	_screen.view.frame = self.view.bounds;
	[self.view addSubview:_screen.view];
	[_screen didMoveToParentViewController:self];
	
	_videoQueue = new PacketQueue(VIDEO_QUEUE_SIZE);
	_audioQueue = new PacketQueue(AUDIO_QUEUE_SIZE);
	
	_connection = [[SMBConnection alloc] init];
	_networkQueue = dispatch_queue_create("com.vchannel.WD-Content.SMBNetwork", DISPATCH_QUEUE_SERIAL);
	_ioBuffer = new unsigned char[kBufferSize];
	_ioContext = avio_alloc_context((unsigned char*)_ioBuffer, kBufferSize, 0, (__bridge void*)self, readContext, NULL, seekContext);
	
	_pause = [[NSCondition alloc] init];
}

- (void)viewDidAppear:(BOOL)animated {
	
	[super viewDidAppear:animated];
	dispatch_queue_t queue = dispatch_queue_create("com.vchannel.WD-Content.Movie", DISPATCH_QUEUE_SERIAL);
	[SVProgressHUD showWithStatus:@"Load..."];
	dispatch_async(queue, ^{
		NSMutableArray* audioChannels = [NSMutableArray array];
		bool success = [self load:_host port:_port user:_user password:_password file:_filePath audioChannels:audioChannels];
		dispatch_async(dispatch_get_main_queue(), ^{
			[SVProgressHUD dismiss];
			if (success) {
				if (audioChannels.count > 1) {
					UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
																				   message:@"Choose audio channel"
																			preferredStyle:UIAlertControllerStyleActionSheet];
					for (NSDictionary *channel in audioChannels) {
						UIAlertAction *action = [UIAlertAction actionWithTitle:[channel objectForKey:@"codec"]
																		 style:UIAlertActionStyleDefault
																	   handler:^(UIAlertAction *action) {
																		   int num = [[channel objectForKey:@"channel"] intValue];
																		   [self play:num];
																	   }];
						[alert addAction:action];
					}
					UIAlertAction *action = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
						[self.navigationController popViewControllerAnimated:true];
					}];
					[alert addAction:action];
					[self presentViewController:alert animated:YES completion:nil];
				} else if (audioChannels.count == 1) {
					NSDictionary* audio = [audioChannels objectAtIndex:0];
					int channel = [[audio objectForKey:@"channel"] intValue];
					[self play: channel];
				} else {
					UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
																				   message:@"Can not play this file."
																			preferredStyle:UIAlertControllerStyleActionSheet];
					UIAlertAction *action = [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
						[self.navigationController popViewControllerAnimated:true];
					}];
					[alert addAction:action];
					[self presentViewController:alert animated:YES completion:nil];
				}
			} else {
				UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
																			   message:@"Can not load file."
																		preferredStyle:UIAlertControllerStyleActionSheet];
				UIAlertAction *action = [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
					[self.navigationController popViewControllerAnimated:true];
				}];
				[alert addAction:action];
				[self presentViewController:alert animated:YES completion:nil];
			}
		});
	});
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
	if (presses.anyObject.type == UIPressTypeMenu) {
		[self close];
	}
	[super pressesBegan:presses withEvent:event];
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
			if ([_screen.decoder openWithContext:enc]) {
				_videoIndex = i;
			}
		}
	}
	return (_videoIndex >= 0);
}

- (BOOL)play:(int)audioCahnnel
{
	AVCodecContext* enc = _mediaContext->streams[audioCahnnel]->codec;
	if (![_audio.decoder openWithContext:enc]) {
		return NO;
	}
	
	self.audioIndex = audioCahnnel;
 
	self.stopped = NO;
	
	[self start];
	
	_threadState = [[NSConditionLock alloc] initWithCondition:ThreadStillWorking];
	av_read_play(_mediaContext);
	
	dispatch_async(_networkQueue, ^() {
		while (!self.stopped) {
			[self checkQueues];
			AVPacket nextPacket;
			if (av_read_frame(_mediaContext, &nextPacket) < 0) { // eof
				break;
			}
			[self pushPacket:&nextPacket withFlush:false];
		}
		[_threadState lock];
		[_threadState unlockWithCondition:ThreadIsDone];
	});
	return YES;
}

- (void)videoDecodeThread
{
	@autoreleasepool {
		[[NSThread currentThread] setThreadPriority:0.8];
		[[NSThread currentThread] setName:[NSString stringWithFormat:@"video-thread-Renderer:%@", self]];
		AVPacket packet;
		_videoDecoderState = [[NSConditionLock alloc] initWithCondition:DecoderStillWorking];
		while (_videoQueue->pop(&packet)) {
			if (_screen.lateFrameCounter > 25) {
				av_packet_unref(&packet);
				int counter = 0;
				while (_videoQueue->pop(&packet)) {
					++counter;
					if (packet.flags & AV_PKT_FLAG_KEY) {
						NSLog(@"Skip %d frames", counter);
						break;
					}
					av_packet_unref(&packet);
				}
				_screen.lateFrameCounter = 0;
			}
			[_screen pushPacket:&packet];
			av_packet_unref(&packet);
			[self checkQueues];
		}
		[_videoDecoderState lock];
		[_videoDecoderState unlockWithCondition:DecoderIsFlashed];
	}
}

- (void)audioDecodeThread
{
	@autoreleasepool {
		[[NSThread currentThread] setThreadPriority:1.0];
		[[NSThread currentThread] setName:[NSString stringWithFormat:@"audio-thread-Renderer:%@", self]];
		AVPacket packet;
		_audioDecoderState = [[NSConditionLock alloc] initWithCondition:DecoderStillWorking];
		while (_audioQueue->pop(&packet)) {
			[_audio pushPacket:&packet];
			av_packet_unref(&packet);
		}
		[_audioDecoderState lock];
		[_audioDecoderState unlockWithCondition:DecoderIsFlashed];
	}
}

- (void)start
{
	_audioQueue->start();
	[NSThread detachNewThreadSelector:@selector(audioDecodeThread) toTarget:self withObject:nil];
	
	_videoQueue->start();
	[NSThread detachNewThreadSelector:@selector(videoDecodeThread) toTarget:self withObject:nil];
}

- (void)stop
{
	////////////////////////////////
	// finish video
	NSLog(@"stop video");
	_videoQueue->stop();
	[_screen flush:AV_NOPTS_VALUE];
	[_videoDecoderState lockWhenCondition:DecoderIsFlashed];
	[_videoDecoderState unlock];
	
	[_screen stop];
	_videoIndex = -1;
	NSLog(@"video stopped");
	
	////////////////////////////////
	// finish audio
	NSLog(@"stop audio");
	_audioQueue->stop();
	[_audio reset];
	[_audioDecoderState lockWhenCondition:DecoderIsFlashed];
	[_audioDecoderState unlock];
	
	[_audio stop];
	_audioIndex = -1;
	
	[_screen close];
	NSLog(@"RENDERER STOPPED");
}

- (void)close {
	if (self.stopped)
		return;
	
	[self stop];
	
	self.stopped = YES;
	if (!_paused) {
		[_pause lock];
		[_pause signal];
		[_pause unlock];
	}
	
	[_threadState lockWhenCondition:ThreadIsDone];
	[_threadState unlock];
	
	avformat_close_input(&_mediaContext);
	
	if (_file)
		[_connection closeFile:_file];
	[_connection disconnect];
	if (_mediaContext)
		avformat_close_input(&_mediaContext);	// AVFormatContext is released by avformat_close_input
	if (_ioContext)
		av_free(_ioContext);					// AVIOContext is released by av_free
}

- (void)checkQueues {
	if (!_paused) {
		_paused = _videoQueue->size() > kMaxQueuesSize;
		if (_paused) {
			[_pause lock];
			[_pause wait];
			_paused = false;
			[_pause unlock];
		}
	} else {
		_paused = _videoQueue->size() > kMaxQueuesSize;
		if (!_paused) {
			[_pause lock];
			[_pause signal];
			[_pause unlock];
		}
	}
}

- (void)pushPacket:(AVPacket*)packet withFlush:(BOOL)flush
{
	static bool wasFlush = false;
	static int64_t flushAudioTo = AV_NOPTS_VALUE;
	if (packet->stream_index == _videoIndex) {
		if (flush) {
			_videoQueue->flush(packet->pts);
			[_screen flush:packet->pts];
#ifdef AUDIO_TRICKS
			flushAudioTo = [_audio shiftTo:packet->pts];
			_audioQueue->flush(AV_NOPTS_VALUE);
#endif
			wasFlush = true;
		}
		if (!_videoQueue->push(packet)) {
			av_packet_unref(packet);
		} else {
			self.latestVideoPTS = packet->pts;
		}
	} else if (packet->stream_index == _audioIndex) {
#ifdef AUDIO_TRICKS
		if (flushAudioTo == AV_NOPTS_VALUE || packet->pts > flushAudioTo) {
			if (!_audioQueue->push(packet)) {
				free(packet->data);
			}
		}
#else
		if (wasFlush) {
			_audioQueue->flush(packet->pts);
			[_audio flush:packet->pts];
			wasFlush = false;
		}
		if (!_audioQueue->push(packet)) {
			free(packet->data);
		}
#endif
	} else {
		av_packet_unref(packet);
	}
}

- (int64_t)bufferLength
{
	return self.latestVideoPTS - _audio.currentPTS;
}

- (CGSize)videoSize
{
	return [_screen videoSize];
}

- (int)undecodedVideoQueueSize
{
	return _videoQueue->size();
}

- (int)decodedVideoQueueSize
{
	return [_screen decodedPacketCount];
}

- (int)audioQueueSize
{
	return (_audioQueue->size() + [_audio decodedPacketCount]);
}

#pragma mark - AudioOutput delegate methods

- (void)audioOutput:(AudioOutput *)audioOutput encounteredError:(NSError *)error
{
}

#pragma mark - GLKViewController delegate methods

- (void)glkViewControllerUpdate:(GLKViewController *)controller
{
	int64_t currasp, currast;
	
	[_audio currentPTS:&currasp withTime:&currast];
	if (currasp == AV_NOPTS_VALUE)
		return;
	int updated = 0;
	int64_t pts  = [_screen updateWithPTS:currasp updated:&updated];
	if (pts == AV_NOPTS_VALUE || updated == 0)
		return;
}

@end
