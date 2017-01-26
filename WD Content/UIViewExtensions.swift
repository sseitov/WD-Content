//
//  UIViewExtensions.swift
//  CIFS Browser
//
//  Created by Сергей Сейтов on 24.01.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

extension UIView {
    
    func setupBorder(_ color:UIColor, radius:CGFloat) {
        self.layer.borderColor = color.cgColor
        self.layer.borderWidth = 1
        self.layer.cornerRadius = radius
        self.clipsToBounds = true
    }
    
}
