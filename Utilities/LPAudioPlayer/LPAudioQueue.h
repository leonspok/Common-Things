//
//  LPAudioQueue.h
//  Leonspok
//
//  Created by Игорь Савельев on 03/06/16.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPAudioPlayerItem.h"

extern NSString *const kQueueChangedNotification;
extern NSString *const kCurrentSongChangedNotification;
extern NSString *const kQueueChangedNotificationQueueKey;

@interface LPAudioQueue : NSObject {
	NSUInteger _currentSongIndex;
	NSMutableArray<__kindof LPAudioPlayerItem *> *_songs;
}

@property (nonatomic, readonly) LPAudioPlayerItem *currentSong;
@property (nonatomic) NSUInteger currentSongIndex;

@property (nonatomic, strong) NSArray<__kindof LPAudioPlayerItem *> *songs;

- (void)addSongs:(NSArray<__kindof LPAudioPlayerItem *> *)newSongs;
- (void)insertSong:(LPAudioPlayerItem *)song atIndex:(NSUInteger)index;
- (void)moveSongAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;
- (void)removeSongAtIndex:(NSUInteger)index;
- (void)removeSongAtIndexes:(NSIndexSet *)indexSet;
- (void)removeSongs:(NSArray<__kindof LPAudioPlayerItem *> *)songs;

@end
