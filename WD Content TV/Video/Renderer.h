//
//  Renderer.h
//  vTV
//
//  Created by Sergey Seitov on 22.08.13.
//  Copyright (c) 2013 V-Channel. All rights reserved.
//

#import <GLKit/GLKit.h>

struct AVPacket;
@class VideoOutput;

@interface Renderer : NSObject <GLKViewControllerDelegate>

- (id)initWithScreen:(VideoOutput*)screen;
- (bool)load:(NSString*)host port:(int)port user:(NSString*)user password:(NSString*)password file:(NSString*)filePath  audioChannels:(NSMutableArray*) audioChannels;
- (void)close;
- (BOOL)play:(int)audioCahnnel;

@end
