//
//  LPCacheClient.m
//  Leonspok
//
//  Created by Игорь Савельев on 03/02/14.
//  Copyright (c) 2014 Leonspok. All rights reserved.
//

#import "LPCacheClient.h"
#import "LPAudioPlayer.h"
#import "LPOfflineChecker.h"
#import "LPSongCachingOperation.h"
#import "NSFileManager+FolderSize.h"
#import <sys/stat.h>

@import AVFoundation;

#define REQUIRED_FREE_SPACE_ON_DEVICE 128
#define DEFAULT_MAX_CACHE_STORAGE_TIME 15*24*60*60
#define DEFAULT_MAX_CACHE_SIZE_MB @256

static NSString *const kMaxCacheCapacityInMBUserDefaultsKey = @"LPCacheClientMaxCacheCapacityInMB";

@interface LPCacheClient()
@property (nonatomic, readwrite) double progress;
@property (nonatomic, strong) LPSongCachingOperation *operation;
@property (nonatomic, strong) LPSongCachingOperation *precacheOperation;
@property (atomic) BOOL checkingCache;
@property (atomic) BOOL cleaningCache;
@end

@implementation LPCacheClient

@synthesize pathToCacheFolder = _pathToCacheFolder;

+ (instancetype)sharedClient {
    static LPCacheClient *client = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        client = [[LPCacheClient alloc] init];
    });
    return client;
}

- (id)init {
    self = [super init];
    if (self) {
		[self createCacheFolderIfNeeded];
        self.progress = 1.0;
    }
    return self;
}

#pragma mark Properties

- (NSString *)pathToCacheFolder {
	if (!_pathToCacheFolder) {
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
		NSString *pathToCacheFolder = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Cache"];
		return pathToCacheFolder;
	}
	return _pathToCacheFolder;
}

- (void)setPathToCacheFolder:(NSString *)pathToCacheFolder {
	if (pathToCacheFolder.length == 0) {
		return;
	}
	
	_pathToCacheFolder = pathToCacheFolder;
	[self createCacheFolderIfNeeded];
}

- (void)createCacheFolderIfNeeded {
	BOOL isDirectory;
	if (![[NSFileManager defaultManager] fileExistsAtPath:self.pathToCacheFolder isDirectory:&isDirectory]) {
		[[NSFileManager defaultManager] createDirectoryAtPath:self.pathToCacheFolder
								  withIntermediateDirectories:NO
												   attributes:nil
														error:nil];
	} else if (!isDirectory) {
		[[NSFileManager defaultManager] removeItemAtPath:self.pathToCacheFolder error:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:self.pathToCacheFolder
								  withIntermediateDirectories:NO
												   attributes:nil
														error:nil];
	}
}

- (LPSongCachingOperationFactory *)cachingOperationsFactory {
	if (!_cachingOperationsFactory) {
		return [LPSongCachingOperationFactory new];
	}
	return _cachingOperationsFactory;
}

- (void)setMaxCacheCapacityInMB:(NSNumber *)maxCacheCapacityInMB {
	if (!maxCacheCapacityInMB) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:kMaxCacheCapacityInMBUserDefaultsKey];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject:maxCacheCapacityInMB forKey:kMaxCacheCapacityInMBUserDefaultsKey];
	}
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSNumber *)maxCacheCapacityInMB {
	NSNumber *number = [[NSUserDefaults standardUserDefaults] objectForKey:kMaxCacheCapacityInMBUserDefaultsKey];
	if (!number) {
		return DEFAULT_MAX_CACHE_SIZE_MB;
	} else {
		return number;
	}
}

- (NSTimeInterval)maxCacheStorageTime {
	if (_maxCacheStorageTime == 0.0f) {
		return DEFAULT_MAX_CACHE_STORAGE_TIME;
	}
	return _maxCacheStorageTime;
}

- (LPAudioPlayerItem *)currentCachingSong {
    return self.operation.song;
}

