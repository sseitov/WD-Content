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

- (void)demuxer:(Demuxer*)demuxer audioDecoded:(AVFrame*)frame;
- (void)demuxerDidStopped:(Demuxer*)demuxer;

@end

@interface Demuxer : NSObject

@property (weak, nonatomic) id<DemuxerDelegate> delegate;

- (void)openWithPath:(NSString*)path completion:(void (^)(BOOL))completion;
- (void)close;

- (void)play;

- (AVCodecContext*)videoContext;
- (CMSampleBufferRef)takeVideo;
- (AVFrame*)takeAudio;

@end
