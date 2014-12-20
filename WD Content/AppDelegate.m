//
//  AppDelegate.m
//  WD Content
//
//  Created by Sergey Seitov on 29.11.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import "AppDelegate.h"
#import "TMDB.h"
#import <Dropbox/Dropbox.h>
#import "DataModel.h"

#define APP_KEY     @"3cujrb3xpbb7fuw"
#define APP_SECRET  @"bfm5uz7aivquetn"

@interface AppDelegate()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[TMDB sharedInstance].apiKey = @"0aec9897fa96fb8f97e70aeb0da26a7e";

	DBAccountManager* accountMgr = [[DBAccountManager alloc]
									initWithAppKey:APP_KEY
									secret:APP_SECRET];
	[DBAccountManager setSharedManager:accountMgr];

//	UITabBarController* tabBar = (UITabBarController*)_window.rootViewController;
//	NSDictionary *auth = [[NSUserDefaults standardUserDefaults] objectForKey:@"auth"];
//	tabBar.selectedIndex = (!auth || auth.count < 1) ? 1 : 0;
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url
  sourceApplication:(NSString *)source annotation:(id)annotation
{
	DBAccount *account = [[DBAccountManager sharedManager] handleOpenURL:url];
	if (account) {
		NSLog(@"App linked successfully!");
		[self doSync:account];
		return YES;
	}
	return NO;
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

#pragma mark - DropBox sync

- (void)sync:(UIViewController*)controller
{
	DBAccountManager* accountMgr = [DBAccountManager sharedManager];
	if (accountMgr.linkedAccount) {
		[self doSync:accountMgr.linkedAccount];
	} else {
		[[DBAccountManager sharedManager] linkFromController:controller];
	}

}

- (BOOL)doSync:(DBAccount *)account
{
	//Check that we're given a linked account.
	
	if (!account || !account.linked) {
		NSLog(@"No account linked");
		return NO;
	}
	
	//Check if shared filesystem already exists - can't create more than
	//one DBFilesystem on the same account.
	
	DBFilesystem *filesystem = [DBFilesystem sharedFilesystem];
	
	if (!filesystem) {
		filesystem = [[DBFilesystem alloc] initWithAccount:account];
		[DBFilesystem setSharedFilesystem:filesystem];
	}
	
	NSString *const DB_FILE_NAME = @"ContentModel.sqlite";
	
	DBError *error = nil;
	DBPath *path = [[DBPath root] childPath:DB_FILE_NAME];
	DBFileInfo *info = [filesystem fileInfoForPath:path error:&error];
	if (info) {
		if ([info.modifiedTime compare:[[DataModel sharedInstance] lastModified]] == NSOrderedAscending) {
			return YES;
		}
	}
	return YES;
/*
	if (![filesystem fileInfoForPath:path error:&error]) { // see if path exists
		
		//Report error if path look up failed for some other reason than NOT FOUND
		
		if ([error code] != DBErrorNotFound) {
			NSLog(@"Error getting file info");
			return NO;
		}
		
		 //Write a new test file.
		DBFile *file = [[DBFilesystem sharedFilesystem] createFile:path error:&error];
		if (!file) {
			NSLog(@"Error creating file.");
			return NO;
		}
		
		NSString *storePath = [[[DataModel sharedInstance] sharedDocumentsPath] stringByAppendingPathComponent:DB_FILE_NAME];
		NSData* data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:storePath]];
		if (![file writeData:data error:&error]) {
			NSLog(@"Error writing file.");
			return NO;
		}
		[file close];
		NSLog(@"Created new file %@.\n", [path stringValue]);
	}
	
	//Read and print the contents of test file.  Since we're not making
	//any attempt to wait for the latest version, this may print an
	//older cached version.  Use status property of DBFile and/or a
	// listener to check for a new version.
	
	DBFileInfo *info = [filesystem fileInfoForPath:path error:&error];
	if (!info) {
		NSLog(@"File does not exist.");
	}
	
	if (![info isFolder]) {
		NSLog(@"file modified at %@", info.modifiedTime);
		DBFile *file = [[DBFilesystem sharedFilesystem] openFile:path error:&error];
		if (!file) {
			NSLog(@"Error opening file.");
			return NO;
		}
		
		NSData *data = [file readData:&error];
		if (!data) {
			NSLog(@"Error reading file.");
			return NO;
		}
		[file close];
	}
	
	return YES;*/
}

@end
