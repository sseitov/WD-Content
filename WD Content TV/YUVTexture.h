//
//  YUVTexture.h
//  WD Content
//
//  Created by Сергей Сейтов on 19.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

#ifndef YUVTexture_h
#define YUVTexture_h

#import <GLKit/GLKit.h>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
};

class YUVTexture
{
	GLuint _planes[3];
	GLint _samplers[3];
	GLfloat _offset;
	GLfloat	_vertices[20];
public:
	int64_t pts;
	CGSize size;

	YUVTexture(GLint* samplers);
	~YUVTexture();
	
	GLfloat ratio();
	
	int numPlanes();
	GLfloat* vertices();
	void activate(int plane);
	void create(AVFrame*);
	void update(AVFrame*);
};

#endif /* YUVTexture_h */
