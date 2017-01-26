//
//  DropboxClient.m
//  WD Content
//
//  Created by Sergey Seitov on 24.12.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import "DropboxClient.h"
#import "DataModel.h"
#import "UIViewController+UIViewControllerExtensions.h"

NSString* const FinishAuthSynchroNotification = @"FinishAuthSynchroNotification";
NSString* const FinishContentSynchroNotification = @"FinishContentSynchroNotification";

@interface DropboxClient () <UIActionSheetDelegate>

@property (nonatomic) enum DropboxClientFile file;

@property (strong, nonatomic) NSString* extension;
@property (strong, nonatomic) NSString* fileName;
@property (strong, nonatomic) NSString* localPath;
@property (strong, nonatomic) NSDate* localDate;
@property (strong, nonatomic) NSString* notification;
@property (strong, nonatomic) DBMetadata* loadMeta;

@property (strong, nonatomic) NSMutableArray* arrayForSync;

@end

@implementation DropboxClient

- (id)initForFile:(enum DropboxClientFile)file
{
	self = [super initWithSession:[DBSession sharedSession]];
	if (self) {
		self.delegate = self;
		_file = file;
		_extension = (file == Auth) ? @"plist" : @"sqlite";
		_fileName = (file == Auth) ? @"Auth.plist" : @"ContentModel.sqlite";
		_localPath = (file == Auth) ? [DataModel authPath] : [DataModel contentPath];
		_notification = (file == Auth) ? FinishAuthSynchroNotification : FinishContentSynchroNotification;
	}
	return self;
}

- (void)sync
{
	_localDate = (_file == Auth) ? [DataModel lastAuthModified] : [DataModel lastModified];
	[self loadMetadata:@"/"];
}

#pragma mark DBRestClientDelegate methods

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == 0) {
		[self uploadFile:_fileName toPath:@"/" withParentRev:nil fromPath:_localPath];
	} else if ((buttonIndex - 1) < _arrayForSync.count && _arrayForSync.count > 0) {
		DBMetadata* meta = [_arrayForSync objectAtIndex:(buttonIndex-1)];
		[_arrayForSync removeObjectAtIndex:(buttonIndex-1)];
		_loadMeta = meta;
		[self loadFile:meta.path intoPath:_localPath];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:NO]];
	}
 }

+ (NSString*)stringForDate:(NSDate*)date
{
	NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
	dateFormat.dateStyle = NSDateFormatterMediumStyle;
	dateFormat.timeStyle = NSDateFormatterMediumStyle;
	return [dateFormat stringFromDate:date];
}

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata
{
	_arrayForSync = [NSMutableArray new];
	for (DBMetadata* fileMeta in metadata.contents) {
		NSString* extension = [[fileMeta.path pathExtension] lowercaseString];
		if (!fileMeta.isDirectory && [extension isEqual:_extension]) {
			if ([fileMeta.lastModifiedDate compare:_localDate] != NSOrderedSame || _localDate == nil) {
				[_arrayForSync addObject:fileMeta];
			}
		}
	}
	[_arrayForSync sortUsingComparator:^ NSComparisonResult(DBMetadata *d1, DBMetadata *d2) {
		return [d1.lastModifiedDate compare:d2.lastModifiedDate];
	}];
	if (_arrayForSync.count > 0) {
		UIActionSheet* actions = [[UIActionSheet alloc] init];
		actions.delegate = self;
		actions.title = _fileName;
		[actions addButtonWithTitle:@"Upload local"];
		for( DBMetadata *meta in _arrayForSync)  {
			[actions addButtonWithTitle:[NSString stringWithFormat:@"Download %@",
										 [DropboxClient stringForDate:meta.lastModifiedDate]]];
		}
		[actions addButtonWithTitle:@"Cancel"];
		actions.destructiveButtonIndex = 0;
		if (IS_PAD) {
			[actions showFromBarButtonItem:self.actionButton animated:YES];
		} else {
			[actions showInView:self.actionView];
		}
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:NO]];
	}
}

- (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path
{
//	NSLog(@"metadataUnchangedAtPath %@", path);
	[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:NO]];
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error
{
//	NSLog(@"restClient:loadMetadataFailedWithError: %@", [error localizedDescription]);
	[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:NO]];
}

-(void)restClient:(DBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath metadata:(DBMetadata*)metadata
{
//	NSLog(@"File %@ uploaded successfully from path: %@", metadata.path, srcPath);
	[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:NO]];
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error
{
//	NSLog(@"File upload failed with error - %@", error);
	[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:NO]];
}

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)localPath
{
//	NSLog(@"File loaded into path: %@", localPath);
	for (DBMetadata *m in _arrayForSync) {
		[self deletePath:m.path];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:YES] userInfo:@{@"meta" : _loadMeta}];
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error
{
//	NSLog(@"There was an error loading the file - %@", error);
	[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:NO]];
}

@end
