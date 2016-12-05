//
//  LPSongCachingOperationFactory.m
//  Leonspok
//
//  Created by Игорь Савельев on 05/12/2016.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import "LPSongCachingOperationFactory.h"

@implementation LPSongCachingOperationFactory

- (NSString *)pathToFinishedFileForSong:(LPAudioPlayerItem *)song
					  pathToCacheFolder:(NSString *)path
								  owner:(NSString *)owner {
	return [LPSongCachingOperation pathToFinishedFileForSong:song pathToCacheFolder:path owner:owner];
}

- (NSString *)pathToTempFileForSong:(LPAudioPlayerItem *)song
				  pathToCacheFolder:(NSString *)path
							  owner:(NSString *)owner {
	return [LPSongCachingOperation pathToTempFileForSong:song pathToCacheFolder:path owner:owner];
}

- (__kindof LPSongCachingOperation *)operationForSong:(nonnull LPAudioPlayerItem *)item pathToCacheFolder:(nonnull NSString *)pathToFolder owner:(nonnull NSString *)owner {
	return [[LPSongCachingOperation alloc] initWithSong:item pathToCacheFolder:pathToFolder owner:owner];
}

@end
