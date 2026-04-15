//
//  Article.swift
//  PodlodkaPerfDemo
//
//  Created by Vitaliy Kamashev on 03.04.2026.
//

import Foundation
import CoreData

@objc(Article)
public class Article: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var title: String
    @NSManaged public var content: String
    @NSManaged public var imageURL: String
    @NSManaged public var imageData: Data?
    @NSManaged public var isLoaded: Bool
    @NSManaged public var createdAt: Date
}

extension Article {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Article> {
        return NSFetchRequest<Article>(entityName: "Article")
    }
}
