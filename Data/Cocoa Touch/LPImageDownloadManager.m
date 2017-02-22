//
//  LPImageDownloadManager.m
//  Leonspok
//
//  Created by Игорь Савельев on 28/01/14.
//  Copyright (c) 2014 Leonspok. All rights reserved.
//

#import "LPImageDownloadManager.h"
#import "NSString+MD5.h"
#import "UIImage+ImageEffects.h"
#import "LPFileDownloader.h"
#import "NSFileManager+FolderSize.h"

#define REQUIRED_FREE_SPACE_ON_DEVICE 128
#define DEFAULT_MAX_STORAGE_TIME 14*24*3600
#define DEFAULT_CHECK_CACHE_INTERVAL 300
#define DEFAULT_MAX_CACHE_CAPACITY_MB 128
#define DEFAULT_IN_MEMORY_CACHE_COUNT_LIMIT 50
#define DEFAULT_IN_MEMORY_CACHE_TOTAL_COST_LIMIT 400

@implementation LPImageDownloadManager {
    NSCache *imageCache;
    NSOperationQueue *renderOperationQueue;
	NSTimer *clearCacheTimer;
}

@synthesize checkCacheInterval = _checkCacheInterval,
			inMemoryCacheCountLimit = _inMemoryCacheCountLimit,
			inMemoryCacheTotalCostLimit = _inMemoryCacheTotalCostLimit,
			pathToCacheFolder = _pathToCacheFolder,
			pathToPermanentCacheFolder = _pathToPermanentCacheFolder;

+ (instancetype)defaultManager {
    static LPImageDownloadManager *manager = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        manager = [[LPImageDownloadManager alloc] init];
    });
    return manager;
}

- (id)init {
    self = [super init];
    if(self) {
        renderOperationQueue = [[NSOperationQueue alloc] init];
        renderOperationQueue.name = @"render images operation queue";
		
		self.fileDownloader = [LPFileDownloader sharedDownloader];
        
        imageCache = [[NSCache alloc] init];
        [imageCache setName:@"images"];
        [imageCache setTotalCostLimit:self.inMemoryCacheTotalCostLimit];
        [imageCache setCountLimit:self.inMemoryCacheCountLimit];
        
        [self createCacheFolderIfNeeded];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			clearCacheTimer = [NSTimer scheduledTimerWithTimeInterval:self.checkCacheInterval target:self selector:@selector(clearCacheIfNeeded) userInfo:nil repeats:YES];
		});
    }
    return self;
}

#pragma mark Cache Management

- (NSString *)pathToCacheFolder {
	if (!_pathToCacheFolder) {
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
		NSString *pathToCacheFolder = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Cache"];
		return pathToCacheFolder;
	}
	return _pathToCacheFolder;
}

- (void)setPathToCacheFolder:(NSString *)pathToCacheFolder {
	if (pathToCacheFolder.length > 0) {
		_pathToCacheFolder = pathToCacheFolder;
		[self createCacheFolderIfNeeded];
	}
}

- (void)createCacheFolderIfNeeded {
	BOOL isDirectory;
	if (![[NSFileManager defaultManager] fileExistsAtPath:self.pathToCacheFolder isDirectory:&isDirectory]) {
		[[NSFileManager defaultManager] createDirectoryAtPath:self.pathToCacheFolder
								  withIntermediateDirectories:NO
												   attributes:nil
														error:nil];
	} else if (!isDirectory) {
		[[NSFileManager defaultManager] removeItemAtPath:self.pathToCacheFolder error:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:self.pathToCacheFolder
								  withIntermediateDirectories:NO
												   attributes:nil
														error:nil];
	}
}

- (NSNumber *)cacheCapacity {
	return [[NSFileManager defaultManager] folderSizeAtURL:[NSURL fileURLWithPath:self.pathToCacheFolder]];
}

