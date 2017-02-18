//
//  SMBConnection.h
//  WD Content TV
//
//  Created by Сергей Сейтов on 13.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <bdsm/smb_file.h>

@class SMBFile;

@interface SMBConnection : NSObject

- (bool)connectTo:(NSString*)host port:(int)port user:(NSString*)user password:(NSString*)password;
- (void)disconnect;
- (bool)isConnected;
- (NSArray *)folderContentsAt:(NSString *)path;
- (smb_fd)openFile:(NSString*)path;
- (void)closeFile:(smb_fd)file;
- (int)readFile:(smb_fd)file buffer:(void*)buffer size:(size_t)size;
- (int)seekFile:(smb_fd)file offset:(off_t)offset whence:(int)whence;

@end
