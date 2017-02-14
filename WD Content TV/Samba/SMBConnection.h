//
//  SMBConnection.h
//  WD Content TV
//
//  Created by Сергей Сейтов on 13.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMBFile;

@interface SMBConnection : NSObject

- (bool)connectTo:(NSString*)share port:(int)port user:(NSString*)user password:(NSString*)password;
- (void)disconnect;
- (NSArray *)folderContentsAt:(NSString *)path;

@end
