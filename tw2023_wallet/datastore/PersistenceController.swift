//
//  PersistenceController.swift
//  tw2023_wallet
//
//  Shared CoreData persistence controller to prevent multiple NSManagedObjectModel instances
//

import CoreData
import Foundation

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "DataModel")

        let description = container.persistentStoreDescriptions.first
        description?.type = NSSQLiteStoreType

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unable to initialize Core Data: \(error)")
            }
        }
    }

    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
}
