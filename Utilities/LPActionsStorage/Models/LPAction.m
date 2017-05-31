//
//  LPAction.m
//  Tele2 Music
//
//  Created by Игорь Савельев on 31/05/2017.
//  Copyright © 2017 Warefly. All rights reserved.
//

#import "LPAction.h"

@implementation LPAction

+ (instancetype)createNewWithCategory:(NSString *)category name:(NSString *)name additionalData:(NSDictionary<NSString *, id<NSCoding>> *)additionalData {
	if (category.length == 0 || name.length == 0) {
		return nil;
	}
	
	LPAction *action = [[LPAction alloc] init];
	action.uid = [[NSUUID UUID] UUIDString];
	action.category = category;
	action.name = name;
	action.additionalData = [additionalData mutableCopy];
	action.dateCreated = [NSDate date];
	action.state = LPActionStateCreated;
	return action;
}

- (void)setAdditionalDataObject:(id<NSCoding>)object forKey:(NSString *)key {
	if (!self.additionalData) {
		self.additionalData = [NSMutableDictionary dictionary];
	}
	if (!object) {
		[self.additionalData removeObjectForKey:key];
	} else {
		[self.additionalData setObject:object forKey:key];
	}
}

- (BOOL)isEqual:(id)object {
	if (![object isKindOfClass:self.class]) {
		return NO;
	}
	if (object == self) {
		return YES;
	}
	
	LPAction *objAction = (LPAction *)object;
	return [objAction.uid isEqualToString:self.uid];
}

- (NSUInteger)hash {
	return self.uid.hash;
}

@end
