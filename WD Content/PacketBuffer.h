//
//  PacketBuffer.h
//  WD Content
//
//  Created by Sergey Seitov on 21.02.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#ifndef WD_Content_PacketBuffer_h
#define WD_Content_PacketBuffer_h

#include <queue>
#include <mutex>

extern "C" {
#	include "libavcodec/avcodec.h"
};

class PacketBuffer
{
protected:
	std::queue<AVPacket>	_queue;
	std::mutex				_mutex;
	std::condition_variable _empty;
	bool					_terminate;
	
public:
	bool					running;
	
	PacketBuffer() : running(true), _terminate(false)
	{
	}
	
	~PacketBuffer()
	{
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
			av_free_packet(&packet);
			_queue.pop();
		}
	}
};

#endif
