//
//  DropboxClient.h
//  WD Content
//
//  Created by Sergey Seitov on 24.12.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DropboxSDK/DropboxSDK.h>

enum DropboxClientFile
{
	Auth,
	Content
};

extern NSString* const FinishAuthSynchroNotification;
extern NSString* const FinishContentSynchroNotification;

@interface DropboxClient : DBRestClient<DBRestClientDelegate>

- (id)initForFile:(enum DropboxClientFile)file;
- (void)sync:(BOOL)first;

@end
