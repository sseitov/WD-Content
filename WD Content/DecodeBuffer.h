//
//  DecodeBuffer.h
//  WD Content
//
//  Created by Sergey Seitov on 19.02.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>

enum {
	ThreadStillWorking,
	ThreadIsDone
};

enum DecodeBufferState {
	Continue,
	StartBuffering,
	StopBuffering
};

struct AVPacket;

@protocol DecodeBufferDelegate <NSObject>

- (void)decodePacket:(AVPacket*)packet;

@end

@interface DecodeBuffer : NSObject

@property (weak, nonatomic) id<DecodeBufferDelegate> delegate;

- (void)startWithAudio:(int)audio;
- (void)changeAudio:(int)audio;
- (void)stop;

- (enum DecodeBufferState)pushPacket:(AVPacket*)packet;
- (int)size;

@end
