//
//  NSFileManager+FolderSize.m
//  Musix
//
//  Created by Игорь Савельев on 09/09/16.
//  Copyright © 2016 mBox. All rights reserved.
//

#import "NSFileManager+FolderSize.h"

@implementation NSFileManager (FolderSize)

- (NSNumber *)folderSizeAtURL:(NSURL *)url {
    NSArray *prefetchedProperties = @[NSURLIsRegularFileKey,NSURLFileAllocatedSizeKey,NSURLTotalFileAllocatedSizeKey,NSURLIsDirectoryKey];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:url
                                                             includingPropertiesForKeys:prefetchedProperties
                                                                                options:0
                                                                           errorHandler:nil];

    unsigned long long size = 0;
    for (NSURL *contentURL in enumerator) {
        NSNumber *isDirectory;
        if (![contentURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil]) {
            return @0;
        }
        if ([isDirectory boolValue]) {
            size += [[self folderSizeAtURL:contentURL] unsignedLongLongValue];
            continue;
        }
        
        NSNumber *isRegularFile;
        if (![contentURL getResourceValue:&isRegularFile forKey:NSURLIsRegularFileKey error:nil]) {
            return @0;
        }
        if (![isRegularFile boolValue]) {
            continue;
        }
        
        NSNumber *fileSize;
        if (![contentURL getResourceValue:&fileSize forKey:NSURLTotalFileAllocatedSizeKey error:nil]) {
            return @0;
        }

        if (fileSize == nil) {
            if (![contentURL getResourceValue:&fileSize forKey:NSURLFileAllocatedSizeKey error:nil]) {
                return @0;
            }
        }
        
        size += [fileSize unsignedLongLongValue];
    }
    
    return [NSNumber numberWithUnsignedLongLong:size];
}

@end
