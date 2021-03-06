//
//  VideoOutput.mm
//  vTV
//
//  Created by Сергей Сейтов on 07.01.12.
//  Copyright (c) 2012 V-Channel. All rights reserved.
//

#import "VideoOutput.h"
#include "TextureItem.h"
#include "SynchroQueue.h"
#import <AVFoundation/AVUtilities.h>

#undef DEBUG_VIDEO

class TextureQueue : public SynchroQueue<PTSTexture*>
{
public:
	virtual void free(PTSTexture** pItem)
	{
	}
	virtual void flush(int64_t pts = AV_NOPTS_VALUE)
	{
	}
	void create(AVFrame* frame)
	{
		queue_type tmp;
		while (!_queue.empty()) {
			auto val = _queue.front();
			_queue.pop();
			val->create(frame);
			tmp.push(val);
		}
		_queue.swap(tmp);
	}
};

@interface VideoOutput ()
{
	// Attribute index
	GLint positionLoc;
	GLint texCoordLoc;
	
	// Sampler location
	GLint Sampler[3];
	
    GLuint programObject;
	
	EAGLContext *_textureContext;
	EAGLContext *_context;
	
	TextureQueue _texPool;
	TextureQueue _texQueue;
	
	PTSTexture* _currentTexture;
}

@end

@implementation VideoOutput

@synthesize decoder, started, lastFlushPTS, lateFrameCounter;

- (instancetype)initWithDelegate:(id<GLKViewControllerDelegate>)delegate {
	
	self = [super init];
	if (self){
		self.preferredFramesPerSecond = 60;
		self.delegate = delegate;
		_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
		_textureContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:_context.sharegroup];
		self.decoder = [[VideoDecoder alloc] init];
		Sampler[0] = Sampler[1] = Sampler[2] = -1;
		self.started = false;
	}
	return self;
}

- (UIView*)glView
{
	return self.view;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    GLKView *view = (GLKView *)self.view;
    view.context = _context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
	view.backgroundColor = [UIColor clearColor];
	
    [EAGLContext setCurrentContext:_context];
	[self loadShaders];
	
	// Get the attribute locations
	positionLoc = glGetAttribLocation ( programObject, "a_position" );
	texCoordLoc = glGetAttribLocation ( programObject, "a_texCoord" );
	Sampler[0] = glGetUniformLocation ( programObject, "SamplerY" );
	Sampler[1] = glGetUniformLocation ( programObject, "SamplerU" );
	Sampler[2] = glGetUniformLocation ( programObject, "SamplerV" );
	
	for (int i=0; i<SCREEN_POOL_SIZE; i++) {
		PTSTexture *item;
		item = new YUV(Sampler);
		_texPool.push(&item);
		
	}
}

- (void)dealloc
{
	NSLog(@"VideoOutput dealloc");
}

- (void)start:(AVFrame*)frame
{
	_texPool.start();
	_texQueue.start();
	[self flush:AV_NOPTS_VALUE];
	
	[EAGLContext setCurrentContext:_context];
	glUseProgram ( programObject );
	_texPool.create(frame);
	
	self.lastFlushPTS = AV_NOPTS_VALUE;
	self.started = true;
}

- (void)stop
{
	if (!self.started)
		return;
	self.started = false;
	NSLog(@"stop queue %d, pool %d", _texQueue.size(), _texPool.size());
	_texPool.stop();
	_texQueue.stop();
	[self.decoder close];
	
}

- (void)close
{
	[self stop];
	self.delegate = nil;
	
	[EAGLContext setCurrentContext:_context];
	if (programObject) {
		glDeleteProgram(programObject);
		programObject = 0;
	}
	[EAGLContext setCurrentContext:nil];
	_context = nil;
}

- (void)flush:(int64_t)pts
{
	self.lastFlushPTS = pts;
	while (!_texQueue.empty()) {
		PTSTexture* item;
		if (_texQueue.pop(&item))
			_texPool.push(&item);
		else
			break;
	}
	if (_currentTexture) {
		_texPool.push(&_currentTexture);
	}
	_currentTexture = nil;
}

- (bool)pushPacket:(AVPacket*)packet
{
	static float pushTimeInterval;
	static float decodeTimeInterval;
	static int counter;
	static AVFrame frame;
	
	if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
		return false;
	}
	
	NSDate* startDecode = [NSDate date];
	
	if (![self.decoder decodePacket:packet toFrame:&frame]) {
		NSLog(@"video decoder error");
		return false;
	}
	
	if (!self.started) {
		[self start:&frame];
	}
	
	if (self.lastFlushPTS != AV_NOPTS_VALUE && frame.pts < self.lastFlushPTS) {
		NSLog(@"Old video frame from decoder with pts %lld", frame.pts);
		return true;
	}
	
	decodeTimeInterval += [startDecode timeIntervalSinceNow];

	PTSTexture* item;
	if (!_texPool.pop(&item)) return true; // if device not started
	
	NSDate* startPush = [NSDate date];
	
	[EAGLContext setCurrentContext:_textureContext];
	CGSize frameSize = CGSizeMake(frame.width, frame.height);
	if (!CGSizeEqualToSize(item->size, frameSize)) {
		item->create(&frame);
	}
	item->update(&frame);
	
	if (self.lastFlushPTS == AV_NOPTS_VALUE || packet->pts >= self.lastFlushPTS)
		_texQueue.push(&item);
	else
		_texPool.push(&item);
	
	counter++;
	if (counter == 100) {
//		NSString* msg = [NSString stringWithFormat:@"DECODE %.2f, PUSH %.2f", decodeTimeInterval*(-10), pushTimeInterval*(-10)];
//		NSLog(@"%@", msg);
		pushTimeInterval = 0.0;
		decodeTimeInterval = 0.0;
		counter = 0;
	} else {
		pushTimeInterval += [startPush timeIntervalSinceNow];
	}
	return true;
}

