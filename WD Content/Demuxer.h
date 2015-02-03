//
//  Demuxer.h
//  WD Content
//
//  Created by Sergey Seitov on 19.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class Demuxer;
struct AVCodecContext;
struct AVFrame;

@protocol DemuxerDelegate <NSObject>

- (void)demuxerDidStopped:(Demuxer*)demuxer;

@end

@interface Demuxer : NSObject

@property (weak, nonatomic) id<DemuxerDelegate> delegate;

- (void)openWithPath:(NSString*)path completion:(void (^)(NSArray*))completion;
- (void)close;

- (void)play:(int)audioCahnnel;

- (AVCodecContext*)videoContext;
- (AVCodecContext*)audioContext;
- (CMSampleBufferRef)takeVideo;

@end
