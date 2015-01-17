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
	int                     _size;
public:
	
	SynchroQueue(SynchroQueue const&) = delete;
	SynchroQueue() : _stopped(false), _size(20) {}
	
	virtual void free(T*) {}
	
	virtual bool push(T* elem)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		if (_queue.size() > _size) {
			_full.wait(lock, [this]() { return (_queue.size() < _size || _stopped);});
		}
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
	
	void start()
	{
		_stopped = false;
	}
	
	void stop()
	{
		_stopped = true;
		_full.notify_one();
		_empty.notify_one();
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
