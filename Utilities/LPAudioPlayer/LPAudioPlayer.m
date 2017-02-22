//
//  LPAudioPlayer.m
//  Leonspok
//
//  Created by Игорь Савельев on 31/01/14.
//  Copyright (c) 2014 Leonspok. All rights reserved.
//

#import "LPAudioPlayer.h"
#import "LPImageDownloadManager.h"
#import "LPOfflineChecker.h"
#import "UIImage+ImageEffects.h"

@import AVFoundation;
@import MediaPlayer;

NSString *const kLPAudioPlayerPlaybackChangedNotification = @"LPAudioPlayerPlaybackChangedNotification";
NSString *const kLPAudioPlayerCurrentTimeChangedNotification = @"LPAudioPlayerCurrentTimeChangedNotification";
NSString *const kLPAudioPlayerCurrentSongChangedNotification = @"LPAudioPlayerCurrentSongChangedNotification";
NSString *const kLPAudioPlayerCurrentSongSkippedNotification = @"LPAudioPlayerCurrentSongSkippedNotification";
NSString *const kLPAudioPlayerQueueChangedNotification = @"LPAudioPlayerQueueChangedNotification";

static NSString *const kRepeatModeUserDefaultsKey = @"LPAudioPlayerRepeatMode";
static NSString *const kShuffleUserDefaultsKey = @"LPAudioPlayerShuffle";

@interface LPAudioPlayer() <AVAudioPlayerDelegate>
@property (strong, atomic) AVAudioPlayer *player;
@end

@implementation LPAudioPlayer{
    NSMutableOrderedSet *shuffledSongs;
	
	BOOL isPlaying;
	
    BOOL shouldPlay;
    NSTimeInterval shouldPlayAtTime;
    BOOL shouldSkipIfFailedToReload;
    NSTimer *loadTimer;
    BOOL songIsLoading;
    UIBackgroundTaskIdentifier backgroundTaskID;
    NSBlockOperation *loadingSongOperation;
    
    AVAudioSession *session;
    BOOL shouldPostCurrentTime;
    
    NSTimer *progressTimer;
    
    BOOL playedBeforeInterruption;
    
    NSTimeInterval lastPostedTime;
    NSTimeInterval lastPlayedTime;
    
    id playPauseCommandHandler;
    id playCommandHandler;
    id pauseCommandHandler;
    id nextCommandHandler;
    id previousCommandHandler;
}

@synthesize songIsLoading = songIsLoading;
@synthesize queue = _queue;
@synthesize isPlaying = isPlaying;

+ (instancetype)sharedPlayer {
    static LPAudioPlayer *player = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        player = [[LPAudioPlayer alloc] init];
    });
    return player;
}

- (id)init {
    self = [super init];
    if (self) {
        _notificationCenter = [[NSNotificationCenter alloc] init];
        
        [self setQueue:[LPAudioQueue new]];
        [self currentSongChanged];
        
        shouldPlay = NO;
        shouldPlayAtTime = -1.0;
        
        shouldPostCurrentTime = YES;
        
        shuffledSongs = [[NSMutableOrderedSet alloc] init];
        [self loadSettings];
                
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        
        [self reloadSession];
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleRouteChange:)
                                                     name: AVAudioSessionRouteChangeNotification
                                                   object: session];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleInterruption:)
                                                     name: AVAudioSessionInterruptionNotification
                                                   object: session];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleMediaServicesWereReset:)
                                                     name: AVAudioSessionMediaServicesWereResetNotification
                                                   object: session];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleMediaServicesWereLost:)
                                                     name: AVAudioSessionMediaServicesWereLostNotification
                                                   object: session];
        
        [[LPOfflineChecker defaultChecker].notificationCenter addObserver:self
                                                                 selector:@selector(offlineStatusChanged)
                                                                     name:kOfflineStatusChangedNotification
                                                                   object:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(recordCurrentPlayingTime) userInfo:nil repeats:YES];
        });
        
        [self setNowPlayingInfo];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[LPOfflineChecker defaultChecker].notificationCenter removeObserver:self];
}

- (void)reloadSession {
    session = [AVAudioSession sharedInstance];
    NSError *error;
    [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (error) {
        NSLog(@"%@", [error localizedDescription]);
    }
    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"%@", [error localizedDescription]);
    }
}

- (void)loadSettings {
    _repeatMode = (LPAudioPlayerRepeatMode)[[[NSUserDefaults standardUserDefaults] stringForKey:kRepeatModeUserDefaultsKey] integerValue];
    [self setShuffle:[[NSUserDefaults standardUserDefaults] boolForKey:kShuffleUserDefaultsKey]];
}

