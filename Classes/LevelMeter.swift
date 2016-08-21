//
//  LevelMeter.swift
//  avTouch
//
//  Created by OOPer in cooperation with shlab.jp, on 2015/2/14.
//
//
//
import UIKit

func LEVELMETER_CLAMP(_ min: CGFloat, x: CGFloat, max: CGFloat) -> CGFloat {
    return x < min ? min : (x > max ? max : x)
}

typealias LevelMeterColorThreshold = (
    maxValue: CGFloat,
    color: UIColor
)

@objc(LevelMeter)
class LevelMeter: UIView {
    var numLights: Int = 0
    var level: CGFloat = 0.0
    var peakLevel: CGFloat = 0.0
    fileprivate var _colorThresholds: [LevelMeterColorThreshold] = [
        (0.25, UIColor(red: 0, green: 1, blue: 0, alpha: 1)),
        (0.8, UIColor(red: 1, green: 1, blue: 0, alpha: 1)),
        (1.0, UIColor(red: 1, green: 0, blue: 0, alpha: 1)),
    ]
    var vertical: Bool = false
    var variableLightIntensity: Bool = true
    var bgColor: UIColor? = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
    var borderColor: UIColor? = UIColor(red: 0, green: 0, blue: 0, alpha: 0.1)
    var _scaleFactor: CGFloat = 0.0
    
    
    func _performInit() {
        vertical = (self.frame.size.width < self.frame.size.height)
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self._performInit()
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self._performInit()
    }
    
    
    override func draw(_ rect: CGRect) {
        let cs: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let cxt: CGContext = UIGraphicsGetCurrentContext()!
        var bds = CGRect()
        
        if vertical {
            cxt.translateBy(x: 0.0, y: self.bounds.size.height)
            cxt.scaleBy(x: 1.0, y: -1.0)
            bds = self.bounds
        } else {
            cxt.translateBy(x: 0.0, y: self.bounds.size.height)
            cxt.rotate(by: -CGFloat(M_PI_2))
            bds = CGRect(x: 0.0, y: 0.0, width: self.bounds.size.height, height: self.bounds.size.width)
        }
        
        cxt.setFillColorSpace(cs)
        cxt.setStrokeColorSpace(cs)
        
        if numLights == 0 {
            var currentTop: CGFloat = 0.0
            
            if bgColor != nil {
                bgColor!.set()
                cxt.fill(bds)
            }
            
            for thisThresh in _colorThresholds {
                let val = min(thisThresh.maxValue, level)
                
                let rect = CGRect(
                    x: 0,
                    y: (bds.size.height) * currentTop,
                    width: bds.size.width,
                    height: (bds.size.height) * (val - currentTop)
                )
                
                thisThresh.color.set()
                cxt.fill(rect)
                
                if level < thisThresh.maxValue { break }
                
                currentTop = val
            }
            
            if borderColor != nil {
                borderColor!.set()
                cxt.stroke(bds.insetBy(dx: 0.5, dy: 0.5))
            }
            
        } else {
            var lightMinVal:CGFloat = 0.0
            var insetAmount: CGFloat = 0.0
            let lightVSpace: CGFloat = bds.size.height / CGFloat(numLights)
            if lightVSpace < 4.0 {
                insetAmount = 0.0
            } else if lightVSpace < 8.0 {
                insetAmount = 0.5
            } else {
                insetAmount = 1.0
            }
            
            var peakLight = -1
            if peakLevel > 0.0 {
                peakLight = Int(peakLevel) * numLights
                if peakLight >= numLights {
                    peakLight = numLights - 1
                }
            }
            
            for light_i in 0..<numLights {
                let lightMaxVal = CGFloat(light_i + 1) / CGFloat(numLights)
                var lightIntensity: CGFloat = 0.0
                
                if light_i == peakLight {
                    lightIntensity = 1.0
                } else {
                    lightIntensity = (level - lightMinVal) / (lightMaxVal - lightMinVal)
                    lightIntensity = LEVELMETER_CLAMP(0.0, x: lightIntensity, max: 1.0)
                    if (!variableLightIntensity) && (lightIntensity > 0.0) {
                        lightIntensity = 1.0
                    }
                }
                
                var lightColor: UIColor = _colorThresholds[0].color
                for color_i in 0..<_colorThresholds.count {
                    let thisThresh = _colorThresholds[color_i]
                    let nextThresh = _colorThresholds[color_i + 1]
                    if thisThresh.maxValue <= lightMaxVal {
                        lightColor = nextThresh.color
                    }
                }
                
                var lightRect:CGRect = CGRect(
                    x: 0.0,
                    y: bds.size.height * (CGFloat(light_i) / CGFloat(numLights)),
                    width: bds.size.width,
                    height: bds.size.height * (1.0 / CGFloat(numLights))
                )
                lightRect = lightRect.insetBy(dx: insetAmount, dy: insetAmount)
                
                if bgColor != nil {
                    bgColor!.set()
                    cxt.fill(lightRect)
                }
                
                if lightIntensity == 1.0 {
                    lightColor.set()
                    cxt.fill(lightRect)
                } else if lightIntensity > 0.0 {
                    let clr = lightColor.cgColor.copy(alpha: lightIntensity)
                    cxt.setFillColor(clr!)
                    cxt.fill(lightRect)
                }
                
                if borderColor != nil {
                    borderColor!.set()
                    cxt.stroke(lightRect.insetBy(dx: 0.5, dy: 0.5))
                }
                
                lightMinVal = lightMaxVal
            }
            
        }
        
    }
    
    var colorThresholds: [LevelMeterColorThreshold] {
        get {
            return _colorThresholds
        }
        
        set {
            _colorThresholds = newValue.sorted {$0.maxValue < $1.maxValue}
            
        }
    }
    
    
    
}
