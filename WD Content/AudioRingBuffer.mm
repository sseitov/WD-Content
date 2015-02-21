//
//  RingBuffer.cpp
//  vTV
//
//  Created by Sergey Seitov on 25.08.13.
//  Copyright (c) 2013 V-Channel. All rights reserved.
//

#include "AudioRingBuffer.h"

extern "C" {
#	include "libavcodec/avcodec.h"
#	include "libavformat/avformat.h"
};

AudioRingBuffer::AudioRingBuffer(int elementsCount, int bufferSize)
:_count(elementsCount+1), _bufferSize(bufferSize), _start(0), _end(0), _stopped(false)
{
	_data = (char*)calloc(_count, _bufferSize);
}

AudioRingBuffer::~AudioRingBuffer()
{
	free(_data);
}

bool readRingBuffer(AudioRingBuffer* rb, AudioQueueBufferRef& buffer)
{
	std::unique_lock<std::mutex> lock(rb->_mutex);
	if (!rb->_overflow.wait_for(lock,  std::chrono::milliseconds(10), [&rb]() { return (!rb->isEmpty() || rb->_stopped);})) {
		return false;
	}
	if (rb->_stopped) return false;
	
	buffer->mAudioDataByteSize = rb->_bufferSize;
	memcpy(buffer->mAudioData, rb->_data + rb->_start*rb->_bufferSize, rb->_bufferSize);
	
	rb->_start = (rb->_start + 1) % rb->_count;
	rb->_overflow.notify_one();
	
	return true;
}

void writeRingBuffer(AudioRingBuffer* rb, AVFrame* audioFrame)
{
	std::unique_lock<std::mutex> lock(rb->_mutex);
	rb->_overflow.wait(lock, [&rb]() { return (!rb->isFull() || rb->_stopped);});
	if (rb->_stopped) return;

	char *output = rb->_data + rb->_end*rb->_bufferSize;
	
	if (audioFrame->channels == 1 || audioFrame->format == AV_SAMPLE_FMT_S16) {
		memcpy(output, audioFrame->data[0], rb->_bufferSize);
	} else if (audioFrame->format == AV_SAMPLE_FMT_S16P) {
		StereoShortSample* outputBuffer = (StereoShortSample*)output;
		uint16_t* leftChannel = (uint16_t*)audioFrame->data[0];
		uint16_t* rightChannel = (uint16_t*)audioFrame->data[1];
		for (int i=0; i<audioFrame->nb_samples; i++) {
			outputBuffer[i].left = leftChannel[i];
			outputBuffer[i].right = rightChannel[i];
		}
	} else { // downmix float multichannel
		StereoFloatSample* outputBuffer = (StereoFloatSample*)output;
		if (audioFrame->channels == 6) {
			float* leftChannel = (float*)audioFrame->data[0];
			float* rightChannel = (float*)audioFrame->data[1];
			float* centerChannel = (float*)audioFrame->data[2];
			float* leftBackChannel = (float*)audioFrame->data[3];
			float* rightBackChannel = (float*)audioFrame->data[4];
			float* lfeChannel = (float*)audioFrame->data[5];
			for (int i=0; i<audioFrame->nb_samples; i++) {
				outputBuffer[i].left = leftChannel[i] + centerChannel[i]/2.0 + lfeChannel[i]/2.0 + (-leftBackChannel[i] - rightBackChannel[i])/2.0;
				outputBuffer[i].right = rightChannel[i] + centerChannel[i]/2.0 + lfeChannel[i]/2.0 + (leftBackChannel[i] + rightBackChannel[i])/2.0;
			}
		} else if (audioFrame->channels == 2) {
			float* leftChannel = (float*)audioFrame->data[0];
			float* rightChannel = (float*)audioFrame->data[1];
			for (int i=0; i<audioFrame->nb_samples; i++) {
				outputBuffer[i].left = leftChannel[i];
				outputBuffer[i].right = rightChannel[i];
			}
		}
	}
    rb->_end = (rb->_end + 1) % rb->_count;
}
