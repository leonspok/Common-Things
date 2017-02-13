//
//  LPImageDownloadManager.h
//  Leonspok
//
//  Created by Игорь Савельев on 28/01/14.
//  Copyright (c) 2014 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>

@import UIKit;

@class LPFileDownloader;

typedef enum {
    TTImageSizeOriginal,
    TTImageSize800px,
    TTImageSize500px,
    TTImageSize300px,
    TTImageSize100px,
    TTImageSize50px
} TTImageSize;

@interface LPImageDownloadManager : NSObject

@property (nonatomic, strong) NSString *pathToCacheFolder;
@property (strong, nonatomic, readonly) NSNumber *cacheCapacity;
@property (nonatomic) NSTimeInterval maxCacheStorageTime;
@property (nonatomic, strong) NSNumber *maxCacheCapacityInMB;
@property (nonatomic) NSTimeInterval checkCacheInterval;
@property (nonatomic) NSUInteger inMemoryCacheCountLimit;
@property (nonatomic) NSUInteger inMemoryCacheTotalCostLimit;

@property (nonatomic, strong) NSString *pathToPermanentCacheFolder;
@property (nonatomic, strong, readonly) NSNumber *permanentCacheCapacity;

@property (nonatomic, strong) LPFileDownloader *fileDownloader;

+ (instancetype)defaultManager;

- (void)clearCache;

- (NSURL *)urlToDownloadedImageFromURL:(NSString *)url
                                  size:(TTImageSize)size
                               rounded:(BOOL)rounded;

- (UIImage *)getImageForURL:(NSString *)url
					   size:(TTImageSize)size
					rounded:(BOOL)rounded
				  permanent:(BOOL)permanent;
- (void)getImageForURL:(NSString *)url
				  size:(TTImageSize)size
			   rounded:(BOOL)rounded
			 permanent:(BOOL)permanent
			completion:(void (^)(UIImage *image))completion;
- (BOOL)hasImageForURL:(NSString *)url
				  size:(TTImageSize)size
			   rounded:(BOOL)rounded
			 permanent:(BOOL)permanent;

- (UIImage *)getImageForURL:(NSString *)url
                       size:(TTImageSize)size
                    rounded:(BOOL)rounded;
- (void)getImageForURL:(NSString *)url
                  size:(TTImageSize)size
               rounded:(BOOL)rounded
            completion:(void (^)(UIImage *image))completion;
- (BOOL)hasImageForURL:(NSString *)url
                  size:(TTImageSize)size
               rounded:(BOOL)rounded;

- (UIImage *)getImageForURL:(NSString *)url
                       size:(TTImageSize)size;
- (void)getImageForURL:(NSString *)url
                  size:(TTImageSize)size
            completion:(void (^)(UIImage *image))completion;
- (BOOL)hasImageForURL:(NSString *)url
                  size:(TTImageSize)size;

- (UIImage *)getImageForURL:(NSString *)url;
- (void)getImageForURL:(NSString *)url
            completion:(void (^)(UIImage *image))completion;
- (BOOL)hasImageForURL:(NSString *)url;

@end
