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
#import "AudioDecoder.h"

static std::mutex audioMutex;

@interface AudioOutput () {
	
	AudioStreamBasicDescription			_dataFormat;
	AudioQueueRef						_queue;
    AudioQueueTimelineRef				_timeLine;
	AudioQueueBufferRef					_pool[AUDIO_POOL_SIZE];
}

@property (readwrite, nonatomic) AudioRingBuffer* ringBuffer;

@end

static void AudioOutputCallback(void *inClientData,
								AudioQueueRef inAQ,
								AudioQueueBufferRef inBuffer)
{
	AudioOutput* output = (__bridge AudioOutput*)inClientData;
	if (!readRingBuffer(output.ringBuffer, inBuffer)) {
		if (output.isReadyForMoreAudioData) {
			[output.delegate requestMoreAudioData:output];
		}
		if (!readRingBuffer(output.ringBuffer, inBuffer)) {
			memset(inBuffer->mAudioData, 0, output.ringBuffer->_bufferSize);
			inBuffer->mAudioDataByteSize = output.ringBuffer->_bufferSize;
		}
	}
	AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

@implementation AudioOutput

- (BOOL)isReadyForMoreAudioData
{
	if (_ringBuffer) {
		return !_ringBuffer->isFull();
	} else {
		return NO;
	}
}

- (void)currentPTS:(int64_t*)ppts withTime:(int64_t*)ptime
{
	if (_ringBuffer != NULL)
		ringBufferPTSWithTime(_ringBuffer, ppts, ptime);
	else {
		*ppts = AV_NOPTS_VALUE;
		*ptime = AV_NOPTS_VALUE;
	}
}

- (int64_t)currentPTS
{
	return (_ringBuffer ? ringBufferPTS(_ringBuffer) : AV_NOPTS_VALUE);
}

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
	
	if (frame->format == AV_SAMPLE_FMT_FLTP) {//
		_dataFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
	} else if (frame->format == AV_SAMPLE_FMT_S16) {
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
	} else {
		bufferSize = frame->nb_samples*sizeof(StereoFloatSample);
	}
	
	_ringBuffer = new AudioRingBuffer(AUDIO_POOL_SIZE, bufferSize, (AVSampleFormat)frame->format, frame->channels);
		
	AudioQueueNewOutput(&_dataFormat, AudioOutputCallback, (__bridge void*)self, NULL, 0, 0, &_queue);
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
	if (startResult != noErr) {
		NSLog(@"Audio not started, stopping");
		[self stop];
		return NO;
	} else {
		NSLog(@"Audio started");
		return YES;
	}
}

- (void)reset
{
	if (_ringBuffer) {
		resetRingBuffer(_ringBuffer);
	}
}

- (void)flush:(int64_t)pts
{
	if (_ringBuffer) {
		flushRingBuffer(_ringBuffer);
	}
}

- (void)stop
{
	if (!_started) return;
	
	AudioQueueStop(_queue, true);
	for (int i=0; i<AUDIO_POOL_SIZE; i++) {
		AudioQueueFreeBuffer(_queue, _pool[i]);
	}
	AudioQueueDispose(_queue, true);
	delete _ringBuffer;
	_ringBuffer = 0;
	
	_started = NO;
	NSLog(@"Audio stopped");
}

- (void)writeData:(uint8_t**)data numSamples:(int)numSamples withPts:(int64_t)pts
{
	std::unique_lock<std::mutex> lock(audioMutex);
	writeRingBuffer(_ringBuffer, data, numSamples, pts);
}

- (double)getCurrentTime
{
	if (_queue == NULL) return 0;
	
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

- (int)decodedPacketCount
{
	if (_ringBuffer == NULL) {
		return 0;
	} else {
		return ringBufferCount(_ringBuffer);
	}
}

@end