- (LPCacheClient *)cacheClient {
	if (!_cacheClient) {
		_cacheClient = [[LPCacheClient alloc] init];
		return _cacheClient;
	}
	return _cacheClient;
}

- (void)setRepeatMode:(LPAudioPlayerRepeatMode)repeatMode {
    _repeatMode = repeatMode;
    [[NSUserDefaults standardUserDefaults] setObject:@(repeatMode) forKey:kRepeatModeUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setShuffle:(BOOL)shuffle {
    _shuffle = shuffle;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:shuffle] forKey:kShuffleUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)play {
    if (self.queue.currentSong == nil) {
        return;
    }
    
    if (songIsLoading) {
        shouldPlay = YES;
        isPlaying = YES;
    } else if (!self.player) {
        shouldPlay = YES;
        isPlaying = YES;
        [self loadSong];
    } else {
        [self.player play];
        shouldPlay = YES;
        isPlaying = YES;
        
        [progressTimer invalidate];
        progressTimer = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            progressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(handleCurrentTimeChange) userInfo:nil repeats:YES];
        });
    }
    [self.notificationCenter postNotificationName:kLPAudioPlayerPlaybackChangedNotification object:self];
}

- (void)playNext {
    [self pause];
    if (self.repeatMode == LPAudioPlayerRepeatModeOne) {
        [self currentSongChanged];
        [self play];
    } else {
        if (self.shuffle) {
            NSInteger oldIndex = self.queue.currentSongIndex;
            NSInteger index = [self nextShuffled];
            self.queue.currentSongIndex = index;
            if (index != oldIndex || self.repeatMode != LPAudioPlayerRepeatModeOff) {
                [self play];
            }
        } else {
            NSInteger index = [self nextForward];
            self.queue.currentSongIndex = index;
            if (self.repeatMode == LPAudioPlayerRepeatModeAll || index != 0) {
                [self play];
            }
        }
    }
}

- (void)pause {
    [self.player pause];
    isPlaying = NO;
    shouldPlay = NO;
    
    if (progressTimer != nil) {
        [progressTimer invalidate];
        progressTimer = nil;
    }
    [self.notificationCenter postNotificationName:kLPAudioPlayerPlaybackChangedNotification object:self];
}

- (void)nextInternal {
    if (self.queue.songs.count == 0) {
        return;
    }
    NSInteger index = 0;
    if (self.shuffle) {
        index = [self nextShuffled];
    } else {
        index = [self nextForward];
    }
    self.queue.currentSongIndex = index;
}

- (void)next {
    [self nextInternal];
	[self.notificationCenter postNotificationName:kLPAudioPlayerCurrentSongSkippedNotification object:self];
}

- (NSInteger)nextShuffled {
    if (shuffledSongs.count == self.queue.songs.count ||
        ([[LPOfflineChecker defaultChecker] isOffline] && shuffledSongs.count >= [self countOfAvailableSongs])) {
        [shuffledSongs removeAllObjects];
    }
    
    if ([self countOfAvailableSongs] <= 1) {
        return self.queue.currentSongIndex;
    }
    
    NSInteger index = 0;
    NSNumber *number = nil;
    
    BOOL available = NO;
    do {
        index = arc4random() % self.queue.songs.count;
        number = [NSNumber numberWithInteger:index];
        LPAudioPlayerItem *song = [self.queue.songs objectAtIndex:index];
        available = ![[LPOfflineChecker defaultChecker] isOffline] || [self.cacheClient isSongCached:song];
    } while([shuffledSongs containsObject:number] ||
            index == self.queue.currentSongIndex ||
            !available);
    
    [shuffledSongs addObject:number];
    
    return index;
}

- (NSInteger)nextForward {
    NSInteger index = (self.queue.currentSongIndex+1)%self.queue.songs.count;
    LPAudioPlayerItem *song = [self.queue.songs objectAtIndex:index];
    BOOL available = ![[LPOfflineChecker defaultChecker] isOffline] || [self.cacheClient isSongCached:song];
    while (!available && index != self.queue.currentSongIndex) {
        index = (index+1)%self.queue.songs.count;
        song = [self.queue.songs objectAtIndex:index];
        available = ![[LPOfflineChecker defaultChecker] isOffline] || [self.cacheClient isSongCached:song];
    }
    return index;
}

- (void)previousInternal {
    if (self.queue.songs.count == 0) {
        return;
    }
    NSInteger index = 0;
    if (self.shuffle) {
        index = [self previousShuffled];
    } else {
        index = [self previousForward];
    }
    self.queue.currentSongIndex = index;
}

