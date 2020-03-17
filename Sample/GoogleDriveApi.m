//
//  GoogleDriveApi.m
//  OneSecure
//
//  Created by OneSecure on 7/5/15.
//  Copyright (c) 2015-2020 OneSecure. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GoogleDriveApi.h"
#import <GoogleSignIn/GoogleSignIn.h>
#import <GoogleDriveSDK/GoogleDriveSDK.h>

#pragma mark -

@interface GTLRDrive_File (isFolder)
@property(nonatomic, assign) BOOL isFolder;
@end
@implementation GTLRDrive_File (isFolder)
- (BOOL) isFolder {
    return [self.mimeType isEqualToString:kGoogleDriveFolderMimeType];
}
- (void) setIsFolder:(BOOL)isFolder {
    self.mimeType = isFolder ? kGoogleDriveFolderMimeType : kGoogleDriveBinFileMimeType;
}
@end

#pragma mark -

@interface GoogleDriveApi () <GIDSignInDelegate>
@end

@implementation GoogleDriveApi {
    NSString *_keychainItemName;
    GIDSignIn *_signIn;
    GIDGoogleUser *_currentUser;
    completionCallback _signInCompletion;

    GTLRDriveService *_driveService;
    NSMutableArray *_filePathComponents;
}

- (BOOL) isAuthorized {
    return (_currentUser != nil);
}

+ (instancetype) sharedInstance {
    static GoogleDriveApi *apiInstance = nil;
    if (apiInstance == nil) {
        @synchronized(self) {
            apiInstance = [[GoogleDriveApi alloc] init];
        }
    }
    return apiInstance;
}

- (void) initGoogleDrive:(NSString *)appName appKey:(NSString *)appKey appSecret:(NSString *)appSecret {
    _keychainItemName = appName;

    _signIn = [GIDSignIn sharedInstance];
    _signIn.clientID = appKey;
    
    _signIn.shouldFetchBasicProfile = YES;
    _signIn.delegate = self;
    _signIn.scopes = @[ kGTLRAuthScopeDriveFile, kGTLRAuthScopeDrive, ];
    [_signIn restorePreviousSignIn];

    _driveService = [[GTLRDriveService alloc] init];
}

- (void) signInGoogleDrive:(UIViewController *)root completion:(completionCallback)completion {
    _signIn.presentingViewController = root;
    _signInCompletion = completion;
    @try {
        [_signIn signIn];
    } @catch (NSException *exception) {
        _signInCompletion = nil;
        if (completion) {
            id info = @{NSLocalizedFailureReasonErrorKey:exception.description};
            completion(nil, [NSError errorWithDomain:NSOSStatusErrorDomain code:-3 userInfo:info]);
        }
    } @finally {
    }
}

- (BOOL) signInHandleUrl:(NSURL *)url {
    return [_signIn handleURL:url];
}

- (void) signOutGoogleDrive {
    [_signIn disconnect];
    [_signIn signOut];
}

- (NSString *) convertLocalPathToRemotePath:(NSString *)localFilePath localRoot:(NSString *)root {
    NSString *localRelative = [localFilePath substringFromIndex:root.length];
    NSString *rometePath = [NSString stringWithFormat:@"%@", _keychainItemName];
    rometePath = [rometePath stringByAppendingPathComponent:localRelative];
    return rometePath;
}

#pragma mark - GIDSignInDelegate

- (void) signIn:(GIDSignIn *)signIn didSignInForUser:(GIDGoogleUser *)user withError:(NSError *)error {
    _driveService.authorizer = user.authentication.fetcherAuthorizer;
    _currentUser = user;
    if (_signInCompletion) {
        _signInCompletion(user, error);
        _signInCompletion = nil;
    }
}

- (void) signIn:(GIDSignIn *)signIn didDisconnectWithUser:(GIDGoogleUser *)user withError:(NSError *)error {
    _currentUser = nil;
    _driveService.authorizer = nil;
}

#pragma mark -

//
// root folderID is kGoogleDriveRootFolder
//
- (void) listFolder:(NSString *)parentID
     excludeTrashed:(BOOL)excludeTrashed
         completion:(void(^)(NSArray<GTLRDrive_File*> *files, NSError *error))completion
{
    GTLRDriveQuery_FilesList *query = [GTLRDriveQuery_FilesList query];
    query.fields = @"kind,nextPageToken,files(mimeType,id,kind,name,webViewLink,thumbnailLink,trashed)";
    query.pageSize = 100;
    if (parentID.length) {
        query.q = [NSString stringWithFormat:@"'%@' in parents", parentID];
    }
    
    [_driveService executeQuery:query completionHandler:^(GTLRServiceTicket *ticket, GTLRDrive_FileList *object, NSError *error) {
        if (completion == nil) {
            return;
        }
        NSMutableArray<GTLRDrive_File*> *tmp = [NSMutableArray arrayWithArray:object.files];
        if (excludeTrashed) {
            [tmp enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(GTLRDrive_File *obj, NSUInteger idx, BOOL *stop) {
                if (obj.trashed.boolValue) {
                    [tmp removeObject:obj];
                }
            }];
        }
        completion(tmp, error);
    }];
}

