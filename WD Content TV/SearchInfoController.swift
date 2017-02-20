//
//  SearchInfoController.swift
//  WD Content
//
//  Created by Сергей Сейтов on 20.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

import UIKit

class SearchInfoController: UITableViewController {

	var searchFile:String?
	var results:[Any] = []
	
	private var imagesBaseURL:String?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		self.title = "Search Info"
		SVProgressHUD.show()
		TMDB.sharedInstance().get(kMovieDBConfiguration, parameters: nil, block: { result, err in
			SVProgressHUD.dismiss()
			if err == nil {
				if let config = result as? [String:Any] {
					if let imagesConfig = config["images"] as? [String:Any] {
						if let url = imagesConfig["base_url"] as? String {
							self.imagesBaseURL = "\(url)w185"
						}
						return
					}
				}
				self.showMessage("Can not connect to TMDB", messageType: .error, messageHandler: {
					_ = self.navigationController?.popViewController(animated: true)
				})
			} else {
				self.showMessage("Can not connect to TMDB", messageType: .error, messageHandler: {
					_ = self.navigationController?.popViewController(animated: true)
				})
			}
		})
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		search()
	}
	
	func search() {
		SVProgressHUD.show(withStatus: "Search...")
		TMDB.sharedInstance().get(kMovieDBSearchMovie, parameters: ["query": searchFile!], block: { responseObject, error in
			SVProgressHUD.dismiss()
			if error != nil {
				self.showMessage("Can not find info for \"\(self.searchFile!)\"", messageType: .information)
			} else {
				if let response = responseObject as? [String:Any] {
					if let results = response["results"] as? [Any] {
						if results.count > 0 {
							self.results = results
							self.tableView.reloadData()
						} else {
							self.showMessage("No results found for \"\(self.searchFile!)\"", messageType: .information)
						}
					}
				}
			}
		})
	}
	
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return section == 0 ? "movie title" : "found results"
	}
	
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 0 {
			return 1
		} else {
			return results.count
		}
    }
	
	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return indexPath.section == 0 ? 66 : 240
	}
	
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.section == 0 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "searchField") as! SearchCell
			cell.field.text = searchFile
			cell.accessoryType = .none
			return cell
		} else {
			let cell = tableView.dequeueReusableCell(withIdentifier: "searchResult", for: indexPath) as! SearchResultCell
			cell.imagesBaseURL = imagesBaseURL!
			cell.movie = results[indexPath.row] as? [String:Any]
			return cell
		}
    }

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if indexPath.section == 0 {
			var nameField:UITextField?
			let alert = UIAlertController(title: "Search Info", message: "Input title of movie:", preferredStyle: .alert)
			alert.addTextField(configurationHandler: { textField in
				textField.textAlignment = .center
				textField.text = self.searchFile
				nameField = textField
			})
			alert.addAction(UIAlertAction(title: "Search", style: .destructive, handler: { _ in
				self.searchFile = nameField?.text
				self.search()
			}))
			alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
			present(alert, animated: true, completion: nil)
		} else {
			if let movie = results[indexPath.row] as? [String:Any] {
				print(movie)
			}
		}
	}

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
