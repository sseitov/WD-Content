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
}

@property (strong, nonatomic) AudioDecoder *audioDecoder;
@property (strong, nonatomic) VTDecoder *videoDecoder;

@property (nonatomic) int audioIndex;
@property (nonatomic) int videoIndex;

@property (readwrite, atomic) AVFormatContext*	mediaContext;
@property (readwrite, atomic) BOOL mediaRunning;
@property (strong, nonatomic) NSConditionLock *demuxerState;

@property (strong, nonatomic) AVSampleBufferDisplayLayer *videoLayer;

- (IBAction)done:(id)sender;

@end

@implementation VideoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.title = [_node.info title] ? _node.info.title : _node.name;
	
	_audioDecoder = [[AudioDecoder alloc] init];
	_videoDecoder = [[VTDecoder alloc] init];
	_videoDecoder.delegate = self;
	
	_videoLayer = [[AVSampleBufferDisplayLayer alloc] init];
	_videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
	_videoLayer.backgroundColor = [[UIColor blackColor] CGColor];
	[self layoutScreen];

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
			if ([_audioDecoder openWithContext:enc]) {
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
													message:@"Error open TV channel"
												   delegate:nil
										  cancelButtonTitle:@"Ok"
										  otherButtonTitles:nil];
	[alert show];
}

- (void)decoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
	_videoQueue.push(&buffer);
}

- (void)refreshScreen
{
	while (true) {
		CMSampleBufferRef buffer;
		if (_videoQueue.pop(&buffer)) {
			NSLog(@"enqueue video");
			[_videoLayer enqueueSampleBuffer:buffer];
			CFRelease(buffer);
			usleep(40);
		} else {
			break;
		}
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
		_videoQueue.start();
		
		[self performSelectorInBackground:@selector(refreshScreen) withObject:nil];
		
		NSLog(@"media opened");
		while (_mediaRunning) {
			AVPacket nextPacket;
			// Read packet
			if (av_read_frame(_mediaContext, &nextPacket) < 0) { // eof
				av_free_packet(&nextPacket);
				break;
			}
			
			// Duplicate current packet
			if (av_dup_packet(&nextPacket) < 0) {	// error packet
				continue;
			}
			
			if (nextPacket.stream_index == _audioIndex) {
				NSLog(@"audio");
				AVFrame* frame = av_frame_alloc();
				[_audioDecoder decodePacket:&nextPacket toFrame:frame];
				av_free(frame);
			} else if (nextPacket.stream_index == _videoIndex) {
				[_videoDecoder decodePacket:&nextPacket toFrame:NULL];
			}
			av_free_packet(&nextPacket);
		}
		
		avformat_close_input(&_mediaContext);
		_mediaContext = 0;
		[_demuxerState lock];
		[_demuxerState unlockWithCondition:ThreadIsDone];
	}
}

- (void)closeMedia
{
	if (_mediaRunning) {
		_mediaRunning = NO;
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
