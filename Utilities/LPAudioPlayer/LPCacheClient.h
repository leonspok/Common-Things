//
//  LPCacheClient.h
//  Leonspok
//
//  Created by Игорь Савельев on 03/02/14.
//  Copyright (c) 2014 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPAudioPlayerItem.h"
#import "LPSongCachingOperationFactory.h"

@interface LPCacheClient : NSObject

@property (nonatomic, strong) NSString *pathToCacheFolder;
@property (strong, nonatomic, readonly) NSNumber *cacheCapacity;
@property (nonatomic) NSTimeInterval maxCacheStorageTime;
@property (nonatomic, strong) NSNumber *maxCacheCapacityInMB;

@property (nonatomic, readonly) double progress;
@property (nonatomic, strong, readonly) LPAudioPlayerItem *currentCachingSong;
@property (nonatomic, strong, readonly) LPAudioPlayerItem *currentPrecachingSong;
@property (nonatomic, strong) LPSongCachingOperationFactory *cachingOperationsFactory;

- (BOOL)isSongCached:(LPAudioPlayerItem *)song;
- (NSString *)getSong:(LPAudioPlayerItem *)song;
- (void)precacheSong:(LPAudioPlayerItem *)song;
- (void)clearCacheForSong:(LPAudioPlayerItem *)song;
- (void)clearCaches;
- (void)stopCurrentCaching;

@end
