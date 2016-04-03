//
//  PadGestureRecognizer.swift
//  TAAESample
//
//  Created by Michael Tyson on 1/04/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//
// Strictly for educational purposes only. No part of TAAESample is to be distributed
// in any form other than as source code within the TAAE2 repository.

import UIKit
import UIKit.UIGestureRecognizerSubclass

class TriggerGestureRecognizer : UIGestureRecognizer {
    var pressure: Double = 0
    private var location: CGPoint = CGPointZero
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent) {
        self.state = UIGestureRecognizerState.Began
        location = touches.first!.locationInView(nil)
        pressure = Double(touches.first!.force / touches.first!.maximumPossibleForce)
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent) {
        self.state = UIGestureRecognizerState.Changed
        location = touches.first!.locationInView(nil)
        pressure = Double(touches.first!.force / touches.first!.maximumPossibleForce)
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent) {
        self.state = UIGestureRecognizerState.Ended
        location = touches.first!.locationInView(nil)
    }
    
    override func touchesCancelled(touches: Set<UITouch>, withEvent event: UIEvent) {
        self.state = UIGestureRecognizerState.Cancelled
    }
    
    override func locationInView(view: UIView?) -> CGPoint {
        if let view = view {
            return view.convertPoint(location, fromView: nil)
        } else {
            return location
        }
    }
}