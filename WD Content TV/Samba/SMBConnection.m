//
//  SMBConnection.m
//  WD Content TV
//
//  Created by Сергей Сейтов on 13.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import "SMBConnection.h"
#import "SMBFile.h"

#import "TOSMBConstants.h"
#import "TONetBIOSNameService.h"
#import "TONetBIOSNameServiceEntry.h"

#import <bdsm/smb_session.h>
#import <bdsm/smb_share.h>
#import <bdsm/smb_stat.h>
#import <arpa/inet.h>

//#define SAMBA_PORT  445

@interface SMBConnection () {
}

@property (nonatomic, assign) smb_session *session;

@end

@implementation SMBConnection

- (instancetype)init {
    self = [super init];
    if (self) {
        _session = nil;
    }
    return self;
}

- (void)dealloc {
    if (_session != nil) {
        smb_session_destroy(_session);
    }
}

- (bool)connectTo:(NSString*)host port:(int)port user:(NSString*)user password:(NSString*)password {
    
    if (_session != nil) {
        smb_session_destroy(_session);
    }
    
    TONetBIOSNameService *nameService = [[TONetBIOSNameService alloc] init];
    NSString* hostName = [nameService lookupNetworkNameForIPAddress:host];
    
    struct sockaddr_in   sin;
    memset ((char *)&sin,0,sizeof(sin));
    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = inet_addr(host.UTF8String);
    sin.sin_port = htons ( port );

    _session = smb_session_new();
    int err = smb_session_connect(_session, hostName.UTF8String, sin.sin_addr.s_addr, SMB_TRANSPORT_TCP);
    if (err != 0) {
        smb_session_destroy(_session);
        _session = nil;
        return false;
    }
    if (smb_session_is_guest(_session) >= 0) {
        return true;
	} else {
		//Attempt a login. Even if we're downgraded to guest, the login call will succeed
		smb_session_set_creds(_session, hostName.UTF8String, user.UTF8String, password.UTF8String);
		int result = smb_session_login(_session);
		return ( result >= 0);
	}
}

- (void)disconnect {
	smb_session_destroy(_session);
	_session = nil;
}

- (bool)isConnected {
	return (_session != nil);
}