- (void) createFolder:(NSString *)folderName
             parentID:(NSString *)parentID
           completion:(void(^)(GTLRDrive_File *updatedFile, NSError *error))completion
{
    [self listFolder:parentID excludeTrashed:YES completion:^(NSArray<GTLRDrive_File *> *files, NSError *error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        GTLRDrive_File *findFile = nil;
        for (GTLRDrive_File *file in files) {
            if ([file.name isEqualToString:folderName]) {
                findFile = file;
                if (file.isFolder == NO) {
                    id info = @{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Object '%@' exist and not a folder", folderName]};
                    error = [NSError errorWithDomain:NSCocoaErrorDomain code:-2 userInfo:info];
                }
                break;
            }
        }
        if (!findFile) {
            GTLRDrive_File *folder = [GTLRDrive_File object];
            folder.name = folderName;
            folder.isFolder = YES;
            
            // If not specified as part of a create request, the file will be placed
            // directly in the user's My Drive folder.
            if (parentID) {
                folder.parents = @[parentID];
            }
            
            GTLRDriveQuery_FilesCreate *query = [GTLRDriveQuery_FilesCreate queryWithObject:folder uploadParameters:nil];
            [self->_driveService executeQuery:query completionHandler:^(GTLRServiceTicket *ticket, GTLRDrive_File *object, NSError *error) {
                if (completion) {
                    completion(object, error);
                }
            }];
        } else {
            if (completion) {
                completion(findFile, error);
            }
        }
    }];
}

- (void) downloadFile:(NSString *)filePath
            localPath:(NSString *)localPath
             progress:(void (^)(CGFloat))progress
           completion:(completionCallback)completion
{
    _filePathComponents = [[NSMutableArray alloc] initWithObjects:kGoogleDriveRootFolder, nil];
    [_filePathComponents addObjectsFromArray:[filePath pathComponents]];
    
    [self _internalDownload:nil localPath:localPath progress:progress completion:completion];
}

- (void) _internalDownload:(GTLRDrive_File *)parent
                 localPath:(NSString *)localPath
                  progress:(void (^)(CGFloat))progress
                completion:(completionCallback)completion
{
    if (_filePathComponents.count < 2) {
        NSAssert(NO, @"Never go here!!!");
        if (completion) {
            id info = @{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Unknown error in folder %@", parent.name]};
            NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:-2 userInfo:info];
            completion(nil, error);
        }
        return;
    }
    
    NSString *currentPath = _filePathComponents[0];
    [_filePathComponents removeObject:currentPath];
    [self listFolder:parent.identifier?:currentPath excludeTrashed:YES completion:^(NSArray<GTLRDrive_File*> *files, NSError *error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        NSString *nextPath = self->_filePathComponents[0];
        GTLRDrive_File *findFile = nil;
        for (GTLRDrive_File *file in files) {
            if ([file.name isEqualToString:nextPath]) {
                findFile = file;
                break;
            }
        }
        
        if (findFile == nil) {
            id info = @{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Object %@ not exist", nextPath]};
            error = [NSError errorWithDomain:NSCocoaErrorDomain code:-2 userInfo:info];
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        
        if (self->_filePathComponents.count > 1) {
            if (findFile.isFolder == NO) {
                if (completion) {
                    id info = @{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Object %@ is NOT a folder", nextPath]};
                    error = [NSError errorWithDomain:NSCocoaErrorDomain code:-2 userInfo:info];
                    completion(findFile, error);
                }
                return;
            }
            [self _internalDownload:findFile localPath:localPath progress:progress completion:completion];
        } else {
            [self _doDownloadFileOperation:findFile localPath:localPath progress:progress completion:completion];
        }
    }];
}

//
// https://github.com/google/google-api-objectivec-client-for-rest/blob/master/Examples/DriveSample/DriveSampleWindowController.m#L241
//
- (void) _doDownloadFileOperation:(GTLRDrive_File *)file
                        localPath:(NSString *)localPath
                         progress:(void (^)(CGFloat))progress
                       completion:(completionCallback)completion
{
    GTLRDriveQuery_FilesGet *query = [GTLRDriveQuery_FilesGet queryForMediaWithFileId:file.identifier];
#if 0
    [_driveService executeQuery:query completionHandler:^(GTLRServiceTicket *ticket, GTLRDataObject *object, NSError *error) {
        if (error == nil) {
            [object.data writeToFile:localPath options:NSDataWritingAtomic error:&error];
        }
        if (completion) {
            completion(file, error);
        }
    }];
#else
    NSURLRequest *request = [_driveService requestForQuery:query];
    GTMSessionFetcher *fetcher = [_driveService.fetcherService fetcherWithRequest:request];
    
    if (progress) {
        [fetcher setReceivedProgressBlock:^(int64_t bytesWritten, int64_t totalBytesWritten) {
            progress(1.0 * bytesWritten / totalBytesWritten);
        }];
    }
    [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
        if (error == nil) {
            [data writeToFile:localPath options:NSDataWritingAtomic error:&error];
        }
        if (completion) {
            completion(file, error);
        }
    }];
#endif
}

- (void) uploadFileLocalPath:(NSString *)localPath
                  remotePath:(NSString *)remotePath
                    progress:(void(^)(CGFloat progress))progress
                  completion:(completionCallback)completion
{
    _filePathComponents = [[NSMutableArray alloc] initWithObjects:kGoogleDriveRootFolder, nil];
    [_filePathComponents addObjectsFromArray:[remotePath pathComponents]];
    
    [self _internalUpload:nil localPath:localPath progress:progress completion:completion];
}

- (void) _internalUpload:(GTLRDrive_File *)parent
               localPath:(NSString *)localPath
                progress:(void (^)(CGFloat))progress
              completion:(completionCallback)completion
{
    if (_filePathComponents.count < 2) {
        NSAssert(NO, @"Never go here!!!");
        if (completion) {
            id info = @{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Unknown error in folder %@", parent.name]};
            NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:-2 userInfo:info];
            completion(nil, error);
        }
        return;
    }
    
    NSString *currentPath = _filePathComponents[0];
    [_filePathComponents removeObject:currentPath];
    
    NSString *parentID = parent.identifier?:currentPath;
    
    [self listFolder:parentID excludeTrashed:YES completion:^(NSArray<GTLRDrive_File *> *files, NSError *error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        NSString *nextPath = self->_filePathComponents[0];
        GTLRDrive_File *findFile = nil;
        for (GTLRDrive_File *file in files) {
            if ([file.name isEqualToString:nextPath]) {
                findFile = file;
                break;
            }
        }
        
        if (self->_filePathComponents.count > 1) {
            if (findFile) {
                if (findFile.isFolder == NO) {
                    if (completion) {
                        id info = @{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Object '%@' is not a folder", nextPath]};
                        error = [NSError errorWithDomain:NSCocoaErrorDomain code:-2 userInfo:info];
                        completion(nil, error);
                    }
                    return;
                }
                [self _internalUpload:findFile localPath:localPath progress:progress completion:completion];
            } else {
                [self createFolder:nextPath parentID:parentID completion:^(GTLRDrive_File *file, NSError *error) {
                    if (error) {
                        if (completion) {
                            completion(file, error);
                        }
                        return;
                    }
                    [self _internalUpload:file localPath:localPath progress:progress completion:completion];
                }];
            }
        } else {
            if (!findFile) {
                findFile = [GTLRDrive_File object];
                
                if (parent.identifier.length) {
                    findFile.parents = @[ parent.identifier ];
                }
                findFile.name = nextPath;
                findFile.originalFilename = nextPath;
            }
            [self _doUploadFileOperation:findFile localPath:localPath progress:progress completion:completion];
        }
    }];
}

- (void) _doUploadFileOperation:(GTLRDrive_File *)file
                      localPath:(NSString *)localPath
                       progress:(void (^)(CGFloat))progress
                     completion:(completionCallback)completion
{
    dispatch_block_t block = ^{
    NSData *fileContent =[NSData dataWithContentsOfFile:localPath];
    
    GTLRUploadParameters *uploadParameters =
    [GTLRUploadParameters uploadParametersWithData:fileContent MIMEType:kGoogleDriveBinFileMimeType];
    //driveFile.title = fileName;
    
    GTLRDriveQuery *query = nil;
    if (file.identifier.length == 0) {
        // This is a new file, instantiate an create query.
        query = [GTLRDriveQuery_FilesCreate queryWithObject:file uploadParameters:uploadParameters];
    } else {
        // This file already exists, instantiate an update query.
        // https://github.com/google/google-api-objectivec-client-for-rest/issues/43#issuecomment-296372759
        query = [GTLRDriveQuery_FilesUpdate queryWithObject:[GTLRDrive_File object] fileId:file.identifier uploadParameters:uploadParameters];
    }
    
    query.fields = @"mimeType,id,kind,name,webViewLink,thumbnailLink,trashed";
    
    if (progress) {
        [query.executionParameters setUploadProgressBlock:^(GTLRServiceTicket *ticket, unsigned long long totalBytesUploaded, unsigned long long totalBytesExpectedToUpload) {
            progress(1.0 * totalBytesUploaded / totalBytesExpectedToUpload);
        }];
    }
    
    [self->_driveService executeQuery:query completionHandler:^(GTLRServiceTicket *ticket, GTLRDrive_File *object, NSError *error) {
        if (completion) {
            completion(object, error);
        }
    }];
    };
#if 0
    if (file.identifier.length) {
        [self deleteFile:file.identifier completion:^(id object, NSError *error) {
            if (error) {
                if (completion) {
                    completion(object, error);
                }
                return;
            }
            file.identifier = nil;
            block();
        }];
    } else
#endif
    {
        block();
    }
}

- (void) deleteFile:(NSString *)fileID completion:(completionCallback)completion {
    GTLRDriveQuery *deleteQuery = [GTLRDriveQuery_FilesDelete queryWithFileId:fileID];
    [_driveService executeQuery:deleteQuery completionHandler:^(GTLRServiceTicket *ticket, id object, NSError *error) {
        if (completion) {
            completion(object, error);
        }
    }];
}

@end

