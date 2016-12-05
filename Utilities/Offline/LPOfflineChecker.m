//
//  LPOfflineChecker.m
//  Leonspok
//
//  Created by Игорь Савельев on 15/01/14.
//  Copyright (c) 2014 10tracks. All rights reserved.
//

#import "LPOfflineChecker.h"
#import "Reachability.h"

@import UIKit;

NSString *const kOfflineStatusChangedNotification = @"kOfflineStatusChanged";

@interface LPOfflineChecker()
@property (atomic, readwrite) BOOL offline;
@property (atomic, readwrite) LPNetworkConnection networkConnection;
@end

@implementation LPOfflineChecker {
    Reachability *reachability;
}

+ (instancetype)defaultChecker {
    static LPOfflineChecker *_checker = nil;
    static dispatch_once_t oncePresicate;
    dispatch_once(&oncePresicate, ^{
        _checker = [[LPOfflineChecker alloc] init];
    });
    return _checker;
}

- (id)init {
    self = [super init];
    if (self) {
        _notificationCenter = [[NSNotificationCenter alloc] init];
        
        reachability = [Reachability reachabilityForInternetConnection];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged) name:kReachabilityChangedNotification object:nil];
        [self setEnabled:YES];
        [self reachabilityChanged];
        [NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(reachabilityChanged) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)reachabilityChanged {
    LPNetworkConnection newConnection;
    switch(reachability.currentReachabilityStatus) {
        case NotReachable: {
            newConnection = LPNetworkConnectionNone;
        }
            break;
        case ReachableViaWiFi: {
            newConnection = LPNetworkConnectionWIFI;
        }
            break;
        case ReachableViaWWAN:{
            newConnection = LPNetworkConnectionCellular;
        }
            break;
    }
	
    LPNetworkConnection connection = self.networkConnection;
    if (newConnection != self.networkConnection) {
        connection = newConnection;
    }
    
    switch (connection) {
        case LPNetworkConnectionNone:
            self.offline = YES;
            break;
        case LPNetworkConnectionCellular:
        case LPNetworkConnectionWIFI:
            self.offline = NO;
            break;
            
        default:
            break;
    }
    
    if (newConnection != self.networkConnection) {
        NSLog(@"REACHABILITY CHANGED");
        self.networkConnection = newConnection;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.notificationCenter postNotificationName:kOfflineStatusChangedNotification object:nil];
        });
    }
}

- (BOOL)isOffline {
    BOOL offline = _offline;
    return offline;
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    if (enabled) {
        [reachability startNotifier];
    } else {
        [reachability stopNotifier];
    }
}

@end
