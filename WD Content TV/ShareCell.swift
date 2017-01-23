//
//  ShareCell.swift
//  WD Content
//
//  Created by Сергей Сейтов on 29.12.16.
//  Copyright © 2016 Sergey Seitov. All rights reserved.
//

import UIKit

class ShareCell: UICollectionViewCell {
    
	@IBOutlet weak var imageView: UIImageView!
	@IBOutlet weak var textView: UILabel!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		imageView.adjustsImageWhenAncestorFocused = false
		imageView.clipsToBounds = false
		textView.alpha = 0.3
	}
	
	override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {

		coordinator.addCoordinatedAnimations({
			if self.isFocused {
				self.textView.alpha = 1.0
				self.imageView.adjustsImageWhenAncestorFocused = true
			}
			else {
				self.textView.alpha = 0.3
				self.imageView.adjustsImageWhenAncestorFocused = false
			}
		}, completion: nil)

	}
}
