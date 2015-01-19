//
//  SynchroQueue.h
//  npTV
//
//  Created by Sergey Seitov on 24.08.13.
//  Copyright (c) 2013 V-Channel. All rights reserved.
//

#ifndef __npTV__SynchroQueue__
#define __npTV__SynchroQueue__

#include <list>
#include <mutex>

template <class T>
class SynchroQueue {
protected:
	std::list<T>			_queue;
	std::mutex				_mutex;
	std::condition_variable _empty;
	std::condition_variable _full;
	bool					_stopped;
	
	virtual void free(T*) = 0;

public:
	
	SynchroQueue(SynchroQueue const&) = delete;
	SynchroQueue() : _stopped(false) {}
	
	int size()
	{
		std::unique_lock<std::mutex> lock(_mutex);
		return _queue.size();
	}
	
	bool empty()
	{
		std::unique_lock<std::mutex> lock(_mutex);
		return _queue.empty();
	}
	
	bool push(T* elem)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		if (_stopped) {
			return false;
		} else {
			_queue.push_back(*elem);
			_empty.notify_one();
			return true;
		}
	}
	
	bool pop(T* elem)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		_empty.wait(lock, [this]() { return (!_queue.empty() || _stopped);});
		if (_stopped) {
			return false;
		} else {
			*elem = _queue.front();
			_queue.pop_front();
			_full.notify_one();
			return true;
		}
	}
	
	void stop()
	{
		std::unique_lock<std::mutex> lock(_mutex);
		_stopped = true;
		while (!_queue.empty()) {
			T elem = _queue.front();
			free(&elem);
			_queue.pop_front();
		}
		_full.notify_one();
		_empty.notify_one();
	}
};

#endif /* defined(__npTV__PacketQueue__) */
