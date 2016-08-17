//
//  PlayerButton.swift
//  TAAESample
//
//  Created by Michael Tyson on 31/03/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//
// Strictly for educational purposes only. No part of TAAESample is to be distributed
// in any form other than as source code within the TAAE2 repository.

import UIKit

let IntrinsicSize = CGSize(width: 177.0, height: 186.0)
let AnimationKey = "rotation"

class PlayerButton: UIView {
    
    var image: UIImage? {
        willSet {
            imageLayer.contents = newValue?.CGImage
        }
    }
    
    var rotateSpeed: Double = 0 {
        willSet {
            if rotateAnimation != nil {
                let angle = positionForTime(CACurrentMediaTime(), speed: rotateSpeed)
                offset = angle
                imageLayer.transform = CATransform3DMakeRotation(CGFloat(angle), 0.0, 0.0, 1.0)
                imageLayer.removeAnimationForKey(AnimationKey)
                rotateAnimation = nil
            }
            
            if newValue != 0 {
                let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                animation.byValue = (newValue > 0 ? 1.0 : -1.0)*2.0*M_PI
                animation.duration = 60.0 / fabs(newValue);
                animation.repeatCount = Float.infinity
                animation.fillMode = kCAFillModeForwards
                imageLayer.addAnimation(animation, forKey: AnimationKey)
                startTime = CACurrentMediaTime()
                rotateAnimation = animation
            }
        }
    }
    
    private var startTime = 0.0
    private var offset = 0.0
    private var imageLayer: CALayer = CALayer()
    private var rotateAnimation: CAAnimation?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        layer.addSublayer(imageLayer)
        imageLayer.frame = layer.bounds
        imageLayer.contentsGravity = kCAGravityCenter
        imageLayer.contentsScale = UIScreen.mainScreen().scale
        
        let highlight = UIImageView(image: UIImage(named: "Vinyl Highlight and Shadow"))
        self.addSubview(highlight)
        self.addConstraint(NSLayoutConstraint(item: highlight, attribute: NSLayoutAttribute.CenterX,
            relatedBy: NSLayoutRelation.Equal, toItem: self, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: highlight, attribute: NSLayoutAttribute.CenterY,
            relatedBy: NSLayoutRelation.Equal, toItem: self, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0))
    }
    
    override func intrinsicContentSize() -> CGSize {
        return IntrinsicSize
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageLayer.frame = layer.bounds
    }
    
    private func positionForTime(time: CFTimeInterval, speed: Double) -> Double {
        return offset + ((time - startTime) / (60.0 / speed)) * 2.0*M_PI;
    }
}