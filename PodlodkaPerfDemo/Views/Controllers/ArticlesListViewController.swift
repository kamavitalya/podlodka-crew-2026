//
//  ArticlesListViewController.swift
//  PodlodkaPerfDemo
//
//  Created by Vitaliy Kamashev on 03.04.2026.
//

import UIKit
import os

class ArticlesListViewController: UIViewController {
    
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.rowHeight = 120
        tv.estimatedRowHeight = 120
        return tv
    }()
    
    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading data..."
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    private let refreshButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Refresh Data", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        ps_begin("ArticlesListScreenLoad", message: "ArticlesList screen load")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        loadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Start signpost when screen appears
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    private func setupUI() {
        title = "Articles"
        view.backgroundColor = .white
        
        view.addSubview(tableView)
        view.addSubview(loadingLabel)
        view.addSubview(refreshButton)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            refreshButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            refreshButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ArticleTableViewCell.self, forCellReuseIdentifier: ArticleTableViewCell.identifier)
    }
    
    @objc private func refreshTapped() {
        ArticleRepository.shared.clearCache()
        tableView.reloadData()
        loadData()
    }
    
    private func loadData() {
        loadingLabel.isHidden = false
        ArticleRepository.shared.clearCache()
        ps_begin("ContentLoaded", message: "Content loaded from network")
        let scale = traitCollection.displayScale
        let screenWidth = view.bounds.width
        let imageWidth = Int(screenWidth * scale)
        let imageHeight = Int(screenWidth * 2 / 3 * scale)
        ArticleRepository.shared.loadAndCacheArticles(imageWidth: imageWidth, imageHeight: imageHeight) {
            ps_end("ContentLoaded", message: "Content loaded from network")
            DispatchQueue.main.async {
                self.loadingLabel.isHidden = true
                self.tableView.reloadData()
                ps_end("ArticlesListScreenLoad", message: "ArticlesList screen loaded")
            }
        }
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension ArticlesListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ArticleRepository.shared.getCachedArticles().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ArticleTableViewCell.identifier, for: indexPath) as? ArticleTableViewCell else {
            return UITableViewCell()
        }
        let articles = ArticleRepository.shared.getCachedArticles()
        let article = articles[indexPath.row]
        
        cell.configure(with: article)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        ps_begin("ArticleDetailScreenLoad", message: "ArticleDetail screen load")
        let articles = ArticleRepository.shared.getCachedArticles()
        let article = articles[indexPath.row]
        let detailVC = ArticleDetailViewController()
        detailVC.article = article
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
