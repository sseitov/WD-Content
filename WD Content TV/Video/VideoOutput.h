//
//  VideoOutput.h
//  vTV
//
//  Created by Сергей Сейтов on 07.01.12.
//  Copyright (c) 2012 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import "Decoder.h"

#define SCREEN_POOL_SIZE	32

struct AVFrame;

@interface VideoOutput : GLKViewController

@property (retain, nonatomic)	NSString*	host;
@property (nonatomic)			int			port;
@property (retain, nonatomic)	NSString*	user;
@property (retain, nonatomic)	NSString*	password;
@property (retain, nonatomic)	NSString*	filePath;

@property (readwrite, atomic) BOOL started;
@property (strong, nonatomic) id<Decoder> decoder;

@property (readonly, nonatomic) CGSize videoSize;
@property (readwrite, atomic) int64_t lastFlushPTS;
@property (readwrite, atomic) int lateFrameCounter;

- (void)stop;
- (void)flush:(int64_t)pts;
- (void)pushPacket:(struct AVPacket*)packet;
- (int64_t)updateWithPTS:(int64_t)pts updated:(int*)updated;
- (UIView*)glView;

- (int64_t)currentPTS;
- (int)decodedPacketCount;

@end
