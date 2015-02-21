//
//  Decoder.m
//  WD Content
//
//  Created by Sergey Seitov on 21.02.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "Decoder.h"
#import "PacketBuffer.h"

@interface Decoder () {
	PacketBuffer _inputBuffer;
}

@property (strong, nonatomic) NSConditionLock *threadState;

@end

@implementation Decoder

- (BOOL)openWithContext:(AVCodecContext*)context
{
	return NO;
}

- (NSString*)name
{
	return nil;
}

- (void)close
{
	if (self.context) {
		avcodec_close(self.context);
	}
	self.context = NULL;
}

- (void)start
{
	self.stopped = NO;
	_threadState = [[NSConditionLock alloc] initWithCondition:ThreadStillWorking];
	dispatch_async(self.decoderThread, ^() {
		while (!self.stopped) {
			if (![self threadStep]) {
				break;
			}
			[self.delegate decoder:self changeState:Continue];
		}
		_inputBuffer.stop();
		[_threadState lock];
		[_threadState unlockWithCondition:ThreadIsDone];
	});
}

- (void)stop
{
	self.stopped = YES;
	[_threadState lockWhenCondition:ThreadIsDone];
	[_threadState unlock];
}

- (BOOL)threadStep
{
	return NO;
}

- (void)push:(AVPacket*)packet
{
	_inputBuffer.push(packet);
}

- (BOOL)pop:(AVPacket*)packet
{
	return _inputBuffer.pop(packet);
}

- (BOOL)isFull
{
	return (_inputBuffer.size() > 256);
}

- (size_t)size
{
	return _inputBuffer.size();
}

- (BOOL)running
{
	return _inputBuffer.running;
}

- (void)pause:(BOOL)pause
{
	_inputBuffer.running = !pause;
}

@end
