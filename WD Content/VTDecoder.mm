//
//  VTDecoder.m
//  DirectVideo
//
//  Created by Sergey Seitov on 03.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VTDecoder.h"
#import <VideoToolbox/VideoToolbox.h>
#import <CoreVideo/CVHostTime.h>
#include <mutex>

@interface VTDecoder () {
    VTDecompressionSessionRef _session;
    CMVideoFormatDescriptionRef _videoFormat;
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
#pragma pack(push,1)

struct SpsHeader
{
	uint8_t     version;                    // ( always 0x01 )
	uint8_t     avc_profile;                // ( sps[0][1] )
	uint8_t     avc_compatibility;          // ( sps[0][2] )
	uint8_t     avc_level;                  // ( sps[0][3] )
	uint8_t     reserved1:6;                // ( all bits on )
	uint8_t     NALULengthSizeMinusOne:2;
	uint8_t     reserved2:3;                // ( all bits on )
	uint8_t     number_of_SPS_NALUs:5;      // (usually 1)
	uint16_t    SPS_size;
};

struct PpsHeader
{
	uint8_t     number_of_PPS_NALUs;        // (usually 1)
	uint16_t    PPS_size;
};

#pragma pack(pop)

/* MPEG-4 esds (elementary stream descriptor) */
typedef struct {
	int version;
	long flags;
	
	uint16_t esid;
	uint8_t  stream_priority;
	
	uint8_t  objectTypeId;
	uint8_t  streamType;
	uint32_t bufferSizeDB;
	uint32_t maxBitrate;
	uint32_t avgBitrate;
	
	int      decoderConfigLen;
	uint8_t* decoderConfig;
} quicktime_esds_t;

quicktime_esds_t* quicktime_set_esds(const uint8_t * decoderConfig, int decoderConfigLen)
{
	// ffmpeg's codec->avctx->extradata, codec->avctx->extradata_size
	// are decoderConfig/decoderConfigLen
	quicktime_esds_t *esds;
	
	esds = (quicktime_esds_t*)malloc(sizeof(quicktime_esds_t));
	memset(esds, 0, sizeof(quicktime_esds_t));
	
	esds->version         = 0;
	esds->flags           = 0;
	
	esds->esid            = 0;
	esds->stream_priority = 0;      // 16 ? 0x1f
	
	esds->objectTypeId    = 32;     // 32 = AV_CODEC_ID_MPEG4, 33 = AV_CODEC_ID_H264
	// the following fields is made of 6 bits to identify the streamtype (4 for video, 5 for audio)
	// plus 1 bit to indicate upstream and 1 bit set to 1 (reserved)
	esds->streamType      = 0x11;
	esds->bufferSizeDB    = 64000;  // Hopefully not important :)
	
	// Maybe correct these later?
	esds->maxBitrate      = 200000; // 0 for vbr
	esds->avgBitrate      = 200000;
	
	esds->decoderConfigLen = decoderConfigLen;
	esds->decoderConfig = (uint8_t*)malloc(esds->decoderConfigLen);
	memcpy(esds->decoderConfig, decoderConfig, esds->decoderConfigLen);
	return esds;
}

int quicktime_write_mp4_descr_length(AVIOContext *pb, int length, int compact)
{
	int i;
	uint8_t b;
	int numBytes;
	
	if (compact)
	{
		if (length <= 0x7F)
		{
			numBytes = 1;
		}
		else if (length <= 0x3FFF)
		{
			numBytes = 2;
		}
		else if (length <= 0x1FFFFF)
		{
			numBytes = 3;
		}
		else
		{
			numBytes = 4;
		}
	}
	else
	{
		numBytes = 4;
	}
	
	for (i = numBytes-1; i >= 0; i--)
	{
		b = (length >> (i * 7)) & 0x7F;
		if (i != 0)
		{
			b |= 0x80;
		}
		avio_w8(pb, b);
	}
	
	return numBytes;
}

void quicktime_write_esds(AVIOContext *pb, quicktime_esds_t *esds)
{
	avio_w8(pb, 0);     // Version
	avio_wb24(pb, 0);     // Flags
	
	// elementary stream descriptor tag
	avio_w8(pb, 0x03);
	quicktime_write_mp4_descr_length(pb,
									 3 + 5 + (13 + 5 + esds->decoderConfigLen) + 3, false);
	// 3 bytes + 5 bytes for tag
	avio_wb16(pb, esds->esid);
	avio_w8(pb, esds->stream_priority);
	
	// decoder configuration description tag
	avio_w8(pb, 0x04);
	quicktime_write_mp4_descr_length(pb,
									 13 + 5 + esds->decoderConfigLen, false);
	// 13 bytes + 5 bytes for tag
	avio_w8(pb, esds->objectTypeId); // objectTypeIndication
	avio_w8(pb, esds->streamType);   // streamType
	avio_wb24(pb, esds->bufferSizeDB); // buffer size
	avio_wb32(pb, esds->maxBitrate);   // max bitrate
	avio_wb32(pb, esds->avgBitrate);   // average bitrate
	
	// decoder specific description tag
	avio_w8(pb, 0x05);
	quicktime_write_mp4_descr_length(pb, esds->decoderConfigLen, false);
	avio_write(pb, esds->decoderConfig, esds->decoderConfigLen);
	
	// sync layer configuration descriptor tag
	avio_w8(pb, 0x06);  // tag
	avio_w8(pb, 0x01);  // length
	avio_w8(pb, 0x7F);  // no SL
	
	/* no IPI_DescrPointer */
	/* no IP_IdentificationDataSet */
	/* no IPMP_DescriptorPointer */
	/* no LanguageDescriptor */
	/* no QoS_Descriptor */
	/* no RegistrationDescriptor */
	/* no ExtensionDescriptor */
	
}

union
{
	void* lpAddress;
	// iOS <= 4.2
	OSStatus (*FigVideoFormatDescriptionCreateWithSampleDescriptionExtensionAtom1)(
																				   CFAllocatorRef allocator, UInt32 formatId, UInt32 width, UInt32 height,
																				   UInt32 atomId, const UInt8 *data, CFIndex len, CMFormatDescriptionRef *formatDesc);
	// iOS >= 4.3
	OSStatus (*FigVideoFormatDescriptionCreateWithSampleDescriptionExtensionAtom2)(
																				   CFAllocatorRef allocator, UInt32 formatId, UInt32 width, UInt32 height,
																				   UInt32 atomId, const UInt8 *data, CFIndex len, CFDictionaryRef extensions, CMFormatDescriptionRef *formatDesc);
} FigVideoHack;

extern "C" OSStatus FigVideoFormatDescriptionCreateWithSampleDescriptionExtensionAtom(
																				  CFAllocatorRef allocator, UInt32 formatId, UInt32 width, UInt32 height,
																				  UInt32 atomId, const UInt8 *data, CFIndex len, CMFormatDescriptionRef *formatDesc);

// helper function to create a avcC atom format descriptor
static CMFormatDescriptionRef CreateFormatDescriptionFromCodecData(CMVideoCodecType format_id,
																   int width, int height,
																   const uint8_t *extradata, int extradata_size, uint32_t atom)
{
	CMFormatDescriptionRef fmt_desc = NULL;
	OSStatus status;
	FigVideoHack.lpAddress = (void*)FigVideoFormatDescriptionCreateWithSampleDescriptionExtensionAtom;
	
	status = FigVideoHack.FigVideoFormatDescriptionCreateWithSampleDescriptionExtensionAtom2(
																							 NULL,
																							 format_id,
																							 width,
																							 height,
																							 atom,
																							 extradata,
																							 extradata_size,
																							 NULL,
																							 &fmt_desc);
	if (status == noErr)
		return fmt_desc;
	else
		return NULL;
}

static CMVideoFormatDescriptionRef CreateFormat(AVCodecContext* context)
{
	CMVideoFormatDescriptionRef format = NULL;
	OSStatus err = noErr;
	switch (context->codec_id) {
		case AV_CODEC_ID_MPEG4:
			if (context->extradata_size) {	// avi format ?
				unsigned int extrasize = context->extradata_size; // extra data for codec to use
				uint8_t *extradata = context->extradata; // size of extra data
				AVIOContext *pb;
				if (avio_open_dyn_buf(&pb) < 0) {
					break;
				}
				quicktime_esds_t *esds = quicktime_set_esds(extradata, extrasize);
				quicktime_write_esds(pb, esds);
				
				// unhook from ffmpeg's extradata
				extradata = NULL;
				// extract the esds atom decoderConfig from extradata
				extrasize = avio_close_dyn_buf(pb, &extradata);
				free(esds->decoderConfig);
				free(esds);
				
				format = CreateFormatDescriptionFromCodecData(kCMVideoCodecType_MPEG4Video, context->width, context->height, extradata, extrasize, 'esds');
				// done with the converted extradata, we MUST free using av_free
				av_free(extradata);
				return format;
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
			SpsHeader spsHeader = *((SpsHeader*)context->extradata);
			uint16_t spsLen = NTOHS(spsHeader.SPS_size);
			const uint8_t *sps = context->extradata+sizeof(SpsHeader);
			
			PpsHeader ppsHeader = *((PpsHeader*)(context->extradata + sizeof(SpsHeader)+spsLen));
			uint16_t ppsLen = NTOHS(ppsHeader.PPS_size);
			const uint8_t *pps = context->extradata+sizeof(SpsHeader)+spsLen+sizeof(PpsHeader);
			
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

- (void)decodePacket:(AVPacket*)packet
{
	std::unique_lock<std::mutex> lock(_mutex);
	if (!_context) {
		return;
	}

	if (packet->pts == AV_NOPTS_VALUE) {
		NSLog(@"packet has no pts");
		return;
	}
	
	CMSampleTimingInfo timingInfo;
	timingInfo.presentationTimeStamp = CMTimeMake(packet->pts, _context->time_base.den);
	timingInfo.duration = CMTimeMake(packet->duration, _context->time_base.den);
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
	} else {
		NSLog(@"decode error");
	}
	
	CFRelease(decodeBuffer);
}
