//
//  AppDelegate.swift
//  ATGoogleDriveDemo
//
//  Created by Dejan on 09/04/2018.
//  Copyright © 2018 Dejan. All rights reserved.
//

import UIKit
import GoogleSignIn

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        printDocumentsDirectory()
        GIDSignIn.sharedInstance().clientID = "CLIENT_ID"
        return true
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return GIDSignIn.sharedInstance().handle(url)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance().handle(url)
    }
    
    private func printDocumentsDirectory() {
        let fileManager = FileManager.default
        if let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).last {
            print("Documents directory: \(documentsDir.absoluteString)")
        } else {
            print("Error: Couldn't find documents directory")
        }
    }
}