- (void)previous {
    [self previousInternal];
	[self.notificationCenter postNotificationName:kLPAudioPlayerCurrentSongSkippedNotification object:self];
}

- (NSInteger)previousShuffled {
    if (shuffledSongs.count <= 1) {
        [shuffledSongs removeAllObjects];
        return [self nextShuffled];
    } else {
        BOOL available = NO;
        NSInteger currentShuffledIndex = [[shuffledSongs lastObject] integerValue];
        do {
            currentShuffledIndex -= 1;
            NSNumber *lastIndex = [shuffledSongs lastObject];
            [shuffledSongs removeObject:lastIndex];
            
            if (currentShuffledIndex < 0) {
                return [self nextShuffled];
            }
            
            LPAudioPlayerItem *song;
            if (currentShuffledIndex < shuffledSongs.count) {
                song = [shuffledSongs objectAtIndex:currentShuffledIndex];
            } else {
                return [self nextShuffled];
            }
            available = ![[LPOfflineChecker defaultChecker] isOffline] || [self.cacheClient isSongCached:song];
        } while(!available);

        return currentShuffledIndex;
    }
}

- (NSInteger)previousForward {
    NSInteger index = (self.queue.currentSongIndex-1)%self.queue.songs.count;
    LPAudioPlayerItem *song = [self.queue.songs objectAtIndex:index];
    BOOL available = ![[LPOfflineChecker defaultChecker] isOffline] || [self.cacheClient isSongCached:song];
    while (!available && index != self.queue.currentSongIndex) {
        index = (index-1)%self.queue.songs.count;
        song = [self.queue.songs objectAtIndex:index];
        available = ![[LPOfflineChecker defaultChecker] isOffline] || [self.cacheClient isSongCached:song];
    }
    return index;
}

- (BOOL)loadPlayerWithURL:(NSURL *)url error:(NSError * __autoreleasing *)error {
    [self.player stop];
    self.player = nil;
	
	NSError *err = nil;
	if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
		err = [NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message": @"file doesn't exist"}];
		if (error) {
			*error = err;
		}
		return NO;
	}
	
	AVURLAsset *asset = [AVURLAsset assetWithURL:url];
	if ([asset tracksWithMediaType:AVMediaTypeAudio].count == 0) {
		err = [NSError errorWithDomain:NSStringFromClass(self.class) code:2 userInfo:@{@"message": @"file doesn't contain audio data"}];
		if (error) {
			*error = err;
		}
		return NO;
	}
	
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:error];
    self.player.delegate = self;
    [self.player prepareToPlay];
	
	return YES;
}

- (void)startLoadingSong {
    [self stopLoadingSong];
    loadingSongOperation = [[NSBlockOperation alloc] init];
    __weak NSBlockOperation *weakOperation = loadingSongOperation;
    songIsLoading = YES;
    [loadingSongOperation addExecutionBlock:^{
        BOOL loaded = [self loadRemoteSongWithCurrentTime:MAX(shouldPlayAtTime, 0.0f)];
        while (!loaded && !weakOperation.cancelled && weakOperation) {
            [NSThread sleepForTimeInterval:0.5f];
            if (!weakOperation.cancelled && weakOperation) {
                loaded = [self loadRemoteSongWithCurrentTime:MAX(shouldPlayAtTime, 0.0f)];
            }
        }
        if (!weakOperation.cancelled && weakOperation) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                if (shouldPlay) {
                    if (shouldPlayAtTime >= 0) {
                        [self setCurrentTime:[NSNumber numberWithDouble:shouldPlayAtTime]];
                    }
                    
                    songIsLoading = NO;
                    [self play];
                    shouldPlayAtTime = -1.0;
                    shouldPlay = NO;
                }
                
                UIBackgroundTaskIdentifier bgTask = backgroundTaskID;
                backgroundTaskID = UIBackgroundTaskInvalid;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (bgTask && bgTask != UIBackgroundTaskInvalid) {
                        NSLog(@"End bg task %s (%d)", __PRETTY_FUNCTION__, __LINE__);
                        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                    }
                });
                [self stopLoadingSong];
            });
        }
    }];
    [loadingSongOperation performSelectorInBackground:@selector(start) withObject:nil];
}

- (void)stopLoadingSong {
    [loadingSongOperation cancel];
    loadingSongOperation = nil;
    songIsLoading = NO;
}

