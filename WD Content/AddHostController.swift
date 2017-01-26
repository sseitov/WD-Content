//
//  AddHostController.swift
//  WD Content
//
//  Created by Сергей Сейтов on 26.01.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

import UIKit

class AddHostController: UIViewController, TextFieldContainerDelegate {

	var delegate:HostBrowserControllerDelegate?
	
    @IBOutlet weak var host: TextFieldContainer!
    @IBOutlet weak var workgroup: TextFieldContainer!
    @IBOutlet weak var user: TextFieldContainer!
    @IBOutlet weak var password: TextFieldContainer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
		self.setTitle("Add Device")
		
		host.placeholder = "xxx.xxx.xxx.xxx"
		host.textType = .numbersAndPunctuation
		host.returnType = .next
		host.setText("")
		host.delegate = self
		
		workgroup.placeholder = "workgroup"
		workgroup.textType = .emailAddress
		workgroup.returnType = .next
		workgroup.setText("WORKGROUP")
		workgroup.delegate = self
		
		user.placeholder = "user name"
		user.textType = .emailAddress
		user.returnType = .next
		user.setText("guest")
		user.delegate = self
		
		password.placeholder = "empty for guest"
		password.textType = .default
		password.secure = true
		password.returnType = .done
		password.setText("")
		password.delegate = self
		
    }
	
	func textDone(_ sender:TextFieldContainer, text:String?) {
		if sender == host {
			workgroup.activate(true)
		} else if sender == workgroup {
			user.activate(true)
		} else if sender == user {
			password.activate(true)
		} else {
			sender.activate(false)
		}
	}
	
	func textChange(_ sender:TextFieldContainer, text:String?) -> Bool {
		return true
	}

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true, completion: nil)
	}
	
	@IBAction func add(_ sender: Any) {
		if host.text().isEmpty {
			host.activate(true)
		}
		let auth = KxSMBAuth()
		auth.workgroup = workgroup.text()
		auth.username = user.text()
		auth.password = password.text()
		SVProgressHUD.show(withStatus: "Connect...")
		KxSMBProvider.shared()?.fetch(atPath: "smb://\(host.text())", auth: auth, block: { result in
			SVProgressHUD.dismiss()
			if let error = result as? NSError {
				self.errorMessage(error.localizedDescription)
			} else if let content = result as? [KxSMBItem] {
				var folders:[String] = []
				for item in content {
					folders.append(item.path)
				}
				self.delegate?.addHost(self.host.text(), content: folders, user: auth.username, password: auth.password)
			}
		})
	}
}
