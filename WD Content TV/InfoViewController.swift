//
//  InfoViewController.swift
//  WD Content
//
//  Created by Сергей Сейтов on 21.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

import UIKit

class InfoViewController: UIViewController, UITableViewDataSource {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var infoTable: UITableView!
    @IBOutlet weak var castView: UITextView!
    @IBOutlet weak var overviewView: UITextView!
    @IBOutlet weak var castConstraint: NSLayoutConstraint!
	
	var info:[String:Any]?
	var imageBaseURL:String?
	var node:Node?
	var metainfo:MetaInfo?
	
	private var movieInfo:[String:Any]?
	private var credits:[String:Any]?

    override func viewDidLoad() {
        super.viewDidLoad()
		self.title = "Movie Info"
		
		castConstraint.constant = 0
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
						self.showInfo()
						SVProgressHUD.dismiss()
					})
				} else {
					self.showInfo()
					SVProgressHUD.dismiss()
				}
			})
		}
    }
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		showInfo()
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
	
	func showInfo() {
		if metainfo != nil {
			self.title = metainfo!.title
			if metainfo!.poster != nil, let url = URL(string: metainfo!.poster!) {
				imageView.sd_setImage(with: url, placeholderImage: UIImage(named: "movie"))
			} else {
				imageView.image = UIImage(named: "movie")
			}
			castView.text = metainfo!.cast
			overviewView.text = metainfo!.overview
		} else {
			self.title = info!["title"] as? String
			if let path = posterPath(), let url = URL(string: path) {
				imageView.sd_setImage(with: url, placeholderImage: UIImage(named: "movie"))
			} else {
				imageView.image = UIImage(named: "movie")
			}
			castView.text = cast()
			overviewView.text = info!["overview"] as? String
		}
		infoTable.reloadData()
		if castView.text != nil {
			let castHeight = castView.text!.heightWithConstrainedWidth(width: castView.frame.width, font: castView.font!) + 40
			let overviewHeight = overviewView.text!.heightWithConstrainedWidth(width: overviewView.frame.width, font: overviewView.font!) + 40
			let height = self.view.frame.height - castView.frame.origin.y - overviewHeight - 80
			castConstraint.constant = castHeight > height ? height : castHeight
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
		metainfo?.rating = rating()
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
	
	private func rating() -> String? {
		if movieInfo != nil, let popularity = movieInfo!["vote_average"] as? Double {
			return "\(popularity)"
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

	func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 5
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
		switch indexPath.row {
		case 0:
			cell.textLabel?.text = "Director"
			cell.detailTextLabel?.text = metainfo != nil ? metainfo!.director : director()
		case 1:
			cell.textLabel?.text = "Release Date"
			let formatter = DateFormatter()
			formatter.dateFormat = "yyyy-MM-dd"
			if let text = metainfo != nil ? metainfo!.release_date : info!["release_date"] as? String, let date = formatter.date(from: text) {
				let yearFormatter = DateFormatter()
				yearFormatter.dateStyle = .long
				yearFormatter.timeStyle = .none
				cell.detailTextLabel?.text = yearFormatter.string(from: date)
			} else {
				cell.detailTextLabel?.text = ""
			}
		case 2:
			cell.textLabel?.text = "Runtime"
			if let runtime = metainfo != nil ? metainfo!.runtime : runtime() {
				cell.detailTextLabel?.text = "\(runtime) min"
			} else {
				cell.detailTextLabel?.text = ""
			}
		case 3:
			cell.textLabel?.text = "Genres"
			cell.detailTextLabel?.text = metainfo != nil ? metainfo!.genre : genres()
		case 4:
			cell.textLabel?.text = "Rating"
			cell.detailTextLabel?.text = metainfo != nil ? metainfo!.rating : rating()
		default:
			break
		}
		return cell
	}
}

extension String {
	
	func heightWithConstrainedWidth(width: CGFloat, font: UIFont) -> CGFloat {
		let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
		let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSFontAttributeName: font], context: nil)
		
		return boundingBox.height
	}
}

