//
//  AudioOutput.h
//  vTV
//
//  Created by Sergey Seitov on 13.08.13.
//  Copyright (c) 2013 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>

struct AVFrame;

@interface AudioOutput : NSObject

@property (readwrite, atomic) BOOL started;

- (BOOL)startWithFrame:(AVFrame*)frame;
- (void)enqueueFrame:(AVFrame*)frame;
- (void)stop;
- (void)pause:(BOOL)doPause;
- (double)getCurrentTime;

@end
