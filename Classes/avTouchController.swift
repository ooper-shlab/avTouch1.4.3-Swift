//
//  avTouchController.swift
//  avTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/2/15.
//
//
  /*

    File: avTouchController.h
    File: avTouchController.mm
Abstract: VBase app controller class
 Version: 1.4.3

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Inc. ("Apple") in consideration of your agreement to the following
terms, and your use, installation, modification or redistribution of
this Apple software constitutes acceptance of these terms.  If you do
not agree with these terms, please do not use, install, modify or
redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may
be used to endorse or promote products derived from the Apple Software
without specific prior written permission from Apple.  Except as
expressly stated in this notice, no other rights or licenses, express or
implied, are granted by Apple herein, including but not limited to any
patent rights that may be infringed by your derivative works or by other
works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2014 Apple Inc. All Rights Reserved.


*/

import UIKit
import AudioToolbox
import AVFoundation

@objc(avTouchController)
class avTouchController: NSObject, UIPickerViewDelegate, AVAudioPlayerDelegate {
    
    @IBOutlet var fileName: UILabel!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var ffwButton: UIButton!
    @IBOutlet var rewButton: UIButton!
    @IBOutlet var volumeSlider: UISlider!
    @IBOutlet var progressBar: UISlider!
    @IBOutlet var currentTime: UILabel!
    @IBOutlet var duration: UILabel!
    @IBOutlet var lvlMeter_in: CALevelMeter!
    
    var player: AVAudioPlayer?
    var playBtnBG: UIImage!
    var pauseBtnBG: UIImage!
    var updateTimer: Timer?
    var rewTimer: Timer?
    var ffwTimer: Timer?
    
    var inBackground: Bool = false
    
    // amount to skip on rewind or fast forward
    private final let SKIP_TIME = 1.0
    // amount to play between skips
    private final let SKIP_INTERVAL = 0.2
    
    private func updateCurrentTimeForPlayer(_ p: AVAudioPlayer) {
        currentTime.text = String(format: "%d:%02d", Int32(p.currentTime) / 60, Int32(p.currentTime) % 60)
        progressBar.value = p.currentTime.f
    }
    
    @objc private func updateCurrentTime() {
        self.updateCurrentTimeForPlayer(self.player!)
    }
    