- (LPAudioPlayerItem *)currentPrecachingSong {
    return self.precacheOperation.song;
}

- (void)setProgress:(double)progress {
	[self willChangeValueForKey:@"progress"];
    _progress = progress;
    [self didChangeValueForKey:@"progress"];
}

- (NSNumber *)cacheCapacity {
	return @([[[NSFileManager defaultManager] folderSizeAtURL:[NSURL fileURLWithPath:self.pathToCacheFolder]] doubleValue] + [[[NSFileManager defaultManager] folderSizeAtURL:[NSURL fileURLWithPath:NSTemporaryDirectory()]] doubleValue]);
}

#pragma mark Cache Management

- (void)clearCacheForSong:(LPAudioPlayerItem *)song {
    if ([self isSongCached:song]) {
        NSString *fileName = [self.cachingOperationsFactory pathToFinishedFileForSong:song pathToCacheFolder:self.pathToCacheFolder owner:NSStringFromClass(self.class)];
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:fileName error:&error];
        if (error) {
            NSLog(@"Error while cleaning cache for song. %ld", (unsigned long)error.code);
        }
    } else {
        NSString *tempName = [self.cachingOperationsFactory pathToTempFileForSong:song pathToCacheFolder:self.pathToCacheFolder owner:NSStringFromClass(self.class)];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:tempName]) {
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtPath:tempName error:&error];
            if (error) {
                NSLog(@"Error while cleaning cache for song. %ld", (unsigned long)error.code);
            }
        }
    }
}

- (void)clearCaches {
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.pathToCacheFolder error:nil];
    for (NSString *file in contents) {
        NSError *error = nil;
        NSString *path = [self.pathToCacheFolder stringByAppendingPathComponent:file];
        [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    }
    
    NSString *tempFolder = NSTemporaryDirectory();
    contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tempFolder error:nil];
    for (NSString *file in contents) {
        NSError *error = nil;
        NSString *path = [tempFolder stringByAppendingPathComponent:file];
        [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    }
}

- (void)clearTempCaches {
    NSString *tempFolder = NSTemporaryDirectory();
    NSArray *tempFolderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tempFolder error:nil];
    NSString *cachingSongPath = [self.cachingOperationsFactory pathToTempFileForSong:self.currentCachingSong pathToCacheFolder:self.pathToCacheFolder owner:NSStringFromClass(self.class)];
    NSString *precachingSongPath = [self.cachingOperationsFactory pathToTempFileForSong:self.currentPrecachingSong pathToCacheFolder:self.pathToCacheFolder owner:NSStringFromClass(self.class)];
    for (NSString *file in tempFolderContents) {
        if ([file containsString:NSStringFromClass(self.class)]) {
            NSString *path = [tempFolder stringByAppendingPathComponent:file];
            if ([path isEqualToString:cachingSongPath] || [path isEqualToString:precachingSongPath]) {
                continue;
            }
            NSError *error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
        }
    }
}

