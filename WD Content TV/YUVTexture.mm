//
//  YUVTexture.c
//  WD Content
//
//  Created by Сергей Сейтов on 19.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

#include "YUVTexture.h"

static GLfloat gVertices[] = {
	-1.0f,  1.0f, 0.0f,		// Position 0
	0.0f,  0.0f,			// TexCoord 0
	-1.0f, -1.0f, 0.0f,		// Position 1
	0.0f,  1.0f,			// TexCoord 1
	1.0f, -1.0f, 0.0f,		// Position 2
	1.0f,  1.0f,			// TexCoord 2
	1.0f,  1.0f, 0.0f,		// Position 3
	1.0f,  0.0f				// TexCoord 3
};

YUVTexture::YUVTexture(GLint* samplers) :  pts(AV_NOPTS_VALUE), size(CGSizeZero), _offset(1.0)
{
	for (int i=0; i < 3; i++) {
		_samplers[i] = samplers[i];
	}
	glGenTextures(3, _planes);
	memcpy(_vertices, gVertices, 20*sizeof(GLfloat));
}

YUVTexture::~YUVTexture()
{
	glDeleteTextures(3, _planes);
}

GLfloat YUVTexture::ratio()
{
	return (size.width+1)/(size.height+1);
}

GLfloat* YUVTexture::vertices()
{
	_vertices[13] =_vertices[18] = _offset;
	return _vertices;
}

void YUVTexture::activate(int plane)
{
	glActiveTexture ( GL_TEXTURE0+plane);
	glBindTexture ( GL_TEXTURE_2D, _planes[plane]);
}

void YUVTexture::create(AVFrame* frame)
{
	size = CGSizeMake(frame->width, frame->height);
	
	glBindTexture ( GL_TEXTURE_2D, _planes[0] );
	glUniform1i ( _samplers[0], 0 );
	glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, frame->linesize[0], size.height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, NULL);
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
	
	glBindTexture ( GL_TEXTURE_2D, _planes[1] );
	glUniform1i ( _samplers[1], 1 );
	glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, frame->linesize[0], size.height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, NULL);
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
	
	glBindTexture ( GL_TEXTURE_2D, _planes[2] );
	glUniform1i ( _samplers[2], 2 );
	glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, frame->linesize[0], size.height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, NULL);
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
	
	if (frame->linesize[0] > 0) {
		_offset = (GLfloat)frame->width / (GLfloat)frame->linesize[0] - 0.001f;
	}
}

void YUVTexture::update(AVFrame* frame)
{
	glBindTexture ( GL_TEXTURE_2D, _planes[0]);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, frame->linesize[0], size.height, GL_LUMINANCE, GL_UNSIGNED_BYTE, frame->data[0]);
	
	glBindTexture ( GL_TEXTURE_2D, _planes[1]);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, frame->linesize[1], size.height/2, GL_LUMINANCE, GL_UNSIGNED_BYTE, frame->data[1]);
	
	glBindTexture ( GL_TEXTURE_2D, _planes[2]);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, frame->linesize[2], size.height/2, GL_LUMINANCE, GL_UNSIGNED_BYTE, frame->data[2]);
	
	pts = frame->pts;
}
