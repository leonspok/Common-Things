//
//  LPFileDownloader.m
//  Irvue
//
//  Created by Игорь Савельев on 26/10/15.
//  Copyright © 2015 Leonspok. All rights reserved.
//

#import "LPFileDownloader.h"

@interface LPFileDownloader()<NSURLSessionDownloadDelegate>

@end

@implementation LPFileDownloader {
    NSMutableDictionary *successBlocks;
    NSMutableDictionary *failureBlocks;
    NSMutableDictionary *progressBlocks;
    NSMutableDictionary *destinationPaths;
    NSURLSession *session;
}

+ (instancetype)sharedDownloader {
    static LPFileDownloader *__sharedDownloader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedDownloader = [[LPFileDownloader alloc] init];
    });
    return __sharedDownloader;
}

- (id)init {
    self = [super init];
    if (self) {
        successBlocks = [NSMutableDictionary dictionary];
        failureBlocks = [NSMutableDictionary dictionary];
        progressBlocks = [NSMutableDictionary dictionary];
        destinationPaths = [NSMutableDictionary dictionary];
        session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

- (void)downloadFileFromURL:(NSURL *)url
            destinationPath:(NSString *)destinationPath
              progressBlock:(void (^)(double totalBytesDownloaded, double totalBytesExpectedToDownload))progress
                    success:(void (^)())success
                    failure:(void (^)(NSError *error))failure {
    if (!url) {
        if (failure) {
            failure([NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message": @"no url"}]);
        }
        return;
    }
    
    if (!destinationPath || destinationPath.length == 0) {
        if (failure) {
            failure([NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message": @"no destinationPath"}]);
        }
        return;
    }
    
    void (^successBlock)() = ^{
        [successBlocks removeObjectForKey:url];
        [failureBlocks removeObjectForKey:url];
        [progressBlocks removeObjectForKey:url];
        if (success) {
            success();
        }
    };
    
    void (^failureBlock)(NSError *error) = ^(NSError *error) {
        [successBlocks removeObjectForKey:url];
        [failureBlocks removeObjectForKey:url];
        [progressBlocks removeObjectForKey:url];
        if (failure) {
            failure(error);
        }
    };
    
    void (^progressBlock)(double, double) = ^(double totalBytesDownloaded, double totalBytesExpectedToDownload) {
        if (progress) {
            progress(totalBytesDownloaded, totalBytesExpectedToDownload);
        }
    };
    
    if ([successBlocks objectForKey:url] &&
        [failureBlocks objectForKey:url] &&
        [progressBlocks objectForKey:url] &&
        [destinationPaths objectForKey:url]) {
        NSMutableArray *successBlocksForURL = [successBlocks objectForKey:url];
        [successBlocksForURL addObject:[successBlock copy]];
        
        NSMutableArray *failureBlocksForURL = [failureBlocks objectForKey:url];
        [failureBlocksForURL addObject:[failureBlock copy]];
        
        NSMutableArray *progressBlocksForURL = [progressBlocks objectForKey:url];
        [progressBlocksForURL addObject:[progressBlock copy]];
        
        NSMutableArray *destinationPathsForURL = [destinationPaths objectForKey:url];
        [destinationPathsForURL addObject:destinationPath];
    } else {
        NSMutableArray *successBlocksForURL = [NSMutableArray array];
        [successBlocks setObject:successBlocksForURL forKey:url];
        [successBlocksForURL addObject:[successBlock copy]];
        
        NSMutableArray *failureBlocksForURL = [NSMutableArray array];
        [failureBlocks setObject:failureBlocksForURL forKey:url];
        [failureBlocksForURL addObject:[failureBlock copy]];
        
        NSMutableArray *progressBlocksForURL = [NSMutableArray array];
        [progressBlocks setObject:progressBlocksForURL forKey:url];
        [progressBlocksForURL addObject:[progressBlock copy]];
        
        NSMutableArray *destinationPathsForURL = [NSMutableArray array];
        [destinationPaths setObject:destinationPathsForURL forKey:url];
        [destinationPathsForURL addObject:destinationPath];
        
        [[session downloadTaskWithURL:url] resume];
    }
}

#pragma mark NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSError *error = downloadTask.error;
    NSURL *url = downloadTask.originalRequest.URL;
    NSArray *destinationPathsForURL = [destinationPaths objectForKey:url];
    if (error) {
        NSArray *blocks = [failureBlocks objectForKey:url];
        for (void (^block)(NSError *error) in blocks) {
            block(error);
        }
    } else {
        NSError *error;
        for (NSString *path in destinationPathsForURL) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            }
            [[NSFileManager defaultManager] copyItemAtURL:location toURL:[NSURL fileURLWithPath:path] error:&error];
        }
        [[NSFileManager defaultManager] removeItemAtURL:location error:nil];
        if (error) {
            NSArray *blocks = [failureBlocks objectForKey:url];
            for (void (^block)(NSError *error) in blocks) {
                block(error);
            }
        } else {
            NSArray *blocks = [successBlocks objectForKey:url];
            for (void (^block)() in blocks) {
                block();
            }
        }
    }
    
    [successBlocks removeObjectForKey:url];
    [failureBlocks removeObjectForKey:url];
    [progressBlocks removeObjectForKey:url];
    [destinationPaths removeObjectForKey:url];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    NSArray *blocks = [progressBlocks objectForKey:downloadTask.originalRequest.URL];
    for (void (^block)(double totalBytesDownloaded, double totalBytesExpectedToDownload) in blocks) {
        block((double)totalBytesWritten, (double)totalBytesExpectedToWrite);
    }
}

@end
