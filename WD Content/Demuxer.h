//
//  Demuxer.h
//  WD Content
//
//  Created by Sergey Seitov on 19.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

extern "C" {
#	include "libavcodec/avcodec.h"
#	include "libavformat/avformat.h"
#	include "libavformat/avio.h"
#	include "libavfilter/avfilter.h"
};

@class Demuxer;

@protocol DemuxerDelegate <NSObject>

- (void)demuxer:(Demuxer*)demuxer buffering:(BOOL)buffering;
- (void)demuxerDidStopped:(Demuxer*)demuxer;

@end

@interface Demuxer : NSObject

@property (weak, nonatomic) id<DemuxerDelegate> delegate;

- (void)openWithPath:(NSString*)path completion:(void (^)(NSArray*))completion;
- (void)stop;
- (void)close;

- (BOOL)play:(int)audioCahnnel;

- (AVRational)timeBase;
- (CMSampleBufferRef)takeVideo;

@end
