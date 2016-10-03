//
//  ViewController.swift
//  TAAESample
//
//  Created by Michael Tyson on 23/03/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//
// Strictly for educational purposes only. No part of TAAESample is to be distributed
// in any form other than as source code within the TAAE2 repository.

import UIKit

let PadWetDryRate              = 0.04
let PadWetDryUpdateInterval    = 0.005
let SpeedSliderRestoreRate     = 0.02
let SpeedSliderRestoreInterval = 0.01
let ShowCountInThreshold       = 0.5
let NormalRecordRotateSpeed    = 30.0
let SyncRecordRotateSpeed      = -3.0

class ViewController: UIViewController {

    @IBOutlet var topBackground: UIView!
    @IBOutlet var bottomBackground: UIView!
    @IBOutlet var beatButton: PlayerButton!
    @IBOutlet var bassButton: PlayerButton!
    @IBOutlet var pianoButton: PlayerButton!
    @IBOutlet var sample1Button: UIButton!
    @IBOutlet var sample2Button: UIButton!
    @IBOutlet var sample3Button: UIButton!
    @IBOutlet var sweepButton: UIButton!
    @IBOutlet var hitButton: UIButton!
    @IBOutlet var speedSlider: UISlider!
    @IBOutlet var pad: UIImageView!
    @IBOutlet var stereoSweepButton: UIButton!
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var playSlider: UISlider!
    @IBOutlet var playSliderWidthConstraint: NSLayoutConstraint!
    @IBOutlet var exportButton: UIButton!
    @IBOutlet var micButton: UIButton!
    
    var audio: AEAudioController?
    
    fileprivate var padWetDryTimer: Timer?
    fileprivate var padWetDryTarget = 0.0
    fileprivate var padWetDryValue = 0.0
    fileprivate var speedRestoreTimer: Timer?
    fileprivate var playSliderUpdateTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup visuals
        topBackground.backgroundColor = UIColor(patternImage: UIImage(named: "Upper Background")!)
        bottomBackground.backgroundColor = UIColor(patternImage: UIImage(named: "Lower Background")!)
        beatButton.image = UIImage(named: "Beat")
        bassButton.image = UIImage(named: "Bass")
        pianoButton.image = UIImage(named: "Piano")
        
        let speedTrackImage = UIImage(named: "Speed Track")?
            .resizableImage(withCapInsets: UIEdgeInsets(top: 0.0, left: 2.0, bottom: 0.0, right: 2.0))
        speedSlider.setMaximumTrackImage(speedTrackImage, for: UIControlState())
        speedSlider.setMinimumTrackImage(speedTrackImage, for: UIControlState())
        speedSlider.setThumbImage(UIImage(named: "Speed Handle"), for: UIControlState())
        speedSlider.maximumValue = 2.0
        speedSlider.minimumValue = 0.0
        speedSlider.value = 1.0
        
