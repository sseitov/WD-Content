//
//  VideoViewController.m
//  WD Content
//
//  Created by Sergey Seitov on 12.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VideoViewController.h"
#import "AudioOutput.h"

#import "Demuxer.h"
#import "MBProgressHUD.h"

#import "Decoder.h"
#include "SynchroQueue.h"

#import <CoreMedia/CoreMedia.h>

@interface VideoViewController () {
	dispatch_queue_t _videoOutputQueue;
}

@property (strong, nonatomic) Demuxer* demuxer;

@property (strong, nonatomic) AVSampleBufferDisplayLayer *videoLayer;

- (IBAction)done:(id)sender;

@end

@implementation VideoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.title = [_node.info title] ? _node.info.title : _node.name;
	
	_demuxer = [[Demuxer alloc] init];
	
	_videoLayer = [[AVSampleBufferDisplayLayer alloc] init];
	_videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
	_videoLayer.backgroundColor = [[UIColor blackColor] CGColor];
	
	CMTimebaseRef tmBase = nil;
	CMTimebaseCreateWithMasterClock(CFAllocatorGetDefault(), CMClockGetHostTimeClock(),&tmBase);
	_videoLayer.controlTimebase = tmBase;
	CMTimebaseSetTime(_videoLayer.controlTimebase, CMTimeMake(5, 1));
	CMTimebaseSetRate(_videoLayer.controlTimebase, 1.0);
	
	[self layoutScreen];
	
	_videoOutputQueue = dispatch_queue_create("com.vchannel.WD-Content.VideoOutput", DISPATCH_QUEUE_SERIAL);

	[MBProgressHUD showHUDAddedTo:self.view animated:YES];
	[_demuxer openWithPath:_node.path completion:^(BOOL success) {
		dispatch_async(dispatch_get_main_queue(), ^() {
			[MBProgressHUD hideHUDForView:self.view animated:YES];
			if (!success) {
				[self errorOpen];
			} else {
				[self play];
			}
		});
	}];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)errorOpen
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error open movie"
													message:@"Error reading or media format not supported"
												   delegate:self
										  cancelButtonTitle:@"Ok"
										  otherButtonTitles:nil];
	[alert show];
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

- (void)play
{
	[_demuxer play];
	[_videoLayer requestMediaDataWhenReadyOnQueue:_videoOutputQueue usingBlock:^() {
		while (_videoLayer.isReadyForMoreMediaData) {
			CMSampleBufferRef buffer = _demuxer.takeVideo;
			if (buffer) {
				[_videoLayer enqueueSampleBuffer:buffer];
				CFRelease(buffer);
			} else {
				break;
			}
		}
	}];
}

- (void)stop
{
	[_videoLayer stopRequestingMediaData];
	[_demuxer stop];
}

- (IBAction)done:(id)sender
{
	[self stop];
	[_demuxer close];
	[self dismissViewControllerAnimated:YES completion:nil];
}

@end
