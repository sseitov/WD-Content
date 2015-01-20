//
//  RingBuffer.cpp
//  vTV
//
//  Created by Sergey Seitov on 25.08.13.
//  Copyright (c) 2013 V-Channel. All rights reserved.
//

#include "AudioRingBuffer.h"
#include <mach/mach_time.h>

static int64_t getUptimeInMilliseconds()
{
	const int64_t kOneMillion = 1000 * 1000;
	static mach_timebase_info_data_t s_timebase_info;
	
	if (s_timebase_info.denom == 0) {
		(void) mach_timebase_info(&s_timebase_info);
	}
	
	// mach_absolute_time() returns billionth of seconds,
	// so divide by one million to get milliseconds
	return (int64_t)((mach_absolute_time() * s_timebase_info.numer) / (kOneMillion * s_timebase_info.denom));
}

AudioRingBuffer::AudioRingBuffer(int elementsCount, int bufferSize, AVSampleFormat format, int num_channels)
:_count(elementsCount+1), _bufferSize(bufferSize), _format(format), _num_channels(num_channels), _start(0), _end(0), _stopped(false)
{
	_data = (char*)calloc(_count, _bufferSize);
	_framePTS = (int64_t*)calloc(_count, sizeof(int64_t));
	for (int i=0; i<_count; i++) {
		_framePTS[i] = AV_NOPTS_VALUE;
	}
	_currentPTSTime = _currentPTS = AV_NOPTS_VALUE;
}

AudioRingBuffer::~AudioRingBuffer()
{
	free(_data);
	free(_framePTS);
}

bool readRingBuffer(AudioRingBuffer* rb, AudioQueueBufferRef& buffer)
{
	std::unique_lock<std::mutex> lock(rb->_mutex);
	if (!rb->_overflow.wait_for(lock,  std::chrono::milliseconds(10), [&rb]() { return (!rb->isEmpty() || rb->_stopped);})) {
		rb->_currentPTS = AV_NOPTS_VALUE;
		rb->_currentPTSTime = AV_NOPTS_VALUE;
		return false;
	}
	if (rb->_stopped) return false;
	
	buffer->mAudioDataByteSize = rb->_bufferSize;
	memcpy(buffer->mAudioData, rb->_data + rb->_start*rb->_bufferSize, rb->_bufferSize);
	rb->_currentPTS = rb->_framePTS[rb->_start];
	rb->_currentPTSTime = getUptimeInMilliseconds();
	
	rb->_start = (rb->_start + 1) % rb->_count;
	rb->_overflow.notify_one();
	
	return true;
}

void writeRingBuffer(AudioRingBuffer* rb, uint8_t* data[], int numSamples, int64_t pts)
{
	std::unique_lock<std::mutex> lock(rb->_mutex);
	rb->_overflow.wait(lock, [&rb]() { return (!rb->isFull() || rb->_stopped);});
	if (rb->_stopped) return;

	char *output = rb->_data + rb->_end*rb->_bufferSize;
	
	if (rb->_num_channels == 1 || rb->_format == AV_SAMPLE_FMT_S16) {
		memcpy(output, data[0], rb->_bufferSize);
	} else { // downmix float multichannel
		StereoFloatSample* outputBuffer = (StereoFloatSample*)output;
		if (rb->_num_channels == 6) {
			float* leftChannel = (float*)data[0];
			float* rightChannel = (float*)data[1];
			float* centerChannel = (float*)data[2];
			float* leftBackChannel = (float*)data[3];
			float* rightBackChannel = (float*)data[4];
			float* lfeChannel = (float*)data[5];
			for (int i=0; i<numSamples; i++) {
				outputBuffer[i].left = leftChannel[i] + centerChannel[i]/2.0 + lfeChannel[i]/2.0 + (-leftBackChannel[i] - rightBackChannel[i])/2.0;
				outputBuffer[i].right = rightChannel[i] + centerChannel[i]/2.0 + lfeChannel[i]/2.0 + (leftBackChannel[i] + rightBackChannel[i])/2.0;
			}
		} else if (rb->_num_channels == 2) {
			float* leftChannel = (float*)data[0];
			float* rightChannel = (float*)data[1];
			for (int i=0; i<numSamples; i++) {
				outputBuffer[i].left = leftChannel[i];
				outputBuffer[i].right = rightChannel[i];
			}
		}
	}
	rb->_framePTS[rb->_end] = pts;
    rb->_end = (rb->_end + 1) % rb->_count;
}

void resetRingBuffer(AudioRingBuffer* rb)
{
	std::unique_lock<std::mutex> lock(rb->_mutex);
	rb->_stopped = true;
	rb->_overflow.notify_one();
}

void flushRingBuffer(AudioRingBuffer* rb)
{
	std::unique_lock<std::mutex> lock(rb->_mutex);
	rb->_start = rb->_end = 0;
	rb->_overflow.notify_one();
}

void ringBufferPTSWithTime(AudioRingBuffer* rb, int64_t* ppts, int64_t* ptime)
{
	std::unique_lock<std::mutex> lock(rb->_mutex);
	*ppts = rb->_currentPTS;
	*ptime = rb->_currentPTSTime;
}

int64_t ringBufferPTS(AudioRingBuffer* rb)
{
	std::unique_lock<std::mutex> lock(rb->_mutex);
	return rb->_currentPTS;
}

int ringBufferCount(AudioRingBuffer* rb)
{
	if (rb->_end > rb->_start) {
		return rb->_end - rb->_start;
	} else {
		return rb->_end + rb->_count - rb->_start;
	}
}
