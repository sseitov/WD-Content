//
//  Decoder.m
//  WD Content
//
//  Created by Sergey Seitov on 21.02.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "Decoder.h"
#include <queue>
#include <mutex>

class PacketBuffer
{
protected:
	std::queue<AVPacket>	_queue;
	std::mutex				_mutex;
	std::condition_variable _empty;
	bool					_terminate;
	
public:
	bool					running;
	
	PacketBuffer() {}
	
	~PacketBuffer() {}
	
	void start()
	{
		running = true;
		_terminate = false;
	}
	
	void stop()
	{
		_terminate = true;
		_empty.notify_one();
		clear();
	}
	
	void push(AVPacket *packet)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		_queue.push(*packet);
		_empty.notify_one();
	}
	
	bool pop(AVPacket *packet)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		_empty.wait(lock, [this]() { return ((!_queue.empty() && running) || _terminate);});
		if (_terminate) {
			return false;
		}
		*packet = _queue.front();
		_queue.pop();
		return true;
	}
	
	size_t size()
	{
		std::unique_lock<std::mutex> lock(_mutex);
		return _queue.size();
	}
	
	void clear()
	{
		std::unique_lock<std::mutex> lock(_mutex);
		while (!_queue.empty()) {
			AVPacket packet = _queue.front();
			av_packet_unref(&packet);
			_queue.pop();
		}
	}
};

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
	_inputBuffer.start();
	_threadState = [[NSConditionLock alloc] initWithCondition:ThreadStillWorking];
	dispatch_async(self.decoderThread, ^() {
		NSLog(@"%@ started", [self name]);
		while (!self.stopped) {
			if (![self threadStep]) {
				break;
			}
			[self.delegate decoder:self changeState:Continue];
		}
		_inputBuffer.stop();
		[_threadState lock];
		[_threadState unlockWithCondition:ThreadIsDone];
		NSLog(@"%@ stopped", [self name]);
	});
}

- (void)stop
{
	self.stopped = YES;
	_inputBuffer.stop();
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
	return (_inputBuffer.size() > MAX_BUFFER_SIZE);
}

- (BOOL)isEmpty
{
	return (_inputBuffer.size() < MIN_BUFFER_SIZE);
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