- (void)loadSong {
    songIsLoading = NO;
    if (self.queue.songs.count == 0) {
        return;
    }
    
    [self setNowPlayingInfo];

    if (!backgroundTaskID || backgroundTaskID == UIBackgroundTaskInvalid) {
        NSLog(@"Begin bg task %s (%d). App has %0.1f sec in background.", __PRETTY_FUNCTION__, __LINE__, ([UIApplication sharedApplication].backgroundTimeRemaining > 10000.0f)? -1.0f : [UIApplication sharedApplication].backgroundTimeRemaining);
        backgroundTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskID];
            backgroundTaskID = UIBackgroundTaskInvalid;
            NSLog(@"bg task exceeded time limit: %s (%d)", __PRETTY_FUNCTION__, __LINE__);
        }];
    } else {
        NSLog(@"App has %0.1f sec in background remaining: %s (%d)", ([UIApplication sharedApplication].backgroundTimeRemaining > 10000.0f)? -1.0f : [UIApplication sharedApplication].backgroundTimeRemaining, __PRETTY_FUNCTION__, __LINE__);
    }
    [self startLoadingSong];
}

- (NSTimeInterval)playableDuration {
    if ([self.cacheClient isSongCached:self.queue.currentSong]) {
        return self.queue.currentSong.duration;
    } else {
        if ([self.cacheClient.currentCachingSong isEqual:self.queue.currentSong]) {
            return self.queue.currentSong.duration * self.cacheClient.progress;
        } else if (self.player) {
            return MAX(0.0f, MIN(self.player.duration, self.queue.currentSong.duration));
        } else {
            return self.queue.currentSong.duration;
        }
    }
}

- (BOOL)loadRemoteSongWithCurrentTime:(NSTimeInterval)currentTime {
    LPAudioPlayerItem *song = self.queue.currentSong;
    if (!song) {
        return NO;
    }
    
    if ([self.cacheClient isSongCached:song]) {
        NSString *path = [self.cacheClient getSong:song];
        NSURL *url = [NSURL fileURLWithPath:path];
        NSError *error = nil;
        [self loadPlayerWithURL:url error:&error];
		if ([error.domain isEqualToString:NSStringFromClass(self.class)] && error.code == 2) {
			NSLog(@"%@", [error localizedDescription]);
			self.player = nil;
			[self stopLoadingSong];
			BOOL wasPlaying = [self isPlaying];
			dispatch_async(dispatch_get_main_queue(), ^{
				[self next];
				if (wasPlaying) {
					[self play];
				}
			});
			return NO;
		} else if (error) {
            NSLog(@"%@", [error localizedDescription]);
            self.player = nil;
            return NO;
        }
    } else {
        NSString *path = [self.cacheClient getSong:song];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            NSTimeInterval currentSongDuration = [self playableDuration];
            NSTimeInterval gap = 0.0f;
            if (currentTime < 0) {
                gap = currentSongDuration;
            } else {
                gap = currentSongDuration-currentTime;
            }
            
            if (gap < 5.0f) {
                self.player = nil;
                return NO;
            }
            
            NSURL *url = [NSURL fileURLWithPath:path];
            NSError *error = nil;
            [self loadPlayerWithURL:url error:&error];
			if ([error.domain isEqualToString:NSStringFromClass(self.class)] && error.code == 2) {
				NSLog(@"%@", [error localizedDescription]);
				self.player = nil;
				[self stopLoadingSong];
				BOOL wasPlaying = [self isPlaying];
				dispatch_async(dispatch_get_main_queue(), ^{
					[self next];
					if (wasPlaying) {
						[self play];
					}
				});
				return NO;
			} else if (error) {
				NSLog(@"%@", [error localizedDescription]);
				self.player = nil;
				return NO;
			}
        } else {
            return NO;
        }
    }
    return YES;
}

- (void)setQueue:(LPAudioQueue *)queue {
    if (_queue) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kQueueChangedNotification object:_queue];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kCurrentSongChangedNotification object:_queue];
    }
    _queue = queue;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queueChanged) name:kQueueChangedNotification object:queue];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentSongChanged) name:kCurrentSongChangedNotification object:queue];
    
    [self.player stop];
    self.player = nil;
    [self.cacheClient stopCurrentCaching];
    
    [shuffledSongs removeAllObjects];
    [self currentSongChanged];
    [self.notificationCenter postNotificationName:kLPAudioPlayerQueueChangedNotification object:self];
}

- (void)softReloadQueue:(LPAudioQueue *)queue {
    if (queue == self.queue && [queue.currentSong isEqual:self.queue.currentSong]) {
        [self.notificationCenter postNotificationName:kLPAudioPlayerQueueChangedNotification object:self];
        return;
    }
    
    if ([queue.currentSong isEqual:self.queue.currentSong]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kQueueChangedNotification object:_queue];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kCurrentSongChangedNotification object:_queue];
        _queue = queue;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queueChanged) name:kQueueChangedNotification object:queue];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentSongChanged) name:kCurrentSongChangedNotification object:queue];
        [self.notificationCenter postNotificationName:kLPAudioPlayerQueueChangedNotification object:self];
    } else {
        BOOL wasPlaying = [self isPlaying];
        [self setQueue:queue];
        if (wasPlaying) {
            [self play];
        }
    }
}

