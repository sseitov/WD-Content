//
//  VideoViewController.m
//  WD Content
//
//  Created by Sergey Seitov on 12.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VideoViewController.h"

#import "Demuxer.h"
#import "MBProgressHUD.h"

#import <CoreMedia/CoreMedia.h>

extern "C" {
#	include "libavformat/avformat.h"
}

@interface VideoViewController () <DemuxerDelegate> {
	dispatch_queue_t _videoOutputQueue;
}

@property (weak, nonatomic) IBOutlet UIToolbar *topBar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *titleItem;
@property (weak, nonatomic) IBOutlet UIView *screen;
@property (weak, nonatomic) IBOutlet UIToolbar *bottomBar;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topBarSpace;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomBarSpace;

@property (nonatomic) BOOL barsHidden;
@property (nonatomic) BOOL doAnimation;

@property (strong, nonatomic) Demuxer* demuxer;

@property (strong, nonatomic) AVSampleBufferDisplayLayer *videoOutput;

- (IBAction)done:(id)sender;

@end

@implementation VideoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	_titleItem.title = [_node.info title] ? _node.info.title : _node.name;

	_videoOutputQueue = dispatch_queue_create("com.vchannel.WD-Content.VideoOutput", DISPATCH_QUEUE_SERIAL);
	
	_videoOutput = [[AVSampleBufferDisplayLayer alloc] init];
	_videoOutput.videoGravity = AVLayerVideoGravityResizeAspect;
	_videoOutput.backgroundColor = [[UIColor blackColor] CGColor];
	
	_demuxer = [[Demuxer alloc] init];
	_demuxer.delegate = self;
	
	[MBProgressHUD showHUDAddedTo:self.view animated:YES];
	[_demuxer openWithPath:_node.path completion:^(BOOL success) {
		dispatch_async(dispatch_get_main_queue(), ^() {
			[MBProgressHUD hideHUDForView:self.view animated:YES];
			if (!success) {
				[self errorOpen];
			} else {
				CMTimebaseRef tmBase = nil;
				CMTimebaseCreateWithMasterClock(CFAllocatorGetDefault(), CMClockGetHostTimeClock(),&tmBase);
				_videoOutput.controlTimebase = tmBase;
				CMTimebaseSetTime(_videoOutput.controlTimebase, kCMTimeZero);
				AVCodecContext* context = [_demuxer videoContext];
				CMTimebaseSetRate(_videoOutput.controlTimebase, context->time_base.den);
				
				[self play];
			}
		});
	}];
	UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOnScreen:)];
	[_screen addGestureRecognizer:tap];
	_doAnimation = YES;
	[self performSelector:@selector(showBars) withObject:nil afterDelay:2.0];
}

- (void)tapOnScreen:(UITapGestureRecognizer *)tap
{
	if (!_doAnimation) {
		[self showBars];
	}
}

- (void)showBars
{
	_doAnimation = YES;
	[UIView animateWithDuration:0.2 animations:^(){
		if (_barsHidden) {
			_topBarSpace.constant = 0;
			_bottomBarSpace.constant = 0;
		} else {
			_topBarSpace.constant = -64;
			_bottomBarSpace.constant = -44;
		}
		[self.view layoutIfNeeded];
	} completion:^(BOOL) {
		_doAnimation = NO;
		_barsHidden = !_barsHidden;
		[self layoutScreen];
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
	[_videoOutput removeFromSuperlayer];
	_videoOutput.bounds = _screen.bounds;
	_videoOutput.position = CGPointMake(CGRectGetMidX(_screen.bounds), CGRectGetMidY(_screen.bounds));
	[_screen.layer addSublayer:_videoOutput];
}

- (void)viewDidAppear:(BOOL)animated
{
	[self layoutScreen];
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self layoutScreen];
}

- (void)play
{
	[_demuxer play];

	[_videoOutput requestMediaDataWhenReadyOnQueue:_videoOutputQueue usingBlock:^() {
		while (_videoOutput && _videoOutput.isReadyForMoreMediaData) {
			CMSampleBufferRef buffer = [_demuxer takeVideo];
			if (buffer) {
				[_videoOutput enqueueSampleBuffer:buffer];
				CFRelease(buffer);
			} else {
				break;
			}
		}
	}];
}

- (void)stop
{
	[_videoOutput stopRequestingMediaData];
	[_demuxer close];
}

- (IBAction)done:(id)sender
{
	[self stop];
	[_demuxer close];
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didStopped:(Demuxer *)demuxer
{
	NSLog(@"demuxer finished");
}

@end