-(int)updateQueueWithPTS:(int64_t)pts
{
	int count = 0;
	bool needJump = false;
	while (true)
	{
		if (_currentTexture == NULL)
		{
			if (_texQueue.empty())
				break;
			_texQueue.pop(&_currentTexture);
			++count;
		}
		if (count <= 1 && pts - _currentTexture->pts > 3600*3)
			needJump = true;
		if (!needJump && count == 1)
			return count;
		if (pts <= _currentTexture->pts)
			return count;
		if (_texQueue.empty())
			break;
		_texPool.push(&_currentTexture);
		_currentTexture = NULL;
	}
	return count;
}

- (int64_t)updateWithPTS:(int64_t)pts updated:(int*)updated
{
	if (!self.started || pts < self.lastFlushPTS)
		return AV_NOPTS_VALUE;

	*updated = [self updateQueueWithPTS:pts];

	if (*updated > 0) {
		int64_t delta = pts - _currentTexture->pts;
		if (delta > 3600 * 5)
			self.lateFrameCounter = self.lateFrameCounter + 1;
		else
			self.lateFrameCounter = 0;
	}

	return _currentTexture ? _currentTexture->pts : AV_NOPTS_VALUE;
}

- (CGSize)videoSize
{
	return _currentTexture ? _currentTexture->size : CGSizeZero;
}

- (int64_t)currentPTS
{
	return (_currentTexture ? _currentTexture->pts : AV_NOPTS_VALUE);
}

- (int)decodedPacketCount
{
	return _texQueue.size();
}

#pragma mark - GLKView delegate methods

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
	PTSTexture* tex = _currentTexture;
	if (!tex || tex->pts < self.lastFlushPTS) return;

#ifdef DEBUG_VIDEO
	static int64_t xxx = AV_NOPTS_VALUE;
	if (xxx == AV_NOPTS_VALUE) {
		xxx = tex->pts;
	} else {
		if (xxx != tex->pts) {
			NSLog(@"render=%lld diff=%lld", tex->pts, tex->pts - xxx);
			xxx = tex->pts;
		}
	}
#endif

	float ratio = tex->ratio();
	CGRect viewRect;
	if (ratio > rect.size.width/rect.size.height) {
		viewRect.size.width = rect.size.width;
		viewRect.origin.x = 0;
		viewRect.size.height = viewRect.size.width/ratio;
		viewRect.origin.y = (rect.size.height - viewRect.size.height)/2.0;
	} else {
		viewRect.size.height = rect.size.height;
		viewRect.origin.y = 0;
		viewRect.size.width = viewRect.size.height*ratio;
		viewRect.origin.x = (rect.size.width - viewRect.size.width)/2;
	}
	
	// Set the viewport
	glViewport(viewRect.origin.x*self.view.contentScaleFactor, viewRect.origin.y*self.view.contentScaleFactor,
			   viewRect.size.width*self.view.contentScaleFactor, viewRect.size.height*self.view.contentScaleFactor);
	
	// Clear the color buffer
	glClearColor (0, 0, 0, 0);
	glClear ( GL_COLOR_BUFFER_BIT );
	
	// Load the vertex position
	glVertexAttribPointer ( positionLoc, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), tex->vertices() );
	// Load the texture coordinate
	glVertexAttribPointer ( texCoordLoc, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), &tex->vertices()[3] );

	glEnableVertexAttribArray ( positionLoc );
	glEnableVertexAttribArray ( texCoordLoc );
	
	for (int i=0; i < tex->numPlanes(); i++) {
		tex->activate(i);
	}
	
	static GLushort indices[] = { 0, 1, 2, 0, 2, 3 };
	glDrawElements ( GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, indices );
}

#pragma mark - Shaders

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    programObject = glCreateProgram();

	// Create and compile vertex shader.
	vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"YUVShader" ofType:@"vsh"];
	if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname])
	{
		NSLog(@"Failed to compile vertex shader");
		return FALSE;
	}
	
	// Create and compile fragment shader.
	fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"YUVShader" ofType:@"fsh"];
	if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname])
	{
		NSLog(@"Failed to compile fragment shader");
		return FALSE;
	}
    
    // Attach vertex shader to program.
    glAttachShader(programObject, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(programObject, fragShader);
	
    // Link program.
    if (![self linkProgram:programObject])
    {
        NSLog(@"Failed to link program: %d", programObject);
        
        if (vertShader)
        {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader)
        {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (programObject)
        {
            glDeleteProgram(programObject);
            programObject = 0;
        }
        
        return FALSE;
    }
    
    // Release vertex and fragment shaders.
    if (vertShader)
        glDeleteShader(vertShader);
    if (fragShader)
        glDeleteShader(fragShader);
    
    return TRUE;
}

@end
