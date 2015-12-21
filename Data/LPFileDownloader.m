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
    NSOperationQueue *sessionQueue;
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
        sessionQueue = [[NSOperationQueue alloc] init];
        sessionQueue.name = NSStringFromClass(self.class);
        
        successBlocks = [NSMutableDictionary dictionary];
        failureBlocks = [NSMutableDictionary dictionary];
        progressBlocks = [NSMutableDictionary dictionary];
        destinationPaths = [NSMutableDictionary dictionary];
        session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:sessionQueue];
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
        if (success) {
            success();
        }
    };
    
    void (^failureBlock)(NSError *error) = ^(NSError *error) {
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
        [successBlocksForURL addObject:successBlock];
        
        NSMutableArray *failureBlocksForURL = [failureBlocks objectForKey:url];
        [failureBlocksForURL addObject:failureBlock];
        
        NSMutableArray *progressBlocksForURL = [progressBlocks objectForKey:url];
        [progressBlocksForURL addObject:progressBlock];
        
        NSMutableArray *destinationPathsForURL = [destinationPaths objectForKey:url];
        @synchronized(destinationPathsForURL) {
            [destinationPathsForURL addObject:destinationPath];
        }
    } else {
        NSMutableArray *successBlocksForURL = [NSMutableArray array];
        [successBlocksForURL addObject:successBlock];
        [successBlocks setObject:successBlocksForURL forKey:url];
        
        NSMutableArray *failureBlocksForURL = [NSMutableArray array];
        [failureBlocksForURL addObject:failureBlock];
        [failureBlocks setObject:failureBlocksForURL forKey:url];
        
        NSMutableArray *progressBlocksForURL = [NSMutableArray array];
        [progressBlocksForURL addObject:progressBlock];
        [progressBlocks setObject:progressBlocksForURL forKey:url];
        
        NSMutableArray *destinationPathsForURL = [NSMutableArray array];
        [destinationPathsForURL addObject:destinationPath];
        [destinationPaths setObject:destinationPathsForURL forKey:url];
        
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
        @synchronized(destinationPathsForURL) {
            for (NSString *path in destinationPathsForURL) {
                if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                }
                [[NSFileManager defaultManager] copyItemAtURL:location toURL:[NSURL fileURLWithPath:path] error:&error];
            }
            [[NSFileManager defaultManager] removeItemAtURL:location error:nil];
        }
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
    if (successBlocks.count == 0) {
        successBlocks = [NSMutableDictionary dictionary];
    }
    [failureBlocks removeObjectForKey:url];
    if (failureBlocks.count == 0) {
        failureBlocks = [NSMutableDictionary dictionary];
    }
    [progressBlocks removeObjectForKey:url];
    if (progressBlocks.count == 0) {
        progressBlocks = [NSMutableDictionary dictionary];
    }
    [destinationPaths removeObjectForKey:url];
    if (destinationPaths.count == 0) {
        destinationPaths = [NSMutableDictionary dictionary];
    }
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

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSURL *url = task.originalRequest.URL;
    if (error) {
        NSArray *blocks = [failureBlocks objectForKey:url];
        for (void (^block)(NSError *error) in blocks) {
            block(error);
        }
    }
    [successBlocks removeObjectForKey:url];
    if (successBlocks.count == 0) {
        successBlocks = [NSMutableDictionary dictionary];
    }
    [failureBlocks removeObjectForKey:url];
    if (failureBlocks.count == 0) {
        failureBlocks = [NSMutableDictionary dictionary];
    }
    [progressBlocks removeObjectForKey:url];
    if (progressBlocks.count == 0) {
        progressBlocks = [NSMutableDictionary dictionary];
    }
    [destinationPaths removeObjectForKey:url];
    if (destinationPaths.count == 0) {
        destinationPaths = [NSMutableDictionary dictionary];
    }
}

@end
