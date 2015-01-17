//
//  Decoder.h
//  WD Content
//
//  Created by Sergey Seitov on 13.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>

struct AVCodecContext;

@interface Decoder : NSObject

@property (readwrite, atomic) struct AVCodecContext* codec;

- (BOOL)openWithContext:(struct AVCodecContext*)context;
- (void)close;

@end
