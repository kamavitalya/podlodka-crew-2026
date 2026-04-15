//
//  ArticleRepository.swift
//  PodlodkaPerfDemo
//
//  Created by Vitaliy Kamashev on 03.04.2026.
//

import Foundation
import os
import CoreData

class ArticleRepository {
    static let shared = ArticleRepository()
    
    private let networkService = NetworkService.shared
    private let coreDataStack = CoreDataStack.shared
    
    // MARK: - In-Memory Cache
    
    private var cachedArticles: [Article] = []
    private var cachedArticlesById: [String: Article] = [:]
    private var isCacheValid = false
    
    func loadAndCacheArticles(imageWidth: Int, imageHeight: Int, completion: @escaping () -> Void) {
        ps_begin("LoadAndCacheArticles", message: "Starting to load and cache articles")
        
        networkService.fetchArticles { [weak self] dtos in
            guard let self = self else { return }
            let group = DispatchGroup()
            if dtos.isEmpty {
                ps_end("LoadAndCacheArticles", message: "No articles to load")
                completion()
                return
            }
            for index in 0 ... min(30, dtos.count) {
                group.enter()
                let dto = dtos[index]
                let imageURL = self.networkService.generatePicsumImageURL(for: dto.id, width: imageWidth, height: imageHeight)

                self.networkService.downloadImage(from: imageURL) { imageData in
                    self.coreDataStack.saveArticle(
                        id: String(dto.id),
                        title: dto.title,
                        content: dto.body,
                        imageURL: imageURL,
                        imageData: imageData
                    )
                    group.leave()
                }
            }
            group.wait()
            self.coreDataStack.saveContext()
            
            ps_end("LoadAndCacheArticles", message: "Finished loading and caching articles")
            DispatchQueue.main.async {
                self.reloadInMemoryCache()
                completion()
            }
        }
    }

    func getCachedArticles() -> [Article] {
        if !isCacheValid {
            reloadInMemoryCache()
        }
        return cachedArticles
    }
    
//    func getCachedArticles() -> [Article] {
//        return coreDataStack.fetchArticles()
//    }

    func getCachedArticle(by id: String) -> Article? {
        if !isCacheValid {
            reloadInMemoryCache()
        }
        return cachedArticlesById[id]
    }
    
//    func getCachedArticle(by id: String) -> Article? {
//        return coreDataStack.fetchArticle(by: id)
//    }
    
    func clearCache() {
        invalidateInMemoryCache()
        
        let context = coreDataStack.context
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Article.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }
    
    // MARK: - Private
    
    private func reloadInMemoryCache() {
        cachedArticles = coreDataStack.fetchArticles()
        cachedArticlesById = Dictionary(uniqueKeysWithValues: cachedArticles.map { ($0.id, $0) })
        isCacheValid = true
    }
    
    private func invalidateInMemoryCache() {
        cachedArticles = []
        cachedArticlesById = [:]
        isCacheValid = false
    }
}