        if traitCollection.horizontalSizeClass != UIUserInterfaceSizeClass.compact {
            speedSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-M_PI_2))
        }
        
        let playTrackImage = UIImage(named: "Play Slider Track")?.resizableImage(withCapInsets: UIEdgeInsetsMake(0, 1, 0, 1))
        playSlider.setMaximumTrackImage(playTrackImage, for: UIControlState())
        playSlider.setMinimumTrackImage(playTrackImage, for: UIControlState())
        playSlider.setThumbImage(UIImage(named: "Play Slider Thumb"), for: UIControlState())
        
        pad.image = UIImage(named: "Effect Bar")?
            .resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 63.0, bottom: 0, right: 62.0))
        
        // Add gesture recognizers
        pad.addGestureRecognizer(TriggerGestureRecognizer(target: self, action: #selector(effectPadPan)))
        hitButton.addGestureRecognizer(TriggerGestureRecognizer(target: self, action: #selector(hitTouch)))
        stereoSweepButton.addGestureRecognizer(TriggerGestureRecognizer(target: self, action: #selector(stereoSweepTouch)))
        
        // Enable/disable actions requiring prior recording
        updateFileActionsEnabled()
        
        // Monitor for some events
        NotificationCenter.default.addObserver(self, selector: #selector(inputEnabledChanged), name: NSNotification.Name.AEAudioControllerInputEnabledChanged, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(inputPermissionsError), name: NSNotification.Name.AEAudioControllerInputPermissionError, object: nil);
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override var prefersStatusBarHidden : Bool {
        // No status bar, please
        return true
    }
    
    override func willTransition(to newCollection: UITraitCollection,
                                                  with coordinator: UIViewControllerTransitionCoordinator) {
        // Slider is horizontal for small screens, vertical otherwise
        if newCollection.horizontalSizeClass == UIUserInterfaceSizeClass.compact {
            speedSlider.transform = CGAffineTransform.identity
        } else {
            speedSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-M_PI_2))
        }
    }
    
    // MARK: - Actions
    
    @IBAction func loopTapped(_ recognizer: UITapGestureRecognizer) {
        let sender = recognizer.view! as! PlayerButton
        if let player = associatedPlayerForView(sender) {
            if let audio = audio {
                if player.playing {
                    // Stop
                    player.stop()
                    sender.rotateSpeed = 0
                } else {
                    // Work out sync time
                    let syncTime = audio.nextSyncTime(forPlayer: player)
                    
                    // Start player
                    player.currentTime = 0
                    player.play(atTime: AETimeStampWithHostTicks(syncTime), begin: {
                        // Show playing state
                        sender.rotateSpeed = self.currentRotateSpeed()
                    })
                    
                    let now = AECurrentTimeInHostTicks()
                    if syncTime > now && AESecondsFromHostTicks(syncTime - now) > ShowCountInThreshold {
                        // If there's a sync delay, spin the record slowly so we know something's happening
                        sender.rotateSpeed = SyncRecordRotateSpeed
                    } else {
                        // Show playing state
                        sender.rotateSpeed = self.currentRotateSpeed()
                    }
                }
            }
        }
    }
    
    @IBAction func sampleButtonTapped(_ sender: UIButton) {
        if let player = associatedPlayerForView(sender) {
            if let audio = audio {
                if player.playing {
                    // Stop, and reset button state
                    player.stop()
                    sender.imageView!.layer.removeAllAnimations()
                    sender.isSelected = false
                } else {
                    // Work out sync time
                    let syncTime = audio.nextSyncTime(forPlayer: player)
                    
                    // Start player
                    player.currentTime = 0
                    player.play(atTime: AETimeStampWithHostTicks(syncTime), begin: {
                        // Set button state to playing
                        sender.imageView!.layer.removeAllAnimations()
                        sender.isSelected = true
                    })
                    
                    // Reset button state when we're done
                    player.completionBlock = { sender.isSelected = false }
                    
                    let now = AECurrentTimeInHostTicks()
                    if syncTime > now && AESecondsFromHostTicks(syncTime - now) > ShowCountInThreshold {
                        // If there's a sync delay, show a little animation so we know something's happening
                        let animation = CABasicAnimation(keyPath: "transform.translation.y")
                        animation.byValue = -8.0
                        animation.duration = audio.drums.duration / 32.0
                        animation.autoreverses = true
                        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
                        animation.repeatCount = Float.infinity
                        sender.imageView!.layer.add(animation, forKey: nil)
                    } else {
                        // Show playing state
                        sender.isSelected = true
                    }
                }
            }
        }
    }
    
    @IBAction func speedSliderDrag() {
        if speedRestoreTimer != nil {
            // Get rid of prior timer
            speedRestoreTimer?.invalidate()
            speedRestoreTimer = nil
        }
        
        // Set the playback rate based on the slider position
        updatePlaybackRate(Double(speedSlider!.value))
    }
    
    @IBAction func speedSliderEnd() {
        // Finished interacting with slider - set a timer to gradually bring the speed back to normal
        speedRestoreTimer = Timer.scheduledTimer(timeInterval: SpeedSliderRestoreInterval, target: self,
                                selector: #selector(speedSliderRestoreTimeout), userInfo: nil, repeats: true);
    }
    
    @IBAction func recordTap() {
        if let audio = audio {
            if audio.recording {
                // Stop recording
                audio.stopRecording(atTime: 0, completionBlock: { 
                    self.recordButton.isSelected = false
                    self.recordButton.layer.removeAllAnimations()
                    self.updateFileActionsEnabled()
                });
            } else {
                do {
                    // Start recording
                    try audio.beginRecording(atTime: 0)
                    
                    // Add a little animation to show recording is active
                    recordButton.isSelected = true
                    let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                    animation.byValue = 2.0*M_PI
                    animation.duration = 2.0
                    animation.repeatCount = Float.infinity
                    recordButton.layer.add(animation, forKey: nil)
                } catch _ {
                    // D'oh, something went wrong. Guess we can't record.
                    recordButton.isEnabled = false
                    recordButton.layer.removeAllAnimations()
                }
            }
        }
    }
    
    @IBAction func playTap() {
        if let audio = audio {
            if audio.playingRecording {
                // Stop the playback
                audio.stopPlayingRecording()
                playButton.isSelected = false
                UIView.animate(withDuration: 0.3, animations: { 
                    self.playSliderWidthConstraint.constant = 0
                    self.view.layoutIfNeeded()
                }, completion: { _ in
                    self.playSlider.isHidden = true
                })
                playSliderUpdateTimer?.invalidate()
                playSliderUpdateTimer = nil
            } else {
                // Start playback
                playButton.isSelected = true
                self.playSlider.isHidden = false
                UIView.animate(withDuration: 0.3, animations: {
                    self.playSliderWidthConstraint.constant = 150
                    self.view.layoutIfNeeded()
                })
                playSliderUpdateTimer = Timer.scheduledTimer(timeInterval: 1.0/60.0, target: self,
                                                                               selector: #selector(updatePlaySlider),
                                                                               userInfo: nil, repeats: true)
                audio.playRecording(completionBlock: { 
                    self.playButton.isSelected = false
                    UIView.animate(withDuration: 0.3, animations: {
                        self.playSliderWidthConstraint.constant = 0
                        self.view.layoutIfNeeded()
                    }, completion: { _ in
                        self.playSlider.isHidden = true
                    })
                    self.playSliderUpdateTimer?.invalidate()
                    self.playSliderUpdateTimer = nil
                })
            }
        }
    }
    
    @IBAction func playSliderChanged(_ sender: UISlider) {
        audio!.recordingPlaybackPosition = Double(sender.value)
    }
    
    @IBAction func exportTap() {
        if let audio = audio {
            // Show the share controller
            let controller = UIActivityViewController(activityItems: [audio.recordingPath], applicationActivities: nil)
            controller.completionWithItemsHandler = { activity, success, items, error in
                self.dismiss(animated: true, completion: nil)
            }
            
            if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
                controller.modalPresentationStyle = UIModalPresentationStyle.popover
                controller.popoverPresentationController?.sourceView = exportButton
            }
            
            present(controller, animated: true, completion: nil)
        }
    }
    
    @IBAction func micTap() {
        if let audio = audio {
            // Toggle mic
            audio.inputEnabled = !audio.inputEnabled
            micButton.isSelected = audio.inputEnabled
        }
    }
    
    @objc fileprivate func hitTouch(_ sender: TriggerGestureRecognizer) {
        if sender.state == UIGestureRecognizerState.began {
            if let audio = audio {
                // Begin playing the hit sample
                audio.hit.regionDuration = audio.drums.regionDuration / 32
                audio.hit.loop = true
                if !audio.hit.playing {
                    audio.hit.currentTime = 0
                    audio.hit.play(atTime: AETimeStampWithHostTicks(audio.nextSyncTime(forPlayer: audio.hit)))
                }
                hitButton.isSelected = true
                
                // Stop the drum loop
                if audio.drums.playing {
                    audio.drums.stop()
                }
                beatButton.rotateSpeed = -60.0 / audio.hit.regionDuration
            }
        } else if ( sender.state == UIGestureRecognizerState.changed ) {
            if let audio = audio {
                // Adjust the hit cycle length, based on 3D Touch pressure, for a beat repeat-like feature
                audio.hit.regionDuration = audio.drums.regionDuration / (sender.pressure >= 1.0 ? 64 : 32)
            }
        } else if sender.state == UIGestureRecognizerState.ended || sender.state == UIGestureRecognizerState.cancelled {
            if let audio = audio {
                // Start the drums playing again
                if !audio.drums.playing {
                    audio.drums.currentTime = 0
                    audio.drums.play(atTime: AETimeStampWithHostTicks(audio.nextSyncTime(forPlayer: audio.drums)))
                    beatButton.rotateSpeed = currentRotateSpeed()
                }
                
                // Stop the hit sample
                audio.hit.completionBlock = {
                    self.hitButton.isSelected = false
                }
                audio.hit.loop = false
            }
        }
        
    }
    
    @objc fileprivate func effectPadPan(_ sender: TriggerGestureRecognizer) {
        if sender.state == UIGestureRecognizerState.began {
            // Start transitioning to 100% wet
            padWetDryTarget = 1.0
            if padWetDryTimer == nil {
                padWetDryTimer = Timer.scheduledTimer(timeInterval: PadWetDryUpdateInterval, target: self,
                                                                       selector: #selector(padWetDryTimeout),
                                                                       userInfo: nil, repeats: true)
            }
        }
        if sender.state == UIGestureRecognizerState.began || sender.state == UIGestureRecognizerState.changed {
            // Update effect
            let location = sender.location(in: sender.view!)
            let bounds = sender.view!.bounds
            let x = Double(location.x / bounds.size.width);
            audio?.bandpassCenterFrequency = min(1.0, max(0.001, x*x*x*x)) * 16000.0
        } else {
            // Start transitioning to 0% wet
            padWetDryTarget = 0.0
            if padWetDryTimer == nil {
                padWetDryTimer = Timer.scheduledTimer(timeInterval: PadWetDryUpdateInterval, target: self,
                                                                        selector: #selector(padWetDryTimeout),
                                                                        userInfo: nil, repeats: true)
            }
        }
    }
    
    @objc fileprivate func stereoSweepTouch(_ sender: TriggerGestureRecognizer) {
        if let audio = audio {
            if sender.state == UIGestureRecognizerState.began || sender.state == UIGestureRecognizerState.changed {
                audio.balanceSweepRate = (sender.pressure >= 1.0 ? 0.5 : 2.0)
            } else {
                audio.balanceSweepRate = 0.0
            }
        }
    }
}

// Mark: - Events

private extension ViewController {
    @objc func inputEnabledChanged() {
        micButton.isSelected = audio!.inputEnabled
    }
    
    @objc func inputPermissionsError() {
        let displayName = Bundle.main.infoDictionary!["CFBundleDisplayName"]!
        let alert = UIAlertController(title: "Microphone permissions required", message: "In order to record, you need to enable microphone permissions for \(displayName). To fix this, open the Settings app, then under Privacy and Microphone, turn on the switch beside \(displayName)", preferredStyle: UIAlertControllerStyle.actionSheet)
        alert.addAction(UIAlertAction.init(title: "Open Settings", style: UIAlertActionStyle.default, handler: { action in
            UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
        }));
        alert.addAction(UIAlertAction.init(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        alert.popoverPresentationController?.sourceView = micButton
        alert.popoverPresentationController?.sourceRect = micButton.bounds
        alert.modalPresentationStyle = UIModalPresentationStyle.popover
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - Helpers

private extension ViewController {
    
    // Get player for a given UI element
    func associatedPlayerForView(_ view: UIView) -> AEAudioFilePlayerModule? {
        if let audio = audio {
            return view == beatButton ? audio.drums :
                    view == bassButton ? audio.bass :
                    view == pianoButton ? audio.piano :
                    view == sample1Button ? audio.sample1 :
                    view == sample2Button ? audio.sample2 :
                    view == sample3Button ? audio.sample3 :
                    view == hitButton ? audio.hit :
                    audio.sweep;
        } else {
            return nil
        }
    }
    
    // Respond to a change in playback rate
    func updatePlaybackRate(_ rate: Double) {
        if let audio = audio {
            audio.varispeed.playbackRate = rate
            let rotateSpeed = currentRotateSpeed()
            if audio.bass.playing {
                bassButton.rotateSpeed = rotateSpeed
            }
            if audio.drums.playing {
                beatButton.rotateSpeed = rotateSpeed
            }
            if audio.piano.playing {
                pianoButton.rotateSpeed = rotateSpeed
            }
        }
    }
    
    // Enable/disable recording-based actions, depending on whether a recording exists
    func updateFileActionsEnabled() {
        if let audio = audio {
            let fileManager = FileManager.default
            exportButton.isEnabled = fileManager.fileExists(atPath: audio.recordingPath.path)
            playButton.isEnabled = exportButton.isEnabled;
        }
    }
    
    // Calculate rotation animation speed
    func currentRotateSpeed() -> Double {
        return audio != nil ? audio!.varispeed.playbackRate * NormalRecordRotateSpeed : 1.0
    }
    
    // Transition between wet and dry for effect
    @objc func padWetDryTimeout() {
        if padWetDryTarget > padWetDryValue {
            padWetDryValue = min(padWetDryTarget, padWetDryValue + PadWetDryRate)
        } else {
            padWetDryValue = max(padWetDryTarget, padWetDryValue - PadWetDryRate)
        }
        audio?.bandpassWetDry = padWetDryValue
        if padWetDryValue == padWetDryTarget {
            padWetDryTimer?.invalidate()
            padWetDryTimer = nil
        }
    }
    
    // Transition speed back to normal
    @objc func speedSliderRestoreTimeout() {
        if let speedSlider = speedSlider {
            if speedSlider.value > 1.0 {
                speedSlider.value = max(1.0, speedSlider.value - Float(SpeedSliderRestoreRate))
            } else {
                speedSlider.value = min(1.0, speedSlider.value + Float(SpeedSliderRestoreRate))
            }
            
            updatePlaybackRate(Double(speedSlider.value))
            
            if speedSlider.value == 1.0 {
                speedRestoreTimer?.invalidate()
                speedRestoreTimer = nil
            }
        }
    }
    
    @objc func updatePlaySlider() {
        playSlider.value = Float(audio!.recordingPlaybackPosition)
    }
}

