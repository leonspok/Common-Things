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
@property (nonatomic, strong) NSMutableArray *intSongs;
@end

@implementation LPAudioQueue

- (LPAudioPlayerItem *)currentSong {
    if (self.currentSongIndex >= self.songs.count) {
        return nil;
    }
    return [self.songs objectAtIndex:self.currentSongIndex];
}

- (void)setSongs:(NSArray *)songs {
    LPAudioPlayerItem *oldCurrentSong = self.currentSong;
    self.intSongs = [songs mutableCopy];
    if ([self.songs containsObject:oldCurrentSong]) {
        _currentSongIndex = [self.songs indexOfObject:oldCurrentSong];
    } else {
        _currentSongIndex = 0;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kQueueChangedNotification object:self userInfo:@{kQueueChangedNotificationQueueKey:self}];
}

- (NSArray *)songs {
    return self.intSongs;
}

- (void)setCurrentSongIndex:(NSUInteger)currentSongIndex {
    _currentSongIndex = currentSongIndex;
    [[NSNotificationCenter defaultCenter] postNotificationName:kCurrentSongChangedNotification object:self userInfo:@{kQueueChangedNotificationQueueKey:self}];
}

- (void)addSongs:(NSArray<__kindof LPAudioPlayerItem *> *)newSongs {
    [self.intSongs addObjectsFromArray:newSongs];
    [[NSNotificationCenter defaultCenter] postNotificationName:kQueueChangedNotification object:self userInfo:@{kQueueChangedNotificationQueueKey:self}];
}

- (void)insertSong:(LPAudioPlayerItem *)song atIndex:(NSUInteger)index {
    if (index < self.currentSongIndex) {
        _currentSongIndex++;
    }
    [self.intSongs insertObject:song atIndex:index];
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
    LPAudioPlayerItem *temp = [self.intSongs objectAtIndex:fromIndex];
    [self.intSongs removeObject:temp];
    [self.intSongs insertObject:temp atIndex:toIndex];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kQueueChangedNotification object:self userInfo:@{kQueueChangedNotificationQueueKey:self}];
}

- (void)removeSongAtIndex:(NSUInteger)index {
    if (index < self.currentSongIndex) {
        _currentSongIndex--;
    } else if (index == self.currentSongIndex && self.currentSongIndex == self.intSongs.count-1) {
        _currentSongIndex = 0;
    }
    [self.intSongs removeObjectAtIndex:index];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kQueueChangedNotification object:self userInfo:@{kQueueChangedNotificationQueueKey:self}];
}

- (void)removeSongAtIndexes:(NSIndexSet *)indexSet {
    [indexSet enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger index, BOOL * _Nonnull stop) {
        if (index < self.currentSongIndex) {
            _currentSongIndex--;
        } else if (index == self.currentSongIndex && self.currentSongIndex == self.intSongs.count-1) {
            _currentSongIndex = 0;
        }
        [self.intSongs removeObjectAtIndex:index];
    }];
    [[NSNotificationCenter defaultCenter] postNotificationName:kQueueChangedNotification object:self userInfo:@{kQueueChangedNotificationQueueKey:self}];
}

- (void)removeSongs:(NSArray<__kindof LPAudioPlayerItem *> *)songs {
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    for (NSUInteger i = 0; i < self.intSongs.count; i++) {
        LPAudioPlayerItem *s = [self.intSongs objectAtIndex:i];
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
