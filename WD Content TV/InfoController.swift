//
//  InfoController.swift
//  WD Content
//
//  Created by Сергей Сейтов on 20.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

import UIKit

class InfoController: UITableViewController {

	var info:[String:Any]?
	var imageBaseURL:String?
	var node:Node?
	var metainfo:MetaInfo?
	
	private var movieInfo:[String:Any]?
	private var credits:[String:Any]?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		self.title = "Movie Info"
		
		if info == nil && metainfo != nil {
			navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(self.clearInfo))
		}
		
		if info != nil, let uid = info!["id"] as? Int {
			navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(self.saveInfo))
			SVProgressHUD.show(withStatus: "Load Info...")
			TMDB.sharedInstance().get(kMovieDBMovie, parameters: ["id" : "\(uid)"], block: { responseObject, error in
				if let movieInfo = responseObject as? [String:Any] {
					self.movieInfo = movieInfo
					TMDB.sharedInstance().get(kMovieDBMovieCredits, parameters: ["id" : "\(uid)"], block: { response, error in
						if let credits = response as? [String:Any] {
							self.credits = credits
						}
						self.tableView.reloadData()
						SVProgressHUD.dismiss()
					})
				} else {
					self.tableView.reloadData()
					SVProgressHUD.dismiss()
				}
			})
		}
    }

	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		if presses.first != nil && presses.first!.type == .menu {
			if metainfo != nil {
				dismiss(animated: true, completion: nil)
			} else {
				_ = navigationController?.popViewController(animated: true)
			}
		}
	}
	
	func clearInfo() {
		metainfo!.node!.info = nil
		Model.shared.clearInfo(metainfo!)
		NotificationCenter.default.post(name: refreshNotification, object: nil)
		dismiss(animated: true, completion: nil)
	}
	
	func saveInfo() {
		let uid = info!["id"] as? Int
		
		metainfo = Model.shared.createInfo("\(uid)")
		metainfo?.title = info!["title"] as? String
		metainfo?.overview = info!["overview"] as? String
		metainfo?.release_date = info!["release_date"] as? String
		metainfo?.poster = posterPath()
		metainfo?.runtime = runtime()
		metainfo?.genre = genres()
		metainfo?.cast = cast()
		metainfo?.director = director()

		if node!.info != nil {
			Model.shared.clearInfo(node!.info!)
		}
		node?.info = metainfo
		metainfo?.node = node
		Model.shared.saveContext()
		NotificationCenter.default.post(name: refreshNotification, object: nil)
		dismiss(animated: true, completion: nil)
	}
	
	private func posterPath() -> String? {
		if let posterPath = info!["poster_path"] as? String {
			return "\(imageBaseURL!)\(posterPath)"
		} else {
			return nil;
		}
	}
	
	private func runtime() -> String? {
		if movieInfo != nil, let runtime = movieInfo!["runtime"] as? Int {
			return "\(runtime)"
		} else {
			return nil
		}
	}
	
	private func genres() -> String? {
		if movieInfo != nil, let genresArr = movieInfo!["genres"] as? [Any] {
			var genres:[String] = []
			for item in genresArr {
				if let genreItem = item as? [String:Any], let genre = genreItem["name"] as? String {
					genres.append(genre)
				}
			}
			return genres.joined(separator: ", ")
		} else {
			return nil
		}
	}
	
	private func cast() -> String? {
		if credits != nil, let castArr = credits!["cast"] as? [Any] {
			var cast:[String] = []
			for item in castArr {
				if let casting = item as? [String:Any], let name = casting["name"] as? String {
					cast.append(name)
				}
			}
			return cast.joined(separator: ", ")
		} else {
			return nil
		}
	}
	
	private func director() -> String? {
		if credits != nil, let crewArr =  credits!["crew"] as? [Any] {
			var director:[String] = []
			for item in crewArr {
				if let crew = item as? [String:Any], let job = crew["job"] as? String, job == "Director", let name = crew["name"] as? String {
					director.append(name)
				}
			}
			return director.joined(separator: ", ")
		} else {
			return nil
		}
	}
	
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 0
    }

    /*
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        // Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
