//
//  TTDownloadManager.h
//  tentracks-ios
//
//  Created by Игорь Савельев on 28/01/14.
//  Copyright (c) 2014 10tracks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TTDownloadManager : NSObject {
    NSString *pathToOfflineFolder;
}

+ (instancetype)defaultManager;

@end
