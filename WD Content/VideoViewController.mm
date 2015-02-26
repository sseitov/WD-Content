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
	dispatch_semaphore_t _videoSemaphore;
}

- (IBAction)chooseAudio:(id)sender;

@property (nonatomic) BOOL barsHidden;

@property (strong, nonatomic) Demuxer* demuxer;

@property (strong, nonatomic) AVSampleBufferDisplayLayer *videoOutput;
@property (atomic) BOOL stopped;
@property (strong, nonatomic) NSArray* audioChannels;

- (IBAction)done:(id)sender;

@end

@implementation VideoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.title = [_node.info title] ? _node.info.title : _node.name;
	self.stopped = YES;
	
	_videoOutputQueue = dispatch_queue_create("com.vchannel.WD-Content.VideoOutput", DISPATCH_QUEUE_SERIAL);
	
	_videoOutput = [[AVSampleBufferDisplayLayer alloc] init];
	_videoOutput.videoGravity = AVLayerVideoGravityResizeAspect;
	_videoOutput.backgroundColor = [[UIColor blackColor] CGColor];
	
	CMTimebaseRef tmBase = nil;
	CMTimebaseCreateWithMasterClock(CFAllocatorGetDefault(), CMClockGetHostTimeClock(),&tmBase);
	_videoOutput.controlTimebase = tmBase;
	CMTimebaseSetTime(_videoOutput.controlTimebase, kCMTimeZero);
	CMTimebaseSetRate(_videoOutput.controlTimebase, 25.0);

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
					_audioChannels = audioChannels;
					UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Choose audio channel"
																							 message:@""
																					  preferredStyle:UIAlertControllerStyleActionSheet];
					for (NSDictionary *channel in _audioChannels) {
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
						[popover presentPopoverFromBarButtonItem:self.navigationItem.rightBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
					} else {
						[self presentViewController:alertController animated:YES completion:nil];
					}
				} else {
					[self.navigationItem setRightBarButtonItem:nil animated:YES];
					[self play:[[[audioChannels objectAtIndex:0] objectForKey:@"channel"] intValue]];
				}
			}
		});
	}];
	UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOnScreen:)];
	[self.view addGestureRecognizer:tap];
}

- (void)tapOnScreen:(UITapGestureRecognizer *)tap
{
	_barsHidden = !_barsHidden;
	[self.navigationController setNavigationBarHidden:_barsHidden animated:YES];
	[self layoutScreen];
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

- (void)errorChange
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
													message:@"Error change audio format"
												   delegate:self
										  cancelButtonTitle:@"Ok"
										  otherButtonTitles:nil];
	[alert show];
}

- (void)layoutScreen
{
	[_videoOutput removeFromSuperlayer];
	_videoOutput.bounds = self.view.bounds;
	_videoOutput.position = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
	[self.view.layer addSublayer:_videoOutput];
}

- (void)viewDidAppear:(BOOL)animated
{
	[self layoutScreen];
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self layoutScreen];
}

- (IBAction)chooseAudio:(id)sender
{
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Choose audio channel"
																			 message:@""
																	  preferredStyle:UIAlertControllerStyleActionSheet];
	for (NSDictionary *channel in _audioChannels) {
		UIAlertAction *action = [UIAlertAction actionWithTitle:[channel objectForKey:@"codec"]
														 style:UIAlertActionStyleDefault
													   handler:^(UIAlertAction *action) {
														   if (![_demuxer changeAudio:[[channel objectForKey:@"channel"] intValue]]) {
															   [self errorChange];
														   }
													   }];
		[alertController addAction:action];
	}
	UIAlertAction *action = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
	[alertController addAction:action];
	
	if(IS_PAD) {
		UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:alertController];
		[popover presentPopoverFromBarButtonItem:self.navigationItem.rightBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	} else {
		[self presentViewController:alertController animated:YES completion:nil];
	}
}

- (void)play:(int)audioChannel
{
	if (![_demuxer play:audioChannel]) {
		[self errorOpen];
		return;
	}
	
	[self tapOnScreen:nil];

	_videoSemaphore = dispatch_semaphore_create(0);
	self.stopped = NO;
	
	[_videoOutput requestMediaDataWhenReadyOnQueue:_videoOutputQueue usingBlock:^() {
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
		}
		dispatch_semaphore_signal(_videoSemaphore);
	}];
}

- (void)stop
{
	if (self.stopped) return;
	
	self.stopped = YES;
	[_videoOutput stopRequestingMediaData];
	dispatch_semaphore_wait(_videoSemaphore, DISPATCH_TIME_FOREVER);
	
	[_videoOutput flushAndRemoveImage];
	[_demuxer close];
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
			MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:self.view];
			hud.removeFromSuperViewOnHide = YES;
			[self.view addSubview:hud];
			hud.labelText = @"Buffering...";
			[hud show:YES];
		} else {
			[MBProgressHUD hideHUDForView:self.view animated:YES];
		}
	});
}

@end
