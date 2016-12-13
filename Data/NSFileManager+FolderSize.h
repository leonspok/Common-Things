//
//  NSFileManager+FolderSize.h
//  Leonspok
//
//  Created by Игорь Савельев on 09/09/16.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSFileManager (FolderSize)

- (NSNumber *)folderSizeAtURL:(NSURL *)url;

@end
