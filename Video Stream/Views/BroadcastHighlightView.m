//
//  BroadcastHighlightView.m
//  Video Stream
//
//  Created by Hai Li on 2/23/16.
//
//

#import "BroadcastHighlightView.h"

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>

#include "MotionProvider.h"

GLuint LoadShader(GLenum type, const char *shaderSrc);

@implementation BroadcastHighlightView {
    CAEAGLLayer *eaglLayer;
    EAGLContext *eaglContext;
    
    GLuint programObject;
    
    GLuint viewRenderbuffer;
    GLuint viewFramebuffer;
    
    GLint backingWidth;
    GLint backingHeight;
    
    GLfloat xyRate;
    GLfloat vVertices[8 * 3];
    GLubyte vIndices[8 * 3];
    
    GLuint vertexBuffer;
    GLuint indexBuffer;
    
    BOOL isStart;
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (id)initWithCoder:(NSCoder *)coder
{
    
    if ((self = [super initWithCoder:coder])) {
        // Get the layer
        eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = NO;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        if (!eaglContext || ![EAGLContext setCurrentContext:eaglContext]) {
            self = nil;
            return nil;
        }
        
        [self calculatePoints];
        
        [self initGlShader];
        
        isStart = YES;
    }
    return self;
}

- (void)drawView
{
    
    if (isStart) {
        [EAGLContext setCurrentContext:eaglContext];
        
        isStart = NO;
        
        [self createFramebuffer];
        [self createVbobuffer];
    }
    
    glViewport(0, 0, backingWidth, backingHeight);
    
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    [self drawPreviewRect];
    
    [eaglContext presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)drawPreviewRect
{
    // Use the program object
    glUseProgram(programObject);
    
    GLuint colorUniform = glGetUniformLocation(programObject,
                                               "fColor");
    glUniform4f(colorUniform, 0.0f, 0.0f, 0.0f, 0.5f);
    
    GLfloat rotateAngle = -[MotionProvider sharedProvider].tiltAngle;
    GLfloat fMatrix[] = {
        cos(rotateAngle), sin(rotateAngle) * xyRate, 0.0f, 0.0f, -sin(rotateAngle), cos(rotateAngle) * xyRate, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f,
    };
    
    GLuint matrixUniform = glGetUniformLocation(programObject,
                                                "vMatrix");
    glUniformMatrix4fv(matrixUniform, 1, false, fMatrix);
    
    GLuint positionSlot = glGetAttribLocation(programObject,
                                              "vPosition");
    glEnableVertexAttribArray(positionSlot);
    
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 3, 0);
    
    glDrawElements(GL_TRIANGLES, sizeof(vIndices) / sizeof(vIndices[0]), GL_UNSIGNED_BYTE, 0);
}

- (void)layoutSubviews
{
    [self drawView];
}

- (BOOL)createFramebuffer
{
    glGenFramebuffers(1, &viewFramebuffer);
    glGenRenderbuffers(1, &viewRenderbuffer);
    
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [eaglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:eaglLayer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, viewRenderbuffer);
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    
    return YES;
}

- (void)releaseFramebuffer
{
    glDeleteFramebuffers(1, &viewFramebuffer);
    viewFramebuffer = 0;
    glDeleteRenderbuffers(1, &viewRenderbuffer);
    viewRenderbuffer = 0;
}

- (void)calculatePoints
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    
    xyRate = (GLfloat)screenWidth / screenHeight;
    
    CGFloat mainDiagonal = sqrtf(powf(screenRect.size.width, 2.0f) + powf(screenRect.size.height, 2.0f));
    mainDiagonal = ceilf(mainDiagonal) + 20.0f;
    
    CGFloat previewDiagonal = (screenWidth > screenHeight) ? screenHeight : screenWidth;
    
    CGFloat previewWidth = previewDiagonal / sqrtf(16 * 16 + 9 * 9) * 16;
    CGFloat previewHeight = previewDiagonal / sqrtf(16 * 16 + 9 * 9) * 9;
    
    // previewWidth = (int)(previewWidth / 16) * 16;
    // previewHeight = (int)(previewHeight / 16) * 16;
    
    CGRect rects[2];
    rects[0] = CGRectMake(-previewWidth / 2 / screenWidth * 2, previewHeight / 2 / screenWidth * 2, previewWidth / screenWidth * 2, previewHeight / screenWidth * 2);
    rects[1] = CGRectMake(-mainDiagonal / 2 / screenWidth * 2, mainDiagonal / 2 / screenWidth * 2, mainDiagonal / screenWidth * 2, mainDiagonal / screenWidth * 2);
    
    GLfloat vertices[] = {
        rects[0].origin.x, rects[0].origin.y, 0.0f, rects[0].origin.x, rects[0].origin.y - rects[0].size.height, 0.0f, rects[0].origin.x + rects[0].size.width, rects[0].origin.y - rects[0].size.height, 0.0f, rects[0].origin.x + rects[0].size.width, rects[0].origin.y, 0.0f, rects[1].origin.x, rects[1].origin.y, 0.0f, rects[1].origin.x, rects[1].origin.y - rects[1].size.height, 0.0f, rects[1].origin.x + rects[1].size.width, rects[1].origin.y - rects[1].size.height, 0.0f, rects[1].origin.x + rects[1].size.width, rects[1].origin.y, 0.0f};
    
    GLubyte indices[] = {
        0, 4, 7, 0, 3, 7, 3, 7, 6, 3, 2, 6, 2, 5, 6, 2, 5, 1, 1, 4, 5, 1, 4, 0};
    
    memcpy(vVertices, vertices, sizeof(vertices));
    memcpy(vIndices, indices, sizeof(indices));
}