- (NSTimeInterval)maxCacheStorageTime {
	if (_maxCacheStorageTime <= 0) {
		_maxCacheStorageTime = DEFAULT_MAX_STORAGE_TIME;
	}
	return _maxCacheStorageTime;
}

- (NSNumber *)maxCacheCapacityInMB {
	if (!_maxCacheCapacityInMB) {
		_maxCacheCapacityInMB = @(DEFAULT_MAX_CACHE_CAPACITY_MB);
	}
	return _maxCacheCapacityInMB;
}

- (NSTimeInterval)checkCacheInterval {
	if (_checkCacheInterval <= 0.0f) {
		_checkCacheInterval = DEFAULT_CHECK_CACHE_INTERVAL;
	}
	return _checkCacheInterval;
}

- (void)setCheckCacheInterval:(NSTimeInterval)checkCacheInterval {
	if (checkCacheInterval > 0) {
		_checkCacheInterval = checkCacheInterval;
		dispatch_async(dispatch_get_main_queue(), ^{
			if (clearCacheTimer) {
				[clearCacheTimer invalidate];
				clearCacheTimer = nil;
			}
			clearCacheTimer = [NSTimer scheduledTimerWithTimeInterval:self.checkCacheInterval target:self selector:@selector(clearCacheIfNeeded) userInfo:nil repeats:YES];
		});
	}
}

- (NSUInteger)inMemoryCacheCountLimit {
	if (_inMemoryCacheCountLimit == 0) {
		_inMemoryCacheCountLimit = DEFAULT_IN_MEMORY_CACHE_COUNT_LIMIT;
	}
	return _inMemoryCacheCountLimit;
}

- (void)setInMemoryCacheCountLimit:(NSUInteger)inMemoryCacheCountLimit {
	if (inMemoryCacheCountLimit > 0) {
		_inMemoryCacheCountLimit = inMemoryCacheCountLimit;
		[imageCache setCountLimit:self.inMemoryCacheCountLimit];
	}
}

- (NSUInteger)inMemoryCacheTotalCostLimit {
	if (_inMemoryCacheTotalCostLimit == 0) {
		_inMemoryCacheTotalCostLimit = DEFAULT_IN_MEMORY_CACHE_TOTAL_COST_LIMIT;
	}
	return _inMemoryCacheTotalCostLimit;
}

- (void)setInMemoryCacheTotalCostLimit:(NSUInteger)inMemoryCacheTotalCostLimit {
	if (inMemoryCacheTotalCostLimit) {
		inMemoryCacheTotalCostLimit = inMemoryCacheTotalCostLimit;
		[imageCache setTotalCostLimit:self.inMemoryCacheTotalCostLimit];
	}
}

- (void)clearCacheIfNeeded {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.pathToCacheFolder error:nil];
		for (NSString *file in contents) {
			NSString *path = [self.pathToCacheFolder stringByAppendingPathComponent:file];
			NSDate *created = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] objectForKey:@"NSFileCreationDate"];
			if ([created compare:[[NSDate date] dateByAddingTimeInterval:-self.maxCacheStorageTime]] == NSOrderedAscending) {
				[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
			}
			
			if ([[self cacheCapacity] compare:self.maxCacheCapacityInMB] == NSOrderedDescending) {
				[self clearUnusedCache];
			}
		}
	});
}

- (void)clearCache {
	[[NSFileManager defaultManager] removeItemAtPath:self.pathToCacheFolder error:nil];
	[self createCacheFolderIfNeeded];
}

