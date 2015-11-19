//
//  LPImageDownloadManager.h
//  Leonspok
//
//  Created by Игорь Савельев on 28/01/14.
//  Copyright (c) 2014 10tracks. All rights reserved.
//

#import "LPDownloadManager.h"

@import UIKit;

typedef enum {
    LPImageSizeOriginal,
    LPImageSize800px,
    LPImageSize500px,
    LPImageSize300px,
    LPImageSize100px,
    LPImageSize50px
} LPImageSize;

@interface LPImageDownloadManager : LPDownloadManager

- (NSURL *)urlToDownloadedImageFromURL:(NSString *)url
                                  size:(LPImageSize)size
                               rounded:(BOOL)rounded;

- (UIImage *)getImageForURL:(NSString *)url
                       size:(LPImageSize)size
                    rounded:(BOOL)rounded;
- (void)getImageForURL:(NSString *)url
                  size:(LPImageSize)size
               rounded:(BOOL)rounded
            completion:(void (^)(UIImage *image))completion;
- (BOOL)hasImageForURL:(NSString *)url
                  size:(LPImageSize)size
               rounded:(BOOL)rounded;

- (UIImage *)getImageForURL:(NSString *)url
                       size:(LPImageSize)size;
- (void)getImageForURL:(NSString *)url
                  size:(LPImageSize)size
            completion:(void (^)(UIImage *image))completion;
- (BOOL)hasImageForURL:(NSString *)url
                  size:(LPImageSize)size;

- (UIImage *)getImageForURL:(NSString *)url;
- (void)getImageForURL:(NSString *)url
            completion:(void (^)(UIImage *image))completion;
- (BOOL)hasImageForURL:(NSString *)url;

@end
