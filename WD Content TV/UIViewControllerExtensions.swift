//
//  UIViewControllerExtensions.swift
//  WD Content
//
//  Created by Сергей Сейтов on 14.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

import UIKit

enum MessageType {
	case error, success, information
}

extension UIViewController {
	
	func setupBackButton() {
		navigationItem.leftBarButtonItem?.target = self
		navigationItem.leftBarButtonItem?.action = #selector(UIViewController.goBack)
	}
	
	func goBack() {
		_ = self.navigationController!.popViewController(animated: true)
	}

	func showMessage(_ message:String, messageType:MessageType, messageHandler: (() -> ())? = nil) {
		var title:String = ""
		switch messageType {
		case .success:
			title = "Success"
		case .information:
			title = "Information"
		default:
			title = "Error"
		}
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
			if messageHandler != nil {
				messageHandler!()
			}
		}))
		present(alert, animated: true, completion: nil)
	}

}
