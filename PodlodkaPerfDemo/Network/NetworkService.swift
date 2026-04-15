//
//  NetworkService.swift
//  PodlodkaPerfDemo
//
//  Created by Vitaliy Kamashev on 03.04.2026.
//

import Foundation
import os

struct ArticleDTO: Decodable {
    let id: Int
    let title: String
    let body: String
}

class NetworkService {
    static let shared = NetworkService()
    
    private let session: URLSession
    private let delegate = UnsafeSessionDelegate()
    
    init() {
        // INTENTIONAL PERFORMANCE ISSUE: Using default session configuration without optimization
        let config = URLSessionConfiguration.default
        // Not setting proper timeout intervals
        // Not setting proper cache policy
        session = URLSession(configuration: config, delegate: delegate, delegateQueue: OperationQueue())
    }
    
    // MARK: - Fetch Articles from JSONPlaceholder
    
    func fetchArticles(completion: @escaping ([ArticleDTO]) -> Void) {
        ps_begin("NetworkFetchArticles", message: "Starting network request for articles")
        
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts") else {
            ps_end("NetworkFetchArticles", message: "Invalid URL")
            completion([])
            return
        }
        
        let task = session.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                ps_end("NetworkFetchArticles", message: "Network request failed")
                completion([])
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let articles = try decoder.decode([ArticleDTO].self, from: data)
                ps_end("NetworkFetchArticles", message: "Fetched \(articles.count) articles from network")
                completion(articles)
            } catch {
                ps_end("NetworkFetchArticles", message: "Decoding failed")
                completion([])
            }
        }
        // INTENTIONAL PERFORMANCE ISSUE: Not setting task priority
        task.resume()
    }
    
    // MARK: - Download Image
    
    func downloadImage(from urlString: String, completion: @escaping (Data?) -> Void) {
        let signpostID = signpostID(for: urlString as NSString)
        ps_begin("NetworkDownloadImage", signpostID: signpostID, message: "Starting image download: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            ps_end("NetworkDownloadImage", signpostID: signpostID, message: "Invalid URL")
            completion(nil)
            return
        }
        
        let task = session.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                ps_end("NetworkDownloadImage", signpostID: signpostID, message: "Image download failed")
                completion(nil)
                return
            }
            
            ps_end("NetworkDownloadImage", signpostID: signpostID, message: "Downloaded image: \(data.count) bytes")
            completion(data)
        }
        task.resume()
    }
    
    // MARK: - Generate Picsum Image URLs
    
    func generatePicsumImageURL(for index: Int, width: Int = 600, height: Int = 400) -> String {
        // Using Picsum for large random images
        return "https://picsum.photos/\(width)/\(height)?random=\(index)"
    }
}

class UnsafeSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
