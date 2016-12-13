//
//  LPSongCachingOperationFactory.h
//  Leonspok
//
//  Created by Игорь Савельев on 05/12/2016.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPSongCachingOperation.h"

@interface LPSongCachingOperationFactory : NSObject

- (nullable NSString *)pathToFinishedFileForSong:(nonnull LPAudioPlayerItem *)song
							   pathToCacheFolder:(nonnull NSString *)path
										   owner:(nonnull NSString *)owner;

- (nullable NSString *)pathToTempFileForSong:(nonnull LPAudioPlayerItem *)song
						   pathToCacheFolder:(nonnull NSString *)path
									   owner:(nonnull NSString *)owner;

- (nullable __kindof LPSongCachingOperation *)operationForSong:(nonnull LPAudioPlayerItem *)item pathToCacheFolder:(nonnull NSString *)pathToFolder owner:(nonnull NSString *)owner;

@end
