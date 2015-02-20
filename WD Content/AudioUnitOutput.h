//
//  AudioUnitOutput.h
//  WD Content
//
//  Created by Sergey Seitov on 01.02.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>

struct AVFrame;

@protocol AudioUnitOutputDelegate <NSObject>

- (void)requestNextFrame:(void (^)(AVFrame*))result;

@end

@interface AudioUnitOutput : NSObject

@property (weak, nonatomic) id<AudioUnitOutputDelegate> delegate;
@property (readwrite, atomic) BOOL started;

- (BOOL)startWithFrame:(AVFrame*)frame;
- (BOOL)stop;

@end
