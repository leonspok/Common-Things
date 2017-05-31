//
//  LPActionsStorage.m
//  Tele2 Music
//
//  Created by Игорь Савельев on 31/05/2017.
//  Copyright © 2017 Warefly. All rights reserved.
//

#import "LPActionsStorage.h"
#import <Realm/Realm.h>
#import "LPRlmStoredAction+Converting.h"
#import "NSArray+Utilities.h"

@interface LPActionsStorage()
@end

@implementation LPActionsStorage

- (instancetype)initWithActionsCategory:(NSString *)actionsCategory {
	if (actionsCategory.length == 0) {
		return nil;
	}
	self = [super init];
	if (self) {
		_actionsCategory = actionsCategory;
	}
	return self;
}

- (void)addOrUpdateAction:(LPAction *)action {
	LPRlmStoredAction *rlmAction = [LPRlmStoredAction instanceWithLPAction:action];
	RLMRealm *realm = [RLMRealm defaultRealm];
	[realm beginWriteTransaction];
	[realm addOrUpdateObject:rlmAction];
	[realm commitWriteTransaction];
}

- (void)addOrUpdateActions:(NSArray<LPAction *> *)actions {
	NSArray<LPRlmStoredAction *> *rlmActions = [actions mapWithBlock:^id(id obj) {
		return [LPRlmStoredAction instanceWithLPAction:obj];
	}];
	RLMRealm *realm = [RLMRealm defaultRealm];
	[realm beginWriteTransaction];
	[realm addOrUpdateObjectsFromArray:rlmActions];
	[realm commitWriteTransaction];
}

- (NSArray<LPAction *> *)pendingActions {
	RLMResults<LPRlmStoredAction *> *results = [LPRlmStoredAction objectsWithPredicate:[NSPredicate predicateWithFormat:@"category == %@ AND state == %d", self.actionsCategory, (int)LPActionStatePending]];
	results = [results sortedResultsUsingDescriptors:@[[RLMSortDescriptor sortDescriptorWithKeyPath:@"dateCreated" ascending:YES]]];
	NSMutableArray *actions = [NSMutableArray array];
	for (LPRlmStoredAction *rlmAction in results) {
		[actions addObject:[rlmAction toLPAction]];
	}
	return actions;
}

- (void)clearAllActions {
	RLMRealm *realm = [RLMRealm defaultRealm];
	[realm beginWriteTransaction];
	[realm deleteObjects:[LPRlmStoredAction objectsWithPredicate:[NSPredicate predicateWithFormat:@"category == %@", self.actionsCategory]]];
	[realm commitWriteTransaction];
}

@end
