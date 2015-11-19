//
//  TTDownloadManager.m
//  tentracks-ios
//
//  Created by Игорь Савельев on 28/01/14.
//  Copyright (c) 2014 10tracks. All rights reserved.
//

#import "TTDownloadManager.h"

@implementation TTDownloadManager

+ (instancetype)defaultManager {
    static TTDownloadManager *manager = nil;
    static dispatch_once_t oncePredicate;
    //NSLog(@"%s", __PRETTY_FUNCTION__);
    dispatch_once(&oncePredicate, ^{
        manager = [[TTDownloadManager alloc] init];
    });
    return manager;
}

- (id)init {
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        pathToOfflineFolder = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Cache"];
        BOOL isDirectory;
        NSError *error;
        if (![[NSFileManager defaultManager] fileExistsAtPath:pathToOfflineFolder isDirectory:&isDirectory]) {
            error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:pathToOfflineFolder
                                      withIntermediateDirectories:NO
                                                       attributes:nil
                                                            error:&error];
            if (error) {
                NSLog(@"%@", [error localizedDescription]);
                abort();
            }
        } else if (!isDirectory) {
            [[NSFileManager defaultManager] removeItemAtPath:pathToOfflineFolder error:&error];
            if (error) {
                NSLog(@"%@", [error localizedDescription]);
            }
            
            error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:pathToOfflineFolder
                                      withIntermediateDirectories:NO
                                                       attributes:nil
                                                            error:&error];
            if (error) {
                NSLog(@"%@", [error localizedDescription]);
                abort();
            }
        }
    }
    return self;
}

@end
