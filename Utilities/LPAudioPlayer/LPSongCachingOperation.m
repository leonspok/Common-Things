//
//  MBSongCachingOperation.m
//  Musix
//
//  Created by Игорь Савельев on 05/03/15.
//  Copyright (c) 2015 mBox. All rights reserved.
//

#import "LPSongCachingOperation.h"
#import <AVFoundation/AVFoundation.h>
#import "LPOfflineChecker.h"

@interface LPSongCachingOperation() <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSessionTask *downloadTask;
@property (nonatomic, strong) NSFileHandle *tempFileHandle;
@property (nonatomic) long long bytesOffset;
@property (nonatomic) long long totalBytesWritten;
@property (nonatomic) long long totalBytesExpectedToRead;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURL *streamingURL;
@property (nonatomic, strong) void (^progress)(float progress);
@property (nonatomic, strong) void (^success)();
@property (nonatomic, strong) void (^failure)(NSError *error);

@property (nonatomic, assign, readwrite) BOOL cancelled;
@property (nonatomic, assign, readwrite) BOOL finished;

@end

@implementation LPSongCachingOperation {
    NSString *pathToCacheFolder;
    NSString *owner;
    
    long long lastCheckReadBytes;
    CFAbsoluteTime lastCheckTime;
}

- (id)initWithSong:(LPAudioPlayerItem *)song pathToCacheFolder:(NSString *)path owner:(NSString *)own {
    self = [super init];
    if (self) {
        self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
        
        _cancelled = NO;
        _finished = NO;
        _song = song;
        pathToCacheFolder = path;
        owner = own;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (object == nil) {
        return NO;
    }
    if ([object isKindOfClass:self.class]) {
        LPSongCachingOperation *otherOperation = (LPSongCachingOperation *)object;
        return [otherOperation.song isEqual:self.song];
    } else {
        return NO;
    }
}

- (double)requiredSpeed {
    if (self.totalBytesExpectedToRead > 0) {
        double speed = (double)self.totalBytesExpectedToRead/self.song.duration;
        if (speed > 1000000.0f) {
            return 0;
        }
        return speed;
    } else {
        return 0.0f;
    }
}

- (void)start {
    [self cancel];
    
    _cancelled = NO;
    _finished = NO;
    
    NSString *tempName = [self.class pathToTempFileForSong:_song pathToCacheFolder:pathToCacheFolder owner:owner];
    
    typeof(self) __weak weakSelf = self;
	[self getStreamingURLSuccess:^(NSURL *streamingURL) {
		if (weakSelf.cancelled) {
			return;
		}
		
		NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:streamingURL];
		weakSelf.streamingURL = streamingURL;
		self.bytesOffset = 0;
		if ([[NSFileManager defaultManager] fileExistsAtPath:tempName]) {
			NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:tempName error:NULL];
			unsigned long long bytes = [attributes fileSize];
			[request setValue:[NSString stringWithFormat:@"bytes=%lld-", bytes] forHTTPHeaderField:@"Range"];
			self.bytesOffset = bytes;
		}
		
		weakSelf.downloadTask = [self.session dataTaskWithRequest:request];
		
		self.totalBytesExpectedToRead = 0;
		_currentSpeed = 0.0f;
		lastCheckReadBytes = 0;
		lastCheckTime = -1;
		
		if (!weakSelf.cancelled) {
			[weakSelf.downloadTask resume];
		}
	} failure:^(NSError *error) {
		if (weakSelf.cancelled) {
			return;
		}
		if (error.code == NSURLErrorCancelled && !weakSelf.cancelled) {
			[weakSelf cancel];
			return;
		}
		weakSelf.finished = YES;
		if (weakSelf.failure) {
			weakSelf.failure([NSError errorWithDomain:NSStringFromClass(weakSelf.class) code:1 userInfo:nil]);
		}
	}];
}

- (void)cancel {
    [self.downloadTask cancel];
    @synchronized (self.tempFileHandle) {
        [self.tempFileHandle closeFile];
        self.tempFileHandle = nil;
    }
    
    _cancelled = YES;
    _finished = YES;
}

- (void)setProgressBlock:(void (^)(float))progressBlock {
    _progress = progressBlock;
}

- (void)setSuccessBlock:(void (^)())successBlock
                failure:(void (^)(NSError *))failureBlock {
    _success = successBlock;
    _failure = failureBlock;
}

+ (NSString *)pathToFinishedFileForSong:(LPAudioPlayerItem *)song
                      pathToCacheFolder:(NSString *)path
                                  owner:(NSString *)owner {
    NSString *permanentName = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", song.uid]];
    return permanentName;
}

