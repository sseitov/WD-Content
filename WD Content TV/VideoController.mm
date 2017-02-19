//
//  VideoController.m
//  WD Content
//
//  Created by Сергей Сейтов on 19.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

#import "VideoController.h"
#import "MovieDemuxer.h"
#import <SVProgressHUD.h>
#import "YUVTexture.h"

@interface VideoController () {
	// Attribute index
	GLint positionLoc;
	GLint texCoordLoc;
	
	// Sampler location
	GLint Sampler[3];
	
	GLuint programObject;
	
	EAGLContext *_textureContext;
	EAGLContext *_context;
}

@property (strong, nonatomic) MovieDemuxer* demuxer;

@end

@implementation VideoController

- (void)viewDidLoad {
    [super viewDidLoad];
	_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
	_textureContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:_context.sharegroup];
	
	((GLKView *)self.view).context = _context;
	
	[EAGLContext setCurrentContext:_context];
	[self loadShaders];
	
	// Get the attribute locations
	positionLoc = glGetAttribLocation ( programObject, "a_position" );
	texCoordLoc = glGetAttribLocation ( programObject, "a_texCoord" );
	Sampler[0] = glGetUniformLocation ( programObject, "SamplerY" );
	Sampler[1] = glGetUniformLocation ( programObject, "SamplerU" );
	Sampler[2] = glGetUniformLocation ( programObject, "SamplerV" );

	_demuxer = [[MovieDemuxer alloc] init];
	_demuxer->texture = new YUVTexture(Sampler);
	glUseProgram ( programObject );

}

- (void)viewDidAppear:(BOOL)animated {
	
	[SVProgressHUD showWithStatus:@"Loading"];
	dispatch_queue_t queue = dispatch_queue_create("com.vchannel.WD-Content.SMBOpen", DISPATCH_QUEUE_SERIAL);
	dispatch_async(queue, ^() {
		NSMutableArray *audioChannels = [NSMutableArray array];
		bool success = [_demuxer load:_host port:_port user:_user password:_password file:_filePath audioChannels:audioChannels];
		dispatch_async(dispatch_get_main_queue(), ^() {
			[SVProgressHUD dismiss];
			if (success) {
				if (audioChannels.count > 1) {
					UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
																							 message:@"Choose audio channel"
																					  preferredStyle:UIAlertControllerStyleActionSheet];
					for (NSDictionary *channel in audioChannels) {
						UIAlertAction *action = [UIAlertAction actionWithTitle:[channel objectForKey:@"codec"]
																		 style:UIAlertActionStyleDefault
																	   handler:^(UIAlertAction *action) {
																		   [self.demuxer play:[[channel objectForKey:@"channel"] intValue]];
																	   }];
						[alertController addAction:action];
					}
					UIAlertAction *action = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
					[alertController addAction:action];
					
					[self presentViewController:alertController animated:true completion:nil];
				} else {
					[self.demuxer play:[[[audioChannels objectAtIndex:0] objectForKey:@"channel"] intValue]];
				}
			} else {
				UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
																						 message:@"Error open file."
																				  preferredStyle:UIAlertControllerStyleAlert];
				[self presentViewController:alertController animated:true completion:nil];
			}
		});
	});
}

#pragma mark - GLKView delegate methods

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
	[EAGLContext setCurrentContext:_context];
	[_demuxer takeVideo];
	
	CGFloat ratio = _demuxer->texture->ratio();
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
	glVertexAttribPointer ( positionLoc, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), _demuxer->texture->vertices() );
	// Load the texture coordinate
	glVertexAttribPointer ( texCoordLoc, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), &_demuxer->texture->vertices()[3] );
	
	glEnableVertexAttribArray ( positionLoc );
	glEnableVertexAttribArray ( texCoordLoc );
	
	for (int i=0; i < 3; i++) {
		_demuxer->texture->activate(i);
	}
	
	static GLushort indices[] = { 0, 1, 2, 0, 2, 3 };
	glDrawElements ( GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, indices );
 
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
	
	if (presses.anyObject.type == UIPressTypeMenu) {
		[_demuxer close];
	}
	[super pressesBegan:presses withEvent: event];
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
