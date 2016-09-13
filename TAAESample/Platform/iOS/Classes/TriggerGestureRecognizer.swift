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
    fileprivate var location: CGPoint = CGPoint.zero
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        self.state = UIGestureRecognizerState.began
        location = touches.first!.location(in: nil)
        pressure = Double(touches.first!.force / touches.first!.maximumPossibleForce)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        self.state = UIGestureRecognizerState.changed
        location = touches.first!.location(in: nil)
        pressure = Double(touches.first!.force / touches.first!.maximumPossibleForce)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        self.state = UIGestureRecognizerState.ended
        location = touches.first!.location(in: nil)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        self.state = UIGestureRecognizerState.cancelled
    }
    
    override func location(in view: UIView?) -> CGPoint {
        if let view = view {
            return view.convert(location, from: nil)
        } else {
            return location
        }
    }
}
