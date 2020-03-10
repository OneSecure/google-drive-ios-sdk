//
//  ViewController.swift
//  ATGoogleDriveDemo
//
//  Created by Dejan on 09/04/2018.
//  Copyright © 2018 Dejan. All rights reserved.
//

import UIKit
import GoogleSignIn
import GoogleAPIClientForREST

class ViewController: UIViewController {

    @IBOutlet weak var resultsLabel: UILabel!
    @IBOutlet weak var signInBtn: UIButton!
    @IBOutlet weak var signOutBtn: UIButton!
    
    fileprivate let driveService = GTLRDriveService()
    private var googleUser: GIDGoogleUser?
    private var drive: ATGoogleDrive?
    private var uploadFolderID: String?
    private let gidSignIn = GIDSignIn.sharedInstance()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupGoogleSignIn()
        
        drive = ATGoogleDrive(driveService)
        
        // let signInBtn:GIDSignInButton = GIDSignInButton()
        // signInBtn.frame = CGRect(x: 10, y: 50, width: 100, height: 40)
        // view.addSubview(signInBtn)
    }
    
    private func setupGoogleSignIn() {
        gidSignIn?.delegate = self
        gidSignIn?.scopes = [kGTLRAuthScopeDriveFile, /* kGTLRAuthScopeDrive, */ ]
        gidSignIn?.presentingViewController = self
        gidSignIn?.restorePreviousSignIn()
    }
    
    // MARK: - Actions
    @IBAction func signIn(_ sender: Any) {
        gidSignIn?.signIn()
    }
    
    @IBAction func signOut(_ sender: Any) {
        gidSignIn?.signOut()
        gidSignIn?.disconnect()
    }
    
    @IBAction func uploadAction(_ sender: Any) {
        populateFolderID()
        /*
        if let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
            let testFilePath = documentsDir.appendingPathComponent("logo.png").path
            drive?.uploadFile("agostini_tech_demo", filePath: testFilePath, MIMEType: "image/png") { (fileID, error) in
                print("Upload file ID: \(String(describing: fileID)); Error: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
 */
    }
    
    @IBAction func listAction(_ sender: Any) {
        drive?.listFilesInFolder("agostini_tech_demo") { (files, error) in
            guard let fileList = files else {
                print("Error listing files: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            self.resultsLabel.text = fileList.files?.description
        }
    }
    
    func populateFolderID() {
        let myFolderName = "my-folder"
        getFolderID(name:myFolderName, service:self.driveService, user:googleUser!) { folderID in
            if folderID == nil {
                self.createFolder(name:myFolderName, service:self.driveService) {
                    self.uploadFolderID = $0
                }
            } else {
                // Folder already exists
                self.uploadFolderID = folderID
            }
        }
    }
    
    func getFolderID (name:String, service:GTLRDriveService, user:GIDGoogleUser, completion:@escaping(String?) -> Void) {
        let query = GTLRDriveQuery_FilesList.query()

        // Comma-separated list of areas the search applies to. E.g., appDataFolder, photos, drive.
        query.spaces = "drive"
        
        // Comma-separated list of access levels to search in. Some possible values are "user,allTeamDrives" or "user"
        query.corpora = "user"
        
        let withName = "name = '\(name)'" // Case insensitive!
        let foldersOnly = "mimeType = 'application/vnd.google-apps.folder'"
        let ownedByUser = "'\(user.profile!.email!)' in owners"
        query.q = "\(withName) and \(foldersOnly) and \(ownedByUser)"
        
        service.executeQuery(query) { (_, result, error) in
            guard error == nil else {
                print("Error getFolderID: \(error!.localizedDescription)")
                // fatalError(error!.localizedDescription)
                return
            }

            let folderList = result as! GTLRDrive_FileList

            // For brevity, assumes only one folder is returned.
            completion(folderList.files?.first?.identifier)
        }
    }
    
    func createFolder(name:String, service:GTLRDriveService, completion:@escaping(String) -> Void) {
        let folder = GTLRDrive_File()
        folder.mimeType = "application/vnd.google-apps.folder"
        folder.name = name
        
        // Google Drive folders are files with a special MIME-type.
        let query = GTLRDriveQuery_FilesCreate.query(withObject: folder, uploadParameters: nil)
        
        service.executeQuery(query) { (_, file, error) in
            guard error == nil else {
                print("Error createFolder: \(error!.localizedDescription)")
                //fatalError(error!.localizedDescription)
                return
            }
            let folder = file as! GTLRDrive_File
            completion(folder.identifier!)
        }
    }
    
    func verifySignStatus(succ:Bool) -> Void {
        self.signInBtn.isEnabled = !succ
        self.signOutBtn.isEnabled = succ
    }
}

// MARK: - GIDSignInDelegate
extension ViewController: GIDSignInDelegate {
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if let _ = error {
            print("Error sign in: \(error.localizedDescription)")
            //googleDriveService.authorizer = nil
            googleUser = nil
        } else {
            //googleDriveService.authorizer = user.authentication.fetcherAuthorizer()
            print("Sign in success")
            googleUser = user;
        }
        verifySignStatus(succ: googleUser != nil)
    }
    
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
        googleUser = nil
        verifySignStatus(succ: googleUser != nil)
    }
}
