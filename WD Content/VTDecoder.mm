//
//  VTDecoder.m
//  DirectVideo
//
//  Created by Sergey Seitov on 03.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VTDecoder.h"
#import <VideoToolbox/VideoToolbox.h>

extern "C" {
#	include "VideoUtility.h"
#	include "libavcodec/avcodec.h"
}

static CMVideoFormatDescriptionRef CreateFormat(AVCodecContext* context, bool* convert)
{
	CMVideoFormatDescriptionRef format = NULL;
	OSStatus err = noErr;
	switch (context->codec_id) {
		case AV_CODEC_ID_MPEG4:
			if (context->extradata_size)
			{	// avi format ?
				AVIOContext *pb;
				quicktime_esds_t *esds;

				unsigned int extrasize = context->extradata_size; // extra data for codec to use
				uint8_t *extradata = (uint8_t*)context->extradata; // size of extra data
				
				if (avio_open_dyn_buf(&pb) < 0)
					break;
				
				esds = quicktime_set_esds(extradata, extrasize);
				quicktime_write_esds(pb, esds);
				
				// unhook from ffmpeg's extradata
				extradata = NULL;
				// extract the esds atom decoderConfig from extradata
				extrasize = avio_close_dyn_buf(pb, &extradata);
				free(esds->decoderConfig);
				free(esds);

				CFMutableDictionaryRef decoderConfiguration = CFDictionaryCreateMutable(kCFAllocatorDefault,
																						2,
																						&kCFTypeDictionaryKeyCallBacks,
																						&kCFTypeDictionaryValueCallBacks);
				CFDataRef data = CFDataCreate(kCFAllocatorDefault, extradata, extrasize);
				
				CFMutableDictionaryRef extradata_info = CFDictionaryCreateMutable(kCFAllocatorDefault,
																				  1,
																				  &kCFTypeDictionaryKeyCallBacks,
																				  &kCFTypeDictionaryValueCallBacks);
				CFDictionarySetValue(extradata_info, CFSTR("esds"), data);
				
				CFDictionarySetValue(decoderConfiguration,
									 kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms,
									 extradata_info);
				err = CMVideoFormatDescriptionCreate(NULL, kCMVideoCodecType_MPEG4Video, context->width, context->height, decoderConfiguration, &format);

				// done with the converted extradata, we MUST free using av_free
				av_free(extradata);
				CFRelease(data);
				CFRelease(extradata_info);
				
				if (err == noErr) {
					return format;
				}
			} else {
				err = CMVideoFormatDescriptionCreate(NULL, kCMVideoCodecType_MPEG4Video, context->width, context->height, NULL, &format);
				if (err == noErr) {
					return format;
				}
			}
			break;
		case AV_CODEC_ID_MPEG2VIDEO:
			err = CMVideoFormatDescriptionCreate(NULL, kCMVideoCodecType_MPEG2Video, context->width, context->height, NULL, &format);
			if (err == noErr) {
				return format;
			}
			break;
		case AV_CODEC_ID_H264:
		{
			uint8_t* extradata = NULL;;
			if ((context->extradata[0] == 0 && context->extradata[1] == 0 && context->extradata[2] == 0 && context->extradata[3] == 1) ||
				(context->extradata[0] == 0 && context->extradata[1] == 0 && context->extradata[2] == 1))
			{
				// video content is from x264 or from bytestream h264 (AnnexB format)
				// NAL reformating to bitstream format required
				AVIOContext *pb;
				if (avio_open_dyn_buf(&pb) < 0)
					break;
				
				// create a valid avcC atom data from ffmpeg's extradata
				isom_write_avcc(pb, context->extradata, context->extradata_size);
				
				// extract the avcC atom data into extradata getting size into extrasize
				avio_close_dyn_buf(pb, &extradata);
				*convert = true;
			} else {
				extradata = context->extradata;
				*convert = false;
			}
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
	VTDecompressionSessionRef _session;
	CMVideoFormatDescriptionRef _videoFormat;
	bool convert_byte_stream;
}

@end

@implementation VTDecoder

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
		_context = context;
        return YES;
    } else {
        return NO;
    }
}

- (void)close
{
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

- (void)decodePacket:(AVPacket*)packet
{
	CMSampleTimingInfo timingInfo;
	timingInfo.presentationTimeStamp = CMTimeMake(packet->pts, 1.0/av_q2d(_context->time_base));
	timingInfo.duration = CMTimeMake(packet->duration, 1.0/av_q2d(_context->time_base));
	timingInfo.decodeTimeStamp = kCMTimeInvalid;
	
	CMSampleBufferRef sampleBuff = NULL;
 	CMBlockBufferRef newBBufOut = NULL;
	OSStatus err = noErr;
	if (convert_byte_stream) {
		// convert demuxer packet from bytestream (AnnexB) to bitstream
		AVIOContext *pb = NULL;
		int demux_size = 0;
		uint8_t *demux_buff = NULL;
		if(avio_open_dyn_buf(&pb) < 0)
			return;
		demux_size = avc_parse_nal_units(pb, packet->data, packet->size);
		demux_size = avio_close_dyn_buf(pb, &demux_buff);

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
	} else {
		err = CMBlockBufferCreateWithMemoryBlock(
												 NULL,             // CFAllocatorRef structureAllocator
												 packet->data,       // void *memoryBlock
												 packet->size,       // size_t blockLengt
												 kCFAllocatorNull, // CFAllocatorRef blockAllocator
												 NULL,             // const CMBlockBufferCustomBlockSource *customBlockSource
												 0,                // size_t offsetToData
												 packet->size,       // size_t dataLength
												 kCMBlockBufferAlwaysCopyDataFlag,            // CMBlockBufferFlags flags
												 &newBBufOut);     // CMBlockBufferRef *newBBufOut
	}
	
	if (err != noErr) {
		NSLog(@"error CMBlockBufferCreateWithMemoryBlock");
		return;
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
                [decoder.delegate videoDecoder:decoder decodedBuffer:sampleBuffer];
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
