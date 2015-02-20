//
//  Decoder.m
//  WD Content
//
//  Created by Sergey Seitov on 19.02.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "DecodeBuffer.h"
#include <list>
#include <mutex>

extern "C" {
#	include "libavcodec/avcodec.h"
#	include "libavformat/avformat.h"
#	include "libavformat/avio.h"
#	include "libavfilter/avfilter.h"
};

class PacketBuffer
{
protected:
	std::list<AVPacket>		_queue;
	std::mutex				_mutex;
	std::condition_variable _empty;
	int						_timeIndex;
	int						_bufferTime;
	bool					_terminate;
	
public:
	bool					running;
	
	PacketBuffer() : running(true), _timeIndex(-1), _bufferTime(0), _terminate(false)
	{
	}
	
	~PacketBuffer()
	{
	}
	
	void clear()
	{
		_terminate = true;
		_empty.notify_one();
		while (!_queue.empty()) {
			AVPacket packet = _queue.front();
			av_free_packet(&packet);
			_queue.pop_front();
		}
	}
	
	void push(AVPacket *packet)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		_queue.push_back(*packet);
		if (packet->stream_index == _timeIndex) {
			_bufferTime++;
		}
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
		_queue.pop_front();
		if (packet->stream_index == _timeIndex) {
			_bufferTime--;
		}
		return true;
	}
	
	int time()
	{
		std::unique_lock<std::mutex> lock(_mutex);
		return _bufferTime;
	}
	
	void setAudio(int index)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		std::list<AVPacket>::iterator it = _queue.begin();
		while ( it != _queue.end()) {
			AVPacket packet = *it;
			if (packet.stream_index == _timeIndex) {
				av_free_packet(&packet);
				_bufferTime--;
				it = _queue.erase(it);
			} else {
				it++;
			}
		}
		_timeIndex = index;
	}
};

@interface DecodeBuffer () {
	
	dispatch_queue_t	_decoderQueue;
	PacketBuffer		_buffer;
}

@property (strong, nonatomic) NSConditionLock *decoderState;
@property (atomic) BOOL stopped;

@end

@implementation DecodeBuffer

- (id)init
{
	self = [super init];
	if (self) {
		_decoderQueue = dispatch_queue_create("com.vchannel.WD-Content.Decoder", DISPATCH_QUEUE_SERIAL);
	}
	return self;
}

- (void)startWithAudio:(int)audio
{
	_buffer.setAudio(audio);
	
	_decoderState = [[NSConditionLock alloc] initWithCondition:ThreadStillWorking];
	
	self.stopped = NO;
	
	dispatch_async(_decoderQueue, ^() {
		while (!self.stopped) {
			AVPacket nextPacket;
			if (_buffer.pop(&nextPacket)) {
				[self.delegate decodePacket:&nextPacket];
			}
		}
		[_decoderState lock];
		[_decoderState unlockWithCondition:ThreadIsDone];
	});
}

- (void)changeAudio:(int)audio
{
	_buffer.setAudio(audio);
}

- (void)stop
{
	self.stopped = YES;
	_buffer.clear();
	[_decoderState lockWhenCondition:ThreadIsDone];
	[_decoderState unlock];
}

- (enum DecodeBufferState)pushPacket:(AVPacket*)packet
{
	_buffer.push(packet);
//	NSLog(@"buffer size %d", _buffer.time());
	if (_buffer.time() > 256 && !_buffer.running) {
		_buffer.running = true;
		return StopBuffering;
	} else if (_buffer.time() < 16 && _buffer.running) {
		_buffer.running = false;
		return StartBuffering;
	} else {
		return Continue;
	}
}

- (int)size
{
	return _buffer.time();
}

@end
