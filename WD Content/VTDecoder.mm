//
//  VTDecoder.m
//  DirectVideo
//
//  Created by Sergey Seitov on 03.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VTDecoder.h"
#import <VideoToolbox/VideoToolbox.h>
#include "ConditionLock.h"

#include <queue>
#include <mutex>

extern "C" {
#	include "VideoUtility.h"
#	include "libavcodec/avcodec.h"
}

static NSData* esdsInfo(uint8_t* data, int size)
{
	AVIOContext *pb;
	quicktime_esds_t *esds;
	
	if (avio_open_dyn_buf(&pb) < 0)
		return nil;
	
	esds = quicktime_set_esds(data, size);
	quicktime_write_esds(pb, esds);
	
	// unhook from ffmpeg's extradata
	data = NULL;
	// extract the esds atom decoderConfig from extradata
	size = avio_close_dyn_buf(pb, &data);
	free(esds->decoderConfig);
	free(esds);
	
	NSData* info = [NSData dataWithBytes:data length:size];
	av_free(data);
	
	return info;
}

void DeompressionDataCallbackHandler(void *decompressionOutputRefCon,
                                     void *sourceFrameRefCon,
                                     OSStatus status,
                                     VTDecodeInfoFlags infoFlags,
                                     CVImageBufferRef imageBuffer,
                                     CMTime presentationTimeStamp,
                                     CMTime presentationDuration );


@interface VTDecoder () {
	std::queue<CMSampleBufferRef>	_queue;
	std::mutex						_mutex;

	VTDecompressionSessionRef _session;
	CMVideoFormatDescriptionRef _videoFormat;
	bool convert_byte_stream;
	bool was_pts;
}

@property (strong, nonatomic) NSCondition* decoderCondition;

@end

@implementation VTDecoder

- (id)init
{
	self = [super init];
	if (self) {
		self.decoderThread = dispatch_queue_create("com.vchannel.WD-Content.VideoDecoder", DISPATCH_QUEUE_SERIAL);
		_decoderCondition = [[NSCondition alloc] init];
	}
	return self;
}

- (NSString*)name
{
	return @"VideoDecoder";
}

- (BOOL)openWithContext:(AVCodecContext*)context
{
	OSStatus status;
	convert_byte_stream = false;
	
	switch (context->codec_id) {
		case AV_CODEC_ID_MPEG4:
			NSLog(@"AV_CODEC_ID_MPEG4");
			if (context->extradata_size) {
				NSData* info = esdsInfo(context->extradata, context->extradata_size);
				if (info) {
					NSDictionary *extradata_info = @{ @"esds" : info};
					NSDictionary *decoderConfiguration = @{(id)kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms : extradata_info};
					status = CMVideoFormatDescriptionCreate(NULL, kCMVideoCodecType_MPEG4Video, context->width, context->height,
														 (__bridge CFDictionaryRef)decoderConfiguration, &_videoFormat);
					if (status != noErr) {
						return NO;
					}
				}
			} else {
				status = CMVideoFormatDescriptionCreate(NULL, kCMVideoCodecType_MPEG4Video, context->width, context->height, NULL, &_videoFormat);
				if (status != noErr) {
					return NO;
				}
			}
			break;
		case AV_CODEC_ID_MPEG2VIDEO:
			NSLog(@"AV_CODEC_ID_MPEG2VIDEO NOT SUPPORTED");
			return NO;
		case AV_CODEC_ID_H264:
		{
			NSLog(@"AV_CODEC_ID_H264");
			uint8_t* extradata = NULL;
			convert_byte_stream = convertAvcc(context->extradata, context->extradata_size, &extradata);
			
			SpsHeader spsHeader = *((SpsHeader*)extradata);
			uint16_t spsLen = NTOHS(spsHeader.SPS_size);
			const uint8_t *sps = extradata+sizeof(SpsHeader);
			
			PpsHeader ppsHeader = *((PpsHeader*)(extradata + sizeof(SpsHeader)+spsLen));
			uint16_t ppsLen = NTOHS(ppsHeader.PPS_size);
			const uint8_t *pps = extradata+sizeof(SpsHeader)+spsLen+sizeof(PpsHeader);
			
			const uint8_t* const parameterSetPointers[2] = { sps , pps };
			const size_t parameterSetSizes[2] = { spsLen, ppsLen };
			
			status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
																	  2,
																	  parameterSetPointers,
																	  parameterSetSizes,
																	  4,
																	  &_videoFormat);
			if (status != noErr) {
				return NO;
			}
		}
			break;
		default:
			NSLog(@"AV_CODEC_ %d NOT SUPPORTED", context->codec_id);
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
	
	status = VTDecompressionSessionCreate(NULL,
										  _videoFormat,
										  NULL,
										  (__bridge CFDictionaryRef)destinationPixelBufferAttributes,
										  &outputCallback,
										  &_session);
    if (status == noErr) {
        VTSessionSetProperty(_session, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)[NSNumber numberWithInt:4]);
        VTSessionSetProperty(_session, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
		self.context = context;
		was_pts = false;
        return YES;
    } else {
        return NO;
    }
}

- (void)stop
{
	[_decoderCondition lock];
	self.stopped = YES;
	[_decoderCondition signal];
	[_decoderCondition unlock];
	
	[super stop];
}

