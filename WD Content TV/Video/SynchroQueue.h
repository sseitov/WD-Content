//
//  SynchroQueue.h
//  npTV
//
//  Created by Sergey Seitov on 24.08.13.
//  Copyright (c) 2013 V-Channel. All rights reserved.
//

#ifndef __npTV__SynchroQueue__
#define __npTV__SynchroQueue__

#include <queue>
#include <mutex>

extern "C" {
#	include "libavcodec/avcodec.h"
};

template <class T>
class SynchroQueue {
protected:
	typedef std::queue<T> queue_type;

	queue_type				_queue;
	std::mutex				_mutex;
	std::condition_variable _empty;
	bool					_stopped;
	
public:
	
	SynchroQueue(SynchroQueue const&) = delete;
	SynchroQueue() : _stopped(false) {}
	
	virtual void free(T*) {}
	
	virtual bool push(T* elem)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		if (_stopped) {
			return false;
		} else {
			_queue.push(*elem);
			_empty.notify_one();
			return true;
		}
	}
	
	bool front(T* elem)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		if (!_queue.empty())
			return *elem = _queue.front(), true;
		return false;
	}
	
	bool pop(T* elem)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		_empty.wait(lock, [this]() { return (!_queue.empty() || _stopped);});
		if (_stopped) {
			return false;
		} else {
			*elem = _queue.front();
			_queue.pop();
			return true;
		}
	}
	
	void start()
	{
		_stopped = false;
	}
	
	void lock()
	{
		_mutex.lock();
	}
	
	void unlock()
	{
		_mutex.unlock();
	}
	
	void shift(int64_t shift)
	{
		auto it = _queue.begin();
		while (it != _queue.end())
		{
			it->pts += shift;
			++it;
		}
	}
	
	virtual void flush(int64_t pts = AV_NOPTS_VALUE)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		while (!_queue.empty()) {
			T elem = _queue.front();
			free(&elem);
			_queue.pop();
		}
		_empty.notify_one();
	}
	
	void stop()
	{
		_stopped = true;
		flush(AV_NOPTS_VALUE);
	}
	
	int size()
	{
		std::unique_lock<std::mutex> lock(_mutex);
		return (int)_queue.size();
	}
	
	bool empty()
	{
		std::unique_lock<std::mutex> lock(_mutex);
		return _queue.empty();
	}
};

#endif /* defined(__npTV__PacketQueue__) */