- (NSNumber *)currentTime {
    if (self.queue.songs.count != 0) {
        NSTimeInterval time = self.player.currentTime;
        NSNumber *currentTime = [NSNumber numberWithDouble:time];
        return currentTime;
    }
    return [NSNumber numberWithInt:0];
}

- (void)setCurrentTime:(NSNumber *)currentTime {
    if ([currentTime doubleValue] <= [self playableDuration]) {
        if (self.player.duration <= [currentTime doubleValue]) {
            NSString *path = [self.cacheClient getSong:self.queue.currentSong];
            NSURL *url = [NSURL fileURLWithPath:path];
            [self loadPlayerWithURL:url error:nil];
            [self.player setCurrentTime:[currentTime doubleValue]];
        } else {
            [self.player setCurrentTime:[currentTime doubleValue]];
        }
        if (songIsLoading) {
            shouldPlayAtTime = [currentTime doubleValue];
        }
        [self handleCurrentTimeChange];
    }
}

- (NSInteger)countOfAvailableSongs {
    NSInteger count = 0;
    for (LPAudioPlayerItem *song in self.queue.songs) {
        if (![[LPOfflineChecker defaultChecker] isOffline] ||
            [self.cacheClient isSongCached:song]) {
            count++;
        }
    }
    return count;
}

- (void)offlineStatusChanged {
    if ([[LPOfflineChecker defaultChecker] isOffline]) {
        if (![self.cacheClient isSongCached:self.queue.currentSong]) {
            BOOL wasPlaying = [self isPlaying];
            [self previousInternal];
            if (wasPlaying) {
                [self play];
            }
        }
    }
}

#pragma mark Queue self observation

- (void)currentSongChanged {
    [self.player stop];
    self.player = nil;
    
    shouldPlayAtTime = -1.0;
    lastPlayedTime = 0.0f;
    lastPostedTime = 0.0f;
    [self reloadSession];
    
    [self.cacheClient stopCurrentCaching];
    [self stopLoadingSong];
    [self pause];
    
    if (self.queue.currentSong) {
        [self setCurrentTime:@0];
        [self loadSong];
    }
    
    [self.notificationCenter postNotificationName:kLPAudioPlayerCurrentSongChangedNotification object:self];
}

- (void)handleCurrentTimeChange {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        if (shouldPostCurrentTime && !songIsLoading) {
            lastPostedTime = [[self currentTime] doubleValue];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.notificationCenter postNotificationName:kLPAudioPlayerCurrentTimeChangedNotification object:self];
            });
        }
        
        if (!self.shuffle && ABS(self.queue.currentSong.duration - [self playableDuration]) < 5.0f && self.currentTime.doubleValue > 5.0f) {
            NSInteger nextIndex = self.queue.currentSongIndex+1;
            if (self.queue.songs.count > 0) {
                nextIndex %= self.queue.songs.count;
            } else {
                return;
            }
            
            LPAudioPlayerItem *nextSong = [self.queue.songs objectAtIndex:nextIndex];
            if (nextSong && ![self.cacheClient isSongCached:nextSong] && ![nextSong isEqual:self.cacheClient.currentPrecachingSong] && ![[LPOfflineChecker defaultChecker] isOffline]) {
                [self.cacheClient precacheSong:nextSong];
            }
        }
        
        if ([self.currentTime integerValue]%15 == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setNowPlayingInfo];
            });
        }
    });
}

- (void)queueChanged {
    [self softReloadQueue:self.queue];
}

