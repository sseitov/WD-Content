//
//  SMBConnection.h
//  WD Content TV
//
//  Created by Сергей Сейтов on 13.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMBFile;

@protocol SMBConnectionDelegate <NSObject>

- (void)requestAuth:(void (^)(NSString *user, NSString* password))auth;

@end

@interface SMBConnection : NSObject

@property (weak, nonatomic) id<SMBConnectionDelegate> delegate;

- (bool)connectTo:(NSString*)share port:(int)port;
- (void)disconnect;
- (bool)isConnected;
- (NSArray *)folderContentsAt:(NSString *)path;

@end
