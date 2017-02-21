//
//  DeviceController.swift
//  WD Content
//
//  Created by Сергей Сейтов on 29.12.16.
//  Copyright © 2016 Sergey Seitov. All rights reserved.
//

import UIKit

let refreshNotification = Notification.Name("REFRESH")

class DeviceController: UITableViewController {

	var target:ServiceHost?
	
	private var connection = SMBConnection()
	private var cashedConnection:Connection?
	private var content:[SMBFile] = []
	
    override func viewDidLoad() {
        super.viewDidLoad()
		self.title = target?.name

		cashedConnection = Model.shared.getConnection(target!.host)
		var connected = false
		if cashedConnection != nil {
			connected = connection.connect(to: cashedConnection!.ip!,
			                   port: cashedConnection!.port,
			                   user: cashedConnection!.user!,
			                   password: cashedConnection?.password!)
		} else {
			connected = connection.connect(to: target!.host,
			                               port: target!.port,
			                               user: "",
			                               password: "")
		}
		if !connected {
			requestAuth()
		} else {
			if cashedConnection == nil {
				cashedConnection = Model.shared.addConnection(ip: self.target!.host, port: self.target!.port, user: "", password: "")
			}
			content = self.connection.folderContents(at: "/") as! [SMBFile]
			self.tableView.reloadData()
		}
    }

	func requestAuth() {
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
			if self.connection.connect(to: self.target!.host,
			                           port: self.target!.port,
			                           user: userField!.text!,
			                           password: passwordField!.text!) {
				
				self.cashedConnection = Model.shared.addConnection(ip: self.target!.host, port: self.target!.port, user: userField!.text!, password: passwordField!.text!)
				self.content = self.connection.folderContents(at: "/") as! [SMBFile]
				self.tableView.reloadData()
			} else {
				self.showMessage("Can not connect.", messageType: .error, messageHandler: {
					self.goBack()
				})
			}
		}))
		alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { _ in
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
		_ = Model.shared.addNode(folder, parent: nil, connection: cashedConnection!)
		dismiss(animated: true, completion: {
			NotificationCenter.default.post(name: refreshNotification, object: nil)
		})
	}
}
