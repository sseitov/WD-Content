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

extern "C" {
#	include "libavcodec/avcodec.h"
};

template <class T>
class SynchroQueue {
protected:
	std::list<T>			_queue;
	std::mutex				_mutex;
	bool					_stopped;
	
public:
	
	SynchroQueue(SynchroQueue const&) = delete;
	SynchroQueue() : _stopped(false) {}
	
	virtual void free(T*) = 0;
	
	virtual bool push(T* elem)
	{
		std::unique_lock<std::mutex> lock(this->_mutex);
		if (this->_stopped) {
			return false;
		} else {
			this->_queue.push_back(*elem);
			return true;
		}
	}
	
	virtual bool pop(T* elem)
	{
		std::unique_lock<std::mutex> lock(this->_mutex);
		if (this->_stopped) {
			return false;
		} else {
			if (!_queue.empty()) {
				*elem = _queue.front();
				_queue.pop_front();
			}
			return true;
		}
	}
	
	virtual void flush()
	{
		std::unique_lock<std::mutex> lock(this->_mutex);
		while (!_queue.empty()) {
			T elem = _queue.front();
			free(&elem);
			_queue.pop_front();
		}
	}
	
	bool front(T* elem)
	{
		std::unique_lock<std::mutex> lock(_mutex);
		if (!_queue.empty())
			return *elem = _queue.front(), true;
		return false;
	}
	
	void start()
	{
		_stopped = false;
	}
		
	void stop()
	{
		_stopped = true;
		flush();
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

template <class T>
class BlockedPopQueue : public SynchroQueue<T> {
protected:
	std::condition_variable _empty;
	
public:
	
	virtual bool push(T* elem)
	{
		std::unique_lock<std::mutex> lock(this->_mutex);
		if (this->_stopped) {
			return false;
		} else {
			this->_queue.push_back(*elem);
			_empty.notify_one();
			return true;
		}
	}
	
	virtual bool pop(T* elem)
	{
		std::unique_lock<std::mutex> lock(this->_mutex);
		_empty.wait(lock, [this]() { return (!this->_queue.empty() || this->_stopped);});
		if (this->_stopped) {
			return false;
		} else {
			*elem = this->_queue.front();
			this->_queue.pop_front();
			return true;
		}
	}

	virtual void flush()
	{
		std::unique_lock<std::mutex> lock(this->_mutex);
		while (!this->_queue.empty()) {
			T elem = this->_queue.front();
			free(&elem);
			this->_queue.pop_front();
		}
		_empty.notify_one();
	}
};

template <class T>
class BlockedQueue : public SynchroQueue<T> {
protected:
	int _maximum_size;
	std::condition_variable _empty;
	std::condition_variable _full;
	
public:
	BlockedQueue(int max) : SynchroQueue<T>(), _maximum_size(max) {}
	
	virtual bool push(T* elem)
	{
		std::unique_lock<std::mutex> lock(this->_mutex);
		_full.wait(lock, [this]() { return ((this->_queue.size() < _maximum_size) || this->_stopped);});
		if (this->_stopped) {
			return false;
		} else {
			this->_queue.push_back(*elem);
			_empty.notify_one();
			return true;
		}
	}
	
	virtual bool pop(T* elem)
	{
		std::unique_lock<std::mutex> lock(this->_mutex);
		_empty.wait(lock, [this]() { return (!this->_queue.empty() || this->_stopped);});
		if (this->_stopped) {
			return false;
		} else {
			*elem = this->_queue.front();
			this->_queue.pop_front();
			_full.notify_one();
			return true;
		}
	}
	
	virtual void flush()
	{
		std::unique_lock<std::mutex> lock(this->_mutex);
		while (!this->_queue.empty()) {
			T elem = this->_queue.front();
			free(&elem);
			this->_queue.pop_front();
		}
		_empty.notify_one();
		_full.notify_one();
	}
};

#endif /* defined(__npTV__PacketQueue__) */
