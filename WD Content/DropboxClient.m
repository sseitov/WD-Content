//
//  DropboxClient.m
//  WD Content
//
//  Created by Sergey Seitov on 24.12.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import "DropboxClient.h"
#import "DataModel.h"

NSString* const FinishAuthSynchroNotification = @"FinishAuthSynchroNotification";
NSString* const FinishContentSynchroNotification = @"FinishContentSynchroNotification";

@interface DropboxClient ()

@property (nonatomic) enum DropboxClientFile file;
@property (nonatomic) BOOL firstSynchro;

@property (strong, nonatomic) NSString* extension;
@property (strong, nonatomic) NSString* fileName;
@property (strong, nonatomic) NSString* dropboxPath;
@property (strong, nonatomic) NSString* localPath;
@property (strong, nonatomic) NSDate* localDate;
@property (strong, nonatomic) NSString* notification;
@property (strong, nonatomic) DBMetadata* loadMeta;

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
		_dropboxPath = (file == Auth) ? @"/Auth.plist" : @"/ContentModel.sqlite";
		_localPath = (file == Auth) ? [DataModel authPath] : [DataModel contentPath];
		_notification = (file == Auth) ? FinishAuthSynchroNotification : FinishContentSynchroNotification;
	}
	return self;
}

- (void)sync:(BOOL)first
{
	_firstSynchro = first;
	_localDate = (_file == Auth) ? [DataModel lastAuthModified] : [DataModel lastModified];
	[self loadMetadata:@"/"];
}

#pragma mark DBRestClientDelegate methods

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata
{
	for (DBMetadata* fileMeta in metadata.contents) {
		NSString* extension = [[fileMeta.path pathExtension] lowercaseString];
		if (!fileMeta.isDirectory && [extension isEqual:_extension]) {
			NSLog(@"%@ ====== %@", fileMeta.lastModifiedDate, _localDate);
			NSComparisonResult result = [fileMeta.lastModifiedDate compare:_localDate];
			if (_firstSynchro || result == NSOrderedDescending) {
				_loadMeta = fileMeta;
				[self loadFile:_dropboxPath intoPath:_localPath];
				return;
			} else if (result == NSOrderedAscending) {
				break;
			} else {
				[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:NO]];
				return;
			}
		}
	}
	if (!_firstSynchro) {
		[self uploadFile:_fileName toPath:@"/" withParentRev:nil fromPath:_localPath];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:NO]];
	}
}

- (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path
{
	NSLog(@"metadataUnchangedAtPath %@", path);
	[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:NO]];
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error
{
	NSLog(@"restClient:loadMetadataFailedWithError: %@", [error localizedDescription]);
	[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:NO]];
}

-(void)restClient:(DBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath metadata:(DBMetadata*)metadata
{
	NSLog(@"File %@ uploaded successfully to path: %@", metadata.path, destPath);
	[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:YES]];
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error
{
	NSLog(@"File upload failed with error - %@", error);
	[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:NO]];
}

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)localPath
{
	NSLog(@"File loaded into path: %@", localPath);
	[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:YES] userInfo:@{@"meta" : _loadMeta}];
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error
{
	NSLog(@"There was an error loading the file - %@", error);
	[[NSNotificationCenter defaultCenter] postNotificationName:_notification object:[NSNumber numberWithBool:NO]];
}

@end
