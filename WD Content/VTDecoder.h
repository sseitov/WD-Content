//
//  VTDecoder.h
//  DirectVideo
//
//  Created by Sergey Seitov on 03.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Decoder.h"
#import <CoreMedia/CoreMedia.h>

@interface VTDecoder : Decoder

- (CMSampleBufferRef)takeWithTime:(double)time;

@end
