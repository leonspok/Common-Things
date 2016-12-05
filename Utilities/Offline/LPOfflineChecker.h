//
//  LPOfflineChecker.h
//  Leonspok
//
//  Created by Игорь Савельев on 15/01/14.
//  Copyright (c) 2014 10tracks. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const kOfflineStatusChangedNotification;

enum {
	LPNetworkConnectionWIFI,
    LPNetworkConnectionCellular,
    LPNetworkConnectionNone
} typedef LPNetworkConnection;

@interface LPOfflineChecker : NSObject

@property (nonatomic, readonly) NSNotificationCenter *notificationCenter;

@property (nonatomic) BOOL enabled;
@property (atomic, readonly) BOOL offline;
@property (atomic, readonly) LPNetworkConnection networkConnection;

+ (instancetype)defaultChecker;
- (BOOL)isOffline;

@end