- (void)removeUnusedCache {
    if (self.cleaningCache) {
        return;
    }
    self.cleaningCache = YES;
    
    [self clearTempCaches];
    
    NSError *error = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:self.pathToCacheFolder] includingPropertiesForKeys:@[NSURLContentModificationDateKey,NSURLFileSizeKey] options:0 error:&error];
    contents = [contents sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSDate *date1, *date2;
        [obj1 getResourceValue:&date1 forKey:NSURLContentAccessDateKey error:nil];
        [obj2 getResourceValue:&date2 forKey:NSURLContentAccessDateKey error:nil];
        if (!date1) {
            [obj1 getResourceValue:&date1 forKey:NSURLContentModificationDateKey error:nil];
        }
        if (!date2) {
            [obj2 getResourceValue:&date2 forKey:NSURLContentModificationDateKey error:nil];
        }
        return [date1 compare:date2];
    }];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
    NSNumber *freeSpaceNumber = [dictionary objectForKey:NSFileSystemFreeSize];
    double freeSpace = freeSpaceNumber.doubleValue/1024/1024;
    
    NSString *cachingSongPath = [self.cachingOperationsFactory pathToFinishedFileForSong:self.currentCachingSong pathToCacheFolder:self.pathToCacheFolder owner:NSStringFromClass(self.class)];
    NSString *precachingSongPath = [self.cachingOperationsFactory pathToFinishedFileForSong:self.currentPrecachingSong pathToCacheFolder:self.pathToCacheFolder owner:NSStringFromClass(self.class)];
    NSString *currentPlayingSongPath = [self.cachingOperationsFactory pathToFinishedFileForSong:[LPAudioPlayer sharedPlayer].queue.currentSong pathToCacheFolder:self.pathToCacheFolder owner:NSStringFromClass(self.class)];
    
    NSDate *startDate = [NSDate date];
    double cacheCapacity = [[self cacheCapacity] doubleValue];
    double folderSize = cacheCapacity/1024/1024;
    for (NSInteger i = 0; i < contents.count && (folderSize >= [self.maxCacheCapacityInMB doubleValue] || folderSize+REQUIRED_FREE_SPACE_ON_DEVICE >= freeSpace) && [[NSDate date] timeIntervalSinceDate:startDate] <= 20.0f; i++) {
        NSNumber *sizeNumber;
        NSURL *url = [contents objectAtIndex:i];
        
        if ([[url path] isEqualToString:cachingSongPath] || [[url path] isEqualToString:precachingSongPath] || [[url path] isEqualToString:currentPlayingSongPath]) {
            continue;
        }
        
        [url getResourceValue:&sizeNumber forKey:NSURLFileSizeKey error:nil];
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        cacheCapacity -= sizeNumber.doubleValue;
        folderSize = cacheCapacity/1024/1024;
    }
    self.cleaningCache = NO;
}

- (BOOL)isCacheFull {
    NSNumber *folderSize = [self cacheCapacity];
    
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
    NSNumber *freeSpaceNumber = [dictionary objectForKey:NSFileSystemFreeSize];
    double freeSpace = freeSpaceNumber.doubleValue/1024/1024;
    
    NSInteger fldSize = [folderSize integerValue]/1024/1024;
    
    return (fldSize >= [self.maxCacheCapacityInMB doubleValue] || fldSize+REQUIRED_FREE_SPACE_ON_DEVICE >= freeSpace);
}

- (void)clearCacheIfNeeded {
    if (self.checkingCache) {
        return;
    }
    self.checkingCache = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.pathToCacheFolder error:nil];
        for (NSString *file in contents) {
            NSString *path = [self.pathToCacheFolder stringByAppendingPathComponent:file];
            NSDate *created = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] objectForKey:@"NSFileCreationDate"];
            if([created compare:[[NSDate date] dateByAddingTimeInterval:-self.maxCacheStorageTime]] == NSOrderedAscending){
                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            }
        }
        
        if ([self isCacheFull]) {
            [self removeUnusedCache];
        }
        self.checkingCache = NO;
    });
}

- (BOOL)isSongCached:(LPAudioPlayerItem *)song {
    NSString *fileName = [self.cachingOperationsFactory pathToFinishedFileForSong:song pathToCacheFolder:self.pathToCacheFolder owner:NSStringFromClass(self.class)];
    return [[NSFileManager defaultManager] fileExistsAtPath:fileName];
}