# pragma mark AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)plyr successfully:(BOOL)flag {
    if (!backgroundTaskID || backgroundTaskID == UIBackgroundTaskInvalid) {
        NSLog(@"Begin bg task %s (%d). App has %0.1f sec in background.", __PRETTY_FUNCTION__, __LINE__, ([UIApplication sharedApplication].backgroundTimeRemaining > 10000.0f)? -1.0f : [UIApplication sharedApplication].backgroundTimeRemaining);
        backgroundTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskID];
            backgroundTaskID = UIBackgroundTaskInvalid;
            NSLog(@"bg task exceeded time limit: %s (%d)", __PRETTY_FUNCTION__, __LINE__);
        }];
    } else {
        NSLog(@"App has %0.1f sec in background remaining: %s (%d)", ([UIApplication sharedApplication].backgroundTimeRemaining > 10000.0f)? -1.0f : [UIApplication sharedApplication].backgroundTimeRemaining, __PRETTY_FUNCTION__, __LINE__);
    }
    
    void (^reloadBlock)() = ^{
        shouldPostCurrentTime = NO;
        if (![self loadRemoteSongWithCurrentTime:lastPlayedTime]) {
            shouldPlayAtTime = lastPlayedTime;
            shouldPlay = YES;
            [self loadSong];
        } else {
            [self setCurrentTime:@(lastPlayedTime)];
            [self play];
            UIBackgroundTaskIdentifier bgTask = backgroundTaskID;
            backgroundTaskID = UIBackgroundTaskInvalid;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (bgTask && bgTask != UIBackgroundTaskInvalid) {
                    NSLog(@"End bg task %s (%d)", __PRETTY_FUNCTION__, __LINE__);
                    [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                }
            });
        }
        shouldPostCurrentTime = YES;
    };
    
    if (![self.cacheClient isSongCached:self.queue.currentSong] && [[LPOfflineChecker defaultChecker] isOffline]) {
        [self playNext];
    } else if (lastPlayedTime >= self.queue.currentSong.duration - 5.0) {
        [self playNext];
    } else if (shouldSkipIfFailedToReload) {
        shouldSkipIfFailedToReload = NO;
        [self playNext];
    } else if ([self.cacheClient isSongCached:self.queue.currentSong]) {
        shouldSkipIfFailedToReload = YES;
        reloadBlock();
    } else {
        reloadBlock();
    }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    NSLog(@"%@", [error localizedDescription]);
}

- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {

}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags {

}

# pragma mark AVAudioSession events

- (NSString *)currentOutputChannel {
    AVAudioSessionPortDescription *portDescription = [[[session currentRoute] outputs] firstObject];
    return portDescription.portName;
}

- (void)handleRouteChange:(NSNotification *)notification {
    NSInteger reason = [[[notification userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    switch (reason) {
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            break;
        case AVAudioSessionRouteChangeReasonOverride:
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            if ([self isPlaying]) {
                [self pause];
            }
            break;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            if ([self isPlaying]) {
                [self play];
            }
            break;
        case AVAudioSessionRouteChangeReasonUnknown:
        default:
            break;
    }
}

- (void)handleInterruption:(NSNotification *)notification {
    if (!backgroundTaskID || backgroundTaskID == UIBackgroundTaskInvalid) {
        NSLog(@"Begin bg task %s (%d). App has %0.1f sec in background.", __PRETTY_FUNCTION__, __LINE__, ([UIApplication sharedApplication].backgroundTimeRemaining > 10000.0f)? -1.0f : [UIApplication sharedApplication].backgroundTimeRemaining);
        backgroundTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskID];
            backgroundTaskID = UIBackgroundTaskInvalid;
            NSLog(@"bg task exceeded time limit: %s (%d)", __PRETTY_FUNCTION__, __LINE__);
        }];
    } else {
        NSLog(@"App has %0.1f sec in background remaining: %s (%d)", ([UIApplication sharedApplication].backgroundTimeRemaining > 10000.0f)? -1.0f : [UIApplication sharedApplication].backgroundTimeRemaining, __PRETTY_FUNCTION__, __LINE__);
    }
    
    NSUInteger reason = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] integerValue];
    
    if (reason == AVAudioSessionInterruptionTypeBegan) {
        playedBeforeInterruption = [self isPlaying] || playedBeforeInterruption;
        [self pause];
        
        UIBackgroundTaskIdentifier bgTask = backgroundTaskID;
        backgroundTaskID = UIBackgroundTaskInvalid;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (bgTask && bgTask != UIBackgroundTaskInvalid) {
                NSLog(@"End bg task %s (%d)", __PRETTY_FUNCTION__, __LINE__);
                [[UIApplication sharedApplication] endBackgroundTask:bgTask];
            }
        });
    } else if (reason == AVAudioSessionInterruptionTypeEnded) {
        NSInteger secondReason = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionOptionKey] integerValue];
        if (secondReason == AVAudioSessionInterruptionOptionShouldResume) {
            [self reloadSession];
            shouldPostCurrentTime = NO;
            if (![self loadRemoteSongWithCurrentTime:lastPlayedTime]) {
                shouldPlayAtTime = lastPlayedTime;
                if (playedBeforeInterruption) {
                    shouldPlay = YES;
                }
                [self loadSong];
            } else {
                [self setCurrentTime:@(lastPlayedTime)];
                if (playedBeforeInterruption) {
                    [self play];
                }
                UIBackgroundTaskIdentifier bgTask = backgroundTaskID;
                backgroundTaskID = UIBackgroundTaskInvalid;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (bgTask && bgTask != UIBackgroundTaskInvalid) {
                        NSLog(@"End bg task %s (%d)", __PRETTY_FUNCTION__, __LINE__);
                        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                    }
                });
            }
            shouldPostCurrentTime = YES;
			playedBeforeInterruption = NO;
        }
    }
}

