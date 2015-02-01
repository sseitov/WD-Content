//
//  AudioUnitOutput.m
//  WD Content
//
//  Created by Sergey Seitov on 01.02.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "AudioUnitOutput.h"
#include <AudioToolbox/AudioToolbox.h>

@interface AudioUnitOutput () {
	AUGraph auGraph;
	AudioStreamBasicDescription mFormat;
	AVFrame* lastFrame;
	int lastOffset;
}

- (void)fillSamples:(int)numSamples inBufferList:(AudioBufferList*)list;

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
/*
struct AudioBuffer
{
	UInt32  mNumberChannels;
	UInt32  mDataByteSize;
	void*   mData;
};
*/
static OSStatus converterRenderCallback(void *inRefCon,
										AudioUnitRenderActionFlags *ioActionFlags,
										const AudioTimeStamp *inTimeStamp,
										UInt32 inBusNumber,
										UInt32 inNumberFrames,
										AudioBufferList *ioData)
{
	AudioUnitOutput *output = (__bridge AudioUnitOutput*)inRefCon;
	[output fillSamples:inNumberFrames inBufferList:ioData];
	return noErr;
}

@implementation AudioUnitOutput

int fillListFromFrame(AudioBufferList* list, int dstOffset, AVFrame *frame, int srcOffset, int count, int frameSize)
{
	int rest = (frame->nb_samples > count) ? (frame->nb_samples - count) : count;
	for (int buffer = 0; buffer < list->mNumberBuffers; buffer++) {
		uint8_t* pDst = (uint8_t*)(list->mBuffers[buffer].mData) + dstOffset*frameSize;
		uint8_t* pSrc = (uint8_t*)(frame->data[buffer]) + srcOffset*frameSize;
		memcpy(pDst, pSrc, rest*frameSize);
	}
	return (rest - count);
}

- (void)fillSamples:(int)numSamples inBufferList:(AudioBufferList*)list
{
/*
	int rest = 0;
	if (lastFrame) {
		rest = fillListFromFrame(list, 0, lastFrame, lastOffset, numSamples, mFormat.mBytesPerPacket);
		av_frame_free(&lastFrame);
		lastFrame = nil;
	}
	numSamples -= rest;
	if (numSamples > 0) {
		[self.delegate requestMoreData:^(AVFrame* frame) {
			if (frame) {
				int count = fillListFromFrame(list, rest, frame, 0, numSamples, mFormat.mBytesPerPacket);
				if (count < numSamples) {
					lastFrame = frame;
					lastOffset = count;
				} else {
					av_frame_free(&frame);
				}
			}
		}];
	}
*/
	NSLog(@"fill %d samples", numSamples);
	[self.delegate requestMoreData:^(AVFrame* frame) {
		if (frame) {
			av_frame_free(&frame);
		}
	}];

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
	
	// Apply format
	AudioStreamBasicDescription desc;
	UInt32 size = sizeof(desc);
	CheckError(AudioUnitGetProperty(outputUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Input,
									0,
									&desc,
									&size), "AudioUnitSetProperty kAudioUnitProperty_StreamFormat for output input failed");
	
	CheckError(AudioUnitSetProperty(converterUnit,
									kAudioUnitProperty_StreamFormat,
									kAudioUnitScope_Output,
									0,
									&desc,
									size), "AudioUnitSetProperty kAudioUnitProperty_StreamFormat for converter output failed");

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
	
	// Set output callback
	AURenderCallbackStruct callbackStruct;
	callbackStruct.inputProc = converterRenderCallback;
	callbackStruct.inputProcRefCon = (__bridge void*)self;
	CheckError(AudioUnitSetProperty(converterUnit,
									kAudioUnitProperty_SetRenderCallback,
									kAudioUnitScope_Global,
									0,
									&callbackStruct,
									sizeof(callbackStruct)), "AudioUnitSetProperty kAudioUnitProperty_SetRenderCallback failed");
	
	lastFrame = NULL;
	// Initialise & start
	CheckError(AUGraphInitialize(auGraph), "AUGraphInitialize failed");
	CheckError(AUGraphStart(auGraph), "AUGraphStart failed");
	
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
