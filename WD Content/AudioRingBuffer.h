//
//  RingBuffer.h
//  vTV
//
//  Created by Sergey Seitov on 25.08.13.
//  Copyright (c) 2013 V-Channel. All rights reserved.
//

#ifndef __vTV__RingBuffer__
#define __vTV__RingBuffer__

#include <AudioToolbox/AudioToolbox.h>
#include <mutex>

struct StereoShortSample
{
	uint16_t left;
	uint16_t right;
};

struct StereoFloatSample
{
	float left;
	float right;
};

struct AudioRingBuffer
{
    int						_count;			// maximum number of elements
	int						_bufferSize;	// size element of data
    int						_start;			// index of oldest element
    int						_end;			// index at which to write new element
	bool					_stopped;
    char*					_data;			// raw data
	
	std::mutex				_mutex;
	std::condition_variable _overflow;
	
	AudioRingBuffer(int elementsCount, int bufferSize);
	~AudioRingBuffer();
	
	bool isFull() { return (_end + 1) % _count == _start; }
	bool isEmpty() { return _end == _start; }
};

struct AVFrame;

bool readRingBuffer(AudioRingBuffer* rb, AudioQueueBufferRef& buffer);
void writeRingBuffer(AudioRingBuffer* rb, AVFrame* audioFrame);

#endif /* defined(__vTV__RingBuffer__) */