- (void)close
{
	[super close];
	
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

- (void)decodePacket:(AVPacket*)packet
{
	if (!was_pts && packet->pts != AV_NOPTS_VALUE) {
		was_pts = true;
	}
	
	double pts_scale = av_q2d(self.context->pkt_timebase) / (1.0/25.0);
	int64_t pts = was_pts ? packet->pts : packet->dts;
	pts = (pts == AV_NOPTS_VALUE) ? AV_NOPTS_VALUE : pts*pts_scale;
	
	CMSampleTimingInfo timingInfo;
	timingInfo.presentationTimeStamp = CMTimeMake(pts, 1);
	timingInfo.duration = CMTimeMake(1, 1);
	timingInfo.decodeTimeStamp = kCMTimeInvalid;
	
	int demux_size = 0;
	uint8_t *demux_buff = NULL;
	if (convert_byte_stream) {
		// convert demuxer packet from bytestream (AnnexB) to bitstream
		AVIOContext *pb = NULL;
		if(avio_open_dyn_buf(&pb) < 0)
			return;
		demux_size = avc_parse_nal_units(pb, packet->data, packet->size);
		demux_size = avio_close_dyn_buf(pb, &demux_buff);

	} else {
		demux_buff = packet->data;
		demux_size = packet->size;
	}
	
	CMBlockBufferRef newBBufOut = NULL;
	OSStatus err = noErr;
	err = CMBlockBufferCreateWithMemoryBlock(
											 NULL,             // CFAllocatorRef structureAllocator
											 demux_buff,       // void *memoryBlock
											 demux_size,       // size_t blockLengt
											 kCFAllocatorNull, // CFAllocatorRef blockAllocator
											 NULL,             // const CMBlockBufferCustomBlockSource *customBlockSource
											 0,                // size_t offsetToData
											 demux_size,       // size_t dataLength
											 kCMBlockBufferAlwaysCopyDataFlag,            // CMBlockBufferFlags flags
											 &newBBufOut);     // CMBlockBufferRef *newBBufOut
	
	if (err != noErr) {
		NSLog(@"error CMBlockBufferCreateWithMemoryBlock");
		return;
	}
	
	CMSampleBufferRef sampleBuff = NULL;
	err = CMSampleBufferCreate(
							   kCFAllocatorDefault,		// CFAllocatorRef allocator
							   newBBufOut,				// CMBlockBufferRef dataBuffer
							   YES,						// Boolean dataReady
							   NULL,					// CMSampleBufferMakeDataReadyCallback makeDataReadyCallback
							   NULL,					// void *makeDataReadyRefcon
							   _videoFormat,			// CMFormatDescriptionRef formatDescription
							   1,						// CMItemCount numSamples
							   1,						// CMItemCount numSampleTimingEntries
							   &timingInfo,				// const CMSampleTimingInfo *sampleTimingArray
							   0,						// CMItemCount numSampleSizeEntries
							   NULL,					// const size_t *sampleSizeArray
							   &sampleBuff);			// CMSampleBufferRef *sBufOut
	if (err != noErr) {
		NSLog(@"error CMSampleBufferCreate");
		return;
	}
	CFRelease(newBBufOut);

	err = VTDecompressionSessionDecodeFrame(_session,
											sampleBuff,
											kVTDecodeFrame_EnableAsynchronousDecompression | kVTDecodeFrame_1xRealTimePlayback,
											sampleBuff,
											NULL);
    if (err != noErr) {
		NSLog(@"error VTDecompressionSessionDecodeFrame");
		CFRelease(sampleBuff);
    } else {
		VTDecompressionSessionWaitForAsynchronousFrames(_session); // xomment for ios9
    }
}

- (void)put:(CMSampleBufferRef)buffer
{
	std::unique_lock<std::mutex> lock(_mutex);
	_queue.push(buffer);
}

- (CMSampleBufferRef)takeWithTime:(double)time
{
//	std::unique_lock<std::mutex> lock(_mutex);
	if (_queue.empty()) {
		return NULL;
	} else {
		ConditionLock locker(_decoderCondition);
		CMSampleBufferRef buffer = _queue.front();
		CMTime t = CMSampleBufferGetPresentationTimeStamp(buffer);
		if (t.value == AV_NOPTS_VALUE) {
			_queue.pop();
			[_decoderCondition signal];
		} else {
			double vt = t.value / 25.0;
//			NSLog(@"video %f, audio %f", vt, time);
			if (vt > time) {
				buffer = NULL;
			} else {
				_queue.pop();
			}
			[_decoderCondition signal];
		}
		return buffer;
	}
}

- (BOOL)threadStep
{
	AVPacket packet;
	if ([self pop:&packet] && !self.stopped) {
		ConditionLock locker(_decoderCondition);
		while (_queue.size() > 32 && !self.stopped) {
			[_decoderCondition wait];
		}
		if (!self.stopped) {
			[self decodePacket:&packet];
			av_packet_unref(&packet);
			return YES;
		} else {
			return NO;
		}
	} else {
		return NO;
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
	if (kVTDecodeInfo_FrameDropped & infoFlags) {
		NSLog(@"frame dropped");
		return;
	}
	
	VTDecoder* decoder = (__bridge VTDecoder*)decompressionOutputRefCon;
	CMSampleBufferRef decodeBuffer = (CMSampleBufferRef)sourceFrameRefCon;
	
    if (status == noErr) {
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
                [decoder put:sampleBuffer];
			} else {
				NSLog(@"error CMSampleBufferCreateForImageBuffer");
			}
		} else {
			NSLog(@"error callback status");
		}
		CFRelease(decodeBuffer);
	} else {
		NSLog(@"decode error %d", (int)status);
	}
}
