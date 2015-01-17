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

#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavformat/avio.h"
#include "libavfilter/avfilter.h"

enum {
	ThreadStillWorking,
	ThreadIsDone
};

@interface VideoViewController ()

@property (strong, nonatomic) Decoder* audioDecoder;
@property (strong, nonatomic) Decoder* videoDecoder;
@property (nonatomic) int audioIndex;
@property (nonatomic) int videoIndex;

@property (readwrite, atomic) AVFormatContext*	mediaContext;
@property (readwrite, atomic) BOOL mediaRunning;
@property (strong, nonatomic) NSConditionLock *demuxerState;

@end

@implementation VideoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.title = [_node.info title] ? _node.info.title : _node.name;
	
	_audioDecoder = [[Decoder alloc] init];
	_videoDecoder = [[Decoder alloc] init];
	
	[MBProgressHUD showHUDAddedTo:self.view animated:YES];
	
	NSRange p = [_node.path rangeOfString:@"smb://"];
	NSRange r = {p.length, _node.path.length - p.length};
	NSRange s = [_node.path rangeOfString:@"/" options:NSCaseInsensitiveSearch range:r];
	NSRange ss = {p.length, s.location - p.length};
	NSString* server = [_node.path substringWithRange:ss];
	NSRange pp = {s.location, _node.path.length - s.location};
	NSString *path = [_node.path substringWithRange:pp];

	NSDictionary* auth = [DataModel authForHost:server];
	if (auth) {
		NSString* url = [NSString stringWithFormat:@"smb://%@:%@@%@%@",
						 [auth objectForKey:@"user"],
						 [auth objectForKey:@"password"],
						 server, path];
		[self performSelectorInBackground:@selector(openMedia:) withObject:url];
	}
}

- (void)dealloc
{
	[self closeMedia];
}

- (AVFormatContext*)loadMedia:(NSString*)url
{
	NSLog(@"open %@", url);
	AVFormatContext* mediaContext = 0;
	
	int err = avformat_open_input(&mediaContext, [url UTF8String], NULL, NULL);
	if ( err != 0) {
		char buf[255];
		av_strerror(err, buf, 255);
		printf("%s\n", buf);
		return 0;
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
			} else if (nextPacket.stream_index == _videoIndex) {
				NSLog(@"video");
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
		[_demuxerState lockWhenCondition:ThreadIsDone];
		[_demuxerState unlock];
	} else {
		return;
	}
}

@end
