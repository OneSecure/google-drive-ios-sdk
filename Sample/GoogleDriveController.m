//
//  GoogleDriveController.m
//  SignInSample
//
//  Created by onesecure on 2020/3/15.
//  Copyright © 2020 Google Inc. All rights reserved.
//

#import "GoogleDriveController.h"

#import <GoogleSignIn/GoogleSignIn.h>
#import <GoogleDriveSDK/GoogleDriveSDK.h>

@interface GoogleDriveController ()

@end

@implementation GoogleDriveController

- (void) viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void) getFolderID:(NSString*)name
             service:(GTLRDriveService*)service
                user:(GIDGoogleUser*)user
          completion:(void(^)(NSString *, NSError*))completion
{
    GTLRDriveQuery_FilesList *query = [GTLRDriveQuery_FilesList query];
    query.spaces = @"drive";
    query.corpora = @"user";
    
    NSString *withName = [NSString stringWithFormat:@"name = %@", name]; // Case insensitive!
    NSString *foldersOnly = @"mimeType = 'application/vnd.google-apps.folder'";
    NSString *ownedByUser = [NSString stringWithFormat:@"'%@' in owners", user.profile.email];
    query.q = [NSString stringWithFormat:@"%@ and %@ and %@", withName, foldersOnly, ownedByUser];
    
    [service executeQuery:query completionHandler:^(GTLRServiceTicket *callbackTicket, id object, NSError *error) {
        NSString *ret = nil;
        if (error == nil) {
            GTLRDrive_FileList *folderList = (GTLRDrive_FileList*)object;
            if (folderList.files.count > 0) {
                // For brevity, assumes only one folder is returned.
                ret = folderList.files[0].identifier;
            }
        }
        if (completion) {
            completion(ret, error);
        }
    }];
}



@end
