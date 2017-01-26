//
//  HostBrowserController.swift
//  WD Content
//
//  Created by Сергей Сейтов on 23.01.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

import UIKit

func WAIT(_ condition:NSCondition) {
	condition.lock()
	condition.wait()
	condition.unlock()
}

func SIGNAL(_ condition:NSCondition) {
	condition.lock()
	condition.signal()
	condition.unlock()
}

@objc protocol HostBrowserControllerDelegate {
	func addHost(_ path:String, content:[String], user:String?, password:String?)
}

class HostBrowserController: UITableViewController {
	
	var delegate:HostBrowserControllerDelegate?
	private var hosts:[String] = []
	
    override func viewDidLoad() {
        super.viewDidLoad()		
		self.setTitle("Devices Browser")
		
		SVProgressHUD.show(withStatus: "Browse...")
		KxSMBProvider.shared()?.fetch(atPath: "smb://", block: { rootResult in
			if let rootError = rootResult as? NSError {
				SVProgressHUD.dismiss()
				print(rootError)
			} else if let root = rootResult as? [KxSMBItem] {
				DispatchQueue.global().async {
					let next = NSCondition()
					for rootItem in root {
						KxSMBProvider.shared()?.fetch(atPath: rootItem.path, block: { result in
							DispatchQueue.main.async {
								if let content = result as? [KxSMBItem] {
									for item in content {
										self.hosts.append(item.path)
									}
								}
							}
							SIGNAL(next)
						})
						WAIT(next)
					}
					DispatchQueue.main.async {
						SVProgressHUD.dismiss()
						self.tableView.reloadData()
					}
				}
			}
		})
    }

    @IBAction func cancel(_ sender: Any) {
		dismiss(animated: true, completion: nil)
    }
	
    @IBAction func addManual(_ sender: Any) {
		let alert = UIAlertController(title: nil, message: "Enter WD device IP address", preferredStyle: .alert)
		var cellTextField:UITextField?
		
		alert.addTextField(configurationHandler: { textField in
			textField.placeholder = "xxx.xxx.xxx.xxx"
			textField.textAlignment = .center
			textField.keyboardType = .numbersAndPunctuation
			cellTextField = textField
		})
		
		alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: nil))
		
		alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { action in
			if cellTextField!.text != nil && !cellTextField!.text!.isEmpty {
				self.tableView.beginUpdates()
				let newElement = IndexPath(row: self.hosts.count, section: 0)
				self.hosts.append("smb://\(cellTextField!.text!)")
				self.tableView.insertRows(at: [newElement], with: .bottom)
				self.tableView.endUpdates()
			}
		}))
		
		present(alert, animated: true, completion: nil)
    }
	
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return hosts.count
    }

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
		let host = hosts[(indexPath as NSIndexPath).row]
		cell.textLabel!.text = host.replacingOccurrences(of: "smb://", with: "")
		cell.accessoryType = .disclosureIndicator
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		SVProgressHUD.show(withStatus: "Fetch...")
		let host = hosts[indexPath.row]
		KxSMBProvider.shared()?.fetch(atPath: host, block: { result in
			SVProgressHUD.dismiss()
			if let error = result as? NSError {
				if error.code == 4 { // SMB Permission denied
					let alert = UIAlertController(title: nil, message: "Input credentials", preferredStyle: .alert)
					var userField:UITextField?
					var passwordField:UITextField?
					alert.addTextField(configurationHandler: { textField in
						textField.placeholder = "user name"
						textField.keyboardType = .emailAddress
						textField.textAlignment = .center
						userField = textField
					})
					alert.addTextField(configurationHandler: { textField in
						textField.placeholder = "password"
						textField.keyboardType = .default
						textField.textAlignment = .center
						textField.isSecureTextEntry = true
						passwordField = textField
					})
					alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: nil))
					alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
						if userField?.text != nil && passwordField?.text != nil {
							let auth = KxSMBAuth()
							auth.username = userField!.text!
							auth.password = passwordField!.text!
							SVProgressHUD.show(withStatus: "Authorize...")
							KxSMBProvider.shared()?.fetch(atPath: host, auth: auth, block: { result in
								SVProgressHUD.dismiss()
								if let error = result as? NSError {
									self.errorMessage(error.localizedDescription)
								} else if let content = result as? [KxSMBItem] {
									var folders:[String] = []
									for item in content {
										folders.append(item.path)
									}
									self.delegate?.addHost(host.replacingOccurrences(of: "smb://", with: ""), content: folders, user: auth.username, password: auth.password)
								}
							})
						}
					}))
					self.present(alert, animated: true, completion: nil)
				} else {
					self.errorMessage(error.localizedDescription)
				}
			} else if let content = result as? [KxSMBItem] {
				var folders:[String] = []
				for item in content {
					folders.append(item.path)
				}
				self.delegate?.addHost(host.replacingOccurrences(of: "smb://", with: ""), content: folders, user: nil, password: nil)
			}
		})
	}

}
