//
//  TTImageDownloadManager.m
//  tentracks-ios
//
//  Created by Игорь Савельев on 28/01/14.
//  Copyright (c) 2014 10tracks. All rights reserved.
//

#import "TTImageDownloadManager.h"
#import "NSString+MD5.h"
#import "UIImage+ImageEffects.h"
#import "LPFileDownloader.h"

@implementation TTImageDownloadManager {
    NSCache *imageCache;
}

+ (instancetype)defaultManager {
    static TTImageDownloadManager *manager = nil;
    static dispatch_once_t oncePredicate;
    //NSLog(@"%s", __PRETTY_FUNCTION__);
    dispatch_once(&oncePredicate, ^{
        manager = [[TTImageDownloadManager alloc] init];
    });
    return manager;
}

- (id)init {
    self = [super init];
    if(self) {
        imageCache = [[NSCache alloc] init];
    }
    return self;
}

- (NSString *)nameForURL:(NSString *)url size:(TTImageSize)size rounded:(BOOL)rounded {
    NSString *postFix = @"";
    switch (size) {
        case TTImageSizeOriginal:
            postFix = @"";
            break;
        case TTImageSize50px:
            postFix = @"50px";
            break;
        case TTImageSize100px:
            postFix = @"100px";
            break;
        case TTImageSize300px:
            postFix = @"300px";
            break;
        case TTImageSize500px:
            postFix = @"500px";
            break;
        case TTImageSize800px:
            postFix = @"800px";
            break;
            
        default:
            break;
    }
    
    NSString *name = [NSString stringWithFormat:@"%@%@%@.png", [url MD5String], postFix, rounded? @"rounded":@""];
    return name;
}

- (NSURL *)urlToDownloadedImageFromURL:(NSString *)url
                                  size:(TTImageSize)size
                               rounded:(BOOL)rounded {
    NSString *fileName = [self nameForURL:url size:size rounded:rounded];
    NSString *imagePath = [pathToOfflineFolder stringByAppendingPathComponent:fileName];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        return nil;
    }
    
    return [[NSURL alloc] initFileURLWithPath:imagePath];
}

- (UIImage *)renderImage:(UIImage *)image toSize:(CGSize)size rounded:(BOOL)rounded {
    if (rounded) {
        return [image roundedImageWithSize:size];
    } else {
        return [image scaledImageToSize:size];
    }
}

- (UIImage *)getImageForURL:(NSString *)url
                       size:(TTImageSize)size
                    rounded:(BOOL)rounded {
    NSString *fileName = [self nameForURL:url size:size rounded:rounded];
    NSString *imagePath = [pathToOfflineFolder stringByAppendingPathComponent:fileName];
    
    if ([imageCache objectForKey:fileName]) {
        UIImage *image = [imageCache objectForKey:fileName];
        return image;
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
        return image;
    }
    return nil;
}

