//
//  AppDelegate.m
//  WD Content
//
//  Created by Sergey Seitov on 29.11.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import "AppDelegate.h"
#import "TMDB.h"
#import <DropboxSDK/DropboxSDK.h>
#import "DataModel.h"
#import <AVFoundation/AVFoundation.h>
#import <SVProgressHUD.h>
#import <IQKeyboardManager.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include "ApiKeys.h"

NSString* const ErrorDBAccountNotification = @"ErrorDBAccountNotification";

@interface AppDelegate() <DBSessionDelegate>
	
@property (strong, nonatomic) NSString *relinkUserId;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[TMDB sharedInstance].apiKey = TMDB_API_KEY;
	
	[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error: nil];
//	[[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.018 error:nil];
	[[AVAudioSession sharedInstance] setActive:YES error:nil];
	
	av_register_all();
	avcodec_register_all();
	int ret = avformat_network_init();
	NSLog(@"avformat_network_init = %d", ret);
	
	DBSession* session = [[DBSession alloc] initWithAppKey:DropBox_APP_KEY appSecret:DropBox_APP_SECRET root:kDBRootAppFolder];
	session.delegate = self;
	[DBSession setSharedSession:session];

	NSArray* auth = [DataModel auth];
	if (!auth) {
		auth = [NSArray array];
	} else if ([auth isKindOfClass:[NSDictionary class]]) {
		[DataModel convertAuth];
	}
	
	[UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
	
	UIFont* font =  [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:17];
	[[UIBarButtonItem appearance] setTitleTextAttributes:@{NSFontAttributeName:font} forState:UIControlStateNormal];
	
	[SVProgressHUD setDefaultStyle:SVProgressHUDStyleCustom];
	[SVProgressHUD setBackgroundColor:[UIColor colorWithRed:0 green:113.0/255.0 blue:165.0/255.0 alpha:1]];
	[SVProgressHUD setForegroundColor:[UIColor whiteColor]];
	[SVProgressHUD setFont:font];
	
	[[IQKeyboardManager sharedManager] setEnableAutoToolbar:NO];
	
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation
{
	if ([[DBSession sharedSession] handleOpenURL:url]) {
		if ([[DBSession sharedSession].userIds count] == 0) {
			[[NSNotificationCenter defaultCenter] postNotificationName:ErrorDBAccountNotification object:nil];
		}
		return YES;
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:ErrorDBAccountNotification object:nil];
		return NO;
	}
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - DBSessionDelegate methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)index
{
	if (index != alertView.cancelButtonIndex) {
		[[DBSession sharedSession] linkUserId:_relinkUserId fromController:self.window.rootViewController];
	}
	_relinkUserId = nil;
}

- (void)sessionDidReceiveAuthorizationFailure:(DBSession*)session userId:(NSString *)userId
{
	_relinkUserId = userId;
	[[[UIAlertView alloc]
	   initWithTitle:@"Dropbox Session Ended" message:@"Do you want to relink?" delegate:self
	  cancelButtonTitle:@"Cancel" otherButtonTitles:@"Relink", nil] show];
}

@end
