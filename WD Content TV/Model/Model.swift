//
//  Model.swift
//  WD Content
//
//  Created by Сергей Сейтов on 14.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

import Foundation
import CoreData

func generateUDID() -> String {
	return UUID().uuidString
}

class Model: NSObject {
	
	static let shared = Model()
	
	private override init() {
		super.init()
	}
	
	lazy var applicationDocumentsDirectory: URL = {
		#if TV
			let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
		#else
			let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
		#endif
		return urls[urls.count-1]
	}()
	
	lazy var managedObjectModel: NSManagedObjectModel = {
		let modelURL = Bundle.main.url(forResource: "WDContentTV", withExtension: "momd")!
		return NSManagedObjectModel(contentsOf: modelURL)!
	}()
	
	lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
		let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
		let url = self.applicationDocumentsDirectory.appendingPathComponent("WDContentTV.sqlite")
		do {
			try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
		} catch {
			print("CoreData data error: \(error)")
		}
		return coordinator
	}()
	
	lazy var managedObjectContext: NSManagedObjectContext = {
		let coordinator = self.persistentStoreCoordinator
		var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
		managedObjectContext.persistentStoreCoordinator = coordinator
		return managedObjectContext
	}()
	
	func saveContext () {
		if managedObjectContext.hasChanges {
			do {
				try managedObjectContext.save()
			} catch {
				print("Saved data error: \(error)")
			}
		}
	}
	
	// MARK: - Connection table

	func addConnection(ip:String, port:Int16, user:String, password:String) -> Connection {
		var connection = getConnection(ip)
		if connection == nil {
			connection = NSEntityDescription.insertNewObject(forEntityName: "Connection", into: managedObjectContext) as? Connection
			connection!.ip = ip
		}
		connection!.port = port
		connection!.user = user
		connection!.password = password
		saveContext()
		return connection!
	}
	
	func getConnection(_ address:String) -> Connection? {
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Connection")
		fetchRequest.predicate = NSPredicate(format: "ip == %@", address)
		if let connection = try? managedObjectContext.fetch(fetchRequest).first as? Connection {
			return connection
		} else {
			return nil
		}
	}
	
	// MARK: - Node table
	
	func addNode(_ file:SMBFile, parent:Node?, connection:Connection) {
        let node = NSEntityDescription.insertNewObject(forEntityName: "Node", into: managedObjectContext) as! Node
		node.uid = generateUDID()
		node.name = file.name
		node.path = file.filePath
		node.size = Int64(file.fileSize)
		node.isFile = !file.directory
		node.connection = connection
		connection.addToNodes(node)
		if parent != nil {
			node.parent = parent
			parent?.addToChilds(node)
		} else {
			node.parent = nil
		}
		saveContext()
	}
	
	func nodes(byRoot:Node?) -> [Node] {
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Node")
		if byRoot != nil {
			fetchRequest.predicate = NSPredicate(format: "parent.uid == %@", byRoot!.uid!)
		} else {
			fetchRequest.predicate = NSPredicate(format: "parent == NULL")
		}
		let descr1 = NSSortDescriptor(key: "isFile", ascending: true)
		let descr2 = NSSortDescriptor(key: "name", ascending: true)
		fetchRequest.sortDescriptors = [descr1, descr2]
		
		if let nodes = try? managedObjectContext.fetch(fetchRequest) as! [Node] {
			return nodes
		} else {
			return []
		}
	}
	
	func nodeByPath(path:String) -> Node? {
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Node")
		fetchRequest.predicate = NSPredicate(format: "path == %@", path)
		if let node = try? managedObjectContext.fetch(fetchRequest).first as? Node {
			return node
		} else {
			return nil
		}
	}
}
