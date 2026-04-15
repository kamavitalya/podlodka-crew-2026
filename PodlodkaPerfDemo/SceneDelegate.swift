//
//  SceneDelegate.swift
//  PodlodkaPerfDemo
//
//  Created by Vitaliy Kamashev on 03.04.2026.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Start profiler
//        AppProfiler.shared.start(sampleIntervalMs: 10)
//        
//        // Stop profiling after 10 seconds and prompt to save
//        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
//            AppProfiler.shared.stop()
//            self?.showSaveProfileButton()
//        }
        
        window = UIWindow(windowScene: windowScene)
        
        // Create navigation controller with ArticlesListViewController as root
        let articlesListVC = ArticlesListViewController()
        let navigationController = UINavigationController(rootViewController: articlesListVC)
        
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
    }
    
    private func showSaveProfileButton() {
        let alert = UIAlertController(
            title: "Profiler",
            message: "Save profiling data to Firefox Profiler format?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in })
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            self.saveProfile()
        })
        
        window?.rootViewController?.present(alert, animated: true)
    }
    
    private func saveProfile() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "profile_\(Date().timeIntervalSince1970).json"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        if AppProfiler.shared.saveProfile(to: fileURL) {
            print("Profile saved successfully to: \(fileURL.path)")
            
            let alert = UIAlertController(
                title: "Profile Saved",
                message: "Profile saved to:\n\(fileURL.path)\n\nOpen https://profiler.firefox.com/ and load this file.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            window?.rootViewController?.present(alert, animated: true)
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        AppProfiler.shared.stop()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

}
