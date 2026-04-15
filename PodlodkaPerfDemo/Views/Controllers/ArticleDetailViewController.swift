//
//  ArticleDetailViewController.swift
//  PodlodkaPerfDemo
//
//  Created by Vitaliy Kamashev on 03.04.2026.
//

import UIKit
import os

class ArticleDetailViewController: UIViewController {
    
    var article: Article?
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let contentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18)
        label.numberOfLines = 0
        label.textColor = .darkText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadArticle()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ps_end("ArticleDetailScreenLoad", message: "ArticleDetail screen loaded")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    private func setupUI() {
        title = "Article Details"
        view.backgroundColor = .white
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(contentLabel)
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 300),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            contentLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func loadArticle() {
        loadingIndicator.startAnimating()
        
        guard let article else {
            loadingIndicator.stopAnimating()
            return
        }
        
        titleLabel.text = article.title
        contentLabel.text = article.content
        
        guard let imageData = article.imageData else {
            imageView.image = UIImage(systemName: "photo")
            loadingIndicator.stopAnimating()
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let cgImage = Self.decodeCGImage(from: imageData)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let cgImage {
                    self.imageView.image = UIImage(cgImage: cgImage)
                } else {
                    self.imageView.image = UIImage(systemName: "photo")
                }
                self.loadingIndicator.stopAnimating()
            }
        }
    }
    
    private static func decodeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let decodeOptions: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, decodeOptions as CFDictionary)
    }
    
    // MARK: - Image Loading (Intentionally Inefficient with DispatchGroup)
    
    private func loadImageFromURL(_ url: URL) {
        // INTENTIONAL PERFORMANCE ISSUE: Using DispatchGroup to wait synchronously on main thread
        let downloadGroup = DispatchGroup()
        downloadGroup.enter()
        
        var downloadedData: Data? = nil
        
        // Using NetworkService for download (NetworkService handles its own signposts)
        NetworkService.shared.downloadImage(from: url.absoluteString) { data in
            downloadedData = data
            downloadGroup.leave()
        }
        
        // INTENTIONAL PERFORMANCE ISSUE: Blocking main thread while waiting for download
        let result = downloadGroup.wait(timeout: .now() + 30)
        
        if result == .success, let data = downloadedData {
            ps_begin("ImageDecode", message: "Starting image decode")
            
            // INTENTIONAL PERFORMANCE ISSUE: Decoding large image on main thread
            let image = UIImage(data: data)
            
            imageView.image = image
            
            ps_end("ImageDecode", message: "Image decoded")
        } else {
            print("Failed to load image: timeout or error")
            imageView.image = UIImage(systemName: "photo")
        }
        
        loadingIndicator.stopAnimating()
    }
}