    private func updateViewForPlayerState(_ p: AVAudioPlayer) {
        self.updateCurrentTimeForPlayer(p)
        
        if updateTimer != nil {
            updateTimer!.invalidate()
        }
        
        if p.isPlaying {
            playButton.setImage(p.isPlaying ? pauseBtnBG : playBtnBG, for: UIControlState())
            lvlMeter_in.player = p
            updateTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(avTouchController.updateCurrentTime), userInfo: p, repeats: true)
        } else {
            playButton.setImage(p.isPlaying ? pauseBtnBG : playBtnBG, for: UIControlState())
            lvlMeter_in.player = nil
            updateTimer = nil
        }
        
    }
    
    private func updateViewForPlayerStateInBackground(_ p: AVAudioPlayer) {
        self.updateCurrentTimeForPlayer(p)
        
        if p.isPlaying {
            playButton.setImage(p.isPlaying ? pauseBtnBG : playBtnBG, for: UIControlState())
        } else {
            playButton.setImage(p.isPlaying ? pauseBtnBG : playBtnBG, for: UIControlState())
        }
    }
    
    private func updateViewForPlayerInfo(_ p: AVAudioPlayer) {
        duration.text = String(format: "%d:%02d", Int32(p.duration) / 60, Int32(p.duration) % 60)
        progressBar.maximumValue = p.duration.f
        volumeSlider.value = p.volume
    }
    
    @objc private func rewind() {
        let p = rewTimer?.userInfo as! AVAudioPlayer
        p.currentTime -= SKIP_TIME
        self.updateCurrentTimeForPlayer(p)
    }
    
    @objc private func ffwd() {
        let p = ffwTimer?.userInfo as! AVAudioPlayer
        p.currentTime += SKIP_TIME
        self.updateCurrentTimeForPlayer(p)
    }
    
    override func awakeFromNib() {
        playBtnBG = UIImage(named: "play.png")!
        pauseBtnBG = UIImage(named: "pause.png")!
        
        playButton.setImage(playBtnBG, for: UIControlState())
        
        self.registerForBackgroundNotifications()
        
        updateTimer = nil
        rewTimer = nil
        ffwTimer = nil
        
        duration.adjustsFontSizeToFitWidth = true
        currentTime.adjustsFontSizeToFitWidth = true
        progressBar.minimumValue = 0.0
        
        // Load the the sample file, use mono or stero sample
        let fileURL = Bundle.main.url(forResource: "sample", withExtension: "m4a")!
        do {
        
            player = try AVAudioPlayer(contentsOf: fileURL)
        } catch _ {
            player = nil
        }
        
        if self.player != nil {
            fileName.text = String(format: "%@ (%ld ch.)", player!.url!.lastPathComponent, player!.numberOfChannels)
            self.updateViewForPlayerInfo(player!)
            self.updateViewForPlayerState(player!)
            player!.numberOfLoops = 1
            player!.delegate = self
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        } catch let setCategoryError as NSError {
            NSLog("Error setting category! %d", Int32(setCategoryError.code))
        }
        
        // we don't do anything special in the route change notification
        NotificationCenter.default.addObserver(self,
            selector: #selector(avTouchController.handleRouteChange(_:)),
            name: .AVAudioSessionRouteChange,
            object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(avTouchController.handleInterruption(_:)),
                                               name: .AVAudioSessionInterruption,
                                               object: nil)
    }
    
    private func pausePlaybackForPlayer(_ p: AVAudioPlayer) {
        p.pause()
        self.updateViewForPlayerState(p)
    }
    
    private func startPlaybackForPlayer(_ p: AVAudioPlayer) {
        if p.play() {
            self.updateViewForPlayerState(p)
        } else {
            NSLog("Could not play \(p.url!)\n")
        }
    }
    
    @IBAction func playButtonPressed(_: UIButton) {
        if player?.isPlaying == true {
            self.pausePlaybackForPlayer(player!)
        } else {
            self.startPlaybackForPlayer(player!)
        }
    }
    
    @IBAction func rewButtonPressed(_: UIButton) {
        if rewTimer != nil { rewTimer!.invalidate() }
        rewTimer = Timer.scheduledTimer(timeInterval: SKIP_INTERVAL, target: self, selector: #selector(avTouchController.rewind), userInfo: player, repeats: true)
    }
    
    @IBAction func rewButtonReleased(_: UIButton) {
        if rewTimer != nil { rewTimer!.invalidate() }
        rewTimer = nil
    }
    
    @IBAction func ffwButtonPressed(_: UIButton) {
        if ffwTimer != nil { ffwTimer!.invalidate() }
        ffwTimer = Timer.scheduledTimer(timeInterval: SKIP_INTERVAL, target: self, selector: #selector(avTouchController.ffwd), userInfo: player, repeats: true)
    }
    
    @IBAction func ffwButtonReleased(_: UIButton) {
        if ffwTimer != nil { ffwTimer!.invalidate() }
        ffwTimer = nil
    }
    
    @IBAction func volumeSliderMoved(_ sender: UISlider) {
        player?.volume = sender.value
    }
    
    @IBAction func progressSliderMoved(_ sender: UISlider) {
        player!.currentTime = sender.value.d
        self.updateCurrentTimeForPlayer(player!)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        
    }
    
    //MARK: AVAudioSession notification handlers
    
    @objc func handleRouteChange(_ notification: Notification) {
        let reasonValue = notification.userInfo![AVAudioSessionRouteChangeReasonKey]! as! UInt
        let routeDescription = notification.userInfo![AVAudioSessionRouteChangePreviousRouteKey]! as! AVAudioSessionRouteDescription
        
        NSLog("Route change:")
        if let reason = AVAudioSessionRouteChangeReason(rawValue: reasonValue) {
            switch reason {
            case .newDeviceAvailable:
                NSLog("     NewDeviceAvailable")
            case .oldDeviceUnavailable:
                self.pausePlaybackForPlayer(player!)
                NSLog("     OldDeviceUnavailable")
            case .categoryChange:
                NSLog("     CategoryChange")
                NSLog(" New Category: %@", AVAudioSession.sharedInstance().category)
            case .override:
                NSLog("     Override")
            case .wakeFromSleep:
                NSLog("     WakeFromSleep")
            case .noSuitableRouteForCategory:
                NSLog("     NoSuitableRouteForCategory")
            case .routeConfigurationChange:
                NSLog("     RouteConfigurationChange")
            case .unknown:
                NSLog("     Unknown")
            }
        } else {
            NSLog("     ReasonUnknown")
        }
        
        NSLog("Previous route:\n")
        NSLog("%@", routeDescription)
    }
    
    func handleInterruption(_ notification: Notification) {
        if
            let interruptionType = notification.userInfo?[AVAudioSessionInterruptionTypeKey]
            as? AVAudioSessionInterruptionType,
            let p = self.player
        {
            switch interruptionType {
            case .began:
                NSLog("Interruption begin. Updating UI for new state")
                // the object has already been paused,	we just need to update UI
                if inBackground {
                    self.updateViewForPlayerStateInBackground(p)
                } else {
                    self.updateViewForPlayerState(p)
                }
            case .ended:
                NSLog("Interruption ended. Resuming playback")
                self.startPlaybackForPlayer(p)
            }
        }
    }
    
    //MARK: AVAudioPlayer delegate methods
    
    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully success: Bool) {
        if !success {
            NSLog("Playback finished unsuccessfully")
        }
        
        p.currentTime = 0.0
        if inBackground {
            self.updateViewForPlayerStateInBackground(p)
        } else {
            self.updateViewForPlayerState(p)
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        NSLog("ERROR IN DECODE: \(error?.localizedDescription ?? "nil")\n")
    }
    
//    // we will only get these notifications if playback was interrupted
//    func audioPlayerBeginInterruption(_ p: AVAudioPlayer) {
//        NSLog("Interruption begin. Updating UI for new state")
//        // the object has already been paused,	we just need to update UI
//        if inBackground {
//            self.updateViewForPlayerStateInBackground(p)
//        } else {
//            self.updateViewForPlayerState(p)
//        }
//    }
//    
//    func audioPlayerEndInterruption(_ p: AVAudioPlayer) {
//        NSLog("Interruption ended. Resuming playback")
//        self.startPlaybackForPlayer(p)
//    }
    
    //MARK: background notifications
    func registerForBackgroundNotifications() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(avTouchController.setInBackgroundFlag),
            name: .UIApplicationWillResignActive,
            object: nil)
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(avTouchController.clearInBackgroundFlag),
            name: .UIApplicationWillEnterForeground,
            object: nil)
    }
    
    @objc private func setInBackgroundFlag() {
        inBackground = true
    }
    
    @objc private func clearInBackgroundFlag() {
        inBackground = false
    }
    
}
