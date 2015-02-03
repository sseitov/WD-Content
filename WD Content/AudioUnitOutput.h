//
//  AudioUnitOutput.h
//  WD Content
//
//  Created by Sergey Seitov on 01.02.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>

extern "C" {
#	include "libavcodec/avcodec.h"
#	include "libavformat/avformat.h"
};

@interface AudioUnitOutput : NSObject

@property (readwrite, atomic) BOOL started;

- (BOOL)startWithFrame:(AVFrame*)frame;
- (BOOL)stop;
- (void)enqueueFrame:(AVFrame*)frame;

@end
