//
//  LPRlmStorageAction+Converting.m
//  Tele2 Music
//
//  Created by Игорь Савельев on 31/05/2017.
//  Copyright © 2017 Warefly. All rights reserved.
//

#import "LPRlmStoredAction+Converting.h"

@implementation LPRlmStoredAction (Converting)

+ (instancetype)instanceWithLPAction:(LPAction *)action {
	LPRlmStoredAction *object = [[LPRlmStoredAction alloc] init];
	[object updateValuesWithLPAction:action];
	return object;
}

- (void)updateValuesWithLPAction:(LPAction *)action {
	self.uid = action.uid;
	self.category = action.category;
	self.name = action.name;
	self.dateCreated = action.dateCreated;
	self.dateSent = action.dateSent;
	self.state = (int)action.state;
	self.additionalData = [NSKeyedArchiver archivedDataWithRootObject:action.additionalData];
}

- (void)copyValueToLPAction:(LPAction *)action {
	action.uid = self.uid;
	action.category = self.category;
	action.name = self.name;
	action.dateCreated = self.dateCreated;
	action.dateSent = self.dateSent;
	action.state = (LPActionState)self.state;
	NSDictionary *additionalData = [NSKeyedUnarchiver unarchiveObjectWithData:self.additionalData];
	action.additionalData = [additionalData mutableCopy];
}

- (LPAction *)toLPAction {
	LPAction *action = [[LPAction alloc] init];
	[self copyValueToLPAction:action];
	return action;
}

@end
