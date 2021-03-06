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

@protocol DemuxerDelegate <NSObject>

- (void)demuxer:(Demuxer*)demuxer buffering:(BOOL)buffering;

@end

@interface Demuxer : NSObject

@property (weak, nonatomic) id<DemuxerDelegate> delegate;

- (void)openWithPath:(NSString*)path completion:(void (^)(NSArray*))completion;
- (void)close;

- (BOOL)play:(int)audioCahnnel;
- (BOOL)changeAudio:(int)audioCahnnel;

- (CMSampleBufferRef)takeVideo;

@end

