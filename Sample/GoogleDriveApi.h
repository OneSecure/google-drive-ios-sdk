//
//  GoogleDriveApi.h
//  OneSecure
//
//  Created by OneSecure on 7/5/15.
//  Copyright (c) 2015 OneSecure. All rights reserved.
//

#import <Foundation/Foundation.h>

@class UIViewController;
@class GTLRDrive_File;

static NSString *const kGoogleDriveFolderMimeType = @"application/vnd.google-apps.folder";
static NSString *const kGoogleDriveBinFileMimeType = @"application/octet-stream";
static NSString *const kGoogleDriveBinFileMimeType2= @"binary/octet-stream";
static NSString *const kGoogleDriveRootFolder = @"root";

typedef void (^completionCallback)(id object, NSError *error);

@interface GoogleDriveApi : NSObject

@property(nonatomic, assign, readonly) BOOL isAuthorized;

+ (instancetype) sharedInstance;

- (void) initGoogleDrive:(NSString *)appName
                  appKey:(NSString *)appKey
               appSecret:(NSString *)appSecret;

- (void) signInGoogleDrive:(UIViewController *)root completion:(completionCallback)completion;
- (BOOL) signInHandleUrl:(NSURL*)url;
- (void) signOutGoogleDrive;
- (NSString *) convertLocalPathToRemotePath:(NSString *)localFilePath localRoot:(NSString *)root;

- (void) listFolder:(NSString *)parentID
     excludeTrashed:(BOOL)excludeTrashed
         completion:(void(^)(NSArray<GTLRDrive_File*> *files, NSError *error))completion;

- (void) createFolder:(NSString *)folderName
             parentID:(NSString *)parentID
           completion:(void(^)(GTLRDrive_File *updatedFile, NSError *error))completion;

- (void) downloadFile:(NSString *)filePath
            localPath:(NSString *)localPath
             progress:(void(^)(CGFloat progress))progress
           completion:(completionCallback)completion;

- (void) uploadFileLocalPath:(NSString *)localPath
                  remotePath:(NSString *)remotePath
                    progress:(void(^)(CGFloat progress))progress
                  completion:(completionCallback)completion;

- (void) deleteFile:(NSString *)fileID completion:(completionCallback)completion;

@end