- (void)clearUnusedCache {
	NSError *error = nil;
	NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:self.pathToCacheFolder] includingPropertiesForKeys:@[NSURLContentModificationDateKey,NSURLFileSizeKey] options:0 error:&error];
	contents = [contents sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
		NSDate *date1, *date2;
		[obj1 getResourceValue:&date1 forKey:NSURLContentAccessDateKey error:nil];
		[obj2 getResourceValue:&date2 forKey:NSURLContentAccessDateKey error:nil];
		if (!date1) {
			[obj1 getResourceValue:&date1 forKey:NSURLContentModificationDateKey error:nil];
		}
		if (!date2) {
			[obj2 getResourceValue:&date2 forKey:NSURLContentModificationDateKey error:nil];
		}
		return [date1 compare:date2];
	}];
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
	NSNumber *freeSpaceNumber = [dictionary objectForKey:NSFileSystemFreeSize];
	double freeSpace = freeSpaceNumber.doubleValue/1024/1024;
	
	NSDate *startDate = [NSDate date];
	double cacheCapacity = [[self cacheCapacity] doubleValue];
	double folderSize = cacheCapacity/1024/1024;
	for (NSInteger i = 0; i < contents.count && (folderSize >= [self.maxCacheCapacityInMB doubleValue] || folderSize+REQUIRED_FREE_SPACE_ON_DEVICE >= freeSpace) && [[NSDate date] timeIntervalSinceDate:startDate] <= 20.0f; i++) {
		NSNumber *sizeNumber;
		NSURL *url = [contents objectAtIndex:i];
		[url getResourceValue:&sizeNumber forKey:NSURLFileSizeKey error:nil];
		[[NSFileManager defaultManager] removeItemAtURL:url error:nil];
		cacheCapacity -= sizeNumber.doubleValue;
		folderSize = cacheCapacity/1024/1024;
	}
}

#pragma mark Permanent Cache

- (NSString *)pathToPermanentCacheFolder {
	if (!_pathToPermanentCacheFolder) {
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
		NSString *pathToCacheFolder = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Images"];
		return pathToCacheFolder;
	}
	return _pathToPermanentCacheFolder;
}

- (void)setPathToPermanentCacheFolder:(NSString *)pathToPermanentCacheFolder {
	if (pathToPermanentCacheFolder.length > 0) {
		_pathToPermanentCacheFolder = pathToPermanentCacheFolder;
		[self createPermanentCacheFolderIfNeeded];
	}
}

- (void)createPermanentCacheFolderIfNeeded {
	BOOL isDirectory;
	if (![[NSFileManager defaultManager] fileExistsAtPath:self.pathToPermanentCacheFolder isDirectory:&isDirectory]) {
		[[NSFileManager defaultManager] createDirectoryAtPath:self.pathToPermanentCacheFolder
								  withIntermediateDirectories:NO
												   attributes:nil
														error:nil];
	} else if (!isDirectory) {
		[[NSFileManager defaultManager] removeItemAtPath:self.pathToPermanentCacheFolder error:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:self.pathToPermanentCacheFolder
								  withIntermediateDirectories:NO
												   attributes:nil
														error:nil];
	}
}

- (NSNumber *)permanentCacheCapacity {
	return [[NSFileManager defaultManager] folderSizeAtURL:[NSURL fileURLWithPath:self.pathToPermanentCacheFolder]];
}

- (void)clearPermanentCache {
	[[NSFileManager defaultManager] removeItemAtPath:self.pathToPermanentCacheFolder error:nil];
	[self createPermanentCacheFolderIfNeeded];
}

#pragma mark Image processing

- (UIImage *)renderImage:(UIImage *)image toSize:(CGSize)size rounded:(BOOL)rounded {
	if (rounded) {
		return [image roundedImageWithSize:size];
	} else {
		return [image scaledImageToSize:size];
	}
}

