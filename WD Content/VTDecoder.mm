//
//  VTDecoder.m
//  DirectVideo
//
//  Created by Sergey Seitov on 03.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VTDecoder.h"
#import <VideoToolbox/VideoToolbox.h>
#include <mutex>

@interface VTDecoder () {
    VTDecompressionSessionRef _session;
    CMVideoFormatDescriptionRef _videoFormat;
	AVCodecContext* _context;
	std::mutex		_mutex;
}

@end

/* extradata
 
 bits
 8   version ( always 0x01 )
 8   avc profile ( sps[0][1] )
 8   avc compatibility ( sps[0][2] )
 8   avc level ( sps[0][3] )
 6   reserved ( all bits on )
 2   NALULengthSizeMinusOne
 3   reserved ( all bits on )
 5   number of SPS NALUs (usually 1)
 repeated once per SPS:
 16     SPS size
 variable   SPS NALU data
 8   number of PPS NALUs (usually 1)
 repeated once per PPS
 16    PPS size
 variable PPS NALU data
 
 */

static CMVideoFormatDescriptionRef CreateFormat(AVCodecContext* context)
{
	switch (context->codec_id) {
		case AV_CODEC_ID_MPEG4:
			/*			if (context->extradata_size) {
				return NO;
			 } else {
				format = CreateFormatDescription(kVTFormatMPEG4Video, theCodec->width, theCodec->height);
			 }*/
			NSLog(@"AV_CODEC_ID_MPEG4 not implemented yet");
			break;
		case AV_CODEC_ID_MPEG2VIDEO:
			//			format = CreateFormatDescription(kVTFormatMPEG2Video, theCodec->width, theCodec->height);
			NSLog(@"AV_CODEC_ID_MPEG2VIDEO not implemented yet");
			return NULL;
		case AV_CODEC_ID_H264:
		{
			uint16_t spsLen = NTOHS(*(uint16_t*)(context->extradata+6));
			const uint8_t *sps = context->extradata+8;
			
			uint16_t ppsLen = NTOHS(*((uint16_t*)(context->extradata+8+spsLen+1)));
			const uint8_t *pps = context->extradata+8+spsLen+3;
			
			const uint8_t* const parameterSetPointers[2] = { sps , pps };
			const size_t parameterSetSizes[2] = { spsLen, ppsLen };
			
			CMVideoFormatDescriptionRef format = NULL;
			OSStatus err = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
																			   2,
																			   parameterSetPointers,
																			   parameterSetSizes,
																			   4,
																			   &format);
			if (err != noErr) {
				return NULL;
			} else {
				return format;
			}
		}
			break;
		default:
			break;
	}
	return NULL;
}

void DeompressionDataCallbackHandler(void *decompressionOutputRefCon,
                                     void *sourceFrameRefCon,
                                     OSStatus status,
                                     VTDecodeInfoFlags infoFlags,
                                     CVImageBufferRef imageBuffer,
                                     CMTime presentationTimeStamp,
                                     CMTime presentationDuration );

@implementation VTDecoder

