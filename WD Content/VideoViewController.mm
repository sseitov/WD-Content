//
//  VideoViewController.m
//  WD Content
//
//  Created by Sergey Seitov on 12.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VideoViewController.h"
#import "MBProgressHUD.h"
#import "Decoder.h"
#import <AVFoundation/AVFoundation.h>
#include "SynchroQueue.h"
#import "VTDecoder.h"
#import "AudioDecoder.h"
#import "AudioOutput.h"

extern "C" {
#	include "libavcodec/avcodec.h"
#	include "libavformat/avformat.h"
#	include "libavformat/avio.h"
#	include "libavfilter/avfilter.h"
};

enum {
	ThreadStillWorking,
	ThreadIsDone
};

@interface VideoViewController () <VTDecoderDelegate> {
	SynchroQueue<CMSampleBufferRef>	_videoQueue;
	SynchroQueue<AVPacket>	_videoDecoderQueue;
	SynchroQueue<AVPacket>	*_audioDecoderQueue;
	dispatch_queue_t _videoOutputQueue;
}

@property (strong, nonatomic) VTDecoder *videoDecoder;

@property (nonatomic) int audioIndex;
@property (nonatomic) int videoIndex;

@property (readwrite, atomic) AVFormatContext*	mediaContext;
@property (readwrite, atomic) BOOL mediaRunning;
@property (strong, nonatomic) NSConditionLock *demuxerState;

@property (strong, nonatomic) AVSampleBufferDisplayLayer *videoLayer;
@property (strong, nonatomic) AudioOutput *audioOutput;

- (IBAction)done:(id)sender;

@end

@implementation VideoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.title = [_node.info title] ? _node.info.title : _node.name;
	
	_audioOutput = [[AudioOutput alloc] init];
	_audioDecoderQueue = new SynchroQueue<AVPacket>(128);
	
	_videoDecoder = [[VTDecoder alloc] init];
	_videoDecoder.delegate = self;
	
	_videoLayer = [[AVSampleBufferDisplayLayer alloc] init];
	_videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
	_videoLayer.backgroundColor = [[UIColor blackColor] CGColor];
	[self layoutScreen];
	
	_videoOutputQueue = dispatch_queue_create("com.vchannel.WD-Content", DISPATCH_QUEUE_SERIAL);

	[MBProgressHUD showHUDAddedTo:self.view animated:YES];
	[self performSelectorInBackground:@selector(openMedia:) withObject:[self mediaSmbPath]];
}

- (void)dealloc
{
	[self closeMedia];
}

- (void)layoutScreen
{
	[_videoLayer removeFromSuperlayer];
	_videoLayer.bounds = self.view.bounds;
	_videoLayer.position = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
	[self.view.layer addSublayer:_videoLayer];
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self layoutScreen];
}

- (NSString*)mediaSmbPath
{
	NSRange p = [_node.path rangeOfString:@"smb://"];
	NSRange r = {p.length, _node.path.length - p.length};
	NSRange s = [_node.path rangeOfString:@"/" options:NSCaseInsensitiveSearch range:r];
	NSRange ss = {p.length, s.location - p.length};
	NSString* server = [_node.path substringWithRange:ss];
	NSRange pp = {s.location, _node.path.length - s.location};
	NSString *path = [_node.path substringWithRange:pp];
	
	NSDictionary* auth = [DataModel authForHost:server];
	if (auth) {
		return [NSString stringWithFormat:@"smb://%@:%@@%@%@",
				[auth objectForKey:@"user"],
				[auth objectForKey:@"password"],
				server, path];
	} else {
		return nil;
	}
}

