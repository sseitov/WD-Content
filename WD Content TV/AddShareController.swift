//
//  AddShareController.swift
//  WD Content
//
//  Created by Сергей Сейтов on 29.12.16.
//  Copyright © 2016 Sergey Seitov. All rights reserved.
//

import UIKit

class ServiceHost : NSObject {
	var name:String = ""
	var host:String = ""
	var port:Int32 = 0
	
	init(name:String, host:String, port:Int32) {
		super.init()
		self.name = name
		self.host = host
		self.port = port
	}
}

class AddShareController: UITableViewController {

	let serviceBrowser:NetServiceBrowser = NetServiceBrowser()
	var services:[NetService] = []
	var hosts:[ServiceHost] = []

    override func viewDidLoad() {
        super.viewDidLoad()
		self.title = "Devices"
		serviceBrowser.delegate = self
		serviceBrowser.searchForServices(ofType: "_smb._tcp.", inDomain: "local")
    }
	
	func updateInterface () {
		for service in self.services {
			if service.port == -1 {
//				print("service \(service.name) of type \(service.type)" +
//					" not yet resolved")
				service.delegate = self
				service.resolve(withTimeout:10)
			} else {
//				print("service \(service.name) of type \(service.type)," +
//					"port \(service.port), addresses \(service.addresses)")
				if let addresses = service.addresses {
					var ips: String = ""
					for address in addresses {
						let ptr = (address as NSData).bytes.bindMemory(to: sockaddr_in.self, capacity: address.count)
						var addr = ptr.pointee.sin_addr
						let buf = UnsafeMutablePointer<Int8>.allocate(capacity: Int(INET6_ADDRSTRLEN))
						let family = ptr.pointee.sin_family
						if family == __uint8_t(AF_INET)
						{
							if let ipc:UnsafePointer<Int8> = inet_ntop(Int32(family), &addr, buf, __uint32_t(INET6_ADDRSTRLEN)) {
								ips = String(cString: ipc)
							}
						}
					}
					if !hostInList(address: ips) {
						hosts.append(ServiceHost(name: service.name, host: ips, port: Int32(service.port)))
					}
					tableView.reloadData()
					service.stop()
				}
			}
		}
	}
	
	func hostInList(address:String) -> Bool {
		for host in hosts {
			if host.host == address {
				return true
			}
		}
		return false
	}
	
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return hosts.count
    }

	
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
		cell.textLabel!.text = hosts[(indexPath as NSIndexPath).row].name
		return cell
    }

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		performSegue(withIdentifier: "showDevice", sender: hosts[indexPath.row])
	}
	
	
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "showDevice" {
			let controller = segue.destination as! DeviceController
			controller.target = sender as? ServiceHost
		}
    }
}

// MARK: - NSNetServiceDelegate

extension AddShareController:NetServiceDelegate {
	
	func netServiceDidResolveAddress(_ sender: NetService) {
		updateInterface()
		sender.startMonitoring()
	}
}

// MARK: - NSNetServiceBrowserDelegate

extension AddShareController:NetServiceBrowserDelegate {

	func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
		services.append(service)
		if !moreComing {
			updateInterface()
		}
	}
}

