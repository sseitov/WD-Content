//
//  AudioUnitOutput.m
//  WD Content
//
//  Created by Sergey Seitov on 01.02.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "AudioUnitOutput.h"
#include <AudioToolbox/AudioToolbox.h>

extern "C" {
#	include "libavcodec/avcodec.h"
#	include "libavformat/avformat.h"
};

@interface AudioUnitOutput () {
	AUGraph auGraph;
	AudioStreamBasicDescription mFormat;
	AVFrame* _lastFrame;
	int _lastOffset;
}

- (void)fillBufferList:(AudioBufferList*)list;

@end

#define CheckError(a,b) if(HasError(a, b)) return NO;

static BOOL HasError(OSStatus error, const char *operation)
{
	if (error == noErr) return NO;
	
	char errorString[20];
	*(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
	if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
		errorString[0] = errorString[5] = '\'';
		errorString[6] = '\0';
	} else {
		snprintf(errorString, sizeof(errorString), "%d", (int)error);
	}
	NSLog(@"Error: %s (%s)\n", operation, errorString);
	return YES;
}

static OSStatus converterRenderCallback(void *inRefCon,
										AudioUnitRenderActionFlags *ioActionFlags,
										const AudioTimeStamp *inTimeStamp,
										UInt32 inBusNumber,
										UInt32 inNumberFrames,
										AudioBufferList *ioData)
{
	AudioUnitOutput *output = (__bridge AudioUnitOutput*)inRefCon;
	[output fillBufferList:ioData];
	return noErr;
}

@implementation AudioUnitOutput

- (BOOL)getLastFrame
{
	[self.delegate requestNextFrame:^(AVFrame* frame) {
		if (_lastFrame) {
			av_frame_free(&_lastFrame);
		}
		_lastFrame = frame;
		_lastOffset = 0;
	}];
	return (_lastFrame != NULL);
}

- (void)fillBufferList:(AudioBufferList*)list
{
	if (!_lastFrame) {
		if (![self getLastFrame]) return;
	}
	
	int restBytes = _lastFrame->linesize[0] - _lastOffset;
	int bufferSize = list->mBuffers[0].mDataByteSize;
	if (restBytes >= bufferSize) {
		for (int i=0; i<list->mNumberBuffers; i++) {
//			uint8_t *pData = (uint8_t*)list->mBuffers[i].mData;
//			memcpy(pData, _lastFrame->data[i] + _lastOffset, bufferSize);
			list->mBuffers[i].mData = _lastFrame->data[i] + _lastOffset;
		}
		_lastOffset += bufferSize;
	} else {
		for (int i=0; i<list->mNumberBuffers; i++) {
			uint8_t *pData = (uint8_t*)list->mBuffers[i].mData;
			memcpy(pData, _lastFrame->data[i] + _lastOffset, restBytes);
		}
		bufferSize -= restBytes;
		if (![self getLastFrame]) return;
		for (int i=0; i<list->mNumberBuffers; i++) {
			uint8_t *pData = (uint8_t*)list->mBuffers[i].mData+restBytes;
			memcpy(pData, _lastFrame->data[i], bufferSize);
		}
		_lastOffset = bufferSize;
	}
}

