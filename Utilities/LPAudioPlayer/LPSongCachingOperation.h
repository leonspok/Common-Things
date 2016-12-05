//
//  MBSongCachingOperation.h
//  Musix
//
//  Created by Игорь Савельев on 05/03/15.
//  Copyright (c) 2015 mBox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPAudioPlayerItem.h"

@interface LPSongCachingOperation : NSObject

@property (nonatomic, strong, readonly) LPAudioPlayerItem *song;
@property (nonatomic, assign, readonly) BOOL cancelled;
@property (nonatomic, assign, readonly) BOOL finished;

@property (nonatomic, assign, readonly) double currentSpeed;
@property (nonatomic, assign, readonly) double requiredSpeed;

- (id)initWithSong:(LPAudioPlayerItem *)song
 pathToCacheFolder:(NSString *)path
             owner:(NSString *)own;

- (void)setProgressBlock:(void (^)(float progress))progressBlock;
- (void)setSuccessBlock:(void (^)())success failure:(void (^)(NSError *))failureBlock;

- (void)start;
- (void)cancel;

+ (NSString *)pathToFinishedFileForSong:(LPAudioPlayerItem *)song
                      pathToCacheFolder:(NSString *)path
                                  owner:(NSString *)owner;

+ (NSString *)pathToTempFileForSong:(LPAudioPlayerItem *)song
                  pathToCacheFolder:(NSString *)path
                              owner:(NSString *)owner;

#pragma mark Override

- (void)getStreamingURLSuccess:(void (^)(NSURL *streamingURL))success
					   failure:(void (^)(NSError *error))failure;

@end