- (void)createVbobuffer
{
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vVertices), vVertices, GL_STATIC_DRAW);
    
    glGenBuffers(1, &indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(vIndices), vIndices, GL_STATIC_DRAW);
}

- (void)releaseVbobuffer
{
    glDeleteBuffers(1, &vertexBuffer);
    vertexBuffer = 0;
    glDeleteBuffers(1, &indexBuffer);
    indexBuffer = 0;
}

- (void)dealloc
{
    [self releaseVbobuffer];
    [self releaseFramebuffer];
    
    if ([EAGLContext currentContext] == eaglContext) {
        [EAGLContext setCurrentContext:nil];
    }
    eaglContext = nil;
}

GLuint LoadShader(GLenum type, const char *shaderSrc)
{
    GLuint shader;
    GLint compiled;
    
    // Create the shader object
    shader = glCreateShader(type);
    
    if (shader == 0)
        return 0;
    
    // Load the shader source
    glShaderSource(shader, 1, &shaderSrc, NULL);
    
    // Compile the shader
    glCompileShader(shader);
    
    // Check the compile status
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    
    if (!compiled) {
        GLint infoLen = 0;
        
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);
        
        if (infoLen > 1) {
            char *infoLog = malloc(sizeof(char) * infoLen);
            
            glGetShaderInfoLog(shader, infoLen, NULL, infoLog);
            
            free(infoLog);
        }
        
        glDeleteShader(shader);
        return 0;
    }
    
    return shader;
}

- (int)initGlShader
{
    GLbyte vShaderStr[] =
    "attribute vec4 vPosition;              \n"
    "uniform mat4 vMatrix;                  \n"
    "void main()                            \n"
    "{                                      \n"
    "   gl_Position = vMatrix * vPosition;            \n"
    "}                                      \n";
    
    GLbyte fShaderStr[] =
    "precision mediump float;\n"
    "uniform vec4 fColor;                   \n"
    "void main()                            \n"
    "{                                      \n"
    "  gl_FragColor = fColor;               \n"
    "}                                      \n";
    
    GLuint vertexShader;
    GLuint fragmentShader;
    GLint linked;
    
    // Load the vertex/fragment shaders
    vertexShader = LoadShader(GL_VERTEX_SHADER, vShaderStr);
    fragmentShader = LoadShader(GL_FRAGMENT_SHADER, fShaderStr);
    
    // Create the program object
    programObject = glCreateProgram();
    
    if (programObject == 0)
        return 0;
    
    glAttachShader(programObject, vertexShader);
    glAttachShader(programObject, fragmentShader);
    
    // Bind vPosition to attribute 0
    glBindAttribLocation(programObject, 0,
                         "vPosition");
    
    // Link the program
    glLinkProgram(programObject);
    
    // Check the link status
    glGetProgramiv(programObject, GL_LINK_STATUS, &linked);
    
    if (!linked) {
        GLint infoLen = 0;
        
        glGetProgramiv(programObject, GL_INFO_LOG_LENGTH, &infoLen);
        
        if (infoLen > 1) {
            char *infoLog = malloc(sizeof(char) * infoLen);
            
            glGetProgramInfoLog(programObject, infoLen, NULL, infoLog);
            
            free(infoLog);
        }
        
        glDeleteProgram(programObject);
        return GL_FALSE;
    }
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    return GL_TRUE;
}

@end

