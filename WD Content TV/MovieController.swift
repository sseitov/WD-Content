//
//  MovieController.swift
//  WD Content
//
//  Created by Сергей Сейтов on 18.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

import UIKit

class MovieController: UIViewController {

	var movie:Node?
	
	let demuxer = MovieDemuxer()
	
    override func viewDidLoad() {
		super.viewDidLoad();
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		SVProgressHUD.show(withStatus: "Load...")
		DispatchQueue.global().async {
			let audioChannels = NSMutableArray()
			let success = self.demuxer.load(self.movie!.connection!.ip!,
			                                port: Int32(self.movie!.connection!.port),
			                                user:self.movie!.connection!.user!,
			                                password:self.movie!.connection!.password!,
			                                file: self.movie!.path!,
			                                audioChannels: audioChannels)
			DispatchQueue.main.async {
				SVProgressHUD.dismiss()
				if !success {
					self.showMessage("Error open \"\(self.movie!.name!)\".", messageType: .error, messageHandler: {
						_ = self.navigationController?.popViewController(animated: true)
					})
				} else {
					let alert = UIAlertController(title: nil, message: "Choose audio channel", preferredStyle: .actionSheet)
					for i in 0..<audioChannels.count {
						if let channel = audioChannels.object(at: i) as? [String:Any], let title = channel["codec"] as? String {
							alert.addAction(UIAlertAction(title: title, style: .default, handler: { _ in
							}))
						}
					}
					alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { _ in
						_ = self.navigationController?.popViewController(animated: true)
					}))
					self.present(alert, animated: true, completion: nil)
				}
			}
		}
	}
	
	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		print("pressesEnded")
/*
		if presses.first != nil && presses.first!.type == .menu {
			if parentNode != nil {
				parentNode = parentNode!.parent
				refresh()
			} else {
				super.pressesEnded(presses, with: event)
			}
		}
*/
	}
	
	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		print("pressesBegan")
	}

}
