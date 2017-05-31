//
//  LPRlmStorageAction.m
//  Tele2 Music
//
//  Created by Игорь Савельев on 31/05/2017.
//  Copyright © 2017 Warefly. All rights reserved.
//

#import "LPRlmStoredAction.h"

@implementation LPRlmStoredAction

+ (NSString *)primaryKey {
	return @"uid";
}

+ (NSArray<NSString *> *)indexedProperties {
	return @[@"uid", @"category", @"name", @"dateCreated", @"state"];
}

@end
