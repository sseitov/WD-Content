//
//  DeviceController.swift
//  WD Content
//
//  Created by Сергей Сейтов on 29.12.16.
//  Copyright © 2016 Sergey Seitov. All rights reserved.
//

import UIKit

let refreshNotification = Notification.Name("REFRESH")

class DeviceController: UITableViewController, SMBConnectionDelegate {

	var target:ServiceHost?
	var connection:SMBConnection?
	var content:[SMBFile] = []
	
    override func viewDidLoad() {
        super.viewDidLoad()
		self.title = target?.name
		
		connection = SMBConnection()
		connection?.delegate = self
		
		SVProgressHUD.show(withStatus: "Connect")
		DispatchQueue.global().async {
			if let connected = self.connection?.connect(to: self.target!.host, port: Int32(self.target!.port)) {
				DispatchQueue.main.async {
					SVProgressHUD.dismiss()
					if connected {
						self.content = self.connection!.folderContents(at: "/") as! [SMBFile]
						self.tableView.reloadData()
					} else {
						self.showMessage("Can not connect.", messageType: .error, messageHandler: {
							self.goBack()
						})
					}
				}
			} else {
				self.showMessage("Can not connect.", messageType: .error, messageHandler: {
					self.goBack()
				})
			}
		}
    }

	func requestAuth(_ auth: ((String?, String?) -> Void)!) {
		let alert = UIAlertController(title: target?.name, message: "Input credentials", preferredStyle: .alert)
		var userField:UITextField?
		var passwordField:UITextField?
		alert.addTextField(configurationHandler: { textField in
			textField.keyboardType = .emailAddress
			textField.textAlignment = .center
			textField.placeholder = "user name"
			userField = textField
		})
		alert.addTextField(configurationHandler: { textField in
			textField.keyboardType = .default
			textField.textAlignment = .center
			textField.placeholder = "password"
			textField.isSecureTextEntry = true
			passwordField = textField
		})
		alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
			auth(userField?.text, passwordField?.text)
			if self.connection!.isConnected() {
				self.content = self.connection!.folderContents(at: "/") as! [SMBFile]
				self.tableView.reloadData()
			} else {
				self.showMessage("Can not connect.", messageType: .error, messageHandler: {
					self.goBack()
				})
			}
		}))
		alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { _ in
			auth(nil, nil)
			self.goBack()
		}))
		present(alert, animated: true, completion: nil)
	}
	
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return content.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
		cell.textLabel!.text = content[(indexPath as NSIndexPath).row].name
		return cell
    }

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let folder = content[indexPath.row];
		Model.shared.addNode(folder, parent: nil)
		dismiss(animated: true, completion: {
			NotificationCenter.default.post(name: refreshNotification, object: nil)
		})
	}
}
