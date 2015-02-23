//
//  VTDecoder.m
//  DirectVideo
//
//  Created by Sergey Seitov on 03.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VTDecoder.h"
#import <VideoToolbox/VideoToolbox.h>

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

static CMVideoFormatDescriptionRef CreateFormat(AVCodecContext* context, bool* convert)
{
	CMVideoFormatDescriptionRef format = NULL;
	OSStatus err = noErr;
	switch (context->codec_id) {
		case AV_CODEC_ID_MPEG4:
			NSLog(@"AV_CODEC_ID_MPEG4");
			if (context->extradata_size) {
				NSData* info = esdsInfo(context->extradata, context->extradata_size);
				if (info) {
					NSDictionary *extradata_info = @{ @"esds" : info};
					NSDictionary *decoderConfiguration = @{(id)kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms : extradata_info};
					err = CMVideoFormatDescriptionCreate(NULL, kCMVideoCodecType_MPEG4Video, context->width, context->height,
														 (__bridge CFDictionaryRef)decoderConfiguration, &format);
					if (err == noErr) {
						return format;
					}
				}
			} else {
				err = CMVideoFormatDescriptionCreate(NULL, kCMVideoCodecType_MPEG4Video, context->width, context->height, NULL, &format);
				if (err == noErr) {
					return format;
				}
			}
			break;
		case AV_CODEC_ID_MPEG2VIDEO:
			NSLog(@"AV_CODEC_ID_MPEG2VIDEO");
			err = CMVideoFormatDescriptionCreate(NULL, kCMVideoCodecType_MPEG2Video, context->width, context->height, NULL, &format);
			if (err == noErr) {
				return format;
			}
			break;
		case AV_CODEC_ID_H264:
		{
			NSLog(@"AV_CODEC_ID_H264");
			uint8_t* extradata = NULL;
			*convert = convertAvcc(context->extradata, context->extradata_size, &extradata);
			
			SpsHeader spsHeader = *((SpsHeader*)extradata);
			uint16_t spsLen = NTOHS(spsHeader.SPS_size);
			const uint8_t *sps = extradata+sizeof(SpsHeader);
			
			PpsHeader ppsHeader = *((PpsHeader*)(extradata + sizeof(SpsHeader)+spsLen));
			uint16_t ppsLen = NTOHS(ppsHeader.PPS_size);
			const uint8_t *pps = extradata+sizeof(SpsHeader)+spsLen+sizeof(PpsHeader);
			
			const uint8_t* const parameterSetPointers[2] = { sps , pps };
			const size_t parameterSetSizes[2] = { spsLen, ppsLen };
			
			err = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
																	  2,
																	  parameterSetPointers,
																	  parameterSetSizes,
																	  4,
																	  &format);
			if (err == noErr) {
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
	convert_byte_stream = false;
	_videoFormat = CreateFormat(context, &convert_byte_stream);
	
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
		self.context = context;
		was_pts = false;
        return YES;
    } else {
        return NO;
    }
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
/*
- (void)decodeMpeg2Packet:(AVPacket*)packet timing:(CMSampleTimingInfo)timing
{
	int got_frame = 0;
	static AVFrame frame;
	avcodec_get_frame_defaults(&frame);
	int len = avcodec_decode_video2(self.context, &frame, &got_frame, packet);
	if (len <= 0 || !got_frame) {
		return;
	}
	
	CVPixelBufferRef imageBuffer = NULL;
	
	void *planeBaseAddress[3];
	size_t planeWidth[3];
	size_t planeHeight[3];
	size_t planeBytesPerRow[3];

	planeBaseAddress[0] = frame.data[0];
	planeWidth[0] = frame.width;
	planeHeight[0] = frame.height;
	planeBytesPerRow[0] = frame.linesize[0];

	planeBaseAddress[1] = frame.data[1];
	planeWidth[1] = frame.width/2;
	planeHeight[1] = frame.height/2;
	planeBytesPerRow[1] = frame.linesize[1];
	
	planeBaseAddress[2] = frame.data[2];
	planeWidth[2] = frame.width/2;
	planeHeight[2] = frame.height/2;
	planeBytesPerRow[2] = frame.linesize[2];
	
	OSStatus err = CVPixelBufferCreateWithPlanarBytes(
													  NULL,
													  frame.width,
													  frame.height,
													  kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
													  NULL,
													  0,
													  3,
													  planeBaseAddress,
													  planeWidth,
													  planeHeight,
													  planeBytesPerRow,
													  NULL,
													  NULL,
													  NULL,
													  &imageBuffer);
	if (err != noErr) {
		NSLog(@"error CVPixelBufferCreateWithPlanarBytes");
		return;
	}
	CMVideoFormatDescriptionRef videoInfo = NULL;
	err = CMVideoFormatDescriptionCreateForImageBuffer(NULL, imageBuffer, &videoInfo);
	if (err != noErr) {
		NSLog(@"error CMVideoFormatDescriptionCreateForImageBuffer");
		return;
	}

	CMSampleBufferRef sampleBuffer = NULL;
	err = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
												imageBuffer,
												true,
												NULL,
												NULL,
												videoInfo,
												&timing,
												&sampleBuffer);
	CFRelease(videoInfo);
	if (err == noErr) {
		[self put:sampleBuffer];
	} else {
		NSLog(@"error CMSampleBufferCreateForImageBuffer");
	}
}
*/
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
		VTDecompressionSessionWaitForAsynchronousFrames(_session);
    }
}

- (void)put:(CMSampleBufferRef)buffer
{
	std::unique_lock<std::mutex> lock(_mutex);
	_queue.push(buffer);
}

- (CMSampleBufferRef)takeWithTime:(double)time
{
	std::unique_lock<std::mutex> lock(_mutex);
	if (_queue.empty()) {
		return NULL;
	} else {
		[_decoderCondition lock];
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
				[_decoderCondition signal];
			}
		}
		[_decoderCondition unlock];
		return buffer;
	}
}

- (BOOL)threadStep
{
	AVPacket packet;
	if ([self pop:&packet]) {
		[_decoderCondition lock];
		while (_queue.size() > 32) {
			[_decoderCondition wait];
		}
		[self decodePacket:&packet];
		av_free_packet(&packet);
		[_decoderCondition unlock];
		return YES;
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