- (UIImage *)processImage:(UIImage *)source size:(TTImageSize)size rounded:(BOOL)rounded cost:(NSUInteger *)c {
	UIImage *renderedImage;
	NSUInteger cost = 0;
	switch (size) {
		case TTImageSize50px:
			renderedImage = [self renderImage:source toSize:CGSizeMake(50, 50) rounded:rounded];
			cost = 1;
			break;
		case TTImageSize100px:
			renderedImage = [self renderImage:source toSize:CGSizeMake(100, 100) rounded:rounded];
			cost = 1;
			break;
		case TTImageSize300px:
			renderedImage = [self renderImage:source toSize:CGSizeMake(300, 300) rounded:rounded];
			cost = 9;
			break;
		case TTImageSize500px:
			renderedImage = [self renderImage:source toSize:CGSizeMake(500, 500) rounded:rounded];
			cost = 25;
			break;
		case TTImageSize800px:
			renderedImage = [self renderImage:source toSize:CGSizeMake(800, 800) rounded:rounded];
			cost = 64;
			break;
		case TTImageSizeOriginal:
			if (rounded) {
				renderedImage = [self renderImage:source toSize:source.size rounded:YES];
				cost = 100;
			}
			break;
			
		default:
			break;
	}
	*c = cost;
	return renderedImage;
}

#pragma mark Downloading

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
    NSString *imagePath = [self.pathToCacheFolder stringByAppendingPathComponent:fileName];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        return nil;
    }
    
    return [[NSURL alloc] initFileURLWithPath:imagePath];
}

- (UIImage *)getImageForURL:(NSString *)url
					   size:(TTImageSize)size
					rounded:(BOOL)rounded
				  permanent:(BOOL)permanent {
	NSString *fileName = [self nameForURL:url size:size rounded:rounded];
	NSString *imagePath = permanent? [self.pathToPermanentCacheFolder stringByAppendingPathComponent:fileName] : [self.pathToCacheFolder stringByAppendingPathComponent:fileName];
	
	UIImage *image;
	if ([imageCache objectForKey:fileName]) {
		image = [imageCache objectForKey:fileName];
	} else if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
		image = [[UIImage alloc] initWithContentsOfFile:imagePath];
		if (image) {
			[imageCache setObject:image forKey:fileName];
		}
	}
	if (!image) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
			if ([imageCache objectForKey:fileName]) {
				[imageCache removeObjectForKey:fileName];
			} else if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
				[[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
			}
		});
		return nil;
	}
	return image;
}