- (void)handleMediaServicesWereLost:(NSNotification *)notification {
    if (!backgroundTaskID || backgroundTaskID == UIBackgroundTaskInvalid) {
        NSLog(@"Begin bg task %s (%d). App has %0.1f sec in background.", __PRETTY_FUNCTION__, __LINE__, ([UIApplication sharedApplication].backgroundTimeRemaining > 10000.0f)? -1.0f : [UIApplication sharedApplication].backgroundTimeRemaining);
        backgroundTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskID];
            backgroundTaskID = UIBackgroundTaskInvalid;
            NSLog(@"bg task exceeded time limit: %s (%d)", __PRETTY_FUNCTION__, __LINE__);
        }];
    } else {
        NSLog(@"App has %0.1f sec in background remaining: %s (%d)", ([UIApplication sharedApplication].backgroundTimeRemaining > 10000.0f)? -1.0f : [UIApplication sharedApplication].backgroundTimeRemaining, __PRETTY_FUNCTION__, __LINE__);
    }
}

- (void)handleMediaServicesWereReset:(NSNotification *)notification {
    if (!backgroundTaskID || backgroundTaskID == UIBackgroundTaskInvalid) {
        NSLog(@"Begin bg task %s (%d). App has %0.1f sec in background.", __PRETTY_FUNCTION__, __LINE__, ([UIApplication sharedApplication].backgroundTimeRemaining > 10000.0f)? -1.0f : [UIApplication sharedApplication].backgroundTimeRemaining);
        backgroundTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskID];
            backgroundTaskID = UIBackgroundTaskInvalid;
            NSLog(@"bg task exceeded time limit: %s (%d)", __PRETTY_FUNCTION__, __LINE__);
        }];
    } else {
        NSLog(@"App has %0.1f sec in background remaining: %s (%d)", ([UIApplication sharedApplication].backgroundTimeRemaining > 10000.0f)? -1.0f : [UIApplication sharedApplication].backgroundTimeRemaining, __PRETTY_FUNCTION__, __LINE__);
    }

    [self reloadSession];
    
    BOOL wasPlaying = [self isPlaying];
    
    void  (^reloadBlock)() = ^{
        shouldPostCurrentTime = NO;
        if (![self loadRemoteSongWithCurrentTime:lastPlayedTime]) {
            shouldPlayAtTime = lastPlayedTime;
            if (wasPlaying) {
                shouldPlay = YES;
            }
            [self loadSong];
        } else {
            [self setCurrentTime:@(lastPlayedTime)];
            if (wasPlaying) {
                [self play];
            }
            UIBackgroundTaskIdentifier bgTask = backgroundTaskID;
            backgroundTaskID = UIBackgroundTaskInvalid;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (bgTask && bgTask != UIBackgroundTaskInvalid) {
                    NSLog(@"End bg task %s (%d)", __PRETTY_FUNCTION__, __LINE__);
                    [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                }
            });
        }
        shouldPostCurrentTime = YES;
    };
    
    if (![self.cacheClient isSongCached:self.queue.currentSong] && [[LPOfflineChecker defaultChecker] isOffline]) {
        if (wasPlaying) {
            [self playNext];
        } else {
            [self nextInternal];
        }
    } else if (lastPlayedTime >= self.queue.currentSong.duration - 5.0) {
        if (wasPlaying) {
            [self playNext];
        } else {
            [self nextInternal];
        }
    } else if (shouldSkipIfFailedToReload) {
        shouldSkipIfFailedToReload = NO;
        if (wasPlaying) {
            [self playNext];
        } else {
            [self nextInternal];
        }
    } else if ([self.cacheClient isSongCached:self.queue.currentSong]) {
        shouldSkipIfFailedToReload = YES;
        reloadBlock();
    } else {
        reloadBlock();
    }
}

