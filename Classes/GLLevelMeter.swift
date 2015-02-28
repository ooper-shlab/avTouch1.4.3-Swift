//
//  GLLevelMeter.swift
//  avTouch
//
//  Created by OOPer in cooperation with shlab.jp, on 2015/2/14.
//
//

import UIKit
import OpenGLES

@objc(GLLevelMeter)
class GLLevelMeter: LevelMeter {
    var _backingWidth: GLint = 0
    var _backingHeight: GLint = 0
    var _context: EAGLContext!
    var _viewRenderbuffer: GLuint = 0
    var _viewFramebuffer: GLuint = 0
    
    
    override class func layerClass() -> AnyClass {
        return CAEAGLLayer.self
    }
    
    private func _createFrameBuffer() -> Bool {
        glGenFramebuffersOES(1, &_viewFramebuffer)
        glGenRenderbuffersOES(1, &_viewRenderbuffer)
        
        glBindFramebufferOES(GL_FRAMEBUFFER_OES.ui, _viewFramebuffer)
        glBindRenderbufferOES(GL_RENDERBUFFER_OES.ui, _viewRenderbuffer)
        _context.renderbufferStorage(GL_RENDERBUFFER_OES.l, fromDrawable: self.layer as! EAGLDrawable)
        glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES.ui, GL_COLOR_ATTACHMENT0_OES.ui, GL_RENDERBUFFER_OES.ui, _viewRenderbuffer)
        
        glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES.ui, GL_RENDERBUFFER_WIDTH_OES.ui, &_backingWidth)
        glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES.ui, GL_RENDERBUFFER_HEIGHT_OES.ui, &_backingHeight)
        
        if glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES.ui) != GL_FRAMEBUFFER_COMPLETE_OES.ui {
            NSLog("failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES.ui))
            return false
        }
        
        return true
    }
    
    private func _destroyFramebuffer() {
        glDeleteFramebuffersOES(1, &_viewFramebuffer)
        _viewFramebuffer = 0
        glDeleteRenderbuffersOES(1, &_viewRenderbuffer)
        _viewRenderbuffer = 0
        
    }
    
    private func _setupView() {
        
        glViewport(0, 0, _backingWidth, _backingHeight)
        glMatrixMode(GL_PROJECTION.ui)
        glLoadIdentity()
        glOrthof(0, _backingWidth.f, 0, _backingHeight.f, -1.0, 1.0)
        glMatrixMode(GL_MODELVIEW.ui)
        
        glClearColor(0.0, 0.0, 0.0, 1.0)
        
        glEnableClientState(GL_VERTEX_ARRAY.ui)
        
    }
    
    override func _performInit() {
        level = 0.0
        numLights = 0
        variableLightIntensity = true
        
        bgColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.6)
        borderColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        colorThresholds = [
            (0.6, UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)),
            (0.9, UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)),
            (1.0, UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)),
        ]
        vertical = (self.frame.size.width < self.frame.size.height)
        
        if self.respondsToSelector("setContentScaleFactor:") {
            self.contentScaleFactor = UIScreen.mainScreen().scale
            _scaleFactor = self.contentScaleFactor
        } else {
            _scaleFactor = 1.0
        }
        
        let eaglLayer = self.layer as! CAEAGLLayer
        
        eaglLayer.opaque = true
        
        eaglLayer.drawableProperties = [
            kEAGLDrawablePropertyRetainedBacking: false, kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8]
        
        _context = EAGLContext(API: .OpenGLES1)
        
        if !EAGLContext.setCurrentContext(_context) || !self._createFrameBuffer() {
            fatalError("\(__FUNCTION__) failed")
        }
        
        self._setupView()
    }
    
    
    private func _drawView() {
        if _viewFramebuffer == 0 { return }
        
        EAGLContext.setCurrentContext(_context)
        
        glBindFramebufferOES(GL_FRAMEBUFFER_OES.ui, _viewFramebuffer)
        
        let bgc = self.bgColor?.CGColor
        bail: do {
            
            if CGColorGetNumberOfComponents(bgc) != 4 { break bail }
            
            let rgba = CGColorGetComponents(bgc)
            
            glClearColor(rgba[0].f, rgba[1].f, rgba[2].f, 1.0)
            glClear(GL_COLOR_BUFFER_BIT.ui)
            
            glPushMatrix()
            
            var bds = CGRect()
            
            if vertical {
                glScalef(1.0, -1.0, 1.0)
                bds = CGRectMake(0.0, -1.0, self.bounds.size.width * _scaleFactor, self.bounds.size.height * _scaleFactor)
            } else {
                glTranslatef(0.0, Float(self.bounds.size.height * _scaleFactor), 0.0)
                glRotatef(-90.0, 0.0, 0.0, 1.0)
                bds = CGRectMake(0.0, 1.0, self.bounds.size.height * _scaleFactor, self.bounds.size.width * _scaleFactor)
            }
            
            if numLights == 0 {
                var currentTop: CGFloat = 0.0
                
                for thisThresh in colorThresholds {
                    let val = min(thisThresh.maxValue, level)
                    
                    let rect = CGRectMake(
                        0,
                        (bds.size.height) * currentTop,
                        bds.size.width,
                        (bds.size.height) * (val - currentTop)
                    )
                    
                    NSLog("Drawing rect (%0.2f, %0.2f, %0.2f, %0.2f)", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
                    
                    
                    var vertices: [GLfloat] = [
                        CGRectGetMinX(rect).f, CGRectGetMinY(rect).f,
                        CGRectGetMaxX(rect).f, CGRectGetMinY(rect).f,
                        CGRectGetMinX(rect).f, CGRectGetMaxY(rect).f,
                        CGRectGetMaxX(rect).f, CGRectGetMaxY(rect).f,
                    ]
                    
                    let clr = thisThresh.color.CGColor
                    if CGColorGetNumberOfComponents(clr) != 4 { break bail }
                    let rgba = CGColorGetComponents(clr)
                    glColor4f(rgba[0].f, rgba[1].f, rgba[2].f, rgba[3].f)
                    
                    
                    glVertexPointer(2, GL_FLOAT.ui, 0, vertices)
                    glDrawArrays(GL_TRIANGLE_STRIP.ui, 0, 4)
                    
                    
                    if level < thisThresh.maxValue { break }
                    
                    currentTop = val
                }
            } else {
                var lightMinVal: CGFloat = 0.0
                var insetAmount: CGFloat
                let lightVSpace = bds.size.height / CGFloat(numLights)
                if lightVSpace < 4.0 {
                    insetAmount = 0
                } else if lightVSpace < 8.0 {
                    insetAmount = 0.5
                } else {
                    insetAmount = 1.0
                }
                
                var peakLight = -1;
                if peakLevel > 0.0 {
                    peakLight = Int(peakLevel) * numLights
                    if peakLight >= numLights { peakLight = numLights - 1 }
                }
                
                for light_i in 0..<numLights {
                    let lightMaxVal = CGFloat(light_i + 1) / CGFloat(numLights)
                    var lightIntensity: CGFloat
                    
                    if light_i == peakLight {
                        lightIntensity = 1.0
                    } else {
                        lightIntensity = (level - lightMinVal) / (lightMaxVal - lightMinVal)
                        lightIntensity = LEVELMETER_CLAMP(0.0, lightIntensity, 1.0)
                        if (!variableLightIntensity) && (lightIntensity > 0.0) {
                            lightIntensity = 1.0
                        }
                    }
                    
                    var lightColor = colorThresholds[0].color
                    for color_i in 0..<(colorThresholds.count-1) {
                        let thisThresh = colorThresholds[color_i]
                        let nextThresh = colorThresholds[color_i + 1]
                        if thisThresh.maxValue <= lightMaxVal {
                            lightColor = nextThresh.color
                        }
                    }
                    
                    var lightRect = CGRectMake(
                        0.0,
                        bds.origin.y * (bds.size.height * (CGFloat(light_i) / CGFloat(numLights))),
                        bds.size.width,
                        bds.size.height * (1.0 / CGFloat(numLights))
                    )
                    lightRect = CGRectInset(lightRect, insetAmount, insetAmount)
                    
                    var vertices: [GLfloat] = [
                        CGRectGetMinX(lightRect).f, CGRectGetMinY(lightRect).f,
                        CGRectGetMaxX(lightRect).f, CGRectGetMinY(lightRect).f,
                        CGRectGetMinX(lightRect).f, CGRectGetMaxY(lightRect).f,
                        CGRectGetMaxX(lightRect).f, CGRectGetMaxY(lightRect).f,
                    ]
                    
                    glVertexPointer(2, GL_FLOAT.ui, 0, vertices)
                    
                    glColor4f(1.0, 0.0, 0.0, 1.0)
                    
                    if lightIntensity == 1.0 {
                        let clr = lightColor.CGColor
                        if CGColorGetNumberOfComponents(clr) != 4 { break bail }
                        let rgba = CGColorGetComponents(clr)
                        glColor4f(rgba[0].f, rgba[1].f, rgba[2].f, rgba[3].f)
                        glDrawArrays(GL_TRIANGLE_STRIP.ui, 0, 4)
                    } else if lightIntensity > 0.0 {
                        let clr = lightColor.CGColor
                        if CGColorGetNumberOfComponents(clr) != 4 { break bail }
                        let rgba = CGColorGetComponents(clr)
                        glColor4f(rgba[0].f, rgba[1].f, rgba[2].f, lightIntensity.f)
                        glDrawArrays(GL_TRIANGLE_STRIP.ui, 0, 4)
                    }
                    
                    lightMinVal = lightMaxVal
                }
                
                
            }
            
            
            
        } while false
        glPopMatrix()
        
        glFlush()
        glBindRenderbufferOES(GL_RENDERBUFFER_OES.ui, _viewRenderbuffer)
        _context.presentRenderbuffer(GL_RENDERBUFFER_OES.l)
    }
    
    
    override func layoutSubviews() {
        EAGLContext.setCurrentContext(_context)
        self._destroyFramebuffer()
        self._createFrameBuffer()
        self._drawView()
    }
    
    
    
    override func drawRect(rect: CGRect) {
        self._drawView()
    }
    
    override func setNeedsDisplay() {
        self._drawView()
    }
    
    
    deinit {
        if EAGLContext.currentContext() === _context {
            EAGLContext.setCurrentContext(nil)
        }
        
        
    }
    
    
    
    
}