- (void)getImageForURL:(NSString *)url
				  size:(TTImageSize)size
			   rounded:(BOOL)rounded
			 permanent:(BOOL)permanent
			completion:(void (^)(UIImage *image))completion {
	if (!url || url.length == 0) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (completion) {
				completion(nil);
			}
		});
		return;
	}
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSString *fileName = [self nameForURL:url size:size rounded:rounded];
		NSString *imagePath = permanent? [self.pathToPermanentCacheFolder stringByAppendingPathComponent:fileName] : [self.pathToCacheFolder stringByAppendingPathComponent:fileName];
		
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
			
			if (image && (size != TTImageSizeOriginal || rounded)) {
				[renderOperationQueue addOperationWithBlock:^{
					NSUInteger cost;
					UIImage *renderedImage = [self processImage:image size:size rounded:rounded cost:&cost];
					
					if (renderedImage) {
						if (fileName) {
							[imageCache setObject:renderedImage forKey:fileName cost:cost];
						}
						NSData *imageData = UIImagePNGRepresentation(renderedImage);
						[imageData writeToFile:imagePath atomically:YES];
					}
					dispatch_async(dispatch_get_main_queue(), ^{
						if (completion) {
							completion(renderedImage);
						}
					});
				}];
				return;
			}
			
			NSString *originalFileName = [self nameForURL:url size:TTImageSizeOriginal rounded:NO];
			NSString *originalImagePath = permanent? [self.pathToPermanentCacheFolder stringByAppendingPathComponent:originalFileName] : [self.pathToCacheFolder stringByAppendingPathComponent:originalFileName];
			[self.fileDownloader downloadFileFromURL:[NSURL URLWithString:url] destinationPath:originalImagePath progressBlock:nil success:^{
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					UIImage *image = [[UIImage alloc] initWithContentsOfFile:originalImagePath];
					if (image) {
						[imageCache setObject:image forKey:originalFileName cost:100];
					} else {
						dispatch_async(dispatch_get_main_queue(), ^{
							if (completion) {
								completion(nil);
							}
						});
						return;
					}
					
					if (size != TTImageSizeOriginal || rounded) {
						[renderOperationQueue addOperationWithBlock:^{
							NSUInteger cost;
							UIImage *renderedImage = [self processImage:image size:size rounded:rounded cost:&cost];
							
							if (renderedImage) {
								if (fileName) {
									[imageCache setObject:renderedImage forKey:fileName cost:cost];
								}
								NSData *imageData = UIImagePNGRepresentation(renderedImage);
								[imageData writeToFile:imagePath atomically:YES];
							}
							dispatch_async(dispatch_get_main_queue(), ^{
								if (completion) {
									completion(renderedImage);
								}
							});
						}];
					} else {
						dispatch_async(dispatch_get_main_queue(), ^{
							if (completion) {
								completion(image);
							}
						});
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
			   rounded:(BOOL)rounded
			 permanent:(BOOL)permanent {
	
	if (!url || url == (id)[NSNull null]) {
		return NO;
	}
	
	NSString *fileName = [self nameForURL:url size:size rounded:rounded];
	NSString *imagePath = permanent? [self.pathToPermanentCacheFolder stringByAppendingPathComponent:fileName] : [self.pathToCacheFolder stringByAppendingPathComponent:fileName];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
		return NO;
	}
	
	return YES;
}

- (UIImage *)getImageForURL:(NSString *)url
                       size:(TTImageSize)size
                    rounded:(BOOL)rounded {
	NSString *fileName = [self nameForURL:url size:size rounded:rounded];
	NSString *imagePath = [self.pathToCacheFolder stringByAppendingPathComponent:fileName];
	NSString *permanentImagePath = [self.pathToPermanentCacheFolder stringByAppendingPathComponent:fileName];
	
	UIImage *image;
	if ([imageCache objectForKey:fileName]) {
		image = [imageCache objectForKey:fileName];
	} else if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
		image = [[UIImage alloc] initWithContentsOfFile:imagePath];
		if (image) {
			[imageCache setObject:image forKey:fileName];
		}
	} else if ([[NSFileManager defaultManager] fileExistsAtPath:permanentImagePath]) {
		image = [[UIImage alloc] initWithContentsOfFile:permanentImagePath];
		if (image) {
			[imageCache setObject:image forKey:fileName];
		}
	}
	if (!image) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
			if ([imageCache objectForKey:fileName]) {
				[imageCache removeObjectForKey:fileName];
			}
			if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
				[[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
			}
			if ([[NSFileManager defaultManager] fileExistsAtPath:permanentImagePath]) {
				[[NSFileManager defaultManager] removeItemAtPath:permanentImagePath error:nil];
			}
		});
		return nil;
	}
	return image;
}

- (void)getImageForURL:(NSString *)url
                  size:(TTImageSize)size
               rounded:(BOOL)rounded
            completion:(void (^)(UIImage *image))completion {
	[self getImageForURL:url size:size rounded:rounded permanent:NO completion:completion];
}

- (BOOL)hasImageForURL:(NSString *)url
                  size:(TTImageSize)size
               rounded:(BOOL)rounded {
    
    if (!url || url == (id)[NSNull null]) {
        return NO;
    }
    
    NSString *fileName = [self nameForURL:url size:size rounded:rounded];
	NSString *imagePath = [self.pathToCacheFolder stringByAppendingPathComponent:fileName];
	NSString *permanentImagePath = [self.pathToPermanentCacheFolder stringByAppendingPathComponent:fileName];
	
	return ([[NSFileManager defaultManager] fileExistsAtPath:imagePath] || [[NSFileManager defaultManager] fileExistsAtPath:permanentImagePath]);
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