# pragma mark Remote Control events

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    if (event.type == UIEventTypeRemoteControl){
        switch (event.subtype) {
            case UIEventSubtypeRemoteControlPreviousTrack:
                [self previous];
                [self play];
                break;
            case UIEventSubtypeRemoteControlPlay:
                [self play];
                break;
            case UIEventSubtypeRemoteControlNextTrack:
                [self next];
                [self play];
                break;
            case UIEventSubtypeRemoteControlPause:
                [self pause];
                break;
            case UIEventSubtypeRemoteControlTogglePlayPause:
                if ([self isPlaying])
                    [self pause];
                else
                    [self play];
                break;
            default:
                break;
        }
    }
}

# pragma mark MPNowPlayingInfoCenter

- (void)initRemoteControls {
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    
    BOOL currentSongAvailable = self.queue.currentSong != nil;
    
    [commandCenter.togglePlayPauseCommand setEnabled:currentSongAvailable];
    [commandCenter.togglePlayPauseCommand removeTarget:playPauseCommandHandler];
    playPauseCommandHandler = nil;
    playPauseCommandHandler = [commandCenter.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        if (![self isPlaying]) {
            [self play];
        } else {
            [self pause];
        }
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    [commandCenter.playCommand setEnabled:currentSongAvailable];
    [commandCenter.playCommand removeTarget:playCommandHandler];
    playCommandHandler = nil;
    playCommandHandler = [commandCenter.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        [self play];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    [commandCenter.pauseCommand setEnabled:currentSongAvailable];
    [commandCenter.pauseCommand removeTarget:pauseCommandHandler];
    pauseCommandHandler = nil;
    pauseCommandHandler = [commandCenter.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        [self pause];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    [commandCenter.nextTrackCommand setEnabled:currentSongAvailable];
    [commandCenter.nextTrackCommand removeTarget:nextCommandHandler];
    nextCommandHandler = nil;
    nextCommandHandler = [commandCenter.nextTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        BOOL wasPlaying = [self isPlaying];
        [self next];
        if (wasPlaying) {
            [self play];
        }
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    [commandCenter.previousTrackCommand setEnabled:currentSongAvailable];
    [commandCenter.previousTrackCommand removeTarget:previousCommandHandler];
    previousCommandHandler = nil;
    previousCommandHandler = [commandCenter.previousTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        BOOL wasPlaying = [self isPlaying];
        [self previous];
        if (wasPlaying) {
            [self play];
        }
        return MPRemoteCommandHandlerStatusSuccess;
    }];
}

- (void)setNowPlayingInfo {
    if (![MPNowPlayingInfoCenter class]) {
        return;
    }
    
    LPAudioPlayerItem *song = self.queue.currentSong;
    [self initRemoteControls];
	
	NSMutableArray *keys = [NSMutableArray array];
	NSMutableArray *values = [NSMutableArray array];
	
	if (song.title) {
		[keys addObject:MPMediaItemPropertyTitle];
		[values addObject:song.title];
	}
	if (song.artistTitle) {
		[keys addObject:MPMediaItemPropertyArtist];
		[values addObject:song.artistTitle];
	}
	if (song.albumTitle) {
		[keys addObject:MPMediaItemPropertyAlbumTitle];
		[values addObject:song.albumTitle];
	}
	if (song.duration > 0) {
		[keys addObject:MPMediaItemPropertyPlaybackDuration];
		[values addObject:@(song.duration)];
	}
	[keys addObject:MPNowPlayingInfoPropertyPlaybackRate];
	[values addObject:[NSNumber numberWithInt:1]];
	[keys addObject:MPNowPlayingInfoPropertyElapsedPlaybackTime];
	[values addObject:[self currentTime]];
	
    NSString *imageURL = [song.coverImageURL absoluteString];
    
    if ([[LPImageDownloadManager defaultManager] hasImageForURL:imageURL]) {
		UIImage *image = [[LPImageDownloadManager defaultManager] getImageForURL:imageURL];
		MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:image.size requestHandler:^UIImage * _Nonnull(CGSize size) {
			return [image scaledImageToSize:size];
		}];
		if (artwork) {
			[keys addObject:MPMediaItemPropertyArtwork];
			[values addObject:artwork];
		}
    } else {
        [[LPImageDownloadManager defaultManager] getImageForURL:imageURL completion:^(UIImage *image) {
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self setNowPlayingInfo];
                });
            }
        }];
    }
    
    NSDictionary *mediaInfo = [NSDictionary dictionaryWithObjects:values forKeys:keys];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:mediaInfo];
}

- (void)recordCurrentPlayingTime {
    NSTimeInterval currentTime = self.player.currentTime;
    if (self.player && self.player.playing && currentTime > 0.5f) {
        lastPlayedTime = currentTime;
        if (lastPlayedTime >= [self.queue.currentSong duration]-0.2f) {
            [self playNext];
        }
    }
}

@end
