//
//  Connection+CoreDataProperties.swift
//  WD Content
//
//  Created by Сергей Сейтов on 17.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

import Foundation
import CoreData


extension Connection {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Connection> {
        return NSFetchRequest<Connection>(entityName: "Connection");
    }

    @NSManaged public var ip: String?
    @NSManaged public var port: Int16
    @NSManaged public var user: String?
    @NSManaged public var password: String?
    @NSManaged public var nodes: NSSet?

}

// MARK: Generated accessors for nodes
extension Connection {

    @objc(addNodesObject:)
    @NSManaged public func addToNodes(_ value: Node)

    @objc(removeNodesObject:)
    @NSManaged public func removeFromNodes(_ value: Node)

    @objc(addNodes:)
    @NSManaged public func addToNodes(_ values: NSSet)

    @objc(removeNodes:)
    @NSManaged public func removeFromNodes(_ values: NSSet)

}