- (NSArray *)folderContentsAt:(NSString *)path
{
    if (_session == nil) {
        return [NSMutableArray array];
    }
    
    //If the path is nil, or '/', we'll be specifically requesting the
    //parent network share names as opposed to the actual file lists
    
    if (path.length == 0 || [path isEqualToString:@"/"]) {
        NSMutableArray *shareList = [NSMutableArray array];
        smb_share_list list;
        size_t shareCount = 0;
        smb_share_get_list(_session, &list, &shareCount);
        if (shareCount == 0)
            return shareList;
        
        for (NSInteger i = 0; i < shareCount; i++) {
            const char *shareName = smb_share_list_at(list, i);
			
            //Skip system shares suffixed by '$'
            if (shareName[strlen(shareName)-1] == '$')
                continue;
            
            NSString *shareNameString = [NSString stringWithCString:shareName encoding:NSUTF8StringEncoding];
            SMBFile *share = [[SMBFile alloc] initWithShareName:shareNameString];
            [shareList addObject:share];
        }
        
        smb_share_list_destroy(list);
        
		return [shareList sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    }
    
    //-----------------------------------------------------------------------------
    
    //Replace any backslashes with forward slashes
    path = [path stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    
    //Work out just the share name from the path (The first directory in the string)
    NSString *shareName = [self shareNameFromPath:path];
    
    //Connect to that share
    
    //If not, make a new connection
    const char *cStringName = [shareName cStringUsingEncoding:NSUTF8StringEncoding];
    smb_tid shareID = -1;
    smb_tree_connect(self.session, cStringName, &shareID);
    if (shareID < 0) {
        return [NSArray array];
    }
    
    //work out the remainder of the file path and create the search query
    NSString *relativePath = [self filePathExcludingSharePathFromPath:path];
    //prepend double backslashes
    relativePath = [NSString stringWithFormat:@"\\%@",relativePath];
    //replace any additional forward slashes with backslashes
    relativePath = [relativePath stringByReplacingOccurrencesOfString:@"/" withString:@"\\"]; //replace forward slashes with backslashes
    //append double backslash if we don't have one
    if (![[relativePath substringFromIndex:relativePath.length-1] isEqualToString:@"\\"])
        relativePath = [relativePath stringByAppendingString:@"\\"];
    
    //Add the wildcard symbol for everything in this folder
    relativePath = [relativePath stringByAppendingString:@"*"]; //wildcard to search for all files
    
    //Query for a list of files in this directory
    smb_stat_list statList = smb_find(self.session, shareID, relativePath.UTF8String);
    size_t listCount = smb_stat_list_count(statList);
    if (listCount == 0) {
        return [NSArray array];
    }
    
    NSMutableArray *fileList = [NSMutableArray array];
    
    for (NSInteger i = 0; i < listCount; i++) {
        smb_stat item = smb_stat_list_at(statList, i);
        const char* name = smb_stat_name(item);
		
		if (strcmp(name, "$RECYCLE.BIN") == 0)
			continue;
		if (strcmp(name, "System Volume Information") == 0)
			continue;
		if (strstr(name, "HFS+ Private") != nil)
			continue;
		
		//Skip hidden files
        if (name[0] == '.')
            continue;
		
        SMBFile *file = [[SMBFile alloc] initWithStat:item parentDirectoryPath:path];
		if (file.isValidFileType)
			[fileList addObject:file];
    }
    smb_stat_list_destroy(statList);
    smb_tree_disconnect(self.session, shareID);
    
    if (fileList.count == 0)
        return [NSArray array];
    else
        return [fileList sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
}

#pragma mark - String Parsing

- (NSString *)shareNameFromPath:(NSString *)path
{
    path = [path copy];
    
    //Remove any potential slashes at the start
    if ([[path substringToIndex:2] isEqualToString:@"//"]) {
        path = [path substringFromIndex:2];
    }
    else if ([[path substringToIndex:1] isEqualToString:@"/"]) {
        path = [path substringFromIndex:1];
    }
    
    NSRange range = [path rangeOfString:@"/"];
    
    if (range.location != NSNotFound)
        path = [path substringWithRange:NSMakeRange(0, range.location)];
    
    return path;
}

- (NSString *)filePathExcludingSharePathFromPath:(NSString *)path
{
    path = [path copy];
    
    //Remove any potential slashes at the start
    if ([[path substringToIndex:2] isEqualToString:@"//"] || [[path substringToIndex:2] isEqualToString:@"\\\\"]) {
        path = [path substringFromIndex:2];
    }
    else if ([[path substringToIndex:1] isEqualToString:@"/"] || [[path substringToIndex:1] isEqualToString:@"\\"]) {
        path = [path substringFromIndex:1];
    }
    
    NSRange range = [path rangeOfString:@"/"];
    if (range.location == NSNotFound) {
        range = [path rangeOfString:@"\\"];
    }
    
    if (range.location != NSNotFound)
        path = [path substringFromIndex:range.location+1];
    
    return path;
}

- (smb_fd)openFile:(NSString*)path {
	smb_tid treeID = 0;
	smb_fd fileID = 0;
	
	NSString *shareName = [self shareNameFromPath:path];

	smb_tree_connect(_session, shareName.UTF8String, &treeID);
	if (!treeID)
		return 0;
	
	NSString *formattedPath = [self filePathExcludingSharePathFromPath:path];
	formattedPath = [NSString stringWithFormat:@"\\%@",formattedPath];
	formattedPath = [formattedPath stringByReplacingOccurrencesOfString:@"/" withString:@"\\\\"];

	smb_fopen(_session, treeID, formattedPath.UTF8String, SMB_MOD_RO, &fileID);
	return fileID;
}

- (void)closeFile:(smb_fd)file {
	smb_fclose(_session, file);
}

- (int)readFile:(smb_fd)file buffer:(void*)buffer size:(size_t)size {
	return (int)smb_fread(_session, file, buffer, size);
}

- (int)seekFile:(smb_fd)file offset:(off_t)offset whence:(int)whence {
	return (int)smb_fseek(_session, file, offset, whence);
}

@end
