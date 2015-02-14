//
//  CALevelMeter.swiftr.swift
//  avTouch
//
//  Created by OOPer in cooperation with shlab.jp, on 2015/2/14.
//
//

import UIKit
import AudioToolbox
import AVFoundation

let kPeakFalloffPerSec: CGFloat	= 0.7
let kLevelFalloffPerSec: CGFloat = 0.8
let kMinDBvalue: Float = -80.0

@objc(CALevelMeter)
class CALevelMeter: UIView {
    private var _player: AVAudioPlayer?
    private var _channelNumbers: [Int] = [0]
    var _subLevelMeters: [LevelMeter] = []
    var _meterTable: MeterTable = MeterTable(minDecibels: kMinDBvalue)!
    var _updateTimer: CADisplayLink?
    var showsPeaks: Bool = true
    var vertical: Bool = false
    private var _useGL: Bool = true
    
    var _peakFalloffLastFire: CFAbsoluteTime = 0
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        vertical = (self.frame.size.width < self.frame.size.height)
        self.layoutSubLevelMeters()
        self.registerForBackgroundNotifications()
    }
    
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        vertical = (self.frame.size.width < self.frame.size.height)
        self.layoutSubLevelMeters()
        self.registerForBackgroundNotifications()
    }
    
    private func registerForBackgroundNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "pauseTimer",
            name: UIApplicationWillResignActiveNotification,
            object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "resumeTimer",
            name: UIApplicationWillEnterForegroundNotification,
            object: nil)
    }
    
    private func layoutSubLevelMeters() {
        for thisMeter in _subLevelMeters {
            thisMeter.removeFromSuperview()
        }
        _subLevelMeters.removeAll(keepCapacity: false)
        
        _subLevelMeters.reserveCapacity(_channelNumbers.count)
        
        var totalRect: CGRect
        
        if vertical {
            totalRect = CGRectMake(0.0, 0.0, self.frame.size.width + 2.0, self.frame.size.height)
        } else {
            totalRect = CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height + 2.0)
        }
        
        for i in 0..<_channelNumbers.count {
            var fr: CGRect
            
            if vertical {
                fr = CGRectMake(
                    totalRect.origin.x + ((CGFloat(i) / CGFloat(_channelNumbers.count)) * totalRect.size.width),
                    totalRect.origin.y,
                    (1.0 / CGFloat(_channelNumbers.count)) * totalRect.size.width - 2.0,
                    totalRect.size.height
                )
            } else {
                fr = CGRectMake(
                    totalRect.origin.x,
                    totalRect.origin.y + ((CGFloat(i) / CGFloat(_channelNumbers.count)) * totalRect.size.height),
                    totalRect.size.width,
                    (1.0 / CGFloat(_channelNumbers.count)) * totalRect.size.height - 2.0
                )
            }
            
            var newMeter: LevelMeter
            
            if _useGL {
                newMeter = GLLevelMeter(frame: fr)
            } else {
                newMeter = LevelMeter(frame: fr)
            }
            
            newMeter.numLights = 30
            newMeter.vertical = self.vertical
            _subLevelMeters.append(newMeter)
            self.addSubview(newMeter)
        }
        
    }
    
    
    @objc private func _refresh() {
        var success = false
        
        bail: do {
            if player == nil {
                var maxLvl: CGFloat = -1.0
                let thisFire = CFAbsoluteTimeGetCurrent()
                let timePassed = thisFire - _peakFalloffLastFire
                for thisMeter in _subLevelMeters {
                    var newLevel = thisMeter.level - timePassed.g * kLevelFalloffPerSec
                    if newLevel < 0.0 { newLevel = 0.0 }
                    thisMeter.level = newLevel
                    if showsPeaks {
                        var newPeak = thisMeter.peakLevel - timePassed.g * kPeakFalloffPerSec
                        if newPeak < 0.0 {
                            newPeak = 0.0
                        }
                        thisMeter.peakLevel = newPeak
                        if newPeak > maxLvl {
                            maxLvl = newPeak
                        }
                    } else if newLevel > maxLvl {
                        maxLvl = newLevel
                    }
                    
                    thisMeter.setNeedsDisplay()
                }
                if maxLvl <= 0.0 {
                    _updateTimer?.invalidate()
                    _updateTimer = nil
                }
                
                _peakFalloffLastFire = thisFire
                success = true
            } else {
                _player!.updateMeters()
                for i in 0..<_channelNumbers.count {
                    let channelIdx = _channelNumbers[i]
                    var channelView = _subLevelMeters[channelIdx]
                    
                    if channelIdx >= _channelNumbers.count { break bail }
                    if channelIdx > 127 { break bail }
                    
                    channelView.level = _meterTable.ValueAt(_player!.averagePowerForChannel(i)).g
                    if showsPeaks {
                        channelView.peakLevel = _meterTable.ValueAt(_player!.peakPowerForChannel(i)).g
                    } else {
                        channelView.peakLevel = 0.0
                    }
                    channelView.setNeedsDisplay()
                    success = true
                }
            }
            
        } while false
        
        if !success {
            for thisMeter in _subLevelMeters {
                thisMeter.level = 0.0
                thisMeter.setNeedsDisplay()
            }
            NSLog("ERROR: metering failed\n")
        }
    }
    
    
    deinit {
        _updateTimer?.invalidate()
        
    }
    
    
    var player: AVAudioPlayer? {
        get { return _player }
        set {
            if _player == nil && newValue != nil {
                if _updateTimer != nil { _updateTimer!.invalidate() }
                _updateTimer = CADisplayLink(target: self, selector: "_refresh")
                _updateTimer!.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
                
            } else if _player != nil && newValue == nil {
                _peakFalloffLastFire = CFAbsoluteTimeGetCurrent()
            }
            
            _player = newValue
            
            if let thePlayer = _player {
                thePlayer.meteringEnabled = true
                if thePlayer.numberOfChannels != _channelNumbers.count {
                    var chan_array: [Int]
                    if thePlayer.numberOfChannels < 2 {
                        chan_array = [0]
                    } else {
                        chan_array = [0, 1]
                    }
                    self.channelNumbers = chan_array
                }
            } else {
                for thisMeter in _subLevelMeters {
                    thisMeter.setNeedsDisplay()
                }
            }
        }
    }
    
    
    var channelNumbers: [Int] {
        get { return _channelNumbers }
        set {
            _channelNumbers = newValue
            self.layoutSubLevelMeters()
        }
    }
    
    var useGL: Bool {
        get { return _useGL }
        set {
            _useGL = newValue
            self.layoutSubLevelMeters()
        }
    }
    
    @objc private func pauseTimer() {
        _updateTimer?.invalidate()
        _updateTimer = nil
    }
    
    @objc private func resumeTimer() {
        if _player != nil {
            _updateTimer = CADisplayLink(target: self, selector: "_refresh")
            _updateTimer!.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        }
    }
    
}