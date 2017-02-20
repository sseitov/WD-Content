//
//  MetaInfo+CoreDataProperties.swift
//  WD Content
//
//  Created by Сергей Сейтов on 20.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

import Foundation
import CoreData


extension MetaInfo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MetaInfo> {
        return NSFetchRequest<MetaInfo>(entityName: "MetaInfo");
    }

    @NSManaged public var cast: String?
    @NSManaged public var director: String?
    @NSManaged public var genre: String?
    @NSManaged public var original_title: String?
    @NSManaged public var overview: String?
    @NSManaged public var release_date: String?
    @NSManaged public var runtime: String?
    @NSManaged public var poster: String?
    @NSManaged public var title: String?
    @NSManaged public var node: Node?

}