- (BOOL)startWithFrame:(AVFrame*)frame
{
	CheckError(NewAUGraph(&auGraph), "NewAUGraph failed");
	
	// output component
	AudioComponentDescription output_desc;
	output_desc.componentType = kAudioUnitType_Output;
	output_desc.componentSubType = kAudioUnitSubType_RemoteIO;
	output_desc.componentFlags = 0;
	output_desc.componentFlagsMask = 0;
	output_desc.componentManufacturer = kAudioUnitManufacturer_Apple;

	// converter component
	AudioComponentDescription converter_desc;
	converter_desc.componentType = kAudioUnitType_FormatConverter;
	converter_desc.componentSubType = kAudioUnitSubType_AUConverter;
	converter_desc.componentFlags = 0;
	converter_desc.componentFlagsMask = 0;
	converter_desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	
	// Get components
	AUNode outputNode;
	AUNode converterNode;
	CheckError(AUGraphAddNode(auGraph, &output_desc, &outputNode), "AUGraphAddNode outputNode failed");
	CheckError(AUGraphAddNode(auGraph, &converter_desc, &converterNode), "AUGraphAddNode converterNode failed");

	// Connect the converter node's output to the output node's input
	CheckError(AUGraphConnectNodeInput(auGraph, converterNode, 0, outputNode, 0), "AUGraphConnectNodeInput failed");

	// Open the graph and get link to units
	CheckError(AUGraphOpen(auGraph), "AUGraphOpen failed");
	AudioUnit outputUnit;
	AudioUnit converterUnit;
	CheckError(AUGraphNodeInfo(auGraph, outputNode, NULL, &outputUnit), "AUGraphNodeInfo outputNode failed");
	CheckError(AUGraphNodeInfo(auGraph, converterNode, NULL, &converterUnit), "AUGraphNodeInfo converterNode failed");
	
	// Enable output for playback
	UInt32 flag = 1;
	CheckError(AudioUnitSetProperty(outputUnit,
									kAudioOutputUnitProperty_EnableIO,
									kAudioUnitScope_Output,
									0,
									&flag,
									sizeof(flag)), "AudioUnitSetProperty kAudioOutputUnitProperty_EnableIO failed");

	// Apply output sample rate
	AudioStreamBasicDescription desc;
	UInt32 size = sizeof(desc);
	CheckError(AudioUnitGetProperty(outputUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Input,
									0,
									&desc,
									&size), "AudioUnitSetProperty kAudioUnitProperty_StreamFormat for output input failed");
	
	desc.mSampleRate = frame->sample_rate;
	
	CheckError(AudioUnitSetProperty(outputUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Input,
									0,
									&desc,
									size), "AudioUnitSetProperty kAudioUnitProperty_StreamFormat for converter output failed");
	CheckError(AudioUnitSetProperty(outputUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Output,
									1,
									&desc,
									size), "AudioUnitSetProperty kAudioUnitProperty_StreamFormat for input failed");

	// Fill audio format from AVFRame
	memset(&mFormat, 0, sizeof(mFormat));
	
	mFormat.mFormatID			= kAudioFormatLinearPCM;
	mFormat.mChannelsPerFrame	= frame->channels;
	mFormat.mSampleRate			= frame->sample_rate;

	switch(frame->format) {
			
		case AV_SAMPLE_FMT_U8P:
			mFormat.mFormatFlags		= kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
			mFormat.mBitsPerChannel		= 8;
			mFormat.mBytesPerPacket		= (mFormat.mBitsPerChannel / 8);
			mFormat.mFramesPerPacket	= 1;
			mFormat.mBytesPerFrame		= mFormat.mBytesPerPacket * mFormat.mFramesPerPacket;
			break;
			
		case AV_SAMPLE_FMT_U8:
			mFormat.mFormatFlags		= kAudioFormatFlagIsPacked;
			mFormat.mBitsPerChannel		= 8;
			mFormat.mBytesPerPacket		= (mFormat.mBitsPerChannel / 8) * mFormat.mChannelsPerFrame;
			mFormat.mFramesPerPacket	= 1;
			mFormat.mBytesPerFrame		= mFormat.mBytesPerPacket * mFormat.mFramesPerPacket;
			break;
			
		case AV_SAMPLE_FMT_S16P:
			mFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
			mFormat.mBitsPerChannel		= 16;
			mFormat.mBytesPerPacket		= (mFormat.mBitsPerChannel / 8);
			mFormat.mFramesPerPacket	= 1;
			mFormat.mBytesPerFrame		= mFormat.mBytesPerPacket * mFormat.mFramesPerPacket;
			break;
			
		case AV_SAMPLE_FMT_S16:
			mFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
			mFormat.mBitsPerChannel		= 16;
			mFormat.mBytesPerPacket		= (mFormat.mBitsPerChannel / 8) * mFormat.mChannelsPerFrame;
			mFormat.mFramesPerPacket	= 1;
			mFormat.mBytesPerFrame		= mFormat.mBytesPerPacket * mFormat.mFramesPerPacket;
			break;
			
		case AV_SAMPLE_FMT_S32P:
			mFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
			mFormat.mBitsPerChannel		= 32;
			mFormat.mBytesPerPacket		= (mFormat.mBitsPerChannel / 8);
			mFormat.mFramesPerPacket	= 1;
			mFormat.mBytesPerFrame		= mFormat.mBytesPerPacket * mFormat.mFramesPerPacket;
			break;
			
		case AV_SAMPLE_FMT_S32:
			mFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
			mFormat.mBitsPerChannel		= 32;
			mFormat.mBytesPerPacket		= (mFormat.mBitsPerChannel / 8) * mFormat.mChannelsPerFrame;
			mFormat.mFramesPerPacket	= 1;
			mFormat.mBytesPerFrame		= mFormat.mBytesPerPacket * mFormat.mFramesPerPacket;
			break;
			
		case AV_SAMPLE_FMT_FLTP:
			mFormat.mFormatFlags		= kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
			mFormat.mBitsPerChannel		= 8 * sizeof(float);
			mFormat.mBytesPerPacket		= (mFormat.mBitsPerChannel / 8);
			mFormat.mFramesPerPacket	= 1;
			mFormat.mBytesPerFrame		= mFormat.mBytesPerPacket * mFormat.mFramesPerPacket;
			break;
			
		case AV_SAMPLE_FMT_FLT:
			mFormat.mFormatFlags		= kAudioFormatFlagsNativeFloatPacked;
			mFormat.mBitsPerChannel		= 8 * sizeof(float);
			mFormat.mBytesPerPacket		= (mFormat.mBitsPerChannel / 8) * mFormat.mChannelsPerFrame;
			mFormat.mFramesPerPacket	= 1;
			mFormat.mBytesPerFrame		= mFormat.mBytesPerPacket * mFormat.mFramesPerPacket;
			break;
			
		case AV_SAMPLE_FMT_DBLP:
			mFormat.mFormatFlags		= kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
			mFormat.mBitsPerChannel		= 8 * sizeof(double);
			mFormat.mBytesPerPacket		= (mFormat.mBitsPerChannel / 8);
			mFormat.mFramesPerPacket	= 1;
			mFormat.mBytesPerFrame		= mFormat.mBytesPerPacket * mFormat.mFramesPerPacket;
			break;
			
		case AV_SAMPLE_FMT_DBL:
			mFormat.mFormatFlags		= kAudioFormatFlagsNativeFloatPacked;
			mFormat.mBitsPerChannel		= 8 * sizeof(double);
			mFormat.mBytesPerPacket		= (mFormat.mBitsPerChannel / 8) * mFormat.mChannelsPerFrame;
			mFormat.mFramesPerPacket	= 1;
			mFormat.mBytesPerFrame		= mFormat.mBytesPerPacket * mFormat.mFramesPerPacket;
			break;
			
		default:
			NSLog(@"Unknown audio sample format");
			return NO;
	}

	CheckError(AudioUnitSetProperty(converterUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Input,
									0,
									&mFormat,
									sizeof(mFormat)), "AudioUnitSetProperty kAudioUnitProperty_StreamFormat for converter input failed");
	CheckError(AudioUnitSetProperty(converterUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Output,
									0,
									&desc,
									sizeof(desc)), "AudioUnitSetProperty kAudioUnitProperty_StreamFormat for converter output failed");
	
	// Set output callback
	AURenderCallbackStruct converterCallbackStruct;
	converterCallbackStruct.inputProc = converterRenderCallback;
	converterCallbackStruct.inputProcRefCon = (__bridge void*)self;
	CheckError(AudioUnitSetProperty(converterUnit,
									kAudioUnitProperty_SetRenderCallback,
									kAudioUnitScope_Global,
									0,
									&converterCallbackStruct,
									sizeof(converterCallbackStruct)), "AudioUnitSetProperty kAudioUnitProperty_SetRenderCallback failed");
	
	// Initialise & start
	CheckError(AUGraphInitialize(auGraph), "AUGraphInitialize failed");
	CheckError(AUGraphStart(auGraph), "AUGraphStart failed");
	
	_lastFrame = frame;
	self.started = YES;
	
	return YES;
}

- (BOOL)stop
{
	CheckError(AUGraphStop(auGraph), "AUGraphStop failed");
	CheckError(AUGraphUninitialize(auGraph), "AUGraphUninitialize failed");
	CheckError(AUGraphClose(auGraph), "AUGraphClose failed");
	self.started = NO;
	return YES;
}

@end
