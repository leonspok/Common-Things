//
//  LPAudioQueue.m
//  Leonspok
//
//  Created by Игорь Савельев on 03/06/16.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import "LPAudioQueue.h"

NSString *const kQueueChangedNotification = @"QueueChangedNotification";
NSString *const kCurrentSongChangedNotification = @"CurrentSongChangedNotification";
NSString *const kQueueChangedNotificationQueueKey = @"QueueChangedNotificationQueue";

@interface LPAudioQueue()
@end

@implementation LPAudioQueue
@synthesize currentSongIndex = _currentSongIndex, songs = _songs;

- (LPAudioPlayerItem *)currentSong {
    if (self.currentSongIndex >= self.songs.count) {
        return nil;
    }
    return [self.songs objectAtIndex:self.currentSongIndex];
}

- (void)setSongs:(NSArray *)songs {
    LPAudioPlayerItem *oldCurrentSong = self.currentSong;
    _songs = [songs mutableCopy];
    if ([self.songs containsObject:oldCurrentSong]) {
        _currentSongIndex = [self.songs indexOfObject:oldCurrentSong];
    } else {
        _currentSongIndex = 0;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kQueueChangedNotification object:self userInfo:@{kQueueChangedNotificationQueueKey:self}];
}

- (void)setCurrentSongIndex:(NSUInteger)currentSongIndex {
    _currentSongIndex = currentSongIndex;
    [[NSNotificationCenter defaultCenter] postNotificationName:kCurrentSongChangedNotification object:self userInfo:@{kQueueChangedNotificationQueueKey:self}];
}

- (void)addSongs:(NSArray<__kindof LPAudioPlayerItem *> *)newSongs {
    [_songs addObjectsFromArray:newSongs];
    [[NSNotificationCenter defaultCenter] postNotificationName:kQueueChangedNotification object:self userInfo:@{kQueueChangedNotificationQueueKey:self}];
}

- (void)insertSong:(LPAudioPlayerItem *)song atIndex:(NSUInteger)index {
    if (index < self.currentSongIndex) {
        _currentSongIndex++;
    }
    [_songs insertObject:song atIndex:index];
    [[NSNotificationCenter defaultCenter] postNotificationName:kQueueChangedNotification object:self userInfo:@{kQueueChangedNotificationQueueKey:self}];
}

- (void)moveSongAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex {
    if ((fromIndex < self.currentSongIndex && toIndex > self.currentSongIndex)) {
        _currentSongIndex--;
    } else if (fromIndex > self.currentSongIndex && toIndex <= self.currentSongIndex) {
        _currentSongIndex++;
    } else if (self.currentSongIndex == fromIndex) {
        _currentSongIndex = toIndex;
    }
    LPAudioPlayerItem *temp = [_songs objectAtIndex:fromIndex];
    [_songs removeObject:temp];
    [_songs insertObject:temp atIndex:toIndex];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kQueueChangedNotification object:self userInfo:@{kQueueChangedNotificationQueueKey:self}];
}

- (void)removeSongAtIndex:(NSUInteger)index {
    if (index < self.currentSongIndex) {
        _currentSongIndex--;
    } else if (index == self.currentSongIndex && self.currentSongIndex == self.songs.count-1) {
        _currentSongIndex = 0;
    }
    [_songs removeObjectAtIndex:index];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kQueueChangedNotification object:self userInfo:@{kQueueChangedNotificationQueueKey:self}];
}

- (void)removeSongAtIndexes:(NSIndexSet *)indexSet {
    [indexSet enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger index, BOOL * _Nonnull stop) {
        if (index < self.currentSongIndex) {
            _currentSongIndex--;
        } else if (index == self.currentSongIndex && self.currentSongIndex == self.songs.count-1) {
            _currentSongIndex = 0;
        }
        [_songs removeObjectAtIndex:index];
    }];
    [[NSNotificationCenter defaultCenter] postNotificationName:kQueueChangedNotification object:self userInfo:@{kQueueChangedNotificationQueueKey:self}];
}

- (void)removeSongs:(NSArray<__kindof LPAudioPlayerItem *> *)songs {
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    for (NSUInteger i = 0; i < self.songs.count; i++) {
        LPAudioPlayerItem *s = [self.songs objectAtIndex:i];
        for (LPAudioPlayerItem *song in songs) {
            if ([s isEqual:song]) {
                [indexSet addIndex:i];
                break;
            }
        }
    }
    [self removeSongAtIndexes:indexSet];
}

@end
