//
//  SharesController.swift
//  WD Content
//
//  Created by Сергей Сейтов on 29.12.16.
//  Copyright © 2016 Sergey Seitov. All rights reserved.
//

import UIKit

class SharesController: UICollectionViewController, UIGestureRecognizerDelegate {

	var parentNode:Node?
	var nodes:[Node] = []
	
	private var focusedIndexPath:IndexPath?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		NotificationCenter.default.addObserver(self,
		                                       selector: #selector(self.refresh),
		                                       name: refreshNotification,
		                                       object: nil)
		
		let longTap = UILongPressGestureRecognizer(target: self, action: #selector(self.pressLongTap(tap:)))
		longTap.delegate = self
		collectionView?.addGestureRecognizer(longTap)
		
		nodes = Model.shared.nodes(byRoot: nil)
		if parentNode == nil && nodes.count == 0 {
			performSegue(withIdentifier: "addShare", sender: nil)
		} else {
			refresh()
		}
    }

	func pressLongTap(tap:UILongPressGestureRecognizer) {
		if tap.state == .began {
			if focusedIndexPath != nil, focusedIndexPath!.row > 0 {
				let node = nodes[focusedIndexPath!.row - 1]
				let alert = UIAlertController(title: "Attention!", message: "Do you want to delete \(node.name!)", preferredStyle: .alert)
				alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
					Model.shared.deleteNode(node)
					self.nodes.remove(at: self.focusedIndexPath!.row - 1)
					self.collectionView?.deleteItems(at: [self.focusedIndexPath!])
				}))
				alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
				present(alert, animated: true, completion: nil)
			}
		}
	}
	
	func refresh() {
		self.title = parentNode == nil ? "My Shares" : parentNode!.name!
		nodes.removeAll()
		SVProgressHUD.show(withStatus: "Refresh...")
		DispatchQueue.global().async {
			self.nodes = Model.shared.nodes(byRoot: self.parentNode)
			DispatchQueue.main.async {
				SVProgressHUD.dismiss()
				self.collectionView?.reloadData()
			}
		}
	}

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return parentNode == nil ? nodes.count + 1 : nodes.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "share", for: indexPath) as! ShareCell
		if indexPath.row == 0 && parentNode == nil {
			cell.imageView.image = UIImage(named: "addShare")
			cell.textView.text = ""
		} else {
			let node = parentNode == nil ? nodes[indexPath.row-1] : nodes[indexPath.row]
			cell.node = node
		}
        return cell
    }

	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		if presses.first != nil && presses.first!.type == .menu {
			if parentNode != nil {
				parentNode = parentNode!.parent
				refresh()
			} else {
				super.pressesEnded(presses, with: event)
			}
		}
	}

	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
	}

    // MARK: UICollectionViewDelegate
	
	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		if parentNode == nil && indexPath.row == 0 {
			performSegue(withIdentifier: "addShare", sender: nil)
		} else  {
			let node = parentNode == nil ? nodes[indexPath.row-1] : nodes[indexPath.row]
			if node.isFile {
				let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
				alert.addAction(UIAlertAction(title: "Preview moview", style: .default, handler: { _ in
					self.performSegue(withIdentifier: "showMovie", sender: node)
				}))
				alert.addAction(UIAlertAction(title: "Show info", style: .destructive, handler: { _ in
					if node.info == nil {
						self.performSegue(withIdentifier: "searchInfo", sender: node)
					} else {
						self.performSegue(withIdentifier: "info", sender: node.info!)
					}
				}))
				alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
				present(alert, animated: true, completion: nil)
			} else {
				parentNode = node
				refresh()
			}
		}
	}

	override func collectionView(_ collectionView: UICollectionView, shouldUpdateFocusIn context: UICollectionViewFocusUpdateContext) -> Bool {
		focusedIndexPath = context.nextFocusedIndexPath
		return true
	}
	
	// MARK: - Navigation
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "showDevice" {
			let controller = segue.destination as! DeviceController
			controller.target = sender as? ServiceHost
		} else if segue.identifier == "showMovie" {
			let nav = segue.destination as! UINavigationController
			let next = nav.topViewController as! MovieController
			if let node = sender as? Node {
				next.host = node.connection!.ip!
				next.port = node.connection!.port
				next.user = node.connection!.user!
				next.password = node.connection!.password!
				next.filePath = node.path!
			}
		} else if segue.identifier == "searchInfo" {
			let nav = segue.destination as! UINavigationController
			let next = nav.topViewController as! SearchInfoController
			next.node = sender as? Node
		} else if segue.identifier == "info" {
			let nav = segue.destination as! UINavigationController
			let next = nav.topViewController as! InfoViewController
			next.metainfo = sender as? MetaInfo
		}
	}

}