+ (NSString *)pathToTempFileForSong:(LPAudioPlayerItem *)song
                  pathToCacheFolder:(NSString *)path
                              owner:(NSString *)owner {
    NSString *tempName = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_temp_%@", song.uid, owner? : @""]];
    return tempName;
}

#pragma mark NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if ([response isKindOfClass:NSHTTPURLResponse.class]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSNumber *length = [[httpResponse allHeaderFields] objectForKey:@"Content-Length"];
        self.totalBytesExpectedToRead = [length longLongValue]+self.bytesOffset;
        if (httpResponse.statusCode >= 400) {
            if (completionHandler) {
                completionHandler(NSURLSessionResponseCancel);
            }
            return;
        }
    }
    if (completionHandler) {
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        if (error.code == NSURLErrorCancelled && ((NSHTTPURLResponse *)task.response).statusCode < 400) {
            return;
        }
        
        if (![task.originalRequest.URL isEqual:self.streamingURL]) {
            return;
        }
        
        if (((NSHTTPURLResponse *)task.response).statusCode >= 400) {
            if (self.failure) {
                self.failure([NSError errorWithDomain:NSStringFromClass(self.class) code:((NSHTTPURLResponse *)task.response).statusCode userInfo:nil]);
            }
        } else {
            if (self.failure) {
                self.failure(error);
            }
        }
        @synchronized (self.tempFileHandle) {
            [self.tempFileHandle closeFile];
            self.tempFileHandle = nil;
        }
        self.finished = YES;
    } else {
        if (![task.originalRequest.URL isEqual:self.streamingURL] || self.cancelled) {
            return;
        }
        @synchronized (self.tempFileHandle) {
            [self.tempFileHandle closeFile];
            self.tempFileHandle = nil;
        }
        
        NSString *permanentName = [self.class pathToFinishedFileForSong:self.song pathToCacheFolder:pathToCacheFolder owner:owner];
        NSString *tempName = [self.class pathToTempFileForSong:self.song pathToCacheFolder:pathToCacheFolder owner:owner];
        
        NSURL *fromURL = [NSURL fileURLWithPath:tempName];
        [[NSFileManager defaultManager] removeItemAtPath:permanentName error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:tempName toPath:permanentName error:nil];
        [[NSFileManager defaultManager] removeItemAtURL:fromURL error:nil];
        [[NSURL fileURLWithPath:permanentName] setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
        [[NSFileManager defaultManager] setAttributes:@{NSFileProtectionKey:NSFileProtectionNone} ofItemAtPath:permanentName error:nil];
        
        if (self.success) {
            self.success();
        }
        self.finished = YES;
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSString *tempName = [self.class pathToTempFileForSong:self.song pathToCacheFolder:pathToCacheFolder owner:owner];
    [data enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
        NSData *chunk = [NSData dataWithBytes:bytes length:byteRange.length];
        if (![[NSFileManager defaultManager] fileExistsAtPath:tempName]) {
            [chunk writeToFile:tempName atomically:YES];
            self.totalBytesWritten += byteRange.length;
            [self progressChanged];
        } else {
            if (!self.tempFileHandle) {
                self.tempFileHandle = [NSFileHandle fileHandleForWritingAtPath:tempName];
                [self.tempFileHandle seekToEndOfFile];
            }
            @synchronized (self.tempFileHandle) {
                [self.tempFileHandle writeData:chunk];
            }
            self.totalBytesWritten += byteRange.length;
            [self progressChanged];
        }
    }];
}

- (void)progressChanged {
    if (self.progress) {
        self.progress(((double)self.bytesOffset+(double)self.totalBytesWritten)/self.totalBytesExpectedToRead);
    }
    
    if (lastCheckTime > 0) {
        CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
        CFTimeInterval timeInterval = currentTime - lastCheckTime;
        if (timeInterval >= 1.0f) {
            long long bytesRead = self.totalBytesWritten-lastCheckReadBytes;
            _currentSpeed = (double)bytesRead/timeInterval;
            lastCheckReadBytes = self.totalBytesWritten;
            lastCheckTime = currentTime;
        }
    } else {
        lastCheckTime = CFAbsoluteTimeGetCurrent();
    }
}

#pragma mark Override

- (void)getStreamingURLSuccess:(void (^)(NSURL *))success failure:(void (^)(NSError *))failure {
	if (success) {
		success(self.song.streamingURL);
	}
}

@end
