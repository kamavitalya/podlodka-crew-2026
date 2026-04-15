//
//  CoreDataStack.swift
//  PodlodkaPerfDemo
//
//  Created by Vitaliy Kamashev on 03.04.2026.
//

import Foundation
import CoreData
import os

public extension OSLog {
    static let pointsOfInterest = OSLog(subsystem: "podlodka.demo", category: .pointsOfInterest)
}

class CoreDataStack {
    static let shared = CoreDataStack()
    
    private let containerName = "PodlodkaPerfDemo"
    private var storeContainer: NSPersistentContainer?
    
    var container: NSPersistentContainer {
        if let container = storeContainer {
            return container
        }
        
        let container = NSPersistentContainer(name: containerName)
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("CoreData store failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        storeContainer = container
        return container
    }
    
    var context: NSManagedObjectContext {
        return container.viewContext
    }
    
    private lazy var backgroundContext: NSManagedObjectContext = {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }()
    
    func saveContext() {
        let bgContext = backgroundContext
        guard bgContext.hasChanges else { return }
        bgContext.performAndWait {
            do {
                try bgContext.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
    
    // MARK: - Article Operations with Performance Issues
    
    func fetchArticles() -> [Article] {
        ps_begin("FetchArticles", message: "Starting to fetch articles from CoreData")
        
        let request: NSFetchRequest<Article> = Article.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            // INTENTIONAL PERFORMANCE ISSUE: Fetching without batch size limit
            let articles = try context.fetch(request)
            ps_end("FetchArticles", message: "Fetched \(articles.count) articles")
            return articles
        } catch {
            ps_end("FetchArticles", message: "Failed to fetch articles")
            return []
        }
    }
    
    func saveArticle(id: String, title: String, content: String, imageURL: String, imageData: Data?) {
        ps_begin("SaveArticle", message: "Starting to save article: \(id)")
        
        let bgContext = backgroundContext
        bgContext.performAndWait {
            let fetchRequest: NSFetchRequest<Article> = Article.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            
            do {
                var article: Article
                if let existing = try bgContext.fetch(fetchRequest).first {
                    article = existing
                } else {
                    article = Article(context: bgContext)
                    article.id = id
                    article.createdAt = Date()
                }
                
                article.title = title
                article.content = content
                article.imageURL = imageURL
                article.imageData = imageData
                article.isLoaded = imageData != nil
                
                ps_end("SaveArticle", message: "Saved article: \(id)")
            } catch {
                ps_end("SaveArticle", message: "Failed to save article")
                print("Failed to save article: \(error)")
            }
        }
    }
    
    func fetchArticle(by id: String) -> Article? {
        ps_begin("FetchArticleDetail", message: "Starting to fetch article detail: \(id)")
        
        let request: NSFetchRequest<Article> = Article.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            // INTENTIONAL PERFORMANCE ISSUE: Not using faulting properly
            let articles = try context.fetch(request)
            let article = articles.first
            ps_end("FetchArticleDetail", message: "Fetched article detail")
            return article
        } catch {
            ps_end("FetchArticleDetail", message: "Failed to fetch article detail")
            return nil
        }
    }
}
