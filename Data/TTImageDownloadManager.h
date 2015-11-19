//
//  TTImageDownloadManager.h
//  tentracks-ios
//
//  Created by Игорь Савельев on 28/01/14.
//  Copyright (c) 2014 10tracks. All rights reserved.
//

#import "TTDownloadManager.h"

@import UIKit;

typedef enum {
    TTImageSizeOriginal,
    TTImageSize800px,
    TTImageSize500px,
    TTImageSize300px,
    TTImageSize100px,
    TTImageSize50px
} TTImageSize;

@class TTArtist, TTAlbum;

@interface TTImageDownloadManager : TTDownloadManager

- (NSURL *)urlToDownloadedImageFromURL:(NSString *)url
                                  size:(TTImageSize)size
                               rounded:(BOOL)rounded;

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