- (void)getImageForURL:(NSString *)url
                  size:(TTImageSize)size
               rounded:(BOOL)rounded
            completion:(void (^)(UIImage *image))completion {
    if (!url || url.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(nil);
            }
        });
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString *fileName = [self nameForURL:url size:size rounded:rounded];
        NSString *imagePath = [pathToOfflineFolder stringByAppendingPathComponent:fileName];
        
        if ([imageCache objectForKey:fileName]) {
            UIImage *image = [imageCache objectForKey:fileName];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(image);
                }
            });
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
            UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(image);
                }
            });
        } else {
            UIImage *image;
            if ([self hasImageForURL:url size:TTImageSizeOriginal]) {
                image = [self getImageForURL:url size:TTImageSizeOriginal];
            }
            for (TTImageSize s = size; s <= TTImageSize800px; s++) {
                if ([self hasImageForURL:url size:s]) {
                    image = [self getImageForURL:url size:s];
                    break;
                }
            }
            
            switch (size) {
                case TTImageSize50px:
                    image = [self renderImage:image toSize:CGSizeMake(50, 50) rounded:rounded];
                    break;
                case TTImageSize100px:
                    image = [self renderImage:image toSize:CGSizeMake(100, 100) rounded:rounded];
                    break;
                case TTImageSize300px:
                    image = [self renderImage:image toSize:CGSizeMake(300, 300) rounded:rounded];
                    break;
                case TTImageSize500px:
                    image = [self renderImage:image toSize:CGSizeMake(500, 500) rounded:rounded];
                    break;
                case TTImageSize800px:
                    image = [self renderImage:image toSize:CGSizeMake(800, 800) rounded:rounded];
                    break;
                case TTImageSizeOriginal:
                    if (rounded) {
                        image = [self renderImage:image toSize:image.size rounded:YES];
                    }
                    break;
                    
                default:
                    break;
            }
            
            if (image) {
                if (fileName) {
                    [imageCache setObject:image forKey:fileName];
                }
                NSData *imageData = UIImagePNGRepresentation(image);
                [imageData writeToFile:imagePath atomically:YES];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(image);
                    }
                });
                return;
            }
            
            NSString *originalFileName = [self nameForURL:url size:TTImageSizeOriginal rounded:NO];
            NSString *originalImagePath = [pathToOfflineFolder stringByAppendingPathComponent:originalFileName];
            [[LPFileDownloader sharedDownloader] downloadFileFromURL:[NSURL URLWithString:url] destinationPath:originalImagePath progressBlock:nil success:^{
                UIImage *image = [[UIImage alloc] initWithContentsOfFile:originalImagePath];
                if (image) {
                    [imageCache setObject:image forKey:originalFileName];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) {
                            completion(image);
                        }
                    });
                    return;
                }
                
                BOOL rerendered = NO;
                switch (size) {
                    case TTImageSize50px:
                        rerendered = YES;
                        image = [self renderImage:image toSize:CGSizeMake(50, 50) rounded:rounded];
                        break;
                    case TTImageSize100px:
                        rerendered = YES;
                        image = [self renderImage:image toSize:CGSizeMake(100, 100) rounded:rounded];
                        break;
                    case TTImageSize300px:
                        rerendered = YES;
                        image = [self renderImage:image toSize:CGSizeMake(300, 300) rounded:rounded];
                        break;
                    case TTImageSize500px:
                        rerendered = YES;
                        image = [self renderImage:image toSize:CGSizeMake(500, 500) rounded:rounded];
                        break;
                    case TTImageSize800px:
                        rerendered = YES;
                        image = [self renderImage:image toSize:CGSizeMake(800, 800) rounded:rounded];
                        break;
                    case TTImageSizeOriginal:
                        if (rounded) {
                            rerendered = YES;
                            image = [self renderImage:image toSize:image.size rounded:YES];
                        }
                        break;
                        
                    default:
                        break;
                }
                if (image && rerendered) {
                    if (fileName) {
                        [imageCache setObject:image forKey:fileName];
                    }
                    NSData *imageData = UIImagePNGRepresentation(image);
                    [imageData writeToFile:imagePath atomically:YES];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(image);
                    }
                });
            } failure:^(NSError *error) {
                NSLog(@"ERROR DOWNLOADING IMAGE: %@", [error localizedDescription]);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(nil);
                    }
                });
            }];
        }
    });
}

- (BOOL)hasImageForURL:(NSString *)url
                  size:(TTImageSize)size
               rounded:(BOOL)rounded {
    
    if (!url || url == (id)[NSNull null]) {
        return NO;
    }
    
    NSString *fileName = [self nameForURL:url size:size rounded:rounded];
    NSString *imagePath = [pathToOfflineFolder stringByAppendingPathComponent:fileName];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        return NO;
    }
    
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    if (!image) {
        [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
        return NO;
    }
    
    return YES;
}

- (UIImage *)getImageForURL:(NSString *)url size:(TTImageSize)size {
    return [self getImageForURL:url size:size rounded:NO];
}

- (void)getImageForURL:(NSString *)url size:(TTImageSize)size completion:(void (^)(UIImage *))completion {
    [self getImageForURL:url size:size rounded:NO completion:completion];
}

- (BOOL)hasImageForURL:(NSString *)url size:(TTImageSize)size {
    return [self hasImageForURL:url size:size rounded:NO];
}

- (UIImage *)getImageForURL:(NSString *)url {
    return [self getImageForURL:url size:TTImageSizeOriginal];
}

- (void)getImageForURL:(NSString *)url completion:(void (^)(UIImage *image))completion {
    [self getImageForURL:url size:TTImageSizeOriginal completion:completion];
}

- (BOOL)hasImageForURL:(NSString *)url {
    return [self hasImageForURL:url size:TTImageSizeOriginal];
}

@end
