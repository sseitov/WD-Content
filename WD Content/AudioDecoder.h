//
//  AudioDecoder.h
//  WD Content
//
//  Created by Sergey Seitov on 17.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Decoder.h"

@class AudioDecoder;

@protocol AudioDecoderDelegate <NSObject>

- (void)audioDecoder:(AudioDecoder*)decoder decodedBuffer:(AVFrame*)frame;

@end

@interface AudioDecoder : NSObject<Decoder>

@property (weak, nonatomic) id<AudioDecoderDelegate> delegate;
@property (readwrite, nonatomic) AVCodecContext* context;

@end
