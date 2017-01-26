//
//  UIColorExtensions.swift
//  CIFS Browser
//
//  Created by Сергей Сейтов on 24.01.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

extension UIColor {
    
    class func color(_ r: Float, _ g: Float, _ b: Float, _ a: Float) -> UIColor {
        return UIColor(red: CGFloat(r/255.0), green: CGFloat(g/255.0), blue: CGFloat(b/255.0), alpha: CGFloat(a))
    }
    
    class func color(_ rgb:UInt32) -> UIColor {
        let red = CGFloat((rgb & 0xFF0000) >> 16)
        let green = CGFloat((rgb & 0xFF00) >> 8)
        let blue = CGFloat(rgb & 0xFF)
        return UIColor(red: red/255.0, green: green/255.0, blue: blue/255.0, alpha: 1.0)
    }
    
    class func mainColor() -> UIColor {
        return color(0, 113, 165, 1)
    }
    
    class func mainColor(_ alpha:Float) -> UIColor {
        return color(0, 113, 165, alpha)
    }
    
}
