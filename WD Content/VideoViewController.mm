//
//  VideoViewController.m
//  WD Content
//
//  Created by Sergey Seitov on 12.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VideoViewController.h"
#import "Demuxer.h"
#import "SVProgressHUD.h"
#import <CoreMedia/CoreMedia.h>

extern "C" {
#	include "libavformat/avformat.h"
}

#define IS_PAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

@interface VideoViewController () <DemuxerDelegate>

- (IBAction)chooseAudio:(id)sender;
- (IBAction)done:(id)sender;

@property (nonatomic) BOOL barsHidden;
@property (strong, nonatomic) Demuxer* demuxer;
@property (strong, nonatomic) AVSampleBufferDisplayLayer *videoOutput;
@property (atomic) BOOL stopped;
@property (strong, nonatomic) NSArray* audioChannels;

@end

@implementation VideoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.title = [_node.info title] ? _node.info.title : _node.name;
	self.stopped = YES;
	
	_videoOutput = [[AVSampleBufferDisplayLayer alloc] init];
	_videoOutput.videoGravity = AVLayerVideoGravityResizeAspect;
	_videoOutput.backgroundColor = [[UIColor blackColor] CGColor];
	CMTimebaseRef tmBase = nil;
	CMTimebaseCreateWithMasterClock(CFAllocatorGetDefault(), CMClockGetHostTimeClock(),&tmBase);
	_videoOutput.controlTimebase = tmBase;
	CMTimebaseSetTime(_videoOutput.controlTimebase, kCMTimeZero);
	CMTimebaseSetRate(_videoOutput.controlTimebase, 40.0);
	[self.view.layer addSublayer:_videoOutput];
	
	_demuxer = [[Demuxer alloc] init];
	_demuxer.delegate = self;

	[SVProgressHUD showWithStatus:@"Loading"];
	[_demuxer openWithPath:_node.path completion:^(NSArray* audioChannels) {
		dispatch_async(dispatch_get_main_queue(), ^() {
			[SVProgressHUD dismiss];
			if (!audioChannels) {
				[self errorOpen];
			} else {
				if (audioChannels.count > 1) {
					_audioChannels = audioChannels;
					UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
																							 message:@"Choose audio channel"
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
						[self presentViewController:alertController animated:YES completion:^{
							UIFont* font =  [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:17];
							[self.navigationItem.leftBarButtonItem setTitleTextAttributes:@{NSFontAttributeName:font} forState:UIControlStateNormal];
							[self.navigationItem.rightBarButtonItem setTitleTextAttributes:@{NSFontAttributeName:font} forState:UIControlStateNormal];
						}];
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

- (void)layoutScreen
{
	_videoOutput.bounds = self.view.bounds;
	_videoOutput.position = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
}

- (void)viewDidAppear:(BOOL)animated
{
	[self layoutScreen];
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self layoutScreen];
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

- (IBAction)chooseAudio:(id)sender
{
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
																			 message:@"Choose audio channel"
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
	UIFont* font =  [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:17];
	[self.navigationItem.leftBarButtonItem setTitleTextAttributes:@{NSFontAttributeName:font} forState:UIControlStateNormal];
	[self.navigationItem.rightBarButtonItem setTitleTextAttributes:@{NSFontAttributeName:font} forState:UIControlStateNormal];
	
	if (![_demuxer play:audioChannel]) {
		[self errorOpen];
		return;
	}
	
	[self tapOnScreen:nil];
	
	self.stopped = NO;
	[_videoOutput requestMediaDataWhenReadyOnQueue:dispatch_get_main_queue() usingBlock:^() {
		while (!self.stopped && _videoOutput.isReadyForMoreMediaData) {
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
	if (self.stopped) return;
	
	self.stopped = YES;
	[_videoOutput stopRequestingMediaData];
	
	[_videoOutput flushAndRemoveImage];
	[_demuxer close];
}

- (IBAction)done:(id)sender
{
	[self stop];
	[SVProgressHUD dismiss];
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Demuxer delegate

- (void)demuxer:(Demuxer*)demuxer buffering:(BOOL)buffering
{
	dispatch_async(dispatch_get_main_queue(), ^() {
		if (buffering) {
			[SVProgressHUD showWithStatus:@"Buffering..."];
		} else {
			[SVProgressHUD dismiss];
		}
	});
}

@end
