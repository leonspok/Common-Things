//
//  LPAudioPlayer.h
//  Leonspok
//
//  Created by Игорь Савельев on 31/01/14.
//  Copyright (c) 2014 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPAudioQueue.h"
#import "LPCacheClient.h"

extern NSString *const kLPAudioPlayerPlaybackChangedNotification;
extern NSString *const kLPAudioPlayerCurrentTimeChangedNotification;
extern NSString *const kLPAudioPlayerCurrentSongChangedNotification;
extern NSString *const kLPAudioPlayerCurrentSongSkippedNotification;
extern NSString *const kLPAudioPlayerQueueChangedNotification;

typedef enum {
    LPAudioPlayerRepeatModeOff,
    LPAudioPlayerRepeatModeAll,
    LPAudioPlayerRepeatModeOne
} LPAudioPlayerRepeatMode;

@interface LPAudioPlayer : NSObject

@property (strong, nonatomic, readonly) NSNotificationCenter *notificationCenter;

@property (nonatomic, strong) LPCacheClient *cacheClient;

@property (nonatomic, strong) LPAudioQueue *queue;
@property (nonatomic) NSNumber *currentTime;

@property (nonatomic) LPAudioPlayerRepeatMode repeatMode;
@property (nonatomic) BOOL shuffle;

@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, readonly) BOOL songIsLoading;

@property (nonatomic, readonly) NSString *currentOutputChannel;

+ (instancetype)sharedPlayer;

- (void)play;
- (void)next;
- (void)previous;
- (void)pause;

- (void)softReloadQueue:(LPAudioQueue *)queue;

@end
