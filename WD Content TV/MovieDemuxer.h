//
//  MovieDemuxer.h
//  WD Content
//
//  Created by Сергей Сейтов on 18.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMBConnection;
@class MovieDemuxer;
class YUVTexture;

@protocol MovieDemuxerDelegate <NSObject>

- (void)demuxer:(MovieDemuxer*)demuxer buffering:(BOOL)buffering;

@end

@interface MovieDemuxer : NSObject {
	@public YUVTexture* texture;
}

@property (weak, nonatomic) id<MovieDemuxerDelegate> delegate;

- (bool)load:(NSString*)host port:(int)port user:(NSString*)user password:(NSString*)password file:(NSString*)filePath  audioChannels:(NSMutableArray*) audioChannels;
- (void)close;
- (BOOL)play:(int)audioCahnnel;
- (void)takeVideo;

@end
