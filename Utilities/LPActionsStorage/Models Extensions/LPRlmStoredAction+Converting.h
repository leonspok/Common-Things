//
//  LPRlmStorageAction+Converting.h
//  Tele2 Music
//
//  Created by Игорь Савельев on 31/05/2017.
//  Copyright © 2017 Warefly. All rights reserved.
//

#import "LPRlmStoredAction.h"
#import "LPAction.h"

@interface LPRlmStoredAction (Converting)

+ (instancetype)instanceWithLPAction:(LPAction *)action;
- (void)updateValuesWithLPAction:(LPAction *)action;
- (void)copyValueToLPAction:(LPAction *)action;
- (LPAction *)toLPAction;

@end