- (void)precacheSong:(LPAudioPlayerItem *)song {
    if ([song isEqual:self.precacheOperation.song] ||
        [song isEqual:self.operation.song]) {
        return;
    }
    
    if (self.precacheOperation) {
        [self.precacheOperation cancel];
        self.precacheOperation = nil;
    }
    
    if ([self isSongCached:song]) {
        return;
    }
    
    NSString *permanentName = [self.cachingOperationsFactory pathToFinishedFileForSong:song pathToCacheFolder:self.pathToCacheFolder owner:NSStringFromClass(self.class)];
    
    [self.precacheOperation cancel];
    self.precacheOperation = nil;
    [self clearCacheIfNeeded];
	self.precacheOperation = [self.cachingOperationsFactory operationForSong:song pathToCacheFolder:self.pathToCacheFolder owner:NSStringFromClass(self.class)];
    [self.precacheOperation setProgressBlock:^(float progress) {
        //do nothing
    }];
    typeof(self) __weak weakSelf = self;
    [self.precacheOperation setSuccessBlock:^{
        NSLog(@"Successfully precached song");
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:permanentName] options:nil];
            CMTime audioDuration = audioAsset.duration;
            Float64 seconds = CMTimeGetSeconds(audioDuration);
            if (seconds > 0) {
                song.duration = MIN(seconds, song.duration);
            }
        });
    } failure:^(NSError *error) {
        if (error && ![[LPOfflineChecker defaultChecker] isOffline]) {
            NSLog(@"CACHING SONG ERROR: %@", [error localizedDescription]);
        }
        weakSelf.precacheOperation = nil;
    }];
    [self.precacheOperation start];
    NSLog(@"PRECACHE STARTED");
}

- (NSString *)getSong:(LPAudioPlayerItem *)song {
    NSString *permanentName = [self.cachingOperationsFactory pathToFinishedFileForSong:song pathToCacheFolder:self.pathToCacheFolder owner:NSStringFromClass(self.class)];
    NSString *tempName = [self.cachingOperationsFactory pathToTempFileForSong:song pathToCacheFolder:self.pathToCacheFolder owner:NSStringFromClass(self.class)];
    
    if ([song isEqual:self.operation.song]) {
        return tempName;
    }
    
    if (self.operation) {
        [self.operation cancel];
        self.operation = nil;
    }
    
    if ([self isSongCached:song]) {
        [[NSFileManager defaultManager] setAttributes:@{NSFileProtectionKey:NSFileProtectionNone} ofItemAtPath:permanentName error:nil];

        AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:permanentName] options:nil];
        CMTime audioDuration = audioAsset.duration;
        Float64 seconds = CMTimeGetSeconds(audioDuration);
        if (seconds > 0) {
            song.duration = MIN(seconds, song.duration);
        }
        
        [self reset];
        return permanentName;
    }
    
    if (self.precacheOperation && [song isEqual:self.precacheOperation.song]) {
        [self.precacheOperation cancel];
        self.precacheOperation = nil;
    }
    
    self.progress = 0.0f;
    typeof(self) __weak weakSelf = self;
    
    [self clearCacheIfNeeded];
    self.operation = [self.cachingOperationsFactory operationForSong:song pathToCacheFolder:self.pathToCacheFolder owner:NSStringFromClass(self.class)];
    [self.operation setProgressBlock:^(float progress) {
        weakSelf.progress = progress;
    }];
    [self.operation setSuccessBlock:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            AVURLAsset* audioAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:permanentName] options:nil];
            CMTime audioDuration = audioAsset.duration;
            Float64 seconds = CMTimeGetSeconds(audioDuration);
            if (seconds > 0) {
                song.duration = MIN(seconds, song.duration);
            }
        });
        [weakSelf reset];
    } failure:^(NSError *error) {
        if (error && (error.code >= 400)) {
            BOOL wasPlaying = [[LPAudioPlayer sharedPlayer] isPlaying];
            [[LPAudioPlayer sharedPlayer] next];
            if (wasPlaying) {
                [[LPAudioPlayer sharedPlayer] play];
            }
        }
        if (error && ![[LPOfflineChecker defaultChecker] isOffline]) {
            NSLog(@"CACHING SONG ERROR: %@", [error localizedDescription]);
        }
        [weakSelf reset];
    }];
    [self.operation start];
    
    return tempName;
}

- (void)reset {
    self.operation = nil;
    self.progress = 1.0f;
}

- (void)stopCurrentCaching {
    if (self.operation) {
        [self.operation cancel];
        self.operation = nil;
    }
}

@end
