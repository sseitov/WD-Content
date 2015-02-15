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
#include <mutex>

#define IS_PAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

enum {
	LayerStillWorking,
	LayerIsDone
};

@interface VideoViewController () <DemuxerDelegate> {
	dispatch_queue_t _videoOutputQueue;
	std::mutex		_mutex;
}

@property (weak, nonatomic) IBOutlet UIToolbar *topBar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *titleItem;
@property (weak, nonatomic) IBOutlet UIView *screen;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topBarSpace;
@property (weak, nonatomic) IBOutlet UISlider *timeLine;

@property (nonatomic) BOOL barsHidden;
@property (nonatomic) BOOL doAnimation;

@property (strong, nonatomic) Demuxer* demuxer;

@property (strong, nonatomic) AVSampleBufferDisplayLayer *videoOutput;
@property (strong, nonatomic) NSConditionLock *layerState;
@property (atomic) BOOL stopped;

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
	[_demuxer openWithPath:_node.path completion:^(NSArray* audioChannels) {
		dispatch_async(dispatch_get_main_queue(), ^() {
			[MBProgressHUD hideHUDForView:self.view animated:YES];
			if (!audioChannels) {
				[self errorOpen];
			} else {
				if (audioChannels.count > 1) {
					UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"What do you want?"
																							 message:@""
																					  preferredStyle:UIAlertControllerStyleActionSheet];
					for (NSDictionary *channel in audioChannels) {
						UIAlertAction *action = [UIAlertAction actionWithTitle:[channel objectForKey:@"codec"]
																		 style:UIAlertActionStyleDefault
																	   handler:^(UIAlertAction *action) {
																		   [self play:[[channel objectForKey:@"channel"] intValue]];
																	   }];
						[alertController addAction:action];
					}
					UIAlertAction *action = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
					[alertController addAction:action];
					
					if(IS_PAD) {
						UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:alertController];
						[popover presentPopoverFromBarButtonItem:_titleItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
					} else {
						[self presentViewController:alertController animated:YES completion:nil];
					}
				} else {
					[self play:[[[audioChannels objectAtIndex:0] objectForKey:@"channel"] intValue]];
				}
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
		} else {
			_topBarSpace.constant = -64;
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

- (void)play:(int)audioChannel
{
	CMTimebaseRef tmBase = nil;
	CMTimebaseCreateWithMasterClock(CFAllocatorGetDefault(), CMClockGetHostTimeClock(),&tmBase);
	_videoOutput.controlTimebase = tmBase;
	CMTimebaseSetTime(_videoOutput.controlTimebase, kCMTimeZero);
	CMTimebaseSetRate(_videoOutput.controlTimebase, 1.0/av_q2d(_demuxer.timeBase));
	
	[_demuxer play:audioChannel];
	
	self.stopped = NO;
	_layerState = [[NSConditionLock alloc] initWithCondition:LayerStillWorking];
	
	[_videoOutput requestMediaDataWhenReadyOnQueue:_videoOutputQueue usingBlock:^() {
		[_layerState lock];
		if (!self.stopped) {
			while (!self.stopped && _videoOutput.isReadyForMoreMediaData) {
				CMSampleBufferRef buffer = [_demuxer takeVideo];
				if (buffer) {
					[_videoOutput enqueueSampleBuffer:buffer];
					CFRelease(buffer);
				} else {
					break;
				}
			}
			[_layerState unlockWithCondition:LayerStillWorking];
		} else {
			[_layerState unlockWithCondition:LayerIsDone];
		}
	}];
}

- (void)stop
{
	self.stopped = YES;
	
	MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:self.view];
	[self.view addSubview:hud];
	[hud showAnimated:YES whileExecutingBlock:^{
		[_layerState lockWhenCondition:LayerIsDone];
		[_layerState unlock];
		[_videoOutput stopRequestingMediaData];
		[_demuxer close];
	} completionBlock:^{
		[hud removeFromSuperview];
	}];
}

- (IBAction)done:(id)sender
{
	[self stop];
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Demuxer delegate

- (void)demuxer:(Demuxer*)demuxer buffering:(BOOL)buffering
{
	dispatch_async(dispatch_get_main_queue(), ^() {
		if (buffering) {
			[MBProgressHUD showHUDAddedTo:self.view animated:YES];
		} else {
			[MBProgressHUD hideHUDForView:self.view animated:YES];
		}
	});
}

- (void)demuxerDidStopped:(Demuxer *)demuxer
{
	NSLog(@"demuxer finished");
}

@end
