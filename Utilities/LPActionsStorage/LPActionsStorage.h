//
//  LPActionsStorage.h
//  Tele2 Music
//
//  Created by Игорь Савельев on 31/05/2017.
//  Copyright © 2017 Warefly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPAction.h"

@interface LPActionsStorage : NSObject

@property (nonatomic, readonly, nonnull) NSString *actionsCategory;
@property (nonatomic, readonly, nullable) NSArray<LPAction *> *pendingActions;

- (nonnull instancetype)initWithActionsCategory:(nonnull NSString *)actionsCategory NS_DESIGNATED_INITIALIZER;
- (null_unspecified instancetype)init NS_UNAVAILABLE;

- (void)addOrUpdateAction:(nonnull LPAction *)action;
- (void)addOrUpdateActions:(nonnull NSArray<LPAction *> *)actions;
- (void)clearAllActions;

@end