- (BOOL)openWithContext:(AVCodecContext*)context
{
	std::unique_lock<std::mutex> lock(_mutex);
	
	_videoFormat = CreateFormat(context);
	if (!_videoFormat) {
		return NO;
	}
	
    NSDictionary* destinationPixelBufferAttributes = @{
                                                       (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
                                                       (id)kCVPixelBufferWidthKey : [NSNumber numberWithInt:context->width],
                                                       (id)kCVPixelBufferHeightKey : [NSNumber numberWithInt:context->height],
                                                       (id)kCVPixelBufferOpenGLCompatibilityKey : [NSNumber numberWithBool:YES]
                                                       };

    VTDecompressionOutputCallbackRecord outputCallback;
    outputCallback.decompressionOutputCallback = DeompressionDataCallbackHandler;
    outputCallback.decompressionOutputRefCon = (__bridge void*)self;
    
    OSStatus status = VTDecompressionSessionCreate(NULL,
                                          _videoFormat,
                                          NULL,
                                          (__bridge CFDictionaryRef)destinationPixelBufferAttributes,
                                          &outputCallback,
                                          &_session);
    if (status == noErr) {
        VTSessionSetProperty(_session, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)[NSNumber numberWithInt:4]);
        VTSessionSetProperty(_session, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
		_context = context;
        return YES;
    } else {
        return NO;
    }
}

- (void)close
{
	std::unique_lock<std::mutex> lock(_mutex);
	if (_context) {
		avcodec_close(_context);
	}
	_context = NULL;
    if (_session) {
        VTDecompressionSessionInvalidate(_session);
        CFRelease(_session);
        _session = NULL;
    }
    if (_videoFormat) {
        CFRelease(_videoFormat);
        _videoFormat = NULL;
    }
}

- (BOOL)decodePacket:(AVPacket*)packet
{
	std::unique_lock<std::mutex> lock(_mutex);
	if (!_context) {
		return NO;
	}
	
	CMSampleTimingInfo timingInfo;
	timingInfo.presentationTimeStamp = CMTimeMake(packet->pts, 1000000.0*av_q2d(_context->time_base));
	timingInfo.duration = CMTimeMake(packet->duration, 1000000.0*av_q2d(_context->time_base));
	timingInfo.decodeTimeStamp = kCMTimeInvalid;

	CMSampleBufferRef sampleBuff = NULL;
 	CMBlockBufferRef newBBufOut = NULL;
	OSStatus err = CMBlockBufferCreateWithMemoryBlock(
													  NULL,             // CFAllocatorRef structureAllocator
													  packet->data,       // void *memoryBlock
													  packet->size,       // size_t blockLengt
													  kCFAllocatorNull, // CFAllocatorRef blockAllocator
													  NULL,             // const CMBlockBufferCustomBlockSource *customBlockSource
													  0,                // size_t offsetToData
													  packet->size,       // size_t dataLength
													  kCMBlockBufferAlwaysCopyDataFlag,            // CMBlockBufferFlags flags
													  &newBBufOut);     // CMBlockBufferRef *newBBufOut
	
	if (err != noErr) {
		return NO;
	}
	err = CMSampleBufferCreate(
							   kCFAllocatorDefault,           // CFAllocatorRef allocator
							   newBBufOut,     // CMBlockBufferRef dataBuffer
							   YES,           // Boolean dataReady
							   NULL,              // CMSampleBufferMakeDataReadyCallback makeDataReadyCallback
							   NULL,              // void *makeDataReadyRefcon
							   _videoFormat,       // CMFormatDescriptionRef formatDescription
							   1,              // CMItemCount numSamples
							   1,              // CMItemCount numSampleTimingEntries
							   &timingInfo,           // const CMSampleTimingInfo *sampleTimingArray
							   0,              // CMItemCount numSampleSizeEntries
							   NULL,           // const size_t *sampleSizeArray
							   &sampleBuff);      // CMSampleBufferRef *sBufOut
	CFRelease(newBBufOut);

	err = VTDecompressionSessionDecodeFrame(_session,
											sampleBuff,
											kVTDecodeFrame_EnableAsynchronousDecompression | kVTDecodeFrame_1xRealTimePlayback,
											sampleBuff,
											NULL);
    if (err != noErr) {
		CFRelease(sampleBuff);
		return NO;
    } else {
        VTDecompressionSessionWaitForAsynchronousFrames(_session);
		return YES;
    }
}

@end

void DeompressionDataCallbackHandler(void *decompressionOutputRefCon,
                                     void *sourceFrameRefCon,
                                     OSStatus status,
                                     VTDecodeInfoFlags infoFlags,
                                     CVImageBufferRef imageBuffer,
                                     CMTime presentationTimeStamp,
                                     CMTime presentationDuration )
{
    if (status == noErr) {
        VTDecoder* decoder = (__bridge VTDecoder*)decompressionOutputRefCon;
        CMVideoFormatDescriptionRef videoInfo = NULL;
        OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(NULL, imageBuffer, &videoInfo);
        if (status == noErr) {
            CMSampleBufferRef sampleBuffer = NULL;
			CMSampleTimingInfo timing;
			timing.presentationTimeStamp = presentationTimeStamp;
			timing.duration = presentationDuration;
			timing.decodeTimeStamp = presentationTimeStamp;
            status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                                        imageBuffer,
                                                        true,
                                                        NULL,
                                                        NULL,
                                                        videoInfo,
                                                        &timing,
                                                        &sampleBuffer);
            CFRelease(videoInfo);
            if (status == noErr) {
                [decoder.delegate videoDecoder:decoder decodedBuffer:sampleBuffer];
            }
        }
    }
    CMSampleBufferRef decodeBuffer = (CMSampleBufferRef)sourceFrameRefCon;
    CFRelease(decodeBuffer);
}
