//
//  AudioOutput.m
//  vTV
//
//  Created by Sergey Seitov on 13.08.13.
//  Copyright (c) 2013 V-Channel. All rights reserved.
//

#import "AudioOutput.h"
#include <AudioToolbox/AudioToolbox.h>
#include "AudioRingBuffer.h"

extern "C" {
#	include "libavcodec/avcodec.h"
#	include "libavformat/avformat.h"
};

#define AUDIO_POOL_SIZE 4

@interface AudioOutput () {

	AudioRingBuffer*					_ringBuffer;
	AudioStreamBasicDescription			_dataFormat;
	AudioQueueRef						_queue;
    AudioQueueTimelineRef				_timeLine;
	AudioQueueBufferRef					_pool[AUDIO_POOL_SIZE];
}

@end

static void AudioOutputCallback(void *inClientData,
								AudioQueueRef inAQ,
								AudioQueueBufferRef inBuffer)
{
	AudioRingBuffer *rb = (AudioRingBuffer*)inClientData;
	if (!readRingBuffer(rb, inBuffer)) {
		memset(inBuffer->mAudioData, 0, rb->_bufferSize);
		inBuffer->mAudioDataByteSize = rb->_bufferSize;
	}

	AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

@implementation AudioOutput

- (BOOL)startWithFrame:(AVFrame*)frame
{
	if (_started) return NO;
	
	_dataFormat.mFormatID = kAudioFormatLinearPCM;
	_dataFormat.mSampleRate = frame->sample_rate;
	_dataFormat.mBitsPerChannel = av_get_bytes_per_sample((AVSampleFormat)frame->format)*8;
	
	if (frame->channels > 2) {
		_dataFormat.mChannelsPerFrame = 2;
	} else {
		_dataFormat.mChannelsPerFrame = frame->channels;
	}
	
	if (frame->format == AV_SAMPLE_FMT_FLTP) {
		_dataFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
	} else if (frame->format == AV_SAMPLE_FMT_S16 || frame->format == AV_SAMPLE_FMT_S16P) {
		_dataFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	} else {
		NSLog(@"UNKNOWN SAMPLE FORMAT %d", frame->format);
		return NO;
	}
	
	_dataFormat.mBytesPerPacket = _dataFormat.mBytesPerFrame = (_dataFormat.mBitsPerChannel / 8) * _dataFormat.mChannelsPerFrame;
	_dataFormat.mFramesPerPacket = 1;
	
	int bufferSize;
	if (frame->channels == 1 || frame->format == AV_SAMPLE_FMT_S16) {
		bufferSize = av_samples_get_buffer_size(NULL, _dataFormat.mChannelsPerFrame, frame->nb_samples, (AVSampleFormat)frame->format, 1);
	} else if (frame->format == AV_SAMPLE_FMT_S16P) {
		bufferSize = frame->nb_samples*sizeof(StereoShortSample);
	} else {
		bufferSize = frame->nb_samples*sizeof(StereoFloatSample);
	}
	
	_ringBuffer = new AudioRingBuffer(AUDIO_POOL_SIZE, bufferSize);
		
	AudioQueueNewOutput(&_dataFormat, AudioOutputCallback, _ringBuffer, NULL, 0, 0, &_queue);
	AudioQueueSetParameter(_queue, kAudioQueueParam_Volume, 1.0);
	AudioQueueCreateTimeline(_queue, &_timeLine);
	
	for (int i=0; i<AUDIO_POOL_SIZE; i++) {
		AudioQueueAllocateBuffer(_queue, bufferSize, &_pool[i]);
		_pool[i]->mAudioDataByteSize = bufferSize;
		memset(_pool[i]->mAudioData, 0, bufferSize);
		AudioQueueEnqueueBuffer(_queue, _pool[i], 0, NULL);
	}
	OSStatus startResult = AudioQueueStart(_queue, 0);
	self.started = YES;
	if (startResult != 0) {
		NSLog(@"Audio not started, stopping");
		[self stop];
		return NO;
	} else {
		NSLog(@"Audio started");
		return YES;
	}
}

- (void)enqueueFrame:(AVFrame*)frame
{
	if (self.started) {
		writeRingBuffer(_ringBuffer, frame);
	}
}

- (void)stop
{
	if (!self.started) return;
	
	AudioQueueStop(_queue, true);
	for (int i=0; i<AUDIO_POOL_SIZE; i++) {
		AudioQueueFreeBuffer(_queue, _pool[i]);
	}
	AudioQueueDispose(_queue, true);
	delete _ringBuffer;
	_ringBuffer = 0;
	_queue = NULL;
	_started = NO;
	NSLog(@"Audio stopped");
}

- (void)pause:(BOOL)doPause
{
	if (self.started) {
		if (doPause) {
			AudioQueuePause(_queue);
		} else {
			AudioQueueStart(_queue, NULL);
		}
	}
}

- (double)getCurrentTime
{
	if (!self.started) return 0;
	
	AudioTimeStamp timeStamp;
	Boolean discontinuity;
	OSStatus err = AudioQueueGetCurrentTime(_queue, _timeLine, &timeStamp, &discontinuity);
	if (err == noErr && _dataFormat.mSampleRate != 0) {
		NSTimeInterval timeInterval = timeStamp.mSampleTime / _dataFormat.mSampleRate;
		return timeInterval;
	} else {
		return 0;
	}
}

@end