- (AVFormatContext*)loadMedia:(NSString*)url
{
	NSLog(@"open %@", url);
	AVFormatContext* mediaContext = 0;
	
	int err = avformat_open_input(&mediaContext, [url UTF8String], NULL, NULL);
	if ( err != 0) {
		return NULL;
	}
	
	// Retrieve stream information
	avformat_find_stream_info(mediaContext, NULL);
	
	AVCodecContext* enc;
	for (unsigned i=0; i<mediaContext->nb_streams; ++i) {
		enc = mediaContext->streams[i]->codec;
		if (enc->codec_type == AVMEDIA_TYPE_AUDIO) {
			if ([_audioOutput.decoder openWithContext:enc]) {
				_audioIndex = i;
			} else {
				return 0;
			}
		} else if (enc->codec_type == AVMEDIA_TYPE_VIDEO) {
			if ([_videoDecoder openWithContext:enc]) {
				_videoIndex = i;
			} else {
				return 0;
			}
		}
	}
	
	return mediaContext;
}

- (void)errorOpen
{
	[MBProgressHUD hideHUDForView:self.view animated:YES];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
													message:@"Error open movie"
												   delegate:nil
										  cancelButtonTitle:@"Ok"
										  otherButtonTitles:nil];
	[alert show];
}

- (void)decoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
	if (self.mediaRunning) {
		_videoQueue.push(&buffer);
	}
}

- (void)openMedia:(NSString*)url
{
	@autoreleasepool {
		_mediaContext = [self loadMedia:url];
		if (!_mediaContext) {
			[self performSelectorOnMainThread:@selector(errorOpen) withObject:nil waitUntilDone:YES];
			return;
		}
		
		dispatch_async(dispatch_get_main_queue(), ^()
					   {
						   [MBProgressHUD hideHUDForView:self.view animated:YES];
					   });
		av_read_play(_mediaContext);
		
		_demuxerState = [[NSConditionLock alloc] initWithCondition:ThreadStillWorking];
		_mediaRunning = YES;
		
		[_videoLayer requestMediaDataWhenReadyOnQueue:_videoOutputQueue usingBlock:^() {
			CMSampleBufferRef buffer;
			if (self.mediaRunning && _videoQueue.pop(&buffer)) {
				NSLog(@"enqueue video %d", _videoQueue.size());
				[_videoLayer enqueueSampleBuffer:buffer];
				CFRelease(buffer);
			} else {
				[_videoLayer stopRequestingMediaData];
			}
		}];

		dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			AVPacket nextPacket;
			while (self.mediaRunning && _audioDecoderQueue->pop(&nextPacket)) {
//				NSLog(@"enqueue audio %d", _audioDecoderQueue->size());
				[_audioOutput pushPacket:&nextPacket];
				av_free_packet(&nextPacket);
			}
		});
		
		dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			AVPacket nextPacket;
			while (self.mediaRunning && _videoDecoderQueue.pop(&nextPacket)) {
				[_videoDecoder decodePacket:&nextPacket toFrame:NULL];
				av_free_packet(&nextPacket);
			}
		});

		while (self.mediaRunning) {
			AVPacket nextPacket;
			if (av_read_frame(_mediaContext, &nextPacket) < 0) { // eof
				av_free_packet(&nextPacket);
				break;
			}
			
			if (nextPacket.stream_index == _audioIndex) {
//				_audioDecoderQueue->push(&nextPacket);
				av_free_packet(&nextPacket);
			} else if (nextPacket.stream_index == _videoIndex) {
				_videoDecoderQueue.push(&nextPacket);
			}
		}
		
		avformat_close_input(&_mediaContext);
		_mediaContext = 0;
		[_demuxerState lock];
		[_demuxerState unlockWithCondition:ThreadIsDone];
	}
}

- (void)closeMedia
{
	if (self.mediaRunning) {
		self.mediaRunning = NO;

		_audioDecoderQueue->stop();
		[_audioOutput stop];
		delete _audioDecoderQueue;
		
		_videoDecoderQueue.stop();
		_videoQueue.stop();
		
		[_demuxerState lockWhenCondition:ThreadIsDone];
		[_demuxerState unlock];
	} else {
		return;
	}
}

- (IBAction)done:(id)sender
{
	[self closeMedia];
	[self dismissViewControllerAnimated:YES completion:nil];
}

@end
