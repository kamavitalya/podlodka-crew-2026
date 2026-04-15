//
//  ArticleTableViewCell.swift
//  PodlodkaPerfDemo
//
//  Created by Vitaliy Kamashev on 03.04.2026.
//

import UIKit
import ImageIO

class ArticleTableViewCell: UITableViewCell {
    static let identifier = "ArticleTableViewCell"
    
    private var currentImageWorkItem: DispatchWorkItem?
    
    private let imageViewCustom: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let contentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .gray
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageViewCustom)
        contentView.addSubview(titleLabel)
        contentView.addSubview(contentLabel)
        
        // INTENTIONAL PERFORMANCE ISSUE: Heavy offscreen rendering
        
        // 1. cornerRadius + masksToBounds on image → offscreen pass
//        imageViewCustom.layer.cornerRadius = 16
//        imageViewCustom.layer.masksToBounds = true
//        
//        // 2. Shadow without shadowPath on contentView → offscreen pass every frame
//        contentView.layer.shadowColor = UIColor.black.cgColor
//        contentView.layer.shadowOpacity = 0.4
//        contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
//        contentView.layer.shadowRadius = 8
//        // No shadowPath → render server must compute shadow from pixel content each frame
//        
//        // 3. Multiple overlay layers with cornerRadius + shadow → stacked offscreen passes
//        for i in 0..<5 {
//            let overlay = UIView()
//            overlay.translatesAutoresizingMaskIntoConstraints = false
//            overlay.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05)
//            overlay.layer.cornerRadius = 12
//            overlay.layer.masksToBounds = true
//            overlay.layer.shadowColor = UIColor.black.cgColor
//            overlay.layer.shadowOpacity = 0.15
//            overlay.layer.shadowRadius = 6
//            overlay.layer.shadowOffset = CGSize(width: 0, height: CGFloat(i))
//            contentView.addSubview(overlay)
//            NSLayoutConstraint.activate([
//                overlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: CGFloat(i * 2)),
//                overlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: CGFloat(-i * 2)),
//                overlay.topAnchor.constraint(equalTo: contentView.topAnchor, constant: CGFloat(i * 2)),
//                overlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: CGFloat(-i * 2))
//            ])
//        }
//        
//        // 4. Blur effect view → additional compositing overhead in render server
//        let blurEffect = UIBlurEffect(style: .light)
//        let blurView = UIVisualEffectView(effect: blurEffect)
//        blurView.translatesAutoresizingMaskIntoConstraints = false
//        blurView.alpha = 0.3
//        blurView.layer.cornerRadius = 10
//        blurView.layer.masksToBounds = true
//        contentView.addSubview(blurView)
//        NSLayoutConstraint.activate([
//            blurView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
//            blurView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
//            blurView.topAnchor.constraint(equalTo: contentView.topAnchor),
//            blurView.heightAnchor.constraint(equalToConstant: 30)
//        ])
//        
//        // 5. allowsGroupOpacity forces offscreen pass for compositing children
//        contentView.layer.allowsGroupOpacity = true
//        contentView.alpha = 0.95
        
        NSLayoutConstraint.activate([
            imageViewCustom.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imageViewCustom.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            imageViewCustom.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            imageViewCustom.widthAnchor.constraint(equalToConstant: 100),
            {
                let h = imageViewCustom.heightAnchor.constraint(equalToConstant: 100)
                h.priority = .defaultHigh
                return h
            }(),
            
            titleLabel.leadingAnchor.constraint(equalTo: imageViewCustom.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            
            contentLabel.leadingAnchor.constraint(equalTo: imageViewCustom.trailingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            contentLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        currentImageWorkItem?.cancel()
        currentImageWorkItem = nil
        imageViewCustom.image = nil
    }
    
    func configure(with article: Article) {
        titleLabel.text = article.title
        contentLabel.text = article.content
        
        // Load image from cached data or placeholder
        if let imageData = article.imageData {
            let targetSize = CGSize(width: 100, height: 100)
            let scale = traitCollection.displayScale
            
            let workItem = DispatchWorkItem {
                let cgImage = Self.downsampledCGImage(data: imageData,
                                                      to: targetSize,
                                                      scale: scale)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.currentImageWorkItem?.isCancelled == false else { return }
                    if let cgImage {
                        self.imageViewCustom.image = UIImage(cgImage: cgImage)
                    } else {
                        self.imageViewCustom.image = UIImage(systemName: "photo")
                    }
                }
            }
            currentImageWorkItem = workItem
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        } else {
            self.imageViewCustom.image = UIImage(systemName: "photo")
        }
    }
    
    /// Downsample image data to the target point size using ImageIO.
    /// Returns a CGImage so this can safely be called from a background thread.
    private static func downsampledCGImage(data: Data, to pointSize: CGSize, scale: CGFloat) -> CGImage? {
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale

        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ]
        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary)
    }
    
    func configureLoading() {
        titleLabel.text = "Loading..."
        contentLabel.text = "Please wait"
        imageViewCustom.image = UIImage(systemName: "arrow.clockwise")
    }
}
