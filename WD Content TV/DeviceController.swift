//
//  DeviceController.swift
//  WD Content
//
//  Created by Сергей Сейтов on 29.12.16.
//  Copyright © 2016 Sergey Seitov. All rights reserved.
//

import UIKit

class DeviceController: UITableViewController {

	var target:ServiceHost?
	var connection:SMBConnection?
	var content:[SMBFile] = []
	
    override func viewDidLoad() {
        super.viewDidLoad()
		self.title = target?.name
		
		connection = SMBConnection()
		
		SVProgressHUD.show(withStatus: "Connect")
		DispatchQueue.global().async {
			if let connected = self.connection?.connect(to: self.target!.host, port: Int32(self.target!.port), user: "guest", password: "") {
				DispatchQueue.main.async {
					SVProgressHUD.dismiss()
					if connected {
						self.content = self.connection!.folderContents(at: "/") as! [SMBFile]
						self.tableView.reloadData()
					} else {
//						self.errorMessage("Can not connect.")
					}
				}
			} else {
//				self.errorMessage("Can not connect.")
			}
		}
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


}